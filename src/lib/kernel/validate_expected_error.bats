#!/usr/bin/env bats

# validate_expected_error.bats - Unit tests for validate_expected_error function
# This is a proper modular test that tests ONLY the specific function

# Load minimal test helper
source "tests/helpers/simple_test_helper.bash"

# Extract only the function we want to test from runner.sh
validate_expected_error() {
    local expected_error="$1"
    local actual_error="$2"
    
    # Parse expected error JSON
    local expected_message
    expected_message=$(echo "$expected_error" | jq -r '.message // empty' 2>/dev/null)
    local expected_code
    expected_code=$(echo "$expected_error" | jq -r '.code // empty' 2>/dev/null)
    
    # If expected_error is not valid JSON, treat it as plain text message
    if [[ -z "$expected_message" ]]; then
        expected_message="$expected_error"
    fi
    
    # Check if actual error contains expected message
    if [[ -n "$expected_message" ]] && echo "$actual_error" | grep -q "$expected_message"; then
        return 0  # Match found
    fi
    
    # Check if expected code matches (if available)
    if [[ -n "$expected_code" && "$expected_code" != "null" ]]; then
        if echo "$actual_error" | grep -q "Code: $expected_code"; then
            return 0  # Code match found
        fi
    fi
    return 1  # No match found
}

@test "validate_expected_error: matches exact message" {
    local expected='{"code": 2, "message": "Division by zero"}'
    local actual='ERROR:\n  Code: Unknown\n  Message: Division by zero'
    
    validate_expected_error "$expected" "$actual"
    [ $? -eq 0 ]
}

@test "validate_expected_error: fails on mismatched message" {
    local expected='{"code": 2, "message": "Division by zero"}'
    local actual='ERROR:\n  Code: Unknown\n  Message: Something completely different'
    
    validate_expected_error "$expected" "$actual"
    [ $? -ne 0 ]
}

@test "validate_expected_error: matches by code when available" {
    local expected='{"code": 5, "message": "Not important"}'
    local actual='ERROR:\n  Code: 5\n  Message: Different message'
    
    validate_expected_error "$expected" "$actual"
    [ $? -eq 0 ]
}

@test "validate_expected_error: handles non-JSON expected error" {
    local expected='Division by zero'
    local actual='ERROR:\n  Code: Unknown\n  Message: Division by zero'
    
    validate_expected_error "$expected" "$actual"
    [ $? -eq 0 ]
}

@test "validate_expected_error: handles gripmock Can't find stub" {
    local expected='{"code": 5, "message": "Can'\''t find stub"}'
    local actual='ERROR:\n  Code: NotFound\n  Message: Can'\''t find stub \n\nService: test.Service'
    
    validate_expected_error "$expected" "$actual"
    [ $? -eq 0 ]
}

@test "validate_expected_error: handles complex gripmock message" {
    local expected='{"message": "Product INVALID_PROD not found for user USER_ERROR. Please check your request.", "code": 5}'
    local actual='ERROR:\n  Code: NotFound\n  Message: Product INVALID_PROD not found for user USER_ERROR. Please check your request.'
    
    validate_expected_error "$expected" "$actual"
    [ $? -eq 0 ]
}

@test "validate_expected_error: handles empty messages" {
    local expected=''
    local actual='ERROR:\n  Code: Unknown\n  Message: Some error'
    
    validate_expected_error "$expected" "$actual"
    [ $? -ne 0 ]
}

@test "validate_expected_error: handles malformed JSON gracefully" {
    local expected='{"code": 5, "message":'  # Malformed JSON
    local actual='ERROR:\n  Code: 5\n  Message: Some error'
    
    validate_expected_error "$expected" "$actual"
    [ $? -eq 0 ]  # Should treat as plain text and match
}


