#!/bin/bash

# Process Mutex System with Auto-Expire for gRPC Testify
# Provides inter-process synchronization with automatic lock expiration
# Prevents deadlocks from crashed processes

# Global mutex configuration
GRPCTESTIFY_MUTEX_DIR="${TMPDIR:-/tmp}/grpctestify_mutex_$$"
GRPCTESTIFY_OUTPUT_MUTEX="$GRPCTESTIFY_MUTEX_DIR/output.lock"
GRPCTESTIFY_STATE_MUTEX="$GRPCTESTIFY_MUTEX_DIR/state.lock"

# Mutex timeout and expiration settings
MUTEX_TIMEOUT=10          # Time to wait for acquiring lock (increased for stability)
MUTEX_EXPIRE_TIME=5       # Auto-expire locks after this time (seconds)
export MUTEX_RETRY_INTERVAL=0.5  # Retry interval (increased to prevent excessive process spawning)

#######################################
# Initialize mutex system
# Globals:
#   GRPCTESTIFY_MUTEX_DIR
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
mutex_init() {
    if [[ -d "$GRPCTESTIFY_MUTEX_DIR" ]]; then
        return 0
    fi
    
    if ! mkdir -p "$GRPCTESTIFY_MUTEX_DIR" 2>/dev/null; then
        log_error "Failed to create mutex directory: $GRPCTESTIFY_MUTEX_DIR"
        return 1
    fi
    
    log_debug "Mutex system initialized: $GRPCTESTIFY_MUTEX_DIR"
    return 0
}

