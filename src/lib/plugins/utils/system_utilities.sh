#!/bin/bash

# system_utilities.sh - System utility functions extracted from kernel config
# Cross-platform system utilities and configuration helpers
# Part of modular architecture initiative

#######################################
# Auto-detect optimal number of parallel jobs based on CPU cores
# Uses kernel-level System API for consistent cross-platform behavior
# Returns:
#   Optimal number of parallel jobs (typically CPU cores)
#######################################
auto_detect_parallel_jobs() {
    # Use kernel System API if available (preferred)
    if command -v kernel_nproc >/dev/null 2>&1; then
        kernel_nproc
        return $?
    fi
    
    # Fallback to legacy portable detection
    if command -v portable_cpu_count >/dev/null 2>&1; then
        portable_cpu_count
        return $?
    fi
    
    # Final fallback: direct detection
    local cpu_count
    
    # Method 1: nproc (Linux, modern systems)
    if command -v nproc >/dev/null 2>&1; then
        cpu_count=$(nproc 2>/dev/null)
        if [ -n "$cpu_count" ] && [ "$cpu_count" -gt 0 ] 2>/dev/null; then
            echo "$cpu_count"
            return 0
        fi
    fi
    
    # Method 2: sysctl (macOS, BSD)
    if command -v sysctl >/dev/null 2>&1; then
        cpu_count=$(sysctl -n hw.ncpu 2>/dev/null)
        if [ -n "$cpu_count" ] && [ "$cpu_count" -gt 0 ] 2>/dev/null; then
            echo "$cpu_count"
            return 0
        fi
    fi
    
    # Fallback: reasonable default
    echo "4"
}

#######################################
# Get default parallel jobs count
# Returns optimal number based on auto-detection unless overridden
#######################################
get_default_parallel_jobs() {
    # Use environment variable if set, otherwise auto-detect
    if [[ -n "${PARALLEL_JOBS:-}" ]]; then
        echo "${PARALLEL_JOBS}"
    else
        auto_detect_parallel_jobs
    fi
}

#######################################
# Retry configuration helper functions
#######################################

# Check if retries are disabled
is_no_retry() {
    [[ "${RETRY_COUNT:-${DEFAULT_RETRY_ATTEMPTS:-3}}" -eq 0 ]]
}

# Get configured retry count
get_retry_count() {
    echo "${RETRY_COUNT:-${DEFAULT_RETRY_ATTEMPTS:-3}}"
}

# Get configured retry delay
get_retry_delay() {
    echo "${RETRY_DELAY:-${DEFAULT_RETRY_DELAY:-1}}"
}

#######################################
# Path validation and security functions
#######################################

# Secure path validation (SECURITY: prevent path traversal)
validate_plugin_path() {
    local plugin_path="$1"
    
    # Ensure path is absolute and within safe directories
    case "$plugin_path" in
        "$HOME/.grpctestify/plugins"*) 
            # Allow only in user's grpctestify directory
            if [[ "$plugin_path" != *".."* && "$plugin_path" == *.sh ]]; then
                return 0
            fi
            ;;
        *)
	    tlog error "Plugin path not allowed: $plugin_path"
            return 1
            ;;
    esac
    
    tlog error "Invalid plugin path: $plugin_path"
    return 1
}

#######################################
# Configuration validation
#######################################

# Validate configuration value
validate_config() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        "timeout"|"cache_ttl"|"retry_delay"|"parallel_jobs")
            if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
                return 1
            fi
            ;;
        "strict_mode"|"debug"|"caching_enabled")
            if [[ ! "$value" =~ ^(true|false)$ ]]; then
                return 1
            fi
            ;;
        "address")
            if [[ ! "$value" =~ ^[a-zA-Z0-9.-]+:[0-9]+$ ]]; then
                return 1
            fi
            ;;
        "email")
            if [[ ! "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                return 1
            fi
            ;;
    esac
    
    return 0
}

#######################################
# System information utilities
#######################################

# Get system architecture
get_system_arch() {
    if command -v uname >/dev/null 2>&1; then
        uname -m
    else
        echo "unknown"
    fi
}

# Get operating system
get_system_os() {
    if command -v uname >/dev/null 2>&1; then
        case "$(uname -s)" in
            Linux*) echo "linux" ;;
            Darwin*) echo "macos" ;;
            CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
            FreeBSD*) echo "freebsd" ;;
            OpenBSD*) echo "openbsd" ;;
            NetBSD*) echo "netbsd" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# Check if running in CI environment
is_ci_environment() {
    [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${GITLAB_CI:-}" || -n "${TRAVIS:-}" || -n "${CIRCLECI:-}" ]]
}

# Get available memory in MB
get_available_memory() {
    local memory=""
    
    case "$(get_system_os)" in
        "linux")
            if [[ -f /proc/meminfo ]]; then
                memory=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
            fi
            ;;
        "macos")
            if command -v sysctl >/dev/null 2>&1; then
                memory=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024)}')
            fi
            ;;
    esac
    
    echo "${memory:-1024}"  # Default to 1GB if unknown
}

# Export utility functions
export -f auto_detect_parallel_jobs
export -f get_default_parallel_jobs
export -f is_no_retry
export -f get_retry_count
export -f get_retry_delay
export -f validate_plugin_path
export -f validate_config
export -f get_system_arch
export -f get_system_os
export -f is_ci_environment
export -f get_available_memory


