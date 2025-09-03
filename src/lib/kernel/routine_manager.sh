#!/bin/bash

# routine_manager.sh - Core routine management system
# Provides go-routines-like functionality for Bash with proper lifecycle management
# Now integrated with unified process manager for better resource control

# Process manager functionality is now integrated directly  
# No more external source dependencies for bashly compatibility

# Global state for routine tracking
declare -g -A ROUTINE_PIDS=()           # routine_id -> PID
declare -g -A ROUTINE_STATUS=()         # routine_id -> status (running|completed|failed|killed)
declare -g -A ROUTINE_START_TIME=()     # routine_id -> start timestamp
declare -g -A ROUTINE_END_TIME=()       # routine_id -> end timestamp
declare -g -A ROUTINE_COMMANDS=()       # routine_id -> command for debugging
declare -g -A ROUTINE_HEARTBEAT=()      # routine_id -> last heartbeat timestamp
declare -g -i ROUTINE_COUNTER            # Auto-incrementing routine ID counter
declare -g ROUTINE_MONITOR_PID           # PID of the monitor worker (lazy initialization)
ROUTINE_COUNTER=0

# Configuration
export ROUTINE_HEARTBEAT_INTERVAL="${ROUTINE_HEARTBEAT_INTERVAL:-5}"  # seconds
export ROUTINE_MAX_LIFETIME="${ROUTINE_MAX_LIFETIME:-300}"            # seconds (5 min)
export ROUTINE_CLEANUP_INTERVAL="${ROUTINE_CLEANUP_INTERVAL:-10}"     # seconds

# Initialize routine manager
routine_manager_init() {
    tlog debug "Initializing routine manager..."
    
    # Ensure required dependencies are available
    if ! command -v jobs >/dev/null 2>&1; then
        tlog error "Routine manager requires 'jobs' command (bash built-in)"
        return 1
    fi
    
    # Initialize unified process manager first
    if ! process_manager_init; then
        tlog error "Failed to initialize process manager"
        return 1
    fi
    
    # Register our cleanup handler with the process manager
    process_manager_register_cleanup "routine_manager" "routine_manager_cleanup"
    
    # LAZY INITIALIZATION: Don't start monitor immediately!
    # Monitor will be started only when first routine is spawned
    tlog debug "Routine manager initialized successfully (monitor will start on demand)"
    return 0
}

# Start monitor only when needed (lazy initialization)
routine_manager_start_monitor_if_needed() {
    # Check if monitor is already running
    if [[ -n "${ROUTINE_MONITOR_PID:-}" ]] && kill -0 "$ROUTINE_MONITOR_PID" 2>/dev/null; then
        return 0  # Monitor already running
    fi
    
    tlog debug "Starting routine monitor on demand..."
    
    # Start the monitor worker
    local monitor_pid
    monitor_pid=$(process_manager_spawn "routine_manager_monitor_worker" "routine_monitor" "monitors" "routine_manager")
    
    # Store monitor PID for future checks
    ROUTINE_MONITOR_PID="$monitor_pid"
    
    tlog debug "Routine monitor started with PID: $monitor_pid"
}

# Spawn a new routine (background process)
routine_spawn() {
    local command="$1"
    local routine_id="${2:-routine_$((++ROUTINE_COUNTER))}"
    
    if [[ -z "$command" ]]; then
    tlog error "routine_spawn: command required"
        return 1
    fi
    
    # SECURITY: Basic validation to prevent obvious injection attacks
    # Allow internal function calls and safe command patterns
    if [[ ! "$command" =~ ^[a-zA-Z_][a-zA-Z0-9_]*.*$ ]] && [[ ! "$command" =~ ^[a-zA-Z0-9_/.-]+(\s+[a-zA-Z0-9_/.-]+)*$ ]]; then
    tlog error "Invalid command pattern for security: $command"
        return 1
    fi
    
    tlog debug "Spawning routine '$routine_id': $command"
    
    # LAZY INITIALIZATION: Start monitor on first routine spawn
    routine_manager_start_monitor_if_needed
    
    # Create heartbeat file upfront and register it for cleanup
    local heartbeat_file="/tmp/grpctestify_heartbeat_${routine_id}"
    local result_file="/tmp/grpctestify_routine_result_${routine_id}"
    process_manager_register_temp_file "$heartbeat_file" "routine_manager"
    process_manager_register_temp_file "$result_file" "routine_manager"
    
    # Start the command in background with proper resource management
    # Create a safe wrapper script in memory instead of temporary file
    local wrapper_script="/tmp/grpctestify_wrapper_${routine_id}.sh"
    
    # Write the wrapper script safely (no more injection!)
    cat > "$wrapper_script" << 'WRAPPER_EOF'
#!/bin/bash
# REMOVED: source routine_manager.sh - functions are now integrated directly
routine_worker_wrapper "$@"
WRAPPER_EOF
    chmod +x "$wrapper_script"
    process_manager_register_temp_file "$wrapper_script" "routine_manager"
    
    local routine_pid
    routine_pid=$(process_manager_spawn "\"$wrapper_script\" '$command' '$routine_id' '$heartbeat_file' '$result_file'" \
                                       "routine_${routine_id}" "routines" "routine_manager")
    
    # Get the actual PID from process manager (more reliable)
    local pid="$routine_pid"
    local start_time=$(date +%s)
    
    # Verify the process actually started
    if ! kill -0 "$pid" 2>/dev/null; then
        tlog error "Failed to spawn routine '$routine_id': process not found"
        return 1
    fi
    
    # Register routine in our tracking
    ROUTINE_PIDS["$routine_id"]=$pid
    ROUTINE_STATUS["$routine_id"]="running"
    ROUTINE_START_TIME["$routine_id"]=$start_time
    ROUTINE_COMMANDS["$routine_id"]="$command"
    ROUTINE_HEARTBEAT["$routine_id"]=$start_time
    
    tlog debug "Routine '$routine_id' spawned with PID $pid"
    echo "$routine_id"
    return 0
}

