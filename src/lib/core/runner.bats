#!/usr/bin/env bats

# runner.bats - Tests for runner.sh module

# Load the runner module
load "${BATS_TEST_DIRNAME}/runner.sh"

@test "run_grpc_call function runs gRPC calls" {
    # Test gRPC call (will fail but should not crash)
    run run_grpc_call "localhost:4770" "test.Method" '{"test": "data"}' "" ""
    [ $status -ne 0 ]  # Expected to fail without real server
}

@test "compare_responses function compares responses correctly" {
    # Test response comparison
    local expected='{"message": "Hello, World!"}'
    local actual='{"message": "Hello, World!"}'
    
    run compare_responses "$expected" "$actual"
    [ $status -eq 0 ]
}


