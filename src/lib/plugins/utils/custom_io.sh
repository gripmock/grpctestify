#!/bin/bash

# Custom IO System for gRPC Testify
# Provides synchronized, file-less IO operations for parallel test execution
# Uses named pipes (FIFOs) and in-memory buffers instead of temporary files

# Mutex system is automatically loaded by bashly

# Global IO configuration
GRPCTESTIFY_IO_DIR="${TMPDIR:-/tmp}/grpctestify_io_$$"
GRPCTESTIFY_PROGRESS_PIPE="$GRPCTESTIFY_IO_DIR/progress"
GRPCTESTIFY_RESULTS_PIPE="$GRPCTESTIFY_IO_DIR/results"
GRPCTESTIFY_ERRORS_PIPE="$GRPCTESTIFY_IO_DIR/errors"

# In-memory buffers (using associative arrays)
declare -g -A GRPCTESTIFY_PROGRESS_BUFFER
declare -g -A GRPCTESTIFY_RESULTS_BUFFER
declare -g -A GRPCTESTIFY_ERROR_BUFFER
declare -g -A GRPCTESTIFY_OUTPUT_BUFFER

# IO system state
GRPCTESTIFY_IO_INITIALIZED="${GRPCTESTIFY_IO_INITIALIZED:-false}"
GRPCTESTIFY_IO_READER_PID=""

#######################################
# Initialize custom IO system
# Creates named pipes and starts background readers
# Globals:
#   GRPCTESTIFY_IO_DIR, GRPCTESTIFY_IO_INITIALIZED
# Returns:
#   0 on success, 1 on error
#######################################
io_init() {
    if [[ "$GRPCTESTIFY_IO_INITIALIZED" == "true" ]]; then
        return 0
    fi
    
    # Initialize mutex system first
    if ! mutex_init; then
    log_error "Failed to initialize mutex system"
        return 1
    fi
    
    # Create IO directory
    if ! mkdir -p "$GRPCTESTIFY_IO_DIR" 2>/dev/null; then
    log_error "Failed to create IO directory: $GRPCTESTIFY_IO_DIR"
        return 1
    fi
    
    # Create named pipes
    if ! mkfifo "$GRPCTESTIFY_PROGRESS_PIPE" "$GRPCTESTIFY_RESULTS_PIPE" "$GRPCTESTIFY_ERRORS_PIPE" 2>/dev/null; then
    log_error "Failed to create named pipes"
        return 1
    fi
    
    # Start background IO reader
    io_start_reader &
    GRPCTESTIFY_IO_READER_PID=$!
    
    GRPCTESTIFY_IO_INITIALIZED=true
    log_debug "Custom IO system initialized: $GRPCTESTIFY_IO_DIR"
    return 0
}

#######################################
# Cleanup custom IO system
# Stops background processes and removes pipes
# Globals:
#   GRPCTESTIFY_IO_DIR, GRPCTESTIFY_IO_READER_PID
# Returns:
#   0 on success
#######################################
io_cleanup() {
    if [[ "$GRPCTESTIFY_IO_INITIALIZED" != "true" ]]; then
        return 0
    fi
    
    # Stop background reader
    if [[ -n "$GRPCTESTIFY_IO_READER_PID" ]] && kill -0 "$GRPCTESTIFY_IO_READER_PID" 2>/dev/null; then
        kill "$GRPCTESTIFY_IO_READER_PID" 2>/dev/null
        wait "$GRPCTESTIFY_IO_READER_PID" 2>/dev/null
    fi
    
    # Remove IO directory
    if [[ -d "$GRPCTESTIFY_IO_DIR" ]]; then
        rm -rf "$GRPCTESTIFY_IO_DIR"
    fi
    
    # Cleanup mutex system
    mutex_cleanup
    
    GRPCTESTIFY_IO_INITIALIZED=false
    log_debug "Custom IO system cleaned up"
    return 0
}