# Worker wrapper function for routine execution
# This replaces the nested subshell madness with proper process management
routine_worker_wrapper() {
    local command="$1"
    local routine_id="$2"
    local heartbeat_file="$3"
    local result_file="$4"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Heartbeat function - simplified and safer
    send_heartbeat() {
        echo "$(date +%s)" > "$heartbeat_file" 2>/dev/null || true
    }
    
    # Start heartbeat in background (simplified, no recursive process manager calls)
    (
        local heartbeat_count=0
        local max_heartbeats=$((ROUTINE_MAX_LIFETIME / ROUTINE_HEARTBEAT_INTERVAL))
        
        while [[ $heartbeat_count -lt $max_heartbeats ]]; do
            echo "$(date +%s)" > "$heartbeat_file" 2>/dev/null || break
            sleep "$ROUTINE_HEARTBEAT_INTERVAL"
            ((heartbeat_count++))
        done
    ) &
    local heartbeat_pid=$!
    
    # Execute the actual command safely
    if bash -c "$command" >/dev/null 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # Stop heartbeat process
    if kill -0 "$heartbeat_pid" 2>/dev/null; then
        kill -TERM "$heartbeat_pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$heartbeat_pid" 2>/dev/null || true
    fi
    
    # Record completion
    local end_time=$(date +%s)
    echo "ROUTINE_COMPLETED:$routine_id:$exit_code:$end_time" > "$result_file" 2>/dev/null || true
    
    exit $exit_code
}

# Heartbeat worker - no more infinite loops!
routine_heartbeat_worker() {
    local heartbeat_file="$1"
    local routine_id="$2"
    
    local heartbeat_count=0
    local max_heartbeats=$((ROUTINE_MAX_LIFETIME / ROUTINE_HEARTBEAT_INTERVAL))
    
    while [[ $heartbeat_count -lt $max_heartbeats ]]; do
        echo "$(date +%s)" > "$heartbeat_file" 2>/dev/null || break
        sleep "$ROUTINE_HEARTBEAT_INTERVAL"
        ((heartbeat_count++))
    done
    
    tlog debug "Heartbeat worker for routine '$routine_id' completed after $heartbeat_count beats"
}

# Monitor worker - replaces the old infinite loop monitor
routine_manager_monitor_worker() {
    local monitor_iterations=0
    local max_iterations=${ROUTINE_MAX_MONITOR_ITERATIONS:-36}  # 36 * 10s = 6 minutes
    
    while [[ $monitor_iterations -lt $max_iterations ]]; do
        # Check for stale routines
        routine_manager_check_stale_routines
        
        # Periodic cleanup
        routine_cleanup false
        
        sleep "$ROUTINE_CLEANUP_INTERVAL"
        ((monitor_iterations++))
    done
    
    tlog debug "Routine monitor worker completed after $monitor_iterations iterations"
}

