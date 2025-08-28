#!/usr/bin/env bats

# grpc_headers_trailers.bats - Tests for grpc_headers_trailers.sh plugin

# Load dependencies
load "${BATS_TEST_DIRNAME}/../core/utils.sh"
load "${BATS_TEST_DIRNAME}/../core/colors.sh"
load "${BATS_TEST_DIRNAME}/../core/plugin_system_enhanced.sh"

# Load the plugin
load "${BATS_TEST_DIRNAME}/grpc_headers_trailers.sh"

@test "assert_grpc_header function validates headers correctly" {
    # Create mock response with headers
    local response='{"_headers": {"x-api-version": "1.0.0", "x-server": "test-server"}}'
    
    # Test successful header assertion
    run assert_grpc_header "$response" "x-api-version" "1.0.0"
    [ $status -eq 0 ]
    
    # Test failed header assertion
    run assert_grpc_header "$response" "x-api-version" "2.0.0"
    [ $status -eq 1 ]
    
    # Test missing header
    run assert_grpc_header "$response" "x-missing" "value"
    [ $status -eq 1 ]
}

@test "assert_grpc_trailer function validates trailers correctly" {
    # Create mock response with trailers
    local response='{"_trailers": {"x-processing-time": "45ms", "x-cache-hit": "false"}}'
    
    # Test successful trailer assertion
    run assert_grpc_trailer "$response" "x-processing-time" "45ms"
    [ $status -eq 0 ]
    
    # Test failed trailer assertion
    run assert_grpc_trailer "$response" "x-processing-time" "50ms"
    [ $status -eq 1 ]
    
    # Test missing trailer
    run assert_grpc_trailer "$response" "x-missing" "value"
    [ $status -eq 1 ]
}

@test "test_grpc_header function validates header patterns correctly" {
    # Create mock response with headers
    local response='{"_headers": {"x-response-time": "150ms", "x-server-version": "1.0.0"}}'
    
    # Test successful pattern matching
    run test_grpc_header "$response" "x-response-time" ".*ms$"
    [ $status -eq 0 ]
    
    # Test failed pattern matching
    run test_grpc_header "$response" "x-response-time" ".*seconds$"
    [ $status -eq 1 ]
    
    # Test missing header
    run test_grpc_header "$response" "x-missing" ".*"
    [ $status -eq 1 ]
}

@test "test_grpc_trailer function validates trailer patterns correctly" {
    # Create mock response with trailers
    local response='{"_trailers": {"x-processing-time": "45ms", "x-cache-hit": "false"}}'
    
    # Test successful pattern matching
    run test_grpc_trailer "$response" "x-processing-time" ".*ms$"
    [ $status -eq 0 ]
    
    # Test failed pattern matching
    run test_grpc_trailer "$response" "x-processing-time" ".*seconds$"
    [ $status -eq 1 ]
    
    # Test missing trailer
    run test_grpc_trailer "$response" "x-missing" ".*"
    [ $status -eq 1 ]
}

@test "plugin functions handle different response formats" {
    # Test with headers in different locations
    local response1='{"headers": {"x-api-version": "1.0.0"}}'
    local response2='{"metadata": {"x-api-version": "1.0.0"}}'
    
    # Both should work
    run assert_grpc_header "$response1" "x-api-version" "1.0.0"
    [ $status -eq 0 ]
    
    run assert_grpc_header "$response2" "x-api-version" "1.0.0"
    [ $status -eq 0 ]
}

@test "plugin functions handle empty or null responses" {
    # Test with empty response
    local empty_response='{}'
    
    run assert_grpc_header "$empty_response" "x-api-version" "1.0.0"
    [ $status -eq 1 ]
    
    run assert_grpc_trailer "$empty_response" "x-processing-time" "45ms"
    [ $status -eq 1 ]
    
    # Test with null values
    local null_response='{"_headers": {"x-api-version": null}}'
    
    run assert_grpc_header "$null_response" "x-api-version" "1.0.0"
    [ $status -eq 1 ]
}
