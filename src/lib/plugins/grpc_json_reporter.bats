#!/usr/bin/env bats

# Tests for JSON Reporter Plugin

setup() {
    # Load plugin
    source src/lib/plugins/grpc_json_reporter.sh
    
    # Mock dependencies
    export APP_VERSION="1.0.0-test"
    
    # Create test directory
    TEST_DIR="$BATS_TMPDIR/json_test_$$"
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

@test "JSON format report requires parameters" {
    run json_format_report
    [ "$status" -eq 1 ]
    [[ "$stderr" =~ "Missing required parameters" ]]
}

@test "JSON report generation with test results" {
    local test_results='{
        "total": 2,
        "passed": 1,
        "failed": 1,
        "skipped": 0,
        "tests": [
            {"name": "test1", "status": "passed", "duration": 1.5},
            {"name": "test2", "status": "failed", "duration": 2.0, "error": "Network error"}
        ]
    }'
    
    local output_file="$TEST_DIR/results.json"
    run json_format_report "$output_file" "$test_results" "1000" "1010"
    
    [ "$status" -eq 0 ]
    [ -f "$output_file" ]
}

@test "Generated JSON has valid structure" {
    local test_results='{"total": 1, "passed": 1, "failed": 0, "skipped": 0, "tests": []}'
    local output_file="$TEST_DIR/test.json"
    
    json_format_report "$output_file" "$test_results" "1000" "1005"
    
    # Check JSON validity
    run jq empty "$output_file"
    [ "$status" -eq 0 ]
    
    # Check required fields
    run jq -r '.total' "$output_file"
    [ "$output" = "1" ]
    
    run jq -r '.duration' "$output_file"
    [ "$output" = "5" ]
    
    run jq -r '.grpctestify_version' "$output_file"
    [ "$output" = "1.0.0-test" ]
}

@test "JSON includes metadata fields" {
    local test_results='{"total": 0, "passed": 0, "failed": 0, "skipped": 0, "tests": []}'
    local output_file="$TEST_DIR/metadata.json"
    
    json_format_report "$output_file" "$test_results" "1000" "1002"
    
    # Check metadata fields exist
    jq -e '.timestamp' "$output_file" >/dev/null
    jq -e '.hostname' "$output_file" >/dev/null  
    jq -e '.username' "$output_file" >/dev/null
    jq -e '.plugin.name' "$output_file" >/dev/null
    jq -e '.plugin.version' "$output_file" >/dev/null
    
    # Check plugin information
    run jq -r '.plugin.name' "$output_file"
    [ "$output" = "json_reporter" ]
}

@test "JSON validation checks for jq dependency" {
    # Mock jq command not found
    PATH="/nonexistent:$PATH" run json_validate_config
    [ "$status" -eq 1 ]
    [[ "$stderr" =~ "requires 'jq'" ]]
}

@test "JSON validation passes when jq is available" {
    if command -v jq >/dev/null 2>&1; then
        run json_validate_config
        [ "$status" -eq 0 ]
    else
        skip "jq not available in test environment"
    fi
}

@test "Plugin help displays information" {
    run json_plugin_help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "JSON Reporter Plugin" ]]
    [[ "$output" =~ "--log-format json" ]]
}

@test "Output directory creation works" {
    local nested_dir="$TEST_DIR/deep/nested/path"
    local test_results='{"total": 0, "passed": 0, "failed": 0, "skipped": 0, "tests": []}'
    local output_file="$nested_dir/results.json"
    
    [ ! -d "$nested_dir" ]
    
    json_format_report "$output_file" "$test_results" "1000" "1001"
    
    [ -d "$nested_dir" ]
    [ -f "$output_file" ]
}