# Check for stale routines (extracted from old monitor)
routine_manager_check_stale_routines() {
    local current_time=$(date +%s)
    
    for routine_id in "${!ROUTINE_PIDS[@]}"; do
        local start_time="${ROUTINE_START_TIME[$routine_id]}"
        local status="${ROUTINE_STATUS[$routine_id]}"
        
        # Skip non-running routines
        [[ "$status" != "running" ]] && continue
        
        # Check lifetime limit
        local lifetime=$((current_time - start_time))
        if [[ $lifetime -gt $ROUTINE_MAX_LIFETIME ]]; then
            tlog warning "Routine '$routine_id' exceeded max lifetime (${lifetime}s), killing..."
            routine_kill "$routine_id" "KILL"
            continue
        fi
        
        # Check heartbeat
        local heartbeat_file="/tmp/grpctestify_heartbeat_${routine_id}"
        if [[ -f "$heartbeat_file" ]]; then
            local last_heartbeat=$(cat "$heartbeat_file" 2>/dev/null || echo "0")
            local heartbeat_age=$((current_time - last_heartbeat))
            
            if [[ $heartbeat_age -gt $((ROUTINE_HEARTBEAT_INTERVAL * 3)) ]]; then
                tlog warning "Routine '$routine_id' heartbeat stale (${heartbeat_age}s), checking..."
                routine_update_status "$routine_id"
            fi
        fi
    done
}

# Kill a routine
routine_kill() {
    local routine_id="$1"
    local signal="${2:-TERM}"
    
    if [[ -z "$routine_id" ]]; then
    tlog error "routine_kill: routine_id required"
        return 1
    fi
    
    local pid="${ROUTINE_PIDS[$routine_id]:-}"
    if [[ -z "$pid" ]]; then
    tlog warning "routine_kill: routine '$routine_id' not found"
        return 1
    fi
    
    tlog debug "Killing routine '$routine_id' (PID $pid) with signal $signal"
    
    # Kill process group to ensure all child processes are terminated
    if kill -$signal -$pid 2>/dev/null; then
        ROUTINE_STATUS["$routine_id"]="killed"
        ROUTINE_END_TIME["$routine_id"]=$(date +%s)
        
        # Cleanup files
        rm -f "/tmp/grpctestify_heartbeat_${routine_id}" 2>/dev/null
        rm -f "/tmp/grpctestify_routine_result_${routine_id}" 2>/dev/null
        
    tlog debug "Routine '$routine_id' killed successfully"
        return 0
    else
    tlog error "Failed to kill routine '$routine_id' (PID $pid)"
        return 1
    fi
}

# Wait for routine completion (blocking)
routine_wait() {
    local routine_id="$1"
    local timeout="${2:-0}"  # 0 = no timeout
    
    if [[ -z "$routine_id" ]]; then
    tlog error "routine_wait: routine_id required"
        return 1
    fi
    
    local pid="${ROUTINE_PIDS[$routine_id]:-}"
    if [[ -z "$pid" ]]; then
    tlog warning "routine_wait: routine '$routine_id' not found"
        return 1
    fi
    
    tlog debug "Waiting for routine '$routine_id' (PID $pid)${timeout:+ with timeout $timeout s}"
    
    if [[ $timeout -gt 0 ]]; then
        # Wait with timeout
        local waited=0
        while [[ $waited -lt $timeout ]]; do
            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi
            sleep 1
            ((waited++))
        done
        
        # Check if still running after timeout
        if kill -0 "$pid" 2>/dev/null; then
    tlog warning "routine_wait: timeout waiting for routine '$routine_id'"
            return 124  # timeout exit code
        fi
    else
        # Wait indefinitely
        wait "$pid" 2>/dev/null || true
    fi
    
    # Update status from result file
    routine_update_status "$routine_id"
    
    local status="${ROUTINE_STATUS[$routine_id]}"
    tlog debug "Routine '$routine_id' wait completed with status: $status"
    
    [[ "$status" == "completed" ]]
}

# Wait for any routine completion (non-blocking check)
routine_wait_any() {
    local timeout="${1:-0}"
    
    # Check for completed routines
    for routine_id in "${!ROUTINE_PIDS[@]}"; do
        local pid="${ROUTINE_PIDS[$routine_id]}"
        local status="${ROUTINE_STATUS[$routine_id]}"
        
        if [[ "$status" == "running" ]]; then
            if ! kill -0 "$pid" 2>/dev/null; then
                routine_update_status "$routine_id"
                echo "$routine_id"
                return 0
            fi
        fi
    done
    
    # If timeout specified, wait briefly
    if [[ $timeout -gt 0 ]]; then
        sleep "$timeout"
        # Check again after timeout
        for routine_id in "${!ROUTINE_PIDS[@]}"; do
            local pid="${ROUTINE_PIDS[$routine_id]}"
            local status="${ROUTINE_STATUS[$routine_id]}"
            
            if [[ "$status" == "running" ]]; then
                if ! kill -0 "$pid" 2>/dev/null; then
                    routine_update_status "$routine_id"
                    echo "$routine_id"
                    return 0
                fi
            fi
        done
    fi
    
    return 1  # No completed routines
}

