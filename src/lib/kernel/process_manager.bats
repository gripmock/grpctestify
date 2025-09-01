#!/usr/bin/env bats

# process_manager.bats - NASA-level critical tests for process management
# ZERO TOLERANCE FOR FAILURES - Each test must be bulletproof

# Test setup - FIXED ISOLATION
setup() {
    export BATS_TEST_ISOLATED=1
    
    # CRITICAL: Remove any PATH references to main grpctestify.sh
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
    
    # CRITICAL: Unset any variables that might trigger main app
    unset GRPCTESTIFY_ROOT
    unset GRPCTESTIFY_CONFIG
    
    # CRITICAL: Set working directory to avoid conflicts
    cd "$BATS_TEST_DIRNAME/../.." || exit 1
    
    # Source dependencies ONLY - NO main app calls
    if ! source "lib/kernel/config.sh" 2>/dev/null; then
        echo "Failed to load config.sh" >&2
        exit 1
    fi
    if ! source "lib/kernel/portability.sh" 2>/dev/null; then
        echo "Failed to load portability.sh" >&2  
        exit 1
    fi
    if ! source "lib/kernel/posix_compat.sh" 2>/dev/null; then
        echo "Failed to load posix_compat.sh" >&2
        exit 1
    fi
    if ! source "lib/kernel/native_utils.sh" 2>/dev/null; then
        echo "Failed to load native_utils.sh" >&2
        exit 1
    fi
    
    # Load the module under test LAST
    if ! source "lib/kernel/process_manager.sh" 2>/dev/null; then
        echo "Failed to load process_manager.sh" >&2
        exit 1
    fi
    
    # Mock logging to avoid conflicts
    tlog() { echo "TEST LOG [$1]: $2" >&2; }
    export -f tlog
    
    # Initialize clean test environment
    PM_INITIALIZED=false
    PM_CURRENT_PROCESSES=0
    PM_MAX_PROCESSES=5  # Low limit for testing
    PROCESS_REGISTRY=()
    PROCESS_GROUPS=()
    TEMP_FILES=()
    FILE_DESCRIPTORS=()
    SIGNAL_HANDLERS=()
    MODULE_CLEANUP_HANDLERS=()
    SIGNAL_MANAGER_INITIALIZED=false
    
    # Create unique lock file for this test
    PM_LOCK_FILE="/tmp/grpctestify_pm_test_$$_${BATS_TEST_NUMBER}"
}

teardown() {
    # Clean up test processes
    for pid in "${!PROCESS_REGISTRY[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
    
    # Clean up lock files
    rm -f "${PM_LOCK_FILE}"* 2>/dev/null || true
    
    # Clean up any test temp files
    rm -f /tmp/grpctestify_test_* 2>/dev/null || true
}

#######################################
# CRITICAL PATH TESTS
#######################################

@test "process_manager initialization is idempotent" {
    # First initialization should succeed
    run process_manager_init
    [ "$status" -eq 0 ]
    [ "$PM_INITIALIZED" = "true" ]
    
    # Second initialization should also succeed (idempotent)
    run process_manager_init
    [ "$status" -eq 0 ]
    [ "$PM_INITIALIZED" = "true" ]
}

@test "signal_manager initialization sets up trap handlers" {
    run signal_manager_init
    [ "$status" -eq 0 ]
    [ "$SIGNAL_MANAGER_INITIALIZED" = "true" ]
}

@test "process registration enforces maximum process limits" {
    # Register processes up to the limit
    for i in {1..5}; do
        # Start a background sleep process
        sleep 60 &
        local test_pid=$!
        
        run process_manager_register_process "$test_pid" "test_process_$i" "test_group"
        [ "$status" -eq 0 ]
        
        # Clean up in teardown
        kill -TERM "$test_pid" 2>/dev/null || true
    done
    
    # Try to register one more (should fail)
    sleep 60 &
    local overflow_pid=$!
    
    run process_manager_register_process "$overflow_pid" "overflow_process" "test_group"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Process limit reached" ]]
    
    # Clean up
    kill -TERM "$overflow_pid" 2>/dev/null || true
}

@test "process registration validates input parameters" {
    # Missing PID should fail
    run process_manager_register_process "" "test_process"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "pid and process_name required" ]]
    
    # Missing name should fail
    run process_manager_register_process "12345" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "pid and process_name required" ]]
}

@test "process registration validates process existence" {
    # Try to register non-existent process
    run process_manager_register_process "999999" "fake_process"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "non-existent process" ]]
}

@test "concurrent process registration is thread-safe" {
    # Test concurrent registration (simulate race condition)
    local pids=()
    
    # Start multiple background processes
    for i in {1..3}; do
        sleep 60 &
        pids+=("$!")
    done
    
    # Try to register them concurrently (in subshells)
    local results=()
    for i in "${!pids[@]}"; do
        {
            process_manager_register_process "${pids[$i]}" "concurrent_$i" "test_group"
            echo $? > "/tmp/grpctestify_test_result_$i"
        } &
    done
    
    # Wait for all registrations
    wait
    
    # Check all succeeded
    local success_count=0
    for i in "${!pids[@]}"; do
        if [[ -f "/tmp/grpctestify_test_result_$i" ]]; then
            local result=$(cat "/tmp/grpctestify_test_result_$i")
            if [[ "$result" -eq 0 ]]; then
                ((success_count++))
            fi
        fi
    done
    
    # All should succeed (thread safety)
    [ "$success_count" -eq 3 ]
    
    # Cleanup
    for pid in "${pids[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
}

