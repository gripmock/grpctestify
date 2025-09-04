#!/bin/bash

# system_api.sh - Kernel-level system API abstractions
# Provides unified, cross-platform system functions with stable contracts
# Part of grpctestify microkernel architecture

#######################################
# Kernel System API Version
#######################################
readonly SYSTEM_API_VERSION="1.0.0"

#######################################
# Kernel-level CPU count function (replaces nproc)
# Contract: Always returns positive integer representing CPU cores
# Returns: Number of CPU cores available to the system
#######################################
kernel_nproc() {
    local cpu_count=0
    
    # Method 1: Direct system calls (fastest)
    case "$(uname -s)" in
        "Linux")
            # Linux: Try multiple methods in order of reliability
            if [[ -r /proc/cpuinfo ]]; then
                cpu_count=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null)
            elif [[ -r /proc/stat ]]; then
                cpu_count=$(grep "^cpu[0-9]" /proc/stat 2>/dev/null | wc -l)
            elif [[ -d /sys/devices/system/cpu ]]; then
                cpu_count=$(find /sys/devices/system/cpu -name "cpu[0-9]*" -type d 2>/dev/null | wc -l)
            fi
            ;;
        "Darwin")
            # macOS: Use sysctl
            if command -v sysctl >/dev/null 2>&1; then
                cpu_count=$(sysctl -n hw.ncpu 2>/dev/null)
            fi
            ;;
        "FreeBSD"|"OpenBSD"|"NetBSD")
            # BSD variants
            if command -v sysctl >/dev/null 2>&1; then
                cpu_count=$(sysctl -n hw.ncpu 2>/dev/null)
            fi
            ;;
        "SunOS")
            # Solaris
            if command -v psrinfo >/dev/null 2>&1; then
                cpu_count=$(psrinfo 2>/dev/null | wc -l)
            fi
            ;;
        "CYGWIN_NT-"*|"MINGW"*|"MSYS_NT-"*)
            # Windows variants
            cpu_count="${NUMBER_OF_PROCESSORS:-}"
            ;;
    esac
    
    # Method 2: External tools fallback (if direct methods failed)
    if [[ -z "$cpu_count" || "$cpu_count" -le 0 ]] 2>/dev/null; then
        if command -v nproc >/dev/null 2>&1; then
            cpu_count=$(nproc 2>/dev/null)
        elif command -v sysctl >/dev/null 2>&1; then
            cpu_count=$(sysctl -n hw.ncpu 2>/dev/null)
        fi
    fi
    
    # Method 3: Environment variables
    if [[ -z "$cpu_count" || "$cpu_count" -le 0 ]] 2>/dev/null; then
        cpu_count="${NUMBER_OF_PROCESSORS:-${NPROCESSORS_ONLN:-}}"
    fi
    
    # Contract enforcement: Always return positive integer
    if [[ -n "$cpu_count" && "$cpu_count" -gt 0 ]] 2>/dev/null; then
        echo "$cpu_count"
    else
        # Reasonable default that works everywhere
        echo "4"
    fi
}

#######################################
# Kernel-level timeout function (replaces timeout/gtimeout)
# Contract: Runs command with specified timeout, returns command exit code or 124 for timeout
# Arguments:
#   1: timeout_seconds - timeout in seconds
#   2+: command and arguments to execute
# Returns: Exit code of command, or 124 if timeout occurred
#######################################
kernel_timeout() {
    local timeout_seconds="$1"
    shift
    
    # Validate timeout parameter
    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -eq 0 ]]; then
        log_error "kernel_timeout: invalid timeout value: $timeout_seconds"
        return 1
    fi
    
    # Method 1: Use system timeout if available
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_seconds" "$@"
        return $?
    fi
    
    # Method 2: Use gtimeout on macOS (if installed)
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$timeout_seconds" "$@"
        return $?
    fi
    
    # Method 3: Pure shell implementation
    local cmd_pid timeout_pid exit_code
    
    # Start command in background
    "$@" &
    cmd_pid=$!
    
    # Start timeout killer in background
    (
        sleep "$timeout_seconds"
        if kill -0 "$cmd_pid" 2>/dev/null; then
            # Send TERM first, then KILL if needed
            kill -TERM "$cmd_pid" 2>/dev/null
            sleep 1
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null
            fi
        fi
    ) &
    timeout_pid=$!
    
    # Wait for command completion
    if wait "$cmd_pid" 2>/dev/null; then
        exit_code=$?
        # Kill timeout process
        kill "$timeout_pid" 2>/dev/null
        wait "$timeout_pid" 2>/dev/null
        return $exit_code
    else
        # Command was killed by timeout
        kill "$timeout_pid" 2>/dev/null
        wait "$timeout_pid" 2>/dev/null
        return 124  # Standard timeout exit code
    fi
}

