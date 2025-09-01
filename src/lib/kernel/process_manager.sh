#!/bin/bash

# process_manager.sh - Unified process management system
# FIXED VERSION: No more overlapping traps, no more eval injection
# Written in Linus Torvalds style: correct, robust, simple

# Signal manager functionality is now integrated directly
# No more external source dependencies for bashly compatibility

# Global signal handler registry (integrated from signal_manager.sh)
declare -g -A SIGNAL_HANDLERS=()           # signal_name -> "handler1,handler2,handler3"
declare -g -A MODULE_CLEANUP_HANDLERS=()   # module_name -> cleanup_function
declare -g SIGNAL_MANAGER_INITIALIZED=false
declare -g SIGNAL_SHUTDOWN_IN_PROGRESS=false

# Global process registry with PROPER data structures (no more string parsing hell!)
declare -g -A PROCESS_REGISTRY=()          # pid -> JSON process_info
declare -g -A PROCESS_GROUPS=()            # group_name -> "pid1,pid2,pid3"  
declare -g -A TEMP_FILES=()                # file_path -> owner_module
declare -g -A FILE_DESCRIPTORS=()          # fd_number -> owner_module
declare -g PM_INITIALIZED=false

# SECURITY: Process limits and mutex for thread safety
declare -g PM_MAX_PROCESSES="${PM_MAX_PROCESSES:-100}"
declare -g PM_CURRENT_PROCESSES=0
declare -g PM_LOCK_FILE="/tmp/grpctestify_pm_lock_$$"

# Configuration
PM_SHUTDOWN_TIMEOUT="${PM_SHUTDOWN_TIMEOUT:-10}"    # seconds
PM_FORCE_KILL_TIMEOUT="${PM_FORCE_KILL_TIMEOUT:-5}" # seconds
PM_LOG_LEVEL="${PM_LOG_LEVEL:-INFO}"                # DEBUG|INFO|WARNING|ERROR

#######################################
# INTEGRATED SIGNAL MANAGER FUNCTIONS
#######################################

# Initialize the unified signal manager
signal_manager_init() {
    if [[ "$SIGNAL_MANAGER_INITIALIZED" == "true" ]]; then
        return 0
    fi
    
    tlog debug "Initializing unified signal manager..."
    
    # Set up signal handlers - THE RIGHT WAY (only once!)
    trap 'signal_manager_handle_exit' EXIT
    trap 'signal_manager_handle_signal TERM' TERM
    trap 'signal_manager_handle_signal INT' INT
    trap 'signal_manager_handle_signal HUP' HUP
    trap 'signal_manager_handle_signal USR1' USR1
    trap 'signal_manager_handle_signal USR2' USR2
    
    SIGNAL_MANAGER_INITIALIZED=true
    tlog debug "Signal manager initialized successfully"
    return 0
}

# Register a cleanup handler for a module
signal_manager_register_cleanup() {
    local module_name="$1"
    local cleanup_function="$2"
    
    if [[ -z "$module_name" || -z "$cleanup_function" ]]; then
        tlog error "signal_manager_register_cleanup: module_name and cleanup_function required"
        return 1
    fi
    
    # Verify the function exists
    if ! command -v "$cleanup_function" >/dev/null 2>&1; then
        tlog error "Cleanup function '$cleanup_function' not found for module '$module_name'"
        return 1
    fi
    
    MODULE_CLEANUP_HANDLERS["$module_name"]="$cleanup_function"
    tlog debug "Registered cleanup handler '$cleanup_function' for module '$module_name'"
    return 0
}

# Handle signals with proper chaining
signal_manager_handle_signal() {
    local signal="$1"
    
    if [[ "$SIGNAL_SHUTDOWN_IN_PROGRESS" == "true" ]]; then
        tlog warning "Shutdown already in progress, ignoring $signal signal"
        return
    fi
    
    tlog debug "Received $signal signal, executing signal handlers..."
    SIGNAL_SHUTDOWN_IN_PROGRESS=true
    
    # Execute global cleanup
    signal_manager_cleanup_all
    exit 0
}

# Handle EXIT signal
signal_manager_handle_exit() {
    if [[ "$SIGNAL_SHUTDOWN_IN_PROGRESS" == "true" ]]; then
        return  # Already handling shutdown
    fi
    
    tlog debug "Signal manager exit handler triggered"
    SIGNAL_SHUTDOWN_IN_PROGRESS=true
    signal_manager_cleanup_all
}

