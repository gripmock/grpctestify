#!/bin/bash

# logging_io.sh - Logging system integrated with Plugin IO API
# Provides centralized logging that respects mutex synchronization

# Original log function for fallback
_original_log_function=""

#######################################
# Initialize logging system with IO integration
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
init_logging_io() {
    # Save original log function if it exists
    if command -v log >/dev/null 2>&1; then
        _original_log_function="$(declare -f log)"
    fi
    
    # Define grpctestify log function (glog) to avoid conflicts with system log
    glog() {
        io_glog "$@"
    }
    

    
    export -f glog
}

#######################################
# IO-aware logging function
# Arguments:
#   1: Log level (debug, info, warn, error, section)
#   2+: Log message parts
# Returns:
#   0 on success
#######################################
io_glog() {
    local level="$1"
    shift
    local message="$*"
    local timestamp formatted_message
    
    # Skip debug logs unless explicitly enabled
    if [[ "$level" == "debug" && "${DEBUG:-}" != "true" && "${GRPCTESTIFY_DEBUG:-}" != "true" ]]; then
        return 0
    fi
    
    # Format timestamp
    timestamp=$(date '+%H:%M:%S')
    
    # Format message based on level
    case "$level" in
        debug)
            formatted_message="🐛 DEBUG [$timestamp]: $message"
            ;;
        info)
            formatted_message="ℹ️  INFO [$timestamp]: $message"
            ;;
        warn)
            formatted_message="⚠️  WARN [$timestamp]: $message"
            ;;
        error)
            formatted_message="❌ ERROR [$timestamp]: $message"
            ;;
        section)
            formatted_message="───[ $message ]───"
            ;;
        *)
            formatted_message="[$timestamp] $level: $message"
            ;;
    esac
    
    # Use Plugin IO API for safe output
    if command -v plugin_io_error_print >/dev/null 2>&1; then
        case "$level" in
            error|warn)
                plugin_io_error_print "$formatted_message"
                ;;
            *)
                plugin_io_print "%s\n" "$formatted_message"
                ;;
        esac
    else
        # Fallback to stderr for errors/warnings
        case "$level" in
            error|warn)
                printf "%s\n" "$formatted_message" >&2
                ;;
            *)
                printf "%s\n" "$formatted_message"
                ;;
        esac
    fi
}

#######################################
# Specialized logging functions for better semantics
#######################################

# Log test execution events
log_test_event() {
    local event="$1"
    local test_name="$2"
    shift 2
    local details="$*"
    
    case "$event" in
        start)
            io_glog info "Starting test: $test_name"
            ;;
        success)
            io_glog info "✅ Test passed: $test_name${details:+ - $details}"
            ;;
        failure)
            io_glog error "❌ Test failed: $test_name${details:+ - $details}"
            ;;
        skip)
            io_glog warn "⏭️  Test skipped: $test_name${details:+ - $details}"
            ;;
        error)
            io_glog error "💥 Test error: $test_name${details:+ - $details}"
            ;;
        *)
            io_glog info "Test $event: $test_name${details:+ - $details}"
            ;;
    esac
}

# Log system events
log_system() {
    local component="$1"
    local level="$2"
    shift 2
    local message="$*"
    
    io_glog "$level" "[$component] $message"
}

# Log performance metrics
log_performance() {
    local metric_name="$1"
    local value="$2"
    local unit="${3:-}"
    
    io_glog debug "📊 Performance: $metric_name = $value${unit:+ $unit}"
}

# Log network operations
log_network() {
    local operation="$1"
    local target="$2"
    local status="$3"
    shift 3
    local details="$*"
    
    case "$status" in
        success)
            io_glog debug "🌐 Network $operation to $target: SUCCESS${details:+ - $details}"
            ;;
        failure)
            io_glog warn "🌐 Network $operation to $target: FAILED${details:+ - $details}"
            ;;
        *)
            io_glog debug "🌐 Network $operation to $target: $status${details:+ - $details}"
            ;;
    esac
}

# Log plugin events
log_plugin() {
    local plugin_name="$1"
    local level="$2"
    shift 2
    local message="$*"
    
    io_glog "$level" "🔌 Plugin[$plugin_name]: $message"
}

#######################################
# Compatibility functions
#######################################

# Restore original log function
restore_original_log() {
    if [[ -n "$_original_log_function" ]]; then
        eval "$_original_log_function"
        export -f log
    fi
}

# Check if IO logging is active
is_io_logging_active() {
    command -v plugin_io_print >/dev/null 2>&1
}

# Get log level setting
get_log_level() {
    if [[ "${DEBUG:-}" == "true" || "${GRPCTESTIFY_DEBUG:-}" == "true" ]]; then
        echo "debug"
    elif [[ "${VERBOSE:-}" == "true" ]]; then
        echo "info"
    else
        echo "warn"
    fi
}

# Set log level
set_log_level() {
    local level="$1"
    
    case "$level" in
        debug)
            export GRPCTESTIFY_DEBUG=true
            export VERBOSE=true
            ;;
        info)
            export GRPCTESTIFY_DEBUG=false
            export VERBOSE=true
            ;;
        warn)
            export GRPCTESTIFY_DEBUG=false
            export VERBOSE=false
            ;;
        error)
            export GRPCTESTIFY_DEBUG=false
            export VERBOSE=false
            ;;
    esac
}

#######################################
# Batch logging for performance
#######################################

# Log multiple events at once
log_batch() {
    local level="$1"
    shift
    
    for message in "$@"; do
        io_glog "$level" "$message"
    done
}

# Log with context (test file, line number, function)
log_context() {
    local level="$1"
    local context="$2"
    shift 2
    local message="$*"
    
    io_glog "$level" "[$context] $message"
}

# Export functions
export -f init_logging_io io_glog log_test_event log_system
export -f log_performance log_network log_plugin
export -f restore_original_log is_io_logging_active
export -f get_log_level set_log_level log_batch log_context
