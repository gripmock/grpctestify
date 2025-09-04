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
    
    # Log-level filtering (error < warn < info < debug < trace). Default: info
    local current_level
    current_level=$(get_log_level)
    local cur_v msg_v
    cur_v=$(_log_level_value "$current_level")
    msg_v=$(_log_level_value "$level")
    # Print only if message level is at least as important as the current threshold
    if [[ "$msg_v" -gt "$cur_v" ]]; then
        return 0
    fi
    
    # Format timestamp
    timestamp=$(date '+%H:%M:%S')
    
    # Format message based on level
    case "$level" in
        debug)
            formatted_message="🐛 DEBUG [$timestamp]: $message"
            ;;
        trace)
            formatted_message="🔬 TRACE [$timestamp]: $message"
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
    
    # Direct output (avoid plugin IO to prevent potential blocking)
    case "$level" in
        error|warn)
            printf "%s\n" "$formatted_message" >&2
            ;;
        *)
            printf "%s\n" "$formatted_message"
            ;;
    esac
}

#######################################
# Level-specific helpers (preferred API)
# Usage: log_error "msg"; log_warn "msg"; log_info "msg"; log_debug "msg"
#######################################

log_error() { io_glog error "$@"; }
log_warn()  { io_glog warn  "$@"; }
log_info()  { io_glog info  "$@"; }
log_debug() { io_glog debug "$@"; }
log_trace() { io_glog trace "$@"; }

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
    local lvl="${GRPCTESTIFY_LOG_LEVEL:-}"
    if [[ -n "$lvl" ]]; then
        lvl="${lvl,,}"
        case "$lvl" in
            error) echo "error"; return ;;
            warn) echo "warn"; return ;;
            info) echo "info"; return ;;
            debug) echo "debug"; return ;;
            trace) echo "trace"; return ;;
        esac
    fi
    echo "info"
}

# Set log level
set_log_level() {
    local level="$1"
    
    case "$level" in
        debug)
            export GRPCTESTIFY_LOG_LEVEL=debug
            ;;
        info)
            export GRPCTESTIFY_LOG_LEVEL=info
            ;;
        warn)
            export GRPCTESTIFY_LOG_LEVEL=warn
            ;;
        error)
            export GRPCTESTIFY_LOG_LEVEL=error
            ;;
    esac
}

# Convert level to numeric value for comparisons (lower is more severe)
_log_level_value() {
    case "${1,,}" in
        error) echo 0 ;;
        warn) echo 1 ;;
        info) echo 2 ;;
        debug) echo 3 ;;
        trace) echo 4 ;;
        *) echo 2 ;; # default info
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
export -f log_error log_warn log_info log_debug log_trace

#######################################
# Perf API (trace-only, concurrency-safe by PID)
# Functions:
#   perf_push key     # start span
#   perf_pop key      # end span -> log_trace one line if enabled
#   perf_mark key     # increment counter
#   perf_summary      # print aggregates for this PID
# Env (optional):
#   PERF_THRESHOLD_MS (default 0) - skip spans shorter than threshold
#   PERF_SAMPLING_N   (default 1) - log every N-th span for key
#######################################
declare -Ag PERF_T0=()       # key: "pid|key" -> t0_ms
declare -Ag PERF_COUNT=()    # key: "pid|key" -> count
declare -Ag PERF_SUM=()      # key: "pid|key" -> total_ms

perf__enabled() {
    [[ "$(get_log_level)" == "trace" ]]
}

perf_push() { :; }
perf_pop() { :; }

perf_mark() { :; }

perf_add() {
    local key="$1"
    local ms="$2"
    [[ -z "$key" || -z "$ms" ]] && return 0
    # Always aggregate; printing remains trace-only via perf_summary
    local agg_key="$$|$key"
    local cur_sum="${PERF_SUM[$agg_key]:-0}"
    local cur_cnt="${PERF_COUNT[$agg_key]:-0}"
    PERF_SUM[$agg_key]=$(( cur_sum + ms ))
    PERF_COUNT[$agg_key]=$(( cur_cnt + 1 ))
}

perf_summary() {
    perf__enabled || return 0
    local pid="$$"
    local k
    for k in "${!PERF_SUM[@]}"; do
        [[ "$k" != ${pid}\|* ]] && continue
        local key="${k#${pid}|}"
        local total="${PERF_SUM[$k]:-0}"
        local cnt="${PERF_COUNT[$k]:-0}"
        local avg=0
        (( cnt > 0 )) && avg=$(( total / cnt ))
        log_trace "perf.summary key=${key} total=${total}ms count=${cnt} avg=${avg}ms"
    done
}

export -f perf_push perf_pop perf_mark perf_summary perf_add
#######################################
# gperf - lightweight start/stop perf markers (trace-only)
# Usage:
#   gperf "parsing"   # start
#   ... code ...
#   gperf "parsing"   # stop -> prints one trace line with duration
#######################################
declare -Ag __GPERF_T0=()
# Aggregated performance metrics (PID-scoped keys: "$$|key")
declare -Ag PERF_SUM=()
declare -Ag PERF_COUNT=()

gperf() {
    local key="$1"
    [[ -z "$key" ]] && return 0
    # Only active in trace level
    if [[ "$(get_log_level)" != "trace" ]]; then
        return 0
    fi
    local now
    now=$(($(date +%s%N)/1000000))
    if [[ -z "${__GPERF_T0[$key]:-}" ]]; then
        __GPERF_T0[$key]="$now"
    else
        local dur=$((now - __GPERF_T0[$key]))
        unset __GPERF_T0[$key]
        # aggregate by PID|key for concurrency safety
        local agg_key="$$|$key"
        local cur_sum="${PERF_SUM[$agg_key]:-0}"
        local cur_cnt="${PERF_COUNT[$agg_key]:-0}"
        PERF_SUM[$agg_key]=$(( cur_sum + dur ))
        PERF_COUNT[$agg_key]=$(( cur_cnt + 1 ))
        # single concise trace line
        log_trace "perf key=${key} dur=${dur}ms"
    fi
}

export -f gperf