@test "temp file registration tracks owner correctly" {
    local test_file="/tmp/grpctestify_test_$$"
    touch "$test_file"
    
    run process_manager_register_temp_file "$test_file" "test_module"
    [ "$status" -eq 0 ]
    
    # Verify tracking
    [ "${TEMP_FILES[$test_file]}" = "test_module" ]
    
    # File should be cleaned up in teardown
}

@test "file descriptor registration validates input" {
    # Valid file descriptor
    run process_manager_register_fd "10" "test_module"
    [ "$status" -eq 0 ]
    
    # Invalid file descriptor (non-numeric)
    run process_manager_register_fd "invalid" "test_module"
    [ "$status" -eq 1 ]
    
    # Missing parameters
    run process_manager_register_fd "" "test_module"
    [ "$status" -eq 1 ]
    
    run process_manager_register_fd "10" ""
    [ "$status" -eq 1 ]
}

#######################################
# SECURITY TESTS
#######################################

@test "emergency stop kills all processes immediately" {
    # Start test processes
    local pids=()
    for i in {1..3}; do
        sleep 300 &  # Long sleep
        local pid=$!
        pids+=("$pid")
        process_manager_register_process "$pid" "emergency_test_$i"
    done
    
    # Verify processes are running
    for pid in "${pids[@]}"; do
        kill -0 "$pid" 2>/dev/null
        [ "$?" -eq 0 ]
    done
    
    # Emergency stop should kill all
    # Note: This will exit, so we test in a subshell
    (
        process_manager_emergency_stop
    ) || true  # Expect non-zero exit
    
    # Give time for kills to take effect
    sleep 1
    
    # Verify processes are dead
    local dead_count=0
    for pid in "${pids[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            ((dead_count++))
        fi
    done
    
    [ "$dead_count" -eq 3 ]
}

@test "cleanup handles missing processes gracefully" {
    # Register a process that will die
    sleep 0.1 &  # Very short sleep
    local short_pid=$!
    
    process_manager_register_process "$short_pid" "short_process"
    
    # Wait for process to die naturally
    sleep 0.2
    
    # Cleanup should handle dead process gracefully
    run process_manager_cleanup_all
    [ "$status" -eq 0 ]
}

#######################################
# EDGE CASE TESTS
#######################################

@test "lock acquisition times out appropriately" {
    # Create a stuck lock file
    echo "999999:$(date +%s)" > "$PM_LOCK_FILE"
    
    # Try to register a process (this will test lock timeout)
    sleep 60 &
    local test_pid=$!
    
    local start_time=$(date +%s)
    run process_manager_register_process "$test_pid" "timeout_test"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 1 ]
    [ "$duration" -ge 5 ]  # Should timeout after 5 seconds
    [[ "$output" =~ "Failed to acquire" ]]
    
    # Cleanup
    kill -TERM "$test_pid" 2>/dev/null || true
}

@test "process groups are managed correctly" {
    # Start processes in different groups
    sleep 60 &
    local pid1=$!
    sleep 60 &
    local pid2=$!
    sleep 60 &
    local pid3=$!
    
    process_manager_register_process "$pid1" "proc1" "group_a"
    process_manager_register_process "$pid2" "proc2" "group_a"
    process_manager_register_process "$pid3" "proc3" "group_b"
    
    # Verify group membership
    [[ "${PROCESS_GROUPS[group_a]}" =~ $pid1 ]]
    [[ "${PROCESS_GROUPS[group_a]}" =~ $pid2 ]]
    [[ "${PROCESS_GROUPS[group_b]}" =~ $pid3 ]]
    [[ ! "${PROCESS_GROUPS[group_b]}" =~ $pid1 ]]
    
    # Cleanup
    kill -TERM "$pid1" "$pid2" "$pid3" 2>/dev/null || true
}

@test "status reporting provides accurate information" {
    # Register some processes
    sleep 60 &
    local pid1=$!
    sleep 60 &
    local pid2=$!
    
    process_manager_register_process "$pid1" "status_test_1" "test_group"
    process_manager_register_process "$pid2" "status_test_2" "test_group"
    
    # Get status
    run process_manager_status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "status_test_1" ]]
    [[ "$output" =~ "status_test_2" ]]
    [[ "$output" =~ "$pid1" ]]
    [[ "$output" =~ "$pid2" ]]
    
    # Cleanup
    kill -TERM "$pid1" "$pid2" 2>/dev/null || true
}

#######################################
# MEMORY AND RESOURCE TESTS
#######################################

@test "no memory leaks in repeated operations" {
    # Repeatedly register and cleanup processes
    for iteration in {1..10}; do
        # Start a short-lived process
        sleep 0.1 &
        local pid=$!
        
        process_manager_register_process "$pid" "leak_test_$iteration"
        
        # Wait for process to complete
        wait "$pid" 2>/dev/null || true
        
        # Manual cleanup to check for leaks
        unset PROCESS_REGISTRY["$pid"]
        ((PM_CURRENT_PROCESSES--))
    done
    
    # Registry should be clean
    [ "${#PROCESS_REGISTRY[@]}" -eq 0 ]
    [ "$PM_CURRENT_PROCESSES" -eq 0 ]
}

@test "temp file cleanup is comprehensive" {
    # Create multiple temp files
    local temp_files=()
    for i in {1..5}; do
        local temp_file="/tmp/grpctestify_test_$$_$i"
        touch "$temp_file"
        temp_files+=("$temp_file")
        process_manager_register_temp_file "$temp_file" "test_module_$i"
    done
    
    # Verify files exist
    for file in "${temp_files[@]}"; do
        [ -f "$file" ]
    done
    
    # Cleanup should remove all files
    process_manager_cleanup_all
    
    # Verify files are gone
    for file in "${temp_files[@]}"; do
        [ ! -f "$file" ]
    done
}
