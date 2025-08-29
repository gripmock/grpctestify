#!/usr/bin/env bats

# expected_error.bats - Tests for expected error validation logic

# Load the runner module
source "${BATS_TEST_DIRNAME}/test_helper.bash"

@test "validate_expected_error should match exact message" {
    # Test that expected error message matches actual error
    local expected='{"code": 2, "message": "Division by zero"}'
    local actual='ERROR:\n  Code: Unknown\n  Message: Division by zero'
    
    run validate_expected_error "$expected" "$actual"
    [ $status -eq 0 ]  # Should pass when messages match
}

@test "validate_expected_error should fail on mismatched message" {
    # Test that different error messages fail validation
    local expected='{"code": 2, "message": "Division by zero"}'
    local actual='ERROR:\n  Code: Unknown\n  Message: Something completely different'
    
    run validate_expected_error "$expected" "$actual"
    [ $status -ne 0 ]  # Should fail when messages don't match
}

@test "validate_expected_error should match by code" {
    # Test that error codes can be matched
    local expected='{"code": 5, "message": "Not important"}'
    local actual='ERROR:\n  Code: NotFound\n  Message: Different message'
    
    # Currently code matching looks for "Code: 5", but actual shows "Code: NotFound"
    # This should fail with current implementation
    run validate_expected_error "$expected" "$actual"
    [ $status -ne 0 ]  # Should fail when codes don't match format
}

@test "validate_expected_error should handle non-JSON expected error" {
    # Test that plain text expected errors work
    local expected='Division by zero'
    local actual='ERROR:\n  Code: Unknown\n  Message: Division by zero'
    
    run validate_expected_error "$expected" "$actual"
    [ $status -eq 0 ]  # Should pass when message is found
}

@test "validate_expected_error should handle gripmock Can't find stub" {
    # Test the specific gripmock "Can't find stub" error
    local expected='{"code": 5, "message": "Can'\''t find stub"}'
    local actual='ERROR:\n  Code: NotFound\n  Message: Can'\''t find stub \n\nService: test.Service'
    
    run validate_expected_error "$expected" "$actual"
    [ $status -eq 0 ]  # Should pass when "Can't find stub" is found
}

@test "validate_expected_error complex gripmock message should match" {
    # Test complex gripmock error message matching
    local expected='{"message": "Product INVALID_PROD not found for user USER_ERROR. Please check your request.", "code": 5}'
    local actual='ERROR:\n  Code: NotFound\n  Message: Product INVALID_PROD not found for user USER_ERROR. Please check your request.'
    
    run validate_expected_error "$expected" "$actual"
    [ $status -eq 0 ]  # Should pass when complex message matches
}


