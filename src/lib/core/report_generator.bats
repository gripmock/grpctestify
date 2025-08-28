#!/usr/bin/env bats

# report_generator.bats - Tests for report_generator.sh module

# Load the report generator module
source "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
    # Initialize colors for testing
    setup_colors
    
    # Initialize report data for each test
    init_report_data
}

@test.skip "init_report_data initializes report structure" {
    init_report_data
    
    [[ "${REPORT_DATA["total_tests"]}" == "0" ]]
    [[ "${REPORT_DATA["passed_count"]}" == "0" ]]
    [[ "${REPORT_DATA["failed_count"]}" == "0" ]]
    [[ "${REPORT_DATA["timeout_count"]}" == "0" ]]
    [[ "${REPORT_DATA["skipped_count"]}" == "0" ]]
    [[ -n "${REPORT_DATA["start_time"]}" ]]
    [[ -n "${REPORT_DATA["hostname"]}" ]]
    [[ -n "${REPORT_DATA["username"]}" ]]
}

@test.skip "add_test_result updates counters correctly for PASS" {
    add_test_result "test1.gctf" "PASS" "100"
    
    [[ "${REPORT_DATA["total_tests"]}" == "1" ]]
    [[ "${REPORT_DATA["passed_count"]}" == "1" ]]
    [[ "${REPORT_DATA["failed_count"]}" == "0" ]]
    [[ "${REPORT_DATA["total_duration"]}" == "100" ]]
    
    # Check that test was added to PASSED_TESTS array
    [[ "${PASSED_TESTS[0]}" == "test1.gctf" ]]
}

@test.skip "add_test_result updates counters correctly for FAIL" {
    add_test_result "test2.gctf" "FAIL" "200" "Assertion failed"
    
    [[ "${REPORT_DATA["total_tests"]}" == "1" ]]
    [[ "${REPORT_DATA["passed_count"]}" == "0" ]]
    [[ "${REPORT_DATA["failed_count"]}" == "1" ]]
    [[ "${REPORT_DATA["total_duration"]}" == "200" ]]
    
    # Check that test was added to FAILED_TESTS array
    [[ "${FAILED_TESTS[0]}" == "test2.gctf" ]]
    
    # Check error message was stored
    [[ "${TEST_RESULTS["test2.gctf_error"]}" == "Assertion failed" ]]
}

@test.skip "add_test_result updates counters correctly for TIMEOUT" {
    add_test_result "test3.gctf" "TIMEOUT" "30000"
    
    [[ "${REPORT_DATA["total_tests"]}" == "1" ]]
    [[ "${REPORT_DATA["timeout_count"]}" == "1" ]]
    [[ "${TIMEOUT_TESTS[0]}" == "test3.gctf" ]]
}

@test.skip "add_test_result updates counters correctly for SKIP" {
    add_test_result "test4.gctf" "SKIP" "0"
    
    [[ "${REPORT_DATA["total_tests"]}" == "1" ]]
    [[ "${REPORT_DATA["skipped_count"]}" == "1" ]]
    [[ "${SKIPPED_TESTS[0]}" == "test4.gctf" ]]
}

@test.skip "finalize_report_data calculates success rate correctly" {
    # Add multiple tests
    add_test_result "test1.gctf" "PASS" "100"
    add_test_result "test2.gctf" "PASS" "150"
    add_test_result "test3.gctf" "FAIL" "200"
    add_test_result "test4.gctf" "TIMEOUT" "30000"
    
    finalize_report_data
    
    # Should be 50% success rate (2 passed out of 4 total)
    [[ "${REPORT_DATA["success_rate"]}" == "50" ]]
    [[ -n "${REPORT_DATA["end_time"]}" ]]
}

@test.skip "finalize_report_data handles zero tests" {
    finalize_report_data
    
    [[ "${REPORT_DATA["success_rate"]}" == "0" ]]
}

@test.skip "generate_json_report produces valid JSON structure" {
    # Add test data
    add_test_result "test1.gctf" "PASS" "100"
    add_test_result "test2.gctf" "FAIL" "200" "Error message"
    
    # Generate JSON to temp file
    local temp_file=$(mktemp)
    generate_json_report "$temp_file"
    
    # Validate JSON structure using jq
    run jq -e '.metadata.grpctestify_version' "$temp_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "\"$APP_VERSION\"" ]]
    
    run jq -e '.summary.total_tests' "$temp_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "2" ]]
    
    run jq -e '.summary.passed_count' "$temp_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "1" ]]
    
    run jq -e '.summary.failed_count' "$temp_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "1" ]]
    
    run jq -e '.tests | length' "$temp_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "2" ]]
    
    # Check specific test data
    run jq -e '.tests[0].status' "$temp_file"
    [[ "$status" -eq 0 ]]
    
    run jq -e '.tests[1].error' "$temp_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == '"Error message"' ]]
    
    # Cleanup
    rm -f "$temp_file"
}





@test.skip "generate_report handles console format" {
    add_test_result "test1.gctf" "PASS" "100"
    
    # Test console format (default)
    run generate_report "console"
    [[ "$status" -eq 0 ]]
}

@test.skip "generate_report handles invalid format" {
    run generate_report "invalid_format"
    [[ "$status" -eq 1 ]]
}

@test.skip "report generator handles special characters in test names" {
    # Add test with special characters
    add_test_result "test with spaces & symbols <test>.gctf" "FAIL" "100" "Error with \"quotes\" & <tags>"
    
    # Test JSON escaping
    local json_output
    json_output=$(generate_report "json")
    echo "$json_output" | jq . > /dev/null  # Should not fail JSON parsing
    [[ $? -eq 0 ]]
    
    # Test XML escaping
    local xml_output
    xml_output=$(generate_report "xml")
    echo "$xml_output" | grep -q '&lt;' # Should escape < to &lt;
    [[ $? -eq 0 ]]
    
    # Test HTML escaping
    local html_output
    html_output=$(generate_report "html")
    echo "$html_output" | grep -q '&lt;' # Should escape < to &lt;
    [[ $? -eq 0 ]]
}

@test.skip "report generator accumulates multiple test results" {
    # Add multiple tests
    add_test_result "test1.gctf" "PASS" "100"
    add_test_result "test2.gctf" "PASS" "150"
    add_test_result "test3.gctf" "FAIL" "200"
    add_test_result "test4.gctf" "TIMEOUT" "30000"
    add_test_result "test5.gctf" "SKIP" "0"
    
    finalize_report_data
    
    # Check totals
    [[ "${REPORT_DATA["total_tests"]}" == "5" ]]
    [[ "${REPORT_DATA["passed_count"]}" == "2" ]]
    [[ "${REPORT_DATA["failed_count"]}" == "1" ]]
    [[ "${REPORT_DATA["timeout_count"]}" == "1" ]]
    [[ "${REPORT_DATA["skipped_count"]}" == "1" ]]
    [[ "${REPORT_DATA["total_duration"]}" == "30450" ]]
    [[ "${REPORT_DATA["success_rate"]}" == "40" ]]  # 2/5 = 40%
    
    # Check arrays
    [[ "${#PASSED_TESTS[@]}" == "2" ]]
    [[ "${#FAILED_TESTS[@]}" == "1" ]]
    [[ "${#TIMEOUT_TESTS[@]}" == "1" ]]
    [[ "${#SKIPPED_TESTS[@]}" == "1" ]]
}
