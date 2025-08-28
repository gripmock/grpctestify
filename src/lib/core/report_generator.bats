#!/usr/bin/env bats

# Load common test helper
source "${BATS_TEST_DIRNAME}/test_helper.bash"

# Fixture for each test
setup() {
    # Clean up any existing report data
    unset REPORT_DATA_start_time REPORT_DATA_end_time
    unset REPORT_DATA_total_tests REPORT_DATA_passed_count REPORT_DATA_failed_count
    unset REPORT_DATA_timeout_count REPORT_DATA_skipped_count REPORT_DATA_total_duration
    unset REPORT_DATA_hostname REPORT_DATA_username REPORT_DATA_grpctestify_version
    unset REPORT_DATA_success_rate
    unset PASSED_TESTS FAILED_TESTS TIMEOUT_TESTS SKIPPED_TESTS
    
    # Initialize report data for each test
    init_report_data
}

@test "init_report_data initializes report structure" {
    init_report_data
    
    [[ "${REPORT_DATA_total_tests}" == "0" ]]
    [[ "${REPORT_DATA_passed_count}" == "0" ]]
    [[ "${REPORT_DATA_failed_count}" == "0" ]]
    [[ "${REPORT_DATA_timeout_count}" == "0" ]]
    [[ "${REPORT_DATA_skipped_count}" == "0" ]]
    [[ -n "${REPORT_DATA_start_time}" ]]
    [[ -n "${REPORT_DATA_hostname}" ]]
    [[ -n "${REPORT_DATA_username}" ]]
}

@test "add_test_result updates counters correctly for PASS" {
    add_test_result "test1.gctf" "PASS" "100"
    
    [[ "${REPORT_DATA_total_tests}" == "1" ]]
    [[ "${REPORT_DATA_passed_count}" == "1" ]]
    [[ "${REPORT_DATA_failed_count}" == "0" ]]
    [[ "${REPORT_DATA_total_duration}" == "100" ]]
    
    # Check that test was added to PASSED_TESTS array
    [[ "${PASSED_TESTS[0]}" == "test1.gctf" ]]
}

@test "add_test_result updates counters correctly for FAIL" {
    add_test_result "test2.gctf" "FAIL" "200" "Assertion failed"
    
    [[ "${REPORT_DATA_total_tests}" == "1" ]]
    [[ "${REPORT_DATA_passed_count}" == "0" ]]
    [[ "${REPORT_DATA_failed_count}" == "1" ]]
    [[ "${REPORT_DATA_total_duration}" == "200" ]]
    
    # Check that test was added to FAILED_TESTS array
    [[ "${FAILED_TESTS[0]}" == "test2.gctf" ]]
}

@test "add_test_result updates counters correctly for TIMEOUT" {
    add_test_result "test3.gctf" "TIMEOUT" "30000"
    
    [[ "${REPORT_DATA_total_tests}" == "1" ]]
    [[ "${REPORT_DATA_timeout_count}" == "1" ]]
    [[ "${TIMEOUT_TESTS[0]}" == "test3.gctf" ]]
}

@test "add_test_result updates counters correctly for SKIP" {
    add_test_result "test4.gctf" "SKIP" "0"
    
    [[ "${REPORT_DATA_total_tests}" == "1" ]]
    [[ "${REPORT_DATA_skipped_count}" == "1" ]]
    [[ "${SKIPPED_TESTS[0]}" == "test4.gctf" ]]
}

@test "finalize_report_data calculates success rate correctly" {
    # Add multiple tests
    add_test_result "test1.gctf" "PASS" "100"
    add_test_result "test2.gctf" "PASS" "150"
    add_test_result "test3.gctf" "FAIL" "200"
    add_test_result "test4.gctf" "TIMEOUT" "30000"
    
    finalize_report_data
    
    # Should be 50% success rate (2 passed out of 4 total)
    [[ "${REPORT_DATA_success_rate}" == "50" ]]
    [[ -n "${REPORT_DATA_end_time}" ]]
}

@test "finalize_report_data handles zero tests" {
    finalize_report_data
    
    [[ "${REPORT_DATA_success_rate}" == "0" ]]
}

@test "generate_report handles console format" {
    add_test_result "test1.gctf" "PASS" "100"
    finalize_report_data
    
    run generate_report "console"
    [[ "$status" -eq 0 ]]
}

@test "generate_report handles invalid format" {
    run generate_report "invalid_format"
    [[ "$status" -eq 1 ]]
}

@test "report generator handles special characters in test names" {
    add_test_result "test with spaces.gctf" "PASS" "100"
    add_test_result "test-with-dashes.gctf" "FAIL" "200"
    add_test_result "test_with_underscores.gctf" "TIMEOUT" "30000"
    add_test_result "test.with.dots.gctf" "SKIP" "0"
    
    finalize_report_data
    
    # Check all tests were recorded
    [[ "${REPORT_DATA_total_tests}" == "4" ]]
    [[ "${REPORT_DATA_passed_count}" == "1" ]]
    [[ "${REPORT_DATA_failed_count}" == "1" ]]
    [[ "${REPORT_DATA_timeout_count}" == "1" ]]
    [[ "${REPORT_DATA_skipped_count}" == "1" ]]
    
    # Check arrays contain the correct test names
    [[ "${PASSED_TESTS[0]}" == "test with spaces.gctf" ]]
    [[ "${FAILED_TESTS[0]}" == "test-with-dashes.gctf" ]]
    [[ "${TIMEOUT_TESTS[0]}" == "test_with_underscores.gctf" ]]
    [[ "${SKIPPED_TESTS[0]}" == "test.with.dots.gctf" ]]
}

@test "report generator accumulates multiple test results" {
    # Add various test results
    add_test_result "test1.gctf" "PASS" "100"
    add_test_result "test2.gctf" "PASS" "150"
    add_test_result "test3.gctf" "FAIL" "200"
    add_test_result "test4.gctf" "TIMEOUT" "30000"
    add_test_result "test5.gctf" "SKIP" "0"
    
    finalize_report_data
    
    # Check totals
    [[ "${REPORT_DATA_total_tests}" == "5" ]]
    [[ "${REPORT_DATA_passed_count}" == "2" ]]
    [[ "${REPORT_DATA_failed_count}" == "1" ]]
    [[ "${REPORT_DATA_timeout_count}" == "1" ]]
    [[ "${REPORT_DATA_skipped_count}" == "1" ]]
    [[ "${REPORT_DATA_total_duration}" == "30450" ]]
    [[ "${REPORT_DATA_success_rate}" == "40" ]]  # 2/5 = 40%
    
    # Check arrays
    [[ "${#PASSED_TESTS[@]}" == "2" ]]
    [[ "${#FAILED_TESTS[@]}" == "1" ]]
    [[ "${#TIMEOUT_TESTS[@]}" == "1" ]]
    [[ "${#SKIPPED_TESTS[@]}" == "1" ]]
}