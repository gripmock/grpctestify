#!/usr/bin/env bats

# response_comparison.bats - Tests for response_comparison.sh module

# Load the response comparison module
source "${BATS_TEST_DIRNAME}/test_helper.bash"

# Mock log function for testing
log() {
    echo "$@" >&2
}

@test "compare_responses handles exact comparison correctly" {
    local expected='{"message": "Hello, World!"}'
    local actual='{"message": "Hello, World!"}'
    
    run compare_responses "$expected" "$actual" ""
    [ $status -eq 0 ]
}

@test "compare_responses handles partial comparison correctly" {
    local expected='{"message": "Hello"}'
    local actual='{"message": "Hello, World!", "extra": "data"}'
    
    run compare_responses "$expected" "$actual" "type=partial"
    [ $status -eq 0 ]
}

@test "compare_responses handles tolerance comparison correctly" {
    local expected='{"value": 10.5}'
    local actual='{"value": 10.7}'
    
    run compare_responses "$expected" "$actual" "tolerance[.value]=0.5"
    [ $status -eq 0 ]
}

@test "apply_tolerance_comparison works for valid numeric values" {
    local expected='{"price": 100.0}'
    local actual='{"price": 101.5}'
    
    run apply_tolerance_comparison "$expected" "$actual" "tolerance[.price]=2.0"
    [ $status -eq 0 ]
}

@test "apply_percentage_tolerance_comparison works correctly" {
    local expected='{"amount": 1000}'
    local actual='{"amount": 1020}'
    
    run apply_percentage_tolerance_comparison "$expected" "$actual" "tol_percent[.amount]=5"
    [ $status -eq 0 ]
}