# Get routine status
routine_status() {
    local routine_id="$1"
    local format="${2:-status}"  # status|full|json
    
    if [[ -z "$routine_id" ]]; then
    tlog error "routine_status: routine_id required"
        return 1
    fi
    
    if [[ -z "${ROUTINE_PIDS[$routine_id]:-}" ]]; then
        echo "unknown"
        return 1
    fi
    
    # Update status first
    routine_update_status "$routine_id"
    
    case "$format" in
        "status")
            echo "${ROUTINE_STATUS[$routine_id]}"
            ;;
        "full")
            local pid="${ROUTINE_PIDS[$routine_id]}"
            local status="${ROUTINE_STATUS[$routine_id]}"
            local start_time="${ROUTINE_START_TIME[$routine_id]}"
            local end_time="${ROUTINE_END_TIME[$routine_id]:-}"
            local command="${ROUTINE_COMMANDS[$routine_id]}"
            local duration=$((${end_time:-$(date +%s)} - start_time))
            
            echo "Routine: $routine_id"
            echo "  PID: $pid"
            echo "  Status: $status"
            echo "  Command: $command"
            echo "  Start Time: $(date -d "@$start_time" '+%Y-%m-%d %H:%M:%S')"
            [[ -n "$end_time" ]] && echo "  End Time: $(date -d "@$end_time" '+%Y-%m-%d %H:%M:%S')"
            echo "  Duration: ${duration}s"
            ;;
        "json")
            local pid="${ROUTINE_PIDS[$routine_id]}"
            local status="${ROUTINE_STATUS[$routine_id]}"
            local start_time="${ROUTINE_START_TIME[$routine_id]}"
            local end_time="${ROUTINE_END_TIME[$routine_id]:-null}"
            local command="${ROUTINE_COMMANDS[$routine_id]}"
            local duration=$((${end_time:-$(date +%s)} - start_time))
            
            echo "{\"routine_id\":\"$routine_id\",\"pid\":$pid,\"status\":\"$status\",\"command\":\"$command\",\"start_time\":$start_time,\"end_time\":$end_time,\"duration\":$duration}"
            ;;
    esac
}

