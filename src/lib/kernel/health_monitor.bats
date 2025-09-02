#!/usr/bin/env bats

# health_monitor.bats - Tests for health monitoring functionality

# Test setup
setup() {
    export BATS_TEST_ISOLATED=1
    
    # Load the module under test
    source "src/lib/kernel/health_monitor.sh"
    
    # Mock logging to avoid conflicts
    tlog() { echo "TEST LOG [$1]: $2" >&2; }
    export -f tlog
}

teardown() {
    # Clean up test environment
    health_monitor_cleanup_all 2>/dev/null || true
}

#######################################
# REAL FUNCTIONALITY TESTS
#######################################

@test "health monitor initialization works" {
    # Test that initialization actually works
    run health_monitor_init
    [ "$status" -eq 0 ]
    
    # Should not fail on second call
    run health_monitor_init
    [ "$status" -eq 0 ]
}

@test "health monitor can create monitors" {
    # Initialize first
    health_monitor_init
    
    # Create a monitor
    run health_monitor_create "test_monitor" "5" "10"
    [ "$status" -eq 0 ]
    
    # Should not fail on second creation
    run health_monitor_create "test_monitor" "5" "10"
    [ "$status" -eq 0 ]
}

@test "health monitor can register processes" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Register a process (using current shell PID)
    local current_pid=$$
    run health_monitor_register "test_process" "$current_pid" "test_monitor"
    [ "$status" -eq 0 ]
    
    # Should not fail on second registration
    run health_monitor_register "test_process" "$current_pid" "test_monitor"
    [ "$status" -eq 0 ]
}

@test "health monitor rejects invalid registrations" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Empty process ID should fail
    run health_monitor_register "" "12345" "test_monitor"
    [ "$status" -ne 0 ]
    
    # Empty PID should fail
    run health_monitor_register "test_process" "" "test_monitor"
    [ "$status" -ne 0 ]
}

@test "health monitor can unregister processes" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Register a process
    local current_pid=$$
    health_monitor_register "test_process" "$current_pid" "test_monitor"
    
    # Unregister the process
    run health_monitor_unregister "test_process"
    [ "$status" -eq 0 ]
    
    # Should not fail on second unregistration
    run health_monitor_unregister "test_process"
    [ "$status" -eq 0 ]
}

@test "health monitor can check process health" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Register current shell process
    local current_pid=$$
    health_monitor_register "test_process" "$current_pid" "test_monitor"
    
    # Check health
    run health_check_process "test_process"
    [ "$status" -eq 0 ]
}

@test "health monitor handles non-existent processes" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Try to check health of non-existent process
    run health_check_process "nonexistent_process"
    [ "$status" -ne 0 ]
}

@test "health monitor can list processes" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Register a process
    local current_pid=$$
    health_monitor_register "test_process" "$current_pid" "test_monitor"
    
    # List processes
    run health_list_processes
    [ "$status" -eq 0 ]
}

@test "health monitor can get status" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Register a process
    local current_pid=$$
    health_monitor_register "test_process" "$current_pid" "test_monitor"
    
    # Get status
    run health_get_status "test_process"
    [ "$status" -eq 0 ]
}

@test "health monitor can get statistics" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Get stats
    run health_get_stats
    [ "$status" -eq 0 ]
}

@test "health monitor can stop monitors" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Stop the monitor
    run health_monitor_stop "test_monitor"
    [ "$status" -eq 0 ]
    
    # Should not fail on second stop
    run health_monitor_stop "test_monitor"
    [ "$status" -eq 0 ]
}

@test "health monitor can pause and resume" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Pause the monitor
    run health_monitor_pause "test_monitor"
    [ "$status" -eq 0 ]
    
    # Resume the monitor
    run health_monitor_resume "test_monitor"
    [ "$status" -eq 0 ]
}

@test "health monitor can cleanup all" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Register a process
    local current_pid=$$
    health_monitor_register "test_process" "$current_pid" "test_monitor"
    
    # Cleanup all
    run health_monitor_cleanup_all
    [ "$status" -eq 0 ]
    
    # Should not fail on second cleanup
    run health_monitor_cleanup_all
    [ "$status" -eq 0 ]
}

@test "health monitor can check if monitor exists" {
    # Initialize and create monitor
    health_monitor_init
    health_monitor_create "test_monitor" "5" "10"
    
    # Check if monitor exists
    run health_monitor_exists "test_monitor"
    [ "$status" -eq 0 ]
    
    # Check non-existent monitor
    run health_monitor_exists "nonexistent_monitor"
    [ "$status" -ne 0 ]
}
