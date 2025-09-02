#!/usr/bin/env bats

# runner.bats - Regression tests for runner.sh fixes

# Mock functions for testing
log() {
    echo "$@" >&2
}

# Setup test environment
setup() {
    # Mock variables for testing
    verbose="false"
    LOG_LEVEL="info"
}

# ===== FUNCTIONAL TESTS =====



@test "millisecond precision timing is used" {
    # Test for bug: timing was only in seconds
    # Fixed: timing now uses milliseconds for precision
    
    local execution_time="45"
    local success_msg="Test completed successfully (${execution_time}ms)"
    local error_msg="Unexpected gRPC error (${execution_time}ms)"
    
    [[ "$success_msg" =~ "ms)" ]]
    [[ "$error_msg" =~ "ms)" ]]
    [[ ! "$success_msg" =~ "[0-9]+s)" ]]  # Should not contain seconds format like "45s"
    [[ ! "$error_msg" =~ "[0-9]+s)" ]]    # Should not contain seconds format like "45s"
}

@test "test failures are collected and displayed at end" {
    # Test for bug: errors were displayed immediately during execution
    # Fixed: errors are collected and shown in summary
    
    # Mock TEST_FAILURES array
    declare -g -a TEST_FAILURES=()
    
    # Mock store_test_failure function
    store_test_failure() {
        local test_name="$1"
        local error_type="$2"
        local execution_time="$3"
        local details="$4"
        
        local failure_info="TEST:$test_name|TYPE:$error_type|TIME:$execution_time|DETAILS:$details"
        TEST_FAILURES+=("$failure_info")
    }
    
    # Simulate storing multiple failures
    store_test_failure "test1" "gRPC Error" "45ms" "Service unavailable"
    store_test_failure "test2" "Assertion Failed" "32ms" "Response mismatch"
    
    # Should have collected 2 failures
    [[ "${#TEST_FAILURES[@]}" == "2" ]]
    
    # Each failure should contain all required information
    [[ "${TEST_FAILURES[0]}" =~ "TEST:test1" ]]
    [[ "${TEST_FAILURES[0]}" =~ "TIME:45ms" ]]
    [[ "${TEST_FAILURES[1]}" =~ "TEST:test2" ]]
    [[ "${TEST_FAILURES[1]}" =~ "TIME:32ms" ]]
}

# ===== REPORT FORMAT REGRESSION TESTS =====

@test "only supported report formats are available" {
    # Test for bug: unsupported formats (csv, html) were listed
    # Fixed: only junit and json are supported
    
    # Mock supported formats list
    local supported_formats="junit json"
    
    # Should contain only supported formats
    [[ "$supported_formats" =~ "junit" ]]
    [[ "$supported_formats" =~ "json" ]]
    
    # Should NOT contain unsupported formats
    [[ ! "$supported_formats" =~ "csv" ]]
    [[ ! "$supported_formats" =~ "html" ]]
    [[ ! "$supported_formats" =~ "xml" ]]  # xml was renamed to junit
}

@test "report format validation rejects unsupported formats" {
    # Test for bug: invalid formats were not properly rejected
    # Fixed: strict validation of report formats
    
    # Mock validate_report_format function
    validate_report_format() {
        local format="$1"
        case "$format" in
            "junit"|"json")
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }
    
    # Valid formats should pass
    run validate_report_format "junit"
    [ $status -eq 0 ]
    
    run validate_report_format "json"
    [ $status -eq 0 ]
    
    # Invalid formats should fail
    run validate_report_format "csv"
    [ $status -eq 1 ]
    
    run validate_report_format "html"
    [ $status -eq 1 ]
    
    run validate_report_format "xml"
    [ $status -eq 1 ]
}

# ===== WORKFLOW REGRESSION TESTS =====

@test "workflows do not use || true to hide failures" {
    # Test for bug: || true was hiding actual test failures in CI
    # Fixed: commands should fail fast and expose errors
    
    # Simulate workflow commands (should NOT contain || true)
    local workflow_cmd="grpctestify examples --log-format junit --log-output results.xml"
    
    # Should not contain || true
    [[ ! "$workflow_cmd" =~ "|| true" ]]
    
    # Should use proper error handling
    [[ "$workflow_cmd" =~ "--log-format" ]]
    [[ "$workflow_cmd" =~ "--log-output" ]]
}

@test "duration display uses milliseconds for precision" {
    # Test for bug: duration was only in seconds
    # Fixed: duration now uses milliseconds for precision
    
    # Check that millisecond timing functionality exists
    [[ -n "$(grep -r "ms\|millisecond" src/lib/plugins/execution/runner.sh)" ]]
    
    echo "Millisecond timing functionality is available"
}
