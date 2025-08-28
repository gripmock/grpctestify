#!/usr/bin/env bats

# validation.bats - Tests for validation.sh module

# Load the validation module
load "${BATS_TEST_DIRNAME}/validation.sh"

@test "validate_address function validates addresses correctly" {
    # Test valid address
    run validate_address "localhost:4770"
    [ $status -eq 0 ]
    
    # Test invalid address
    run validate_address "invalid"
    [ $status -ne 0 ]
}

@test "validate_json function validates JSON correctly" {
    # Test valid JSON
    run validate_json '{"key": "value"}'
    [ $status -eq 0 ]
    
    # Test invalid JSON
    run validate_json '{"key": "value"'
    [ $status -ne 0 ]
}

@test "validate_file_exists function validates file existence" {
    # Test existing file
    local temp_file=$(mktemp)
    run validate_file_exists "$temp_file"
    [ $status -eq 0 ]
    
    # Test non-existing file
    run validate_file_exists "/non/existing/file"
    [ $status -ne 0 ]
    
    # Cleanup
    rm -f "$temp_file"
}

@test "validate_positive_integer function validates positive integers" {
    # Test valid positive integer
    run validate_positive_integer "5"
    [ $status -eq 0 ]
    
    # Test invalid integer
    run validate_positive_integer "-1"
    [ $status -ne 0 ]
    
    # Test non-integer
    run validate_positive_integer "abc"
    [ $status -ne 0 ]
}

