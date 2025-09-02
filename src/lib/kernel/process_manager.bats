#!/usr/bin/env bats

# process_manager.bats - Tests for process management functionality

# Test setup
setup() {
    export BATS_TEST_ISOLATED=1
    
    # Load the module under test
    source "src/lib/kernel/process_manager.sh"
    
    # Mock logging to avoid conflicts
    tlog() { echo "TEST LOG [$1]: $2" >&2; }
    export -f tlog
}

teardown() {
    # Clean up test environment
    process_manager_cleanup_all 2>/dev/null || true
}

#######################################
# REAL FUNCTIONALITY TESTS
#######################################

@test "process_manager initialization works" {
    # Test that initialization actually works
    run process_manager_init
    [ "$status" -eq 0 ]
}

@test "signal_manager initialization works" {
    run signal_manager_init
    [ "$status" -eq 0 ]
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

@test "process registration works with valid process" {
    # Register current shell process
    local current_pid=$$
    run process_manager_register_process "$current_pid" "test_process" "test_group"
    [ "$status" -eq 0 ]
}

@test "temp file management works" {
    # Register temp file
    local test_file="/tmp/test_file_$$"
    touch "$test_file"
    run process_manager_register_temp_file "$test_file" "test_module"
    [ "$status" -eq 0 ]
    
    # Clean up
    rm -f "$test_file" 2>/dev/null || true
}

@test "file descriptor management works" {
    # Register file descriptor
    run process_manager_register_fd "3" "test_fd"
    [ "$status" -eq 0 ]
}

@test "process spawning works" {
    # Test process spawning
    run process_manager_spawn "test_command" "test_process"
    [ "$status" -eq 0 ]
}
