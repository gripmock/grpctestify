#!/usr/bin/env bats

# Tests for JUnit Reporter Plugin

setup() {
    # Load plugin
    source src/lib/plugins/grpc_junit_reporter.sh
    
    # Mock dependencies
    export APP_VERSION="1.0.0-test"
    
    # Create test directory
    TEST_DIR="$BATS_TMPDIR/junit_test_$$"
    mkdir -p "$TEST_DIR"
    
    # Mock log function if not available
    if ! declare -f log >/dev/null 2>&1; then
        log() { echo "[$1] $2" >&2; }
        export -f log
    fi
    
    # Mock register_plugin function if not available
    if ! declare -f register_plugin >/dev/null 2>&1; then
        register_plugin() { return 0; }
        export -f register_plugin
    fi
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "Plugin registration works" {
    run register_plugin "junit_reporter" "junit_format_report" "Generate JUnit XML reports" "internal"
    [ "$status" -eq 0 ]
}

@test "JUnit format report requires output file parameter" {
    run junit_format_report
    [ "$status" -eq 1 ]
    [[ "$stderr" =~ "Missing required parameters" ]]
}

@test "JUnit format report requires test results parameter" {
    run junit_format_report "$TEST_DIR/output.xml"
    [ "$status" -eq 1 ]
    [[ "$stderr" =~ "Missing required parameters" ]]
}

@test "JUnit XML generation with simple test results" {
    local test_results='{
        "total": 3,
        "passed": 2,
        "failed": 1,
        "skipped": 0,
        "tests": [
            {"name": "test1", "status": "passed", "duration": 1.5},
            {"name": "test2", "status": "passed", "duration": 2.0},
            {"name": "test3", "status": "failed", "duration": 0.5, "error": "Connection failed"}
        ]
    }'
    
    local start_time=1000
    local end_time=1010
    local output_file="$TEST_DIR/results.xml"
    
    run junit_format_report "$output_file" "$test_results" "$start_time" "$end_time"
    [ "$status" -eq 0 ]
    [ -f "$output_file" ]
}

@test "Generated JUnit XML has valid structure" {
    local test_results='{
        "total": 2,
        "passed": 1,
        "failed": 1,
        "skipped": 0,
        "tests": [
            {"name": "passing_test", "status": "passed", "duration": 1.0},
            {"name": "failing_test", "status": "failed", "duration": 2.0, "error": "Test error message"}
        ]
    }'
    
    local output_file="$TEST_DIR/test.xml"
    junit_format_report "$output_file" "$test_results" "1000" "1005"
    
    # Check XML structure
    run xmllint --noout "$output_file" 2>/dev/null || true
    
    # Check required elements exist
    grep -q '<?xml version="1.0" encoding="UTF-8"?>' "$output_file"
    grep -q '<testsuites' "$output_file"
    grep -q '<testsuite' "$output_file"
    grep -q '</testsuites>' "$output_file"
    grep -q 'tests="2"' "$output_file"
    grep -q 'failures="1"' "$output_file"
}

@test "JUnit XML contains test case details" {
    local test_results='{
        "total": 1,
        "passed": 0,
        "failed": 1,
        "skipped": 0,
        "tests": [
            {"name": "error_test", "status": "failed", "duration": 1.5, "error": "Connection timeout"}
        ]
    }'
    
    local output_file="$TEST_DIR/detailed.xml"
    junit_format_report "$output_file" "$test_results" "1000" "1003"
    
    # Check test case is present
    grep -q '<testcase name="error_test"' "$output_file"
    grep -q 'time="1.5"' "$output_file"
    grep -q '<failure message="Test failed">' "$output_file"
    grep -q 'Connection timeout' "$output_file"
}

@test "JUnit XML handles skipped tests" {
    local test_results='{
        "total": 2,
        "passed": 1,
        "failed": 0,
        "skipped": 1,
        "tests": [
            {"name": "normal_test", "status": "passed", "duration": 1.0},
            {"name": "skipped_test", "status": "skipped", "duration": 0}
        ]
    }'
    
    local output_file="$TEST_DIR/skipped.xml"
    junit_format_report "$output_file" "$test_results" "1000" "1002"
    
    grep -q 'skipped="1"' "$output_file"
    grep -q '<skipped/>' "$output_file"
}

@test "Plugin validation checks for jq dependency" {
    # Mock jq command not found
    PATH="/nonexistent:$PATH" run junit_validate_config
    [ "$status" -eq 1 ]
    [[ "$stderr" =~ "requires 'jq'" ]]
}

@test "Plugin validation passes when jq is available" {
    # Assuming jq is available in test environment
    if command -v jq >/dev/null 2>&1; then
        run junit_validate_config
        [ "$status" -eq 0 ]
    else
        skip "jq not available in test environment"
    fi
}

@test "Plugin help displays usage information" {
    run junit_plugin_help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "JUnit Reporter Plugin" ]]
    [[ "$output" =~ "--log-junit" ]]
    [[ "$output" =~ "Examples:" ]]
}

@test "Output directory is created if it doesn't exist" {
    local nested_dir="$TEST_DIR/reports/nested/deep"
    local test_results='{"total": 1, "passed": 1, "failed": 0, "skipped": 0, "tests": []}'
    local output_file="$nested_dir/results.xml"
    
    # Directory shouldn't exist initially
    [ ! -d "$nested_dir" ]
    
    junit_format_report "$output_file" "$test_results" "1000" "1001"
    
    # Directory should be created and file should exist
    [ -d "$nested_dir" ]
    [ -f "$output_file" ]
}

@test "XML escapes special characters in error messages" {
    local test_results='{
        "total": 1,
        "passed": 0,
        "failed": 1,
        "skipped": 0,
        "tests": [
            {"name": "xml_test", "status": "failed", "duration": 1.0, "error": "Error with <xml> & \"quotes\""}
        ]
    }'
    
    local output_file="$TEST_DIR/escaped.xml"
    junit_format_report "$output_file" "$test_results" "1000" "1001"
    
    # Error message should be in CDATA section for proper escaping
    grep -q '<!\[CDATA\[Error with <xml> & "quotes"\]\]>' "$output_file"
}