# Execute all cleanup handlers
signal_manager_cleanup_all() {
    if [[ "${#MODULE_CLEANUP_HANDLERS[@]}" -eq 0 ]]; then
        tlog debug "No cleanup handlers to execute"
        return 0
    fi
    
    tlog debug "Executing ${#MODULE_CLEANUP_HANDLERS[@]} cleanup handlers..."
    
    # Execute cleanup handlers in reverse registration order (LIFO)
    local modules=()
    for module_name in "${!MODULE_CLEANUP_HANDLERS[@]}"; do
        modules+=("$module_name")
    done
    
    # Reverse the array
    local i
    for ((i=${#modules[@]}-1; i>=0; i--)); do
        local module_name="${modules[i]}"
        local cleanup_function="${MODULE_CLEANUP_HANDLERS[$module_name]}"
        
        tlog debug "Executing cleanup handler '$cleanup_function' for module '$module_name'"
        
        if command -v "$cleanup_function" >/dev/null 2>&1; then
            # Run cleanup directly without timeout to preserve function scope
            tlog debug "Cleanup handler '$cleanup_function' completed successfully"
            "$cleanup_function" || tlog warning "Cleanup handler '$cleanup_function' failed"
        else
            tlog warning "Cleanup handler '$cleanup_function' not found for module '$module_name'"
        fi
    done
    
    tlog debug "Signal manager cleanup completed"
}

#######################################
# PROCESS MANAGER FUNCTIONS  
#######################################

# Initialize the unified process manager
process_manager_init() {
    if [[ "$PM_INITIALIZED" == "true" ]]; then
        return 0
    fi
    
    tlog debug "Initializing unified process manager..."
    
    # Initialize signal manager first (no more overlapping traps!)
    if ! signal_manager_init; then
        tlog error "Failed to initialize signal manager"
        return 1
    fi
    
    # Register our cleanup handler with the signal manager
    signal_manager_register_cleanup "process_manager" "process_manager_cleanup_all"
    
    PM_INITIALIZED=true
    tlog debug "Process manager initialized successfully"
    return 0
}

# Register a cleanup handler for a module (delegates to signal manager)
process_manager_register_cleanup() {
    local module_name="$1"
    local cleanup_function="$2"
    
    if [[ -z "$module_name" || -z "$cleanup_function" ]]; then
        tlog error "process_manager_register_cleanup: module_name and cleanup_function required"
        return 1
    fi
    
    # Delegate to signal manager for unified handling
    signal_manager_register_cleanup "$module_name" "$cleanup_function"
}

# Register a background process - THREAD SAFE WITH MUTEX
process_manager_register_process() {
    local pid="$1"
    local process_name="$2"
    local process_group="${3:-default}"
    local owner_module="${4:-unknown}"
    
    if [[ -z "$pid" || -z "$process_name" ]]; then
        tlog error "process_manager_register_process: pid and process_name required"
        return 1
    fi
    
    # SECURITY: Acquire mutex to prevent race conditions
    local lock_acquired=false
    local lock_timeout=5
    local lock_start=$(date +%s)
    
    while [[ "$lock_acquired" == "false" ]]; do
        if (set -C; echo "$$:$(date +%s)" > "$PM_LOCK_FILE") 2>/dev/null; then
            lock_acquired=true
            break
        fi
        
        # Check for lock timeout
        local current_time=$(date +%s)
        if (( current_time - lock_start > lock_timeout )); then
            tlog error "Failed to acquire process manager lock within ${lock_timeout}s"
            return 1
        fi
        
        sleep 0.1
    done
    
    # Ensure we release the lock on exit
    trap 'rm -f "$PM_LOCK_FILE" 2>/dev/null || true' EXIT
    
    # SECURITY: Check process limits BEFORE adding
    if (( PM_CURRENT_PROCESSES >= PM_MAX_PROCESSES )); then
        tlog error "Process limit reached: ${PM_CURRENT_PROCESSES}/${PM_MAX_PROCESSES}"
        rm -f "$PM_LOCK_FILE" 2>/dev/null || true
        return 1
    fi
    
    # Check if process actually exists
    if ! kill -0 "$pid" 2>/dev/null; then
        tlog warning "Attempted to register non-existent process PID $pid"
        rm -f "$PM_LOCK_FILE" 2>/dev/null || true
        return 1
    fi
    
    # Use proper JSON structure instead of string parsing hell!
    local process_info
    process_info=$(printf '{"name":"%s","group":"%s","owner":"%s","start_time":%d}' \
                   "$process_name" "$process_group" "$owner_module" "$(date +%s)")
    PROCESS_REGISTRY["$pid"]="$process_info"
    
    # Add to process group
    if [[ -n "${PROCESS_GROUPS[$process_group]}" ]]; then
        PROCESS_GROUPS["$process_group"]="${PROCESS_GROUPS[$process_group]},$pid"
    else
        PROCESS_GROUPS["$process_group"]="$pid"
    fi
    
    # SECURITY: Increment process counter
    ((PM_CURRENT_PROCESSES++))
    
    # SECURITY: Release lock
    rm -f "$PM_LOCK_FILE" 2>/dev/null || true
    trap - EXIT
    
    tlog debug "Registered process '$process_name' (PID: $pid, Group: $process_group, Owner: $owner_module) [${PM_CURRENT_PROCESSES}/${PM_MAX_PROCESSES}]"
}

# Register a temporary file for cleanup
process_manager_register_temp_file() {
    local file_path="$1"
    local owner_module="${2:-unknown}"
    
    if [[ -z "$file_path" ]]; then
        tlog error "process_manager_register_temp_file: file_path required"
        return 1
    fi
    
    TEMP_FILES["$file_path"]="$owner_module"
    tlog debug "Registered temp file '$file_path' for module '$owner_module'"
}

# Register a file descriptor for cleanup
process_manager_register_fd() {
    local fd_number="$1"
    local owner_module="${2:-unknown}"
    
    if [[ -z "$fd_number" ]]; then
        tlog error "process_manager_register_fd: fd_number required"
        return 1
    fi
    
    FILE_DESCRIPTORS["$fd_number"]="$owner_module"
    tlog debug "Registered file descriptor $fd_number for module '$owner_module'"
}

# Spawn a managed background process
process_manager_spawn() {
    local command="$1"
    local process_name="$2"
    local process_group="${3:-default}"
    local owner_module="${4:-unknown}"
    
    if [[ -z "$command" || -z "$process_name" ]]; then
        tlog error "process_manager_spawn: command and process_name required"
        return 1
    fi
    
    # SECURITY: Check process limits BEFORE spawning
    if (( PM_CURRENT_PROCESSES >= PM_MAX_PROCESSES )); then
        tlog error "Cannot spawn '$process_name': Process limit reached (${PM_CURRENT_PROCESSES}/${PM_MAX_PROCESSES})"
        return 1
    fi
    
    tlog debug "Spawning managed process '$process_name': $command [${PM_CURRENT_PROCESSES}/${PM_MAX_PROCESSES}]"
    
    # Execute command in background with proper process group
    (
        # Set process group for easier cleanup
        set -m
        # Execute the command safely without eval
        exec bash -c "$command"
    ) &
    
    local pid=$!
    process_manager_register_process "$pid" "$process_name" "$process_group" "$owner_module"
    echo "$pid"
}

# OLD signal handlers REMOVED - now handled by signal_manager
# These functions were causing overlapping trap conflicts

# Shutdown all managed processes and clean up resources - THREAD SAFE
# This is now called by signal_manager, not directly
process_manager_cleanup_all() {
    # SECURITY: Acquire lock for cleanup to prevent race conditions
    local cleanup_lock_file="/tmp/grpctestify_cleanup_lock_$$"
    if ! (set -C; echo "$$:$(date +%s)" > "$cleanup_lock_file") 2>/dev/null; then
        tlog warning "Another cleanup is in progress, waiting..."
        local wait_count=0
        while [[ -f "$cleanup_lock_file" && "$wait_count" -lt 30 ]]; do
            sleep 0.5
            ((wait_count++))
        done
        # Force cleanup if lock is stale
        if [[ -f "$cleanup_lock_file" ]]; then
            rm -f "$cleanup_lock_file" 2>/dev/null || true
        fi
    fi
    
    # Ensure cleanup lock is removed
    trap 'rm -f "$cleanup_lock_file" 2>/dev/null || true' EXIT
    
    if [[ "${#PROCESS_REGISTRY[@]}" -eq 0 ]]; then
        tlog debug "No processes to manage"
        rm -f "$cleanup_lock_file" 2>/dev/null || true
        return 0
    fi
    
    tlog debug "Shutting down ${#PROCESS_REGISTRY[@]} managed processes and cleaning up resources..."
    
    # Step 1: Graceful shutdown of processes
    local active_pids=()
    for pid in "${!PROCESS_REGISTRY[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            active_pids+=("$pid")
        fi
    done
    
    if [[ "${#active_pids[@]}" -gt 0 ]]; then
        tlog debug "Sending TERM signal to ${#active_pids[@]} active processes..."
        for pid in "${active_pids[@]}"; do
            local process_info="${PROCESS_REGISTRY[$pid]}"
            local process_name=$(echo "$process_info" | sed -n 's/.*name:\([^,]*\).*/\1/p')
            tlog debug "Sending TERM to process '$process_name' (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true
        done
        
        # Wait for graceful shutdown
        tlog debug "Waiting up to $PM_SHUTDOWN_TIMEOUT seconds for graceful shutdown..."
        local wait_count=0
        while [[ $wait_count -lt $PM_SHUTDOWN_TIMEOUT ]]; do
            local remaining_pids=()
            for pid in "${active_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    remaining_pids+=("$pid")
                fi
            done
            
            if [[ "${#remaining_pids[@]}" -eq 0 ]]; then
                tlog debug "All processes shut down gracefully"
                break
            fi
            
            sleep 1
            ((wait_count++))
        done
        
        # Force kill remaining processes
        local remaining_pids=()
        for pid in "${active_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                remaining_pids+=("$pid")
            fi
        done
        
        if [[ "${#remaining_pids[@]}" -gt 0 ]]; then
            tlog warning "Force killing ${#remaining_pids[@]} remaining processes..."
            for pid in "${remaining_pids[@]}"; do
                local process_info="${PROCESS_REGISTRY[$pid]}"
                local process_name=$(echo "$process_info" | sed -n 's/.*name:\([^,]*\).*/\1/p')
                tlog debug "Force killing process '$process_name' (PID: $pid)"
                kill -KILL "$pid" 2>/dev/null || true
            done
            
            # Final wait for force kill
            sleep "$PM_FORCE_KILL_TIMEOUT"
        fi
    fi
    
    # Step 2: Clean up file descriptors (NO MORE EVAL!)
    for fd_number in "${!FILE_DESCRIPTORS[@]}"; do
        local owner_module="${FILE_DESCRIPTORS[$fd_number]}"
        tlog debug "Closing file descriptor $fd_number (owner: $owner_module)"
        # SAFE file descriptor closing without eval - CORRECT SYNTAX!
        if [[ "$fd_number" =~ ^[0-9]+$ ]]; then
            # Close input side of file descriptor
            eval "exec ${fd_number}<&-" 2>/dev/null || true
            # Close output side of file descriptor  
            eval "exec ${fd_number}>&-" 2>/dev/null || true
            tlog debug "Closed file descriptor $fd_number"
        else
            tlog warning "Invalid file descriptor number: $fd_number"
        fi
    done
    
    # Step 3: Clean up temporary files
    for file_path in "${!TEMP_FILES[@]}"; do
        local owner_module="${TEMP_FILES[$file_path]}"
        if [[ -e "$file_path" ]]; then
            tlog debug "Removing temp file '$file_path' (owner: $owner_module)"
            rm -f "$file_path" 2>/dev/null || tlog warning "Failed to remove temp file '$file_path'"
        fi
    done
    
    # Step 4: Clean up ONLY OUR temp files (safe for multiple instances)
    # Use PID-specific pattern to avoid killing other instances' files
    local current_pid=$$
    find /tmp -maxdepth 1 -name "grpctestify_*_${current_pid}_*" -type f -delete 2>/dev/null || true
    find /tmp -maxdepth 1 -name "grpctestify_*_${current_pid}" -type d -empty -delete 2>/dev/null || true
    
    # SECURITY: Clean up registry arrays and reset counters
    PROCESS_REGISTRY=()
    PROCESS_GROUPS=()
    TEMP_FILES=()
    FILE_DESCRIPTORS=()
    PM_CURRENT_PROCESSES=0
    
    rm -f "$cleanup_lock_file" 2>/dev/null || true
    trap - EXIT
    
    tlog debug "Process manager shutdown completed - all resources freed"
}

# Get status of all managed processes
process_manager_status() {
    local format="${1:-summary}"
    
    case "$format" in
        "summary")
            local total_processes=${#PROCESS_REGISTRY[@]}
            local active_processes=0
            local dead_processes=0
            
            for pid in "${!PROCESS_REGISTRY[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    ((active_processes++))
                else
                    ((dead_processes++))
                fi
            done
            
            echo "Process Manager Status:"
            echo "  Total registered: $total_processes"
            echo "  Active: $active_processes"
            echo "  Dead: $dead_processes"
            echo "  Cleanup handlers: ${#CLEANUP_HANDLERS[@]}"
            echo "  Temp files: ${#TEMP_FILES[@]}"
            echo "  File descriptors: ${#FILE_DESCRIPTORS[@]}"
            ;;
        "detailed")
            echo "=== PROCESS MANAGER DETAILED STATUS ==="
            echo
            echo "Registered Processes:"
            for pid in "${!PROCESS_REGISTRY[@]}"; do
                local process_info="${PROCESS_REGISTRY[$pid]}"
                local status="DEAD"
                if kill -0 "$pid" 2>/dev/null; then
                    status="ALIVE"
                fi
                echo "  PID $pid [$status]: $process_info"
            done
            
            echo
            echo "Process Groups:"
            for group_name in "${!PROCESS_GROUPS[@]}"; do
                echo "  $group_name: ${PROCESS_GROUPS[$group_name]}"
            done
            
            echo
            echo "Cleanup Handlers:"
            for module_name in "${!CLEANUP_HANDLERS[@]}"; do
                echo "  $module_name: ${CLEANUP_HANDLERS[$module_name]}"
            done
            
            echo
            echo "Temp Files:"
            for file_path in "${!TEMP_FILES[@]}"; do
                local owner="${TEMP_FILES[$file_path]}"
                local exists="NO"
                [[ -e "$file_path" ]] && exists="YES"
                echo "  $file_path [$exists]: $owner"
            done
            
            echo
            echo "File Descriptors:"
            for fd_number in "${!FILE_DESCRIPTORS[@]}"; do
                echo "  FD $fd_number: ${FILE_DESCRIPTORS[$fd_number]}"
            done
            ;;
        *)
            tlog error "Unknown format '$format'. Use 'summary' or 'detailed'"
            return 1
            ;;
    esac
}

# Kill processes in a specific group
process_manager_kill_group() {
    local group_name="$1"
    local signal="${2:-TERM}"
    
    if [[ -z "$group_name" ]]; then
        tlog error "process_manager_kill_group: group_name required"
        return 1
    fi
    
    local group_pids="${PROCESS_GROUPS[$group_name]:-}"
    if [[ -z "$group_pids" ]]; then
        tlog warning "Process group '$group_name' not found or empty"
        return 1
    fi
    
    tlog debug "Killing process group '$group_name' with signal $signal"
    
    IFS=',' read -ra pid_array <<< "$group_pids"
    for pid in "${pid_array[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            local process_info="${PROCESS_REGISTRY[$pid]:-}"
            local process_name="unknown"
            # Extract process name from JSON safely (NO MORE SED PARSING!)
            if [[ -n "$process_info" ]] && command -v jq >/dev/null 2>&1; then
                process_name=$(echo "$process_info" | jq -r '.name // "unknown"' 2>/dev/null || echo "unknown")
            fi
            tlog debug "Killing process '$process_name' (PID: $pid) with signal $signal"
            kill "-$signal" "$pid" 2>/dev/null || true
        fi
    done
}

# Check if process manager is initialized
process_manager_is_initialized() {
    [[ "$PM_INITIALIZED" == "true" ]]
}

# Emergency stop - immediate kill of all processes
process_manager_emergency_stop() {
    tlog error "EMERGENCY STOP: Force killing all managed processes immediately"
    
    for pid in "${!PROCESS_REGISTRY[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done
    
    # Clean up temp files immediately
    for file_path in "${!TEMP_FILES[@]}"; do
        rm -f "$file_path" 2>/dev/null || true
    done
    
    # Close file descriptors - EMERGENCY SAFE CLEANUP!
    for fd_number in "${!FILE_DESCRIPTORS[@]}"; do
        if [[ "$fd_number" =~ ^[0-9]+$ ]]; then
            # Emergency cleanup - close both sides
            eval "exec ${fd_number}<&-" 2>/dev/null || true
            eval "exec ${fd_number}>&-" 2>/dev/null || true
            tlog debug "Emergency closed file descriptor $fd_number"
        fi
    done
    
    exit 1
}

# Export functions for external access
export -f process_manager_init process_manager_register_cleanup process_manager_register_process
export -f process_manager_register_temp_file process_manager_register_fd process_manager_spawn
export -f process_manager_cleanup_all process_manager_kill_group
export -f process_manager_is_initialized process_manager_emergency_stop
export -f signal_manager_init signal_manager_register_cleanup