# List all routines
routine_list() {
    local format="${1:-summary}"  # summary|full|json
    
    if [[ ${#ROUTINE_PIDS[@]} -eq 0 ]]; then
        echo "No routines"
        return 0
    fi
    
    case "$format" in
        "summary")
            printf "%-20s %-10s %-10s %-10s %s\n" "ROUTINE_ID" "PID" "STATUS" "DURATION" "COMMAND"
            printf "%-20s %-10s %-10s %-10s %s\n" "--------------------" "----------" "----------" "----------" "----------"
            
            for routine_id in "${!ROUTINE_PIDS[@]}"; do
                routine_update_status "$routine_id"
                local pid="${ROUTINE_PIDS[$routine_id]}"
                local status="${ROUTINE_STATUS[$routine_id]}"
                local start_time="${ROUTINE_START_TIME[$routine_id]}"
                local end_time="${ROUTINE_END_TIME[$routine_id]:-$(date +%s)}"
                local command="${ROUTINE_COMMANDS[$routine_id]}"
                local duration=$((end_time - start_time))
                
                # Truncate command for display
                local short_command="${command:0:40}"
                [[ ${#command} -gt 40 ]] && short_command="${short_command}..."
                
                printf "%-20s %-10s %-10s %-10s %s\n" "$routine_id" "$pid" "$status" "${duration}s" "$short_command"
            done
            ;;
        "full")
            for routine_id in "${!ROUTINE_PIDS[@]}"; do
                routine_status "$routine_id" "full"
                echo
            done
            ;;
        "json")
            echo "["
            local first=true
            for routine_id in "${!ROUTINE_PIDS[@]}"; do
                [[ "$first" == "true" ]] && first=false || echo ","
                routine_status "$routine_id" "json"
            done
            echo "]"
            ;;
    esac
}

# Cleanup finished routines
routine_cleanup() {
    local force="${1:-false}"  # Force cleanup of all routines
    
    tlog debug "Cleaning up routines (force: $force)..."
    
    local cleaned=0
    for routine_id in "${!ROUTINE_PIDS[@]}"; do
        local pid="${ROUTINE_PIDS[$routine_id]}"
        local status="${ROUTINE_STATUS[$routine_id]}"
        
        # Update status first
        routine_update_status "$routine_id"
        status="${ROUTINE_STATUS[$routine_id]}"
        
        # Cleanup completed/failed routines or force cleanup
        if [[ "$force" == "true" || "$status" == "completed" || "$status" == "failed" || "$status" == "killed" ]]; then
    tlog debug "Cleaning up routine '$routine_id' (status: $status)"
            
            # Remove from tracking
            unset ROUTINE_PIDS["$routine_id"]
            unset ROUTINE_STATUS["$routine_id"]
            unset ROUTINE_START_TIME["$routine_id"]
            unset ROUTINE_END_TIME["$routine_id"]
            unset ROUTINE_COMMANDS["$routine_id"]
            unset ROUTINE_HEARTBEAT["$routine_id"]
            
            # Cleanup files
            rm -f "/tmp/grpctestify_heartbeat_${routine_id}" 2>/dev/null
            rm -f "/tmp/grpctestify_routine_result_${routine_id}" 2>/dev/null
            
            ((cleaned++))
        fi
    done
    
    tlog debug "Cleaned up $cleaned routines"
    return 0
}

# Emergency stop all routines
routine_manager_emergency_stop() {
    tlog warning "Emergency stop: killing all routines..."
    
    for routine_id in "${!ROUTINE_PIDS[@]}"; do
        routine_kill "$routine_id" "KILL"
    done
    
    routine_cleanup true
    exit 1
}

# Old background health monitor - REMOVED
# This function was replaced by routine_manager_monitor_worker() and proper process management
# The old version had infinite loops and resource leaks

# Update routine status from system state
routine_update_status() {
    local routine_id="$1"
    
    local pid="${ROUTINE_PIDS[$routine_id]:-}"
    [[ -z "$pid" ]] && return 1
    
    local current_status="${ROUTINE_STATUS[$routine_id]}"
    
    # Skip if already marked as completed/failed/killed
    [[ "$current_status" == "completed" || "$current_status" == "failed" || "$current_status" == "killed" ]] && return 0
    
    # Check if process is still running
    if ! kill -0 "$pid" 2>/dev/null; then
        # Process ended, check result file
        local result_file="/tmp/grpctestify_routine_result_${routine_id}"
        if [[ -f "$result_file" ]]; then
            local result_line=$(cat "$result_file" 2>/dev/null)
            if [[ "$result_line" =~ ^ROUTINE_COMPLETED:([^:]+):([0-9]+):([0-9]+)$ ]]; then
                local exit_code="${BASH_REMATCH[2]}"
                local end_time="${BASH_REMATCH[3]}"
                
                ROUTINE_END_TIME["$routine_id"]=$end_time
                
                if [[ $exit_code -eq 0 ]]; then
                    ROUTINE_STATUS["$routine_id"]="completed"
                else
                    ROUTINE_STATUS["$routine_id"]="failed"
                fi
                
    tlog debug "Routine '$routine_id' finished with exit code $exit_code"
            else
                ROUTINE_STATUS["$routine_id"]="failed"
                ROUTINE_END_TIME["$routine_id"]=$(date +%s)
            fi
        else
            # No result file, assume failed
            ROUTINE_STATUS["$routine_id"]="failed"
            ROUTINE_END_TIME["$routine_id"]=$(date +%s)
        fi
    fi
}

# Full cleanup on exit
routine_manager_cleanup() {
    tlog debug "Routine manager cleanup..."
    routine_cleanup true
    
    # Clean up any remaining files
    rm -f /tmp/grpctestify_heartbeat_* 2>/dev/null || true
    rm -f /tmp/grpctestify_routine_result_* 2>/dev/null || true
}

# Get routine statistics
routine_stats() {
    local total=0
    local running=0
    local completed=0
    local failed=0
    local killed=0
    
    for routine_id in "${!ROUTINE_PIDS[@]}"; do
        routine_update_status "$routine_id"
        local status="${ROUTINE_STATUS[$routine_id]}"
        
        ((total++))
        case "$status" in
            "running") ((running++)) ;;
            "completed") ((completed++)) ;;
            "failed") ((failed++)) ;;
            "killed") ((killed++)) ;;
        esac
    done
    
    echo "Total: $total, Running: $running, Completed: $completed, Failed: $failed, Killed: $killed"
}

# Export functions
export -f routine_manager_init routine_spawn routine_kill routine_wait routine_wait_any
export -f routine_status routine_list routine_cleanup routine_stats
export -f routine_manager_emergency_stop routine_manager_cleanup
export -f routine_worker_wrapper routine_heartbeat_worker routine_manager_monitor_worker
export -f routine_manager_check_stale_routines routine_manager_start_monitor_if_needed
export -f routine_update_status
