#!/usr/bin/env bats

# error_recovery.bats - Tests for error_recovery.sh module

# Load the error recovery module
load "${BATS_TEST_DIRNAME}/error_recovery.sh"

@test "retry_with_backoff function retries with backoff" {
    # Test retry with backoff
    run retry_with_backoff "echo 'test'" 3 1
    [ $status -eq 0 ]
    [[ "$output" =~ "test" ]]
}

@test "is_retryable_error function identifies retryable errors" {
    # Test retryable error identification
    run is_retryable_error "Connection refused"
    [ $status -eq 0 ]
    
    # Test non-retryable error
    run is_retryable_error "Invalid argument"
    [ $status -ne 0 ]
}

@test "wait_for_service function waits for service" {
    # Test service waiting (will timeout quickly)
    run wait_for_service "localhost:9999" 1
    [ $status -ne 0 ]  # Expected to fail
}

@test "check_service_health function checks service health" {
    # Test service health check
    run check_service_health "localhost:9999"
    [ $status -ne 0 ]  # Expected to fail
}

@test "get_retry_config function gets retry configuration" {
    # Test retry configuration
    run get_retry_config
    [ $status -eq 0 ]
}