#!/usr/bin/env bats

# Test suite for Kernel System API

setup() {
    # Mock tlog function
    tlog() {
        echo "TLOG [$1]: $2" >&2
    }
    
    # Source the system API
    source "$BATS_TEST_DIRNAME/system_api.sh"
}

@test "kernel_nproc: returns positive integer" {
    run kernel_nproc
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -gt 0 ]
}

@test "kernel_nproc: realistic range on actual system" {
    run kernel_nproc
    [ "$status" -eq 0 ]
    # Should be between 1 and 128 cores (reasonable range)
    [ "$output" -ge 1 ]
    [ "$output" -le 128 ]
}

@test "kernel_nproc: contract enforcement with broken system" {
    # Mock all detection methods to fail
    uname() { echo "UnknownOS"; }
    nproc() { return 127; }
    sysctl() { return 127; }
    export -f uname nproc sysctl
    
    # Mock file operations to fail
    test() {
        case "$*" in
            "-r /proc/cpuinfo"|"-r /proc/stat"|"-d /sys/devices/system/cpu")
                return 1
                ;;
            *)
                command test "$@"
                ;;
        esac
    }
    export -f test
    
    # Should still return reasonable default
    run kernel_nproc
    [ "$status" -eq 0 ]
    [ "$output" = "4" ]
}

@test "kernel_timeout: basic functionality" {
    # Test successful command
    run kernel_timeout 5 echo "test"
    [ "$status" -eq 0 ]
    [ "$output" = "test" ]
}

@test "kernel_timeout: timeout enforcement" {
    # Test command that should timeout
    run kernel_timeout 1 sleep 3
    [ "$status" -eq 124 ]  # Standard timeout exit code
}

@test "kernel_timeout: preserves command exit code" {
    # Test that non-zero exit codes are preserved
    run kernel_timeout 5 bash -c "exit 42"
    [ "$status" -eq 42 ]
}

@test "kernel_timeout: invalid timeout parameter" {
    run kernel_timeout abc echo "test"
    [ "$status" -eq 1 ]
}

@test "kernel_timeout: zero timeout parameter" {
    run kernel_timeout 0 echo "test"
    [ "$status" -eq 1 ]
}

@test "kernel_memory_mb: returns positive integer" {
    run kernel_memory_mb
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -gt 0 ]
}

@test "kernel_memory_mb: realistic range" {
    run kernel_memory_mb
    [ "$status" -eq 0 ]
    # Should be at least 64MB (very conservative), at most 1TB (reasonable range)
    [ "$output" -ge 64 ]
    [ "$output" -le 1048576 ]
}

@test "kernel_memory_mb: fallback when detection fails" {
    # Mock system detection to fail
    uname() { echo "UnknownOS"; }
    export -f uname
    
    # Mock file operations to fail
    test() {
        case "$*" in
            "-r /proc/meminfo")
                return 1
                ;;
            *)
                command test "$@"
                ;;
        esac
    }
    export -f test
    
    # Mock commands to fail
    vm_stat() { return 127; }
    sysctl() { return 127; }
    export -f vm_stat sysctl
    
    run kernel_memory_mb
    [ "$status" -eq 0 ]
    [ "$output" = "1024" ]  # Default fallback
}

@test "kernel_disk_space_mb: returns positive integer" {
    run kernel_disk_space_mb /tmp
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -gt 0 ]
}

@test "kernel_disk_space_mb: uses current directory by default" {
    run kernel_disk_space_mb
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -gt 0 ]
}

@test "kernel_disk_space_mb: fallback when df fails" {
    # Mock df to fail
    df() { return 127; }
    export -f df
    
    run kernel_disk_space_mb
    [ "$status" -eq 0 ]
    [ "$output" = "10240" ]  # Default fallback
}

@test "kernel_process_count: returns positive integer" {
    run kernel_process_count
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -gt 0 ]
}

@test "kernel_process_count: realistic range" {
    run kernel_process_count
    [ "$status" -eq 0 ]
    # Should be at least 10 processes, at most 32768 (reasonable range)
    [ "$output" -ge 10 ]
    [ "$output" -le 32768 ]
}

@test "kernel_load_average: returns valid float" {
    run kernel_load_average
    [ "$status" -eq 0 ]
    # Should be floating point number or 0.0
    [[ "$output" =~ ^[0-9]+\.?[0-9]*$ ]]
}

@test "kernel_load_average: fallback when detection fails" {
    # Mock all detection methods to fail
    test() {
        case "$*" in
            "-r /proc/loadavg")
                return 1
                ;;
            *)
                command test "$@"
                ;;
        esac
    }
    uptime() { echo "invalid output"; }
    export -f test uptime
    
    run kernel_load_average
    [ "$status" -eq 0 ]
    [ "$output" = "0.0" ]
}

@test "system_api_init: successful initialization" {
    run system_api_init
    [ "$status" -eq 0 ]
}

@test "system_api_init: logs system information" {
    run system_api_init
    [ "$status" -eq 0 ]
    [[ "$output" == *"System API initialized"* ]]
    [[ "$output" == *"CPU="* ]]
    [[ "$output" == *"Memory="* ]]
}

@test "integration: all kernel functions work together" {
    # Test that all functions can be called successfully
    local cpu_count memory_mb disk_mb proc_count load_avg
    
    cpu_count=$(kernel_nproc)
    memory_mb=$(kernel_memory_mb)
    disk_mb=$(kernel_disk_space_mb)
    proc_count=$(kernel_process_count)
    load_avg=$(kernel_load_average)
    
    # All should return reasonable values
    [ "$cpu_count" -gt 0 ]
    [ "$memory_mb" -gt 0 ]
    [ "$disk_mb" -gt 0 ]
    [ "$proc_count" -gt 0 ]
    [[ "$load_avg" =~ ^[0-9]+\.?[0-9]*$ ]]
}

@test "cross-platform: works on different OS types" {
    # Test with different uname outputs
    local os_types=("Linux" "Darwin" "FreeBSD" "SunOS")
    
    for os in "${os_types[@]}"; do
        # Mock uname for this OS
        uname() { 
            case "$1" in
                "-s") echo "$os" ;;
                *) command uname "$@" ;;
            esac
        }
        export -f uname
        
        # Should still work (even if using fallbacks)
        run kernel_nproc
        [ "$status" -eq 0 ]
        [ "$output" -gt 0 ]
        
        run kernel_memory_mb
        [ "$status" -eq 0 ]
        [ "$output" -gt 0 ]
    done
}
