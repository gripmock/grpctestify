#!/usr/bin/env bats

# grpc_response_time.bats - Tests for grpc_response_time.sh plugin

# Load the plugin system and response time plugin
load "${BATS_TEST_DIRNAME}/../core/plugin_system_enhanced.sh"
load "${BATS_TEST_DIRNAME}/grpc_response_time.sh"

@test "grpc_response_time plugin registers correctly" {
    # Check if plugin is registered
    run list_plugins
    [ $status -eq 0 ]
    [[ "$output" =~ "grpc_response_time" ]]
}

@test "assert_grpc_response_time function validates response time" {
    # Test response time assertion
    local response='{"response_time": 100}'
    local args="200"
    
    run assert_grpc_response_time "$response" "$args"
    [ $status -eq 0 ]
}

@test "assert_grpc_response_time function fails for slow responses" {
    # Test response time assertion failure
    local response='{"response_time": 300}'
    local args="200"
    
    run assert_grpc_response_time "$response" "$args"
    [ $status -ne 0 ]
}
