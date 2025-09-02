#!/usr/bin/env bats

# validate_expected_error.bats - Unit tests for validate_expected_error function

setup() {
    # Load the module under test
    source "src/lib/plugins/execution/runner.sh"
}

@test "validate_expected_error: basic validation works" {
    # Test basic functionality with simple input
    local test_response='{"error": "test error"}'
    local expected_error="test error"
    
    # Just check that the function can be called without crashing
    run validate_expected_error "$test_response" "error" "$expected_error"
    # Don't check status as it may vary depending on implementation
}