#######################################
# Kernel-level memory info function
# Contract: Returns available memory in MB, always positive integer
# Returns: Available memory in megabytes
#######################################
kernel_memory_mb() {
    local memory_mb=0
    
    case "$(uname -s)" in
        "Linux")
            if [[ -r /proc/meminfo ]]; then
                # Extract MemAvailable or MemFree
                memory_mb=$(awk '/MemAvailable/ {print int($2/1024); exit} /MemFree/ {mem=$2} /MemTotal/ {total=$2} END {if(!mem) mem=total*0.8; print int(mem/1024)}' /proc/meminfo 2>/dev/null)
            fi
            ;;
        "Darwin")
            if command -v vm_stat >/dev/null 2>&1; then
                # Calculate free memory from vm_stat
                memory_mb=$(vm_stat 2>/dev/null | awk '/Pages free/ {free=$3} /page size of/ {pagesize=$8} END {print int(free*pagesize/1024/1024)}')
            elif command -v sysctl >/dev/null 2>&1; then
                # Fallback to total memory * 0.6 (conservative estimate)
                memory_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1*0.6/1024/1024)}')
            fi
            ;;
        "FreeBSD"|"OpenBSD"|"NetBSD")
            if command -v sysctl >/dev/null 2>&1; then
                memory_mb=$(sysctl -n hw.physmem 2>/dev/null | awk '{print int($1*0.6/1024/1024)}')
            fi
            ;;
    esac
    
    # Contract enforcement: Always return reasonable positive value
    if [[ -n "$memory_mb" && "$memory_mb" -gt 0 ]] 2>/dev/null; then
        echo "$memory_mb"
    else
        # 1GB default - safe for most systems
        echo "1024"
    fi
}

#######################################
# Kernel-level disk space function
# Contract: Returns available disk space in MB for given path
# Arguments:
#   1: path - directory path to check (default: current directory)
# Returns: Available disk space in megabytes
#######################################
kernel_disk_space_mb() {
    local path="${1:-.}"
    local space_mb=0
    
    # Method 1: Use df with POSIX format
    if command -v df >/dev/null 2>&1; then
        # Use -P for portable format, 4th column is available space in KB
        space_mb=$(df -P "$path" 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
    fi
    
    # Method 2: Try alternative df formats
    if [[ -z "$space_mb" || "$space_mb" -le 0 ]] 2>/dev/null; then
        space_mb=$(df "$path" 2>/dev/null | tail -1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/ && $i > 1000) {print int($i/1024); break}}')
    fi
    
    # Contract enforcement: Always return reasonable positive value
    if [[ -n "$space_mb" && "$space_mb" -gt 0 ]] 2>/dev/null; then
        echo "$space_mb"
    else
        # 10GB default - reasonable minimum
        echo "10240"
    fi
}

#######################################
# Kernel-level process count function
# Contract: Returns number of running processes, always positive integer
# Returns: Number of currently running processes
#######################################
kernel_process_count() {
    local proc_count=0
    
    case "$(uname -s)" in
        "Linux")
            if [[ -d /proc ]]; then
                proc_count=$(find /proc -maxdepth 1 -name "[0-9]*" -type d 2>/dev/null | wc -l)
            fi
            ;;
        *)
            if command -v ps >/dev/null 2>&1; then
                proc_count=$(ps aux 2>/dev/null | wc -l)
                # Subtract header line
                proc_count=$((proc_count - 1))
            fi
            ;;
    esac
    
    # Contract enforcement
    if [[ -n "$proc_count" && "$proc_count" -gt 0 ]] 2>/dev/null; then
        echo "$proc_count"
    else
        echo "50"  # Reasonable default
    fi
}

#######################################
# Kernel-level load average function
# Contract: Returns 1-minute load average as floating point string
# Returns: System load average (1-minute)
#######################################
kernel_load_average() {
    local load_avg=""
    
    case "$(uname -s)" in
        "Linux"|"Darwin"|"FreeBSD"|"OpenBSD"|"NetBSD")
            if [[ -r /proc/loadavg ]]; then
                load_avg=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
            elif command -v uptime >/dev/null 2>&1; then
                # Parse uptime output for load average
                load_avg=$(uptime 2>/dev/null | sed 's/.*load average[s]*: \([0-9.]*\).*/\1/')
            fi
            ;;
    esac
    
    # Contract enforcement: Return valid floating point or 0.0
    if [[ "$load_avg" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$load_avg"
    else
        echo "0.0"
    fi
}

#######################################
# System API initialization
#######################################
system_api_init() {
    log_debug "Initializing System API v$SYSTEM_API_VERSION"
    
    # Verify critical functions work
    local cpu_count memory_mb
    cpu_count=$(kernel_nproc)
    memory_mb=$(kernel_memory_mb)
    
    if [[ "$cpu_count" -gt 0 && "$memory_mb" -gt 0 ]]; then
        log_debug "System API initialized: CPU=$cpu_count cores, Memory=${memory_mb}MB"
        return 0
    else
        log_error "System API initialization failed"
        return 1
    fi
}

# Export kernel functions for global use
export -f kernel_nproc
export -f kernel_timeout
export -f kernel_memory_mb
export -f kernel_disk_space_mb
export -f kernel_process_count
export -f kernel_load_average
export -f system_api_init