#######################################
# Cleanup mutex system
# Globals:
#   GRPCTESTIFY_MUTEX_DIR
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
mutex_cleanup() {
    if [[ -d "$GRPCTESTIFY_MUTEX_DIR" ]]; then
        # Force remove all locks before cleanup
        rm -f "$GRPCTESTIFY_MUTEX_DIR"/*.lock 2>/dev/null
        rm -rf "$GRPCTESTIFY_MUTEX_DIR" 2>/dev/null
        log_debug "Mutex system cleaned up"
    fi
    return 0
}

#######################################
# Check if lock file is expired
# Arguments:
#   1: Lock file path
# Returns:
#   0 if expired, 1 if still valid
#######################################
_mutex_is_expired() {
    local lock_file="$1"
    
    if [[ ! -f "$lock_file" ]]; then
        return 0  # No lock file = expired
    fi
    
    # Get lock creation time from file timestamp
    local lock_time
    if command -v stat >/dev/null 2>&1; then
        # Use stat to get file modification time
        case "$(uname)" in
            Darwin) lock_time=$(stat -f %m "$lock_file" 2>/dev/null) ;;
            Linux)  lock_time=$(stat -c %Y "$lock_file" 2>/dev/null) ;;
            *)      lock_time="" ;;
        esac
    fi
    
    if [[ -z "$lock_time" ]]; then
        # Fallback: assume not expired if we can't get timestamp
        return 1
    fi
    
    local current_time
    current_time=$(date +%s)
    local age=$((current_time - lock_time))
    
    if [[ $age -gt $MUTEX_EXPIRE_TIME ]]; then
        log_debug "Lock expired: age=${age}s > ${MUTEX_EXPIRE_TIME}s"
        return 0  # Expired
    else
        return 1  # Still valid
    fi
}

#######################################
# Acquire a mutex lock with auto-expire
# Arguments:
#   1: Lock file path
#   2: Timeout in seconds (optional, defaults to MUTEX_TIMEOUT)
# Returns:
#   0 on success, 1 on timeout/error
#######################################
mutex_acquire() {
    local lock_file="$1"
    local timeout="${2:-$MUTEX_TIMEOUT}"
    local start_time end_time
    
    start_time=$(date +%s)
    end_time=$((start_time + timeout))
    
    local retry_count=0
    local max_retries=$((timeout * 2))  # Maximum retries based on timeout
    
    while [[ $retry_count -lt $max_retries ]]; do
        # Clean up expired locks first
        if [[ -f "$lock_file" ]] && _mutex_is_expired "$lock_file"; then
        log_debug "Removing expired lock: $(basename "$lock_file")"
            rm -f "$lock_file" 2>/dev/null
        fi
        
        # Try to acquire lock atomically
        if (set -C; echo "$$:$(date +%s)" > "$lock_file") 2>/dev/null; then
            log_debug "Mutex acquired: $(basename "$lock_file")"
            return 0
        fi
        
        # Check timeout
        local current_time
        current_time=$(date +%s)
        if [[ $current_time -ge $end_time ]]; then
        log_warn "Mutex acquisition timeout: $(basename "$lock_file") after ${timeout}s"
            # Show lock info for debugging
            if [[ -f "$lock_file" ]]; then
                local lock_content
                lock_content=$(cat "$lock_file" 2>/dev/null)
            log_debug "Lock content: $lock_content"
            fi
            return 1
        fi
        
        # Check if lock holder process is still alive
        if [[ -f "$lock_file" ]]; then
            local lock_content lock_pid lock_time
            lock_content=$(cat "$lock_file" 2>/dev/null)
            lock_pid="${lock_content%%:*}"
            lock_time="${lock_content##*:}"
            
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
            log_debug "Removing stale lock: PID $lock_pid is dead"
                rm -f "$lock_file" 2>/dev/null
                continue
            fi
        fi
        
        # Increment retry count and wait before retry
        ((retry_count++))
        sleep "$MUTEX_RETRY_INTERVAL"
    done
    
    # Failed to acquire lock within timeout
    log_error "Failed to acquire lock after $max_retries retries"
    return 1
}

#######################################
# Release a mutex lock
# Arguments:
#   1: Lock file path
# Returns:
#   0 on success, 1 on error
#######################################
mutex_release() {
    local lock_file="$1"
    
    if [[ ! -f "$lock_file" ]]; then
        log_debug "Lock file does not exist: $(basename "$lock_file")"
        return 0
    fi
    
    local lock_content lock_pid
    lock_content=$(cat "$lock_file" 2>/dev/null)
    lock_pid="${lock_content%%:*}"
    
    # Only remove if we own the lock
    if [[ "$lock_pid" == "$$" ]]; then
        rm -f "$lock_file"
        log_debug "Mutex released: $(basename "$lock_file")"
        return 0
    else
        log_warn "Cannot release lock owned by PID $lock_pid (current: $$)"
        return 1
    fi
}

#######################################
# Execute function with output mutex
# Arguments:
#   1+: Command and arguments to execute
# Returns:
#   Exit code of the executed command
#######################################
mutex_with_output_lock() {
    local exit_code
    
    if ! mutex_acquire "$GRPCTESTIFY_OUTPUT_MUTEX"; then
        log_error "Failed to acquire output mutex"
        return 1
    fi
    
    # Execute command with mutex held
    "$@"
    exit_code=$?
    
    mutex_release "$GRPCTESTIFY_OUTPUT_MUTEX"
    return $exit_code
}

#######################################
# Execute function with state mutex
# Arguments:
#   1+: Command and arguments to execute
# Returns:
#   Exit code of the executed command
#######################################
mutex_with_state_lock() {
    local exit_code
    
    if ! mutex_acquire "$GRPCTESTIFY_STATE_MUTEX"; then
        log_error "Failed to acquire state mutex"
        return 1
    fi
    
    # Execute command with mutex held
    "$@"
    exit_code=$?
    
    mutex_release "$GRPCTESTIFY_STATE_MUTEX"
    return $exit_code
}

#######################################
# Safe print to stdout with mutex
# Arguments:
#   1+: Text to print
# Returns:
#   0 on success
#######################################
mutex_print() {
    mutex_with_output_lock printf '%s\n' "$*"
}

#######################################
# Safe print to stderr with mutex
# Arguments:
#   1+: Text to print
# Returns:
#   0 on success
#######################################
mutex_eprint() {
    mutex_with_output_lock bash -c "printf '%s\n' '$*' >&2"
}

#######################################
# Safe printf to stdout with mutex
# Arguments:
#   1: Format string
#   2+: Arguments for printf
# Returns:
#   0 on success
#######################################
mutex_printf() {
    local format="$1"
    shift
    mutex_with_output_lock printf "$format" "$@"
}

#######################################
# Check if mutex system is available
# Returns:
#   0 if available, 1 if not
#######################################
mutex_is_available() {
    [[ -d "$GRPCTESTIFY_MUTEX_DIR" ]]
}

#######################################
# Get mutex status information
# Returns:
#   Prints mutex status
#######################################
mutex_status() {
    echo "Mutex System Status:"
    echo "  Directory: $GRPCTESTIFY_MUTEX_DIR"
    echo "  Available: $(mutex_is_available && echo "Yes" || echo "No")"
    echo "  Timeout: ${MUTEX_TIMEOUT}s"
    echo "  Expire Time: ${MUTEX_EXPIRE_TIME}s"
    
    if [[ -f "$GRPCTESTIFY_OUTPUT_MUTEX" ]]; then
        local output_content output_pid output_time age
        output_content=$(cat "$GRPCTESTIFY_OUTPUT_MUTEX" 2>/dev/null)
        output_pid="${output_content%%:*}"
        output_time="${output_content##*:}"
        age=$(($(date +%s) - output_time))
        echo "  Output Lock: Held by PID $output_pid (age: ${age}s)"
    else
        echo "  Output Lock: Free"
    fi
    
    if [[ -f "$GRPCTESTIFY_STATE_MUTEX" ]]; then
        local state_content state_pid state_time age
        state_content=$(cat "$GRPCTESTIFY_STATE_MUTEX" 2>/dev/null)
        state_pid="${state_content%%:*}"
        state_time="${state_content##*:}"
        age=$(($(date +%s) - state_time))
        echo "  State Lock: Held by PID $state_pid (age: ${age}s)"
    else
        echo "  State Lock: Free"
    fi
}

#######################################
# Force cleanup of all expired locks
# Returns:
#   Number of locks cleaned
#######################################
mutex_cleanup_expired() {
    local cleaned=0
    
    if [[ ! -d "$GRPCTESTIFY_MUTEX_DIR" ]]; then
        echo 0
        return 0
    fi
    
    for lock_file in "$GRPCTESTIFY_MUTEX_DIR"/*.lock; do
        if [[ -f "$lock_file" ]] && _mutex_is_expired "$lock_file"; then
            log_debug "Force removing expired lock: $(basename "$lock_file")"
            rm -f "$lock_file" 2>/dev/null
            ((cleaned++))
        fi
    done
    
    echo $cleaned
}

# Cleanup on exit
 
# Now using unified signal_manager for proper cleanup handling

# Export functions
export -f mutex_init mutex_cleanup mutex_acquire mutex_release
export -f mutex_with_output_lock mutex_with_state_lock
export -f mutex_print mutex_eprint mutex_printf
export -f mutex_is_available mutex_status mutex_cleanup_expired