#######################################
# Background IO reader process
# Reads from named pipes and stores in memory buffers
# Globals:
#   GRPCTESTIFY_*_PIPE, GRPCTESTIFY_*_BUFFER
# Returns:
#   Never returns (background process)
#######################################
io_start_reader() {
    exec 3< "$GRPCTESTIFY_PROGRESS_PIPE" &
    exec 4< "$GRPCTESTIFY_RESULTS_PIPE" &
    exec 5< "$GRPCTESTIFY_ERRORS_PIPE" &
    
    local iteration_count=0
    local max_iterations=30000  # Prevent infinite loops (30000 * 0.01s = 5min max)
    
    while [[ "$GRPCTESTIFY_IO_INITIALIZED" == "true" && $iteration_count -lt $max_iterations ]]; do
        # Read progress updates
        if read -r -t 0.1 -u 3 line 2>/dev/null; then
            mutex_with_state_lock io_store_progress "$line"
        fi
        
        # Read test results
        if read -r -t 0.1 -u 4 line 2>/dev/null; then
            mutex_with_state_lock io_store_result "$line"
        fi
        
        # Read error messages
        if read -r -t 0.1 -u 5 line 2>/dev/null; then
            mutex_with_state_lock io_store_error "$line"
        fi
        
        # Increment iteration count and small sleep to prevent busy loop
        ((iteration_count++))
        sleep 0.01
    done
    
    # Log if we hit max iterations
    if [[ $iteration_count -ge $max_iterations ]]; then
        log_warn "IO reader reached maximum iterations ($max_iterations) - stopping to prevent infinite loop"
    fi
    
    exec 3<&- 4<&- 5<&-
}

#######################################
# Store progress update in memory buffer
# Arguments:
#   1: Progress message (format: "test_name:status:symbol")
# Globals:
#   GRPCTESTIFY_PROGRESS_BUFFER
# Returns:
#   0 on success
#######################################
io_store_progress() {
    local message="$1"
    local test_name status symbol
    
    IFS=':' read -r test_name status symbol <<< "$message"
    GRPCTESTIFY_PROGRESS_BUFFER["$test_name"]="$status:$symbol"
    
    # Immediately display progress symbol
    if [[ -n "$symbol" ]]; then
        mutex_printf "%s" "$symbol"
    fi
}

#######################################
# Store test result in memory buffer
# Arguments:
#   1: Result message (format: "test_name:status:duration:details")
# Globals:
#   GRPCTESTIFY_RESULTS_BUFFER
# Returns:
#   0 on success
#######################################
io_store_result() {
    local message="$1"
    local test_name status duration details
    
    IFS=':' read -r test_name status duration details <<< "$message"
    GRPCTESTIFY_RESULTS_BUFFER["$test_name"]="$status:$duration:$details"
}

#######################################
# Store error message in memory buffer
# Arguments:
#   1: Error message (format: "test_name:error_details")
# Globals:
#   GRPCTESTIFY_ERROR_BUFFER
# Returns:
#   0 on success
#######################################
io_store_error() {
    local message="$1"
    local test_name error_details
    
    IFS=':' read -r test_name error_details <<< "$message"
    GRPCTESTIFY_ERROR_BUFFER["$test_name"]="$error_details"
}

#######################################
# Send progress update to IO system
# Arguments:
#   1: Test name
#   2: Status (running, passed, failed, skipped)
#   3: Display symbol (., F, S, etc.)
# Returns:
#   0 on success
#######################################
io_send_progress() {
    local test_name="$1"
    local status="$2"
    local symbol="$3"
    
    if [[ "$GRPCTESTIFY_IO_INITIALIZED" == "true" ]]; then
        echo "$test_name:$status:$symbol" > "$GRPCTESTIFY_PROGRESS_PIPE" &
    else
        # Fallback to direct output
        mutex_printf "%s" "$symbol"
    fi
}

#######################################
# Send test result to IO system
# Arguments:
#   1: Test name
#   2: Status (PASSED, FAILED, ERROR, SKIPPED)
#   3: Duration in milliseconds
#   4: Additional details (optional)
# Returns:
#   0 on success
#######################################
io_send_result() {
    local test_name="$1"
    local status="$2"
    local duration="$3"
    local details="${4:-}"
    
    if [[ "$GRPCTESTIFY_IO_INITIALIZED" == "true" ]]; then
        echo "$test_name:$status:$duration:$details" > "$GRPCTESTIFY_RESULTS_PIPE" &
    else
        # Fallback to state system
        test_state_record_result "$test_name" "$status" "$duration" "$details"
    fi
}

#######################################
# Send error message to IO system
# Arguments:
#   1: Test name
#   2: Error details
# Returns:
#   0 on success
#######################################
io_send_error() {
    local test_name="$1"
    local error_details="$2"
    
    if [[ "$GRPCTESTIFY_IO_INITIALIZED" == "true" ]]; then
        echo "$test_name:$error_details" > "$GRPCTESTIFY_ERRORS_PIPE" &
    else
        # Fallback to error storage
        store_test_failure "$test_name" "$error_details"
    fi
}

#######################################
# Get all progress updates from buffer
# Globals:
#   GRPCTESTIFY_PROGRESS_BUFFER
# Returns:
#   Prints all progress updates
#######################################
io_get_progress() {
    mutex_with_state_lock bash -c '
        for test_name in "${!GRPCTESTIFY_PROGRESS_BUFFER[@]}"; do
            echo "$test_name:${GRPCTESTIFY_PROGRESS_BUFFER[$test_name]}"
        done
    '
}

#######################################
# Get all test results from buffer
# Globals:
#   GRPCTESTIFY_RESULTS_BUFFER
# Returns:
#   Prints all test results
#######################################
io_get_results() {
    mutex_with_state_lock bash -c '
        for test_name in "${!GRPCTESTIFY_RESULTS_BUFFER[@]}"; do
            echo "$test_name:${GRPCTESTIFY_RESULTS_BUFFER[$test_name]}"
        done
    '
}

#######################################
# Get all error messages from buffer
# Globals:
#   GRPCTESTIFY_ERROR_BUFFER
# Returns:
#   Prints all error messages
#######################################
io_get_errors() {
    mutex_with_state_lock bash -c '
        for test_name in "${!GRPCTESTIFY_ERROR_BUFFER[@]}"; do
            echo "$test_name:${GRPCTESTIFY_ERROR_BUFFER[$test_name]}"
        done
    '
}

#######################################
# Clear all IO buffers
# Globals:
#   GRPCTESTIFY_*_BUFFER
# Returns:
#   0 on success
#######################################
io_clear_buffers() {
    mutex_with_state_lock bash -c '
        GRPCTESTIFY_PROGRESS_BUFFER=()
        GRPCTESTIFY_RESULTS_BUFFER=()
        GRPCTESTIFY_ERROR_BUFFER=()
        GRPCTESTIFY_OUTPUT_BUFFER=()
    '
}

#######################################
# Get IO system status
# Returns:
#   Prints IO system status
#######################################
io_status() {
    echo "Custom IO System Status:"
    echo "  Initialized: $GRPCTESTIFY_IO_INITIALIZED"
    echo "  Directory: $GRPCTESTIFY_IO_DIR"
    echo "  Reader PID: $GRPCTESTIFY_IO_READER_PID"
    
    if [[ "$GRPCTESTIFY_IO_INITIALIZED" == "true" ]]; then
        echo "  Progress Buffer: ${#GRPCTESTIFY_PROGRESS_BUFFER[@]} entries"
        echo "  Results Buffer: ${#GRPCTESTIFY_RESULTS_BUFFER[@]} entries"
        echo "  Error Buffer: ${#GRPCTESTIFY_ERROR_BUFFER[@]} entries"
    fi
}

#######################################
# Synchronized output function
# Replaces printf/echo with mutex-protected output
# Arguments:
#   1: Format string
#   2+: Arguments
# Returns:
#   0 on success
#######################################
io_printf() {
    mutex_printf "$@"
}

#######################################
# Synchronized error output function
# Arguments:
#   1+: Error message
# Returns:
#   0 on success
#######################################
io_error() {
    mutex_eprint "$@"
}

#######################################
# Synchronized newline output
# Returns:
#   0 on success
#######################################
io_newline() {
    mutex_printf "\n"
}

# Cleanup on exit
# REMOVED: trap 'io_cleanup' EXIT  
# Now using unified signal_manager for proper cleanup handling

# Export functions
export -f io_init io_cleanup io_start_reader
export -f io_store_progress io_store_result io_store_error
export -f io_send_progress io_send_result io_send_error
export -f io_get_progress io_get_results io_get_errors
export -f io_clear_buffers io_status
export -f io_printf io_error io_newline
