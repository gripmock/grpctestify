#!/bin/bash

# error_recovery.sh - Error recovery and retry mechanisms

# Default retry configuration
DEFAULT_MAX_RETRIES=3
# DEFAULT_RETRY_DELAY is defined in config.sh
DEFAULT_BACKOFF_MULTIPLIER=2
DEFAULT_MAX_RETRY_DELAY=30

# Retry a function with exponential backoff (SECURITY: no eval)
retry_with_backoff() {
    local func_name="$1"
    shift
    local max_retries="${1:-$DEFAULT_MAX_RETRIES}"
    shift
    local initial_delay="${1:-$DEFAULT_RETRY_DELAY}"
    shift
    local backoff_multiplier="${1:-$DEFAULT_BACKOFF_MULTIPLIER}"
    shift
    local max_delay="${1:-$DEFAULT_MAX_RETRY_DELAY}"
    shift
    # Remaining arguments passed to function
    
    local attempt=1
    local delay="$initial_delay"
    
    while [[ $attempt -le $max_retries ]]; do
        log debug "Attempt $attempt/$max_retries: calling $func_name"
        
        if "$func_name" "$@"; then
            if [[ $attempt -gt 1 ]]; then
                log success "Function succeeded on attempt $attempt"
            fi
            return 0
        fi
        
        local exit_code=$?
        
        if [[ $attempt -eq $max_retries ]]; then
            log error "Command failed after $max_retries attempts"
            return $exit_code
        fi
        
        log warning "Command failed (attempt $attempt/$max_retries), retrying in ${delay}s..."
        sleep "$delay"
        
        # Calculate next delay with exponential backoff
        delay=$((delay * backoff_multiplier))
        if [[ $delay -gt $max_delay ]]; then
            delay="$max_delay"
        fi
        
        ((attempt++))
    done
}

# Retry gRPC call with network error handling
retry_grpc_call() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local max_retries="${5:-$DEFAULT_MAX_RETRIES}"
    
    local retry_count=0
    local last_error=""
    
    while [[ $retry_count -lt $max_retries ]]; do
        log debug "gRPC call attempt $((retry_count + 1))/$max_retries to $address$endpoint"
        
        # Attempt the gRPC call
        local grpc_output
        grpc_output=$(run_grpc_call "$address" "$endpoint" "$request" "$headers" "")
        local grpc_status=$?
        
        if [[ $grpc_status -eq 0 ]]; then
            if [[ $retry_count -gt 0 ]]; then
                log success "gRPC call succeeded on attempt $((retry_count + 1))"
            fi
            echo "$grpc_output"
            return 0
        fi
        
        last_error="$grpc_output"
        
        # Check if this is a retryable error
        if ! is_retryable_error "$grpc_output" "$grpc_status"; then
            log error "Non-retryable error: $grpc_output"
            echo "$grpc_output"
            return $grpc_status
        fi
        
        ((retry_count++))
        
        if [[ $retry_count -lt $max_retries ]]; then
            local delay
            delay=$((DEFAULT_RETRY_DELAY * (2 ** (retry_count - 1))))
            if [[ $delay -gt $DEFAULT_MAX_RETRY_DELAY ]]; then
                delay="$DEFAULT_MAX_RETRY_DELAY"
            fi
            
            log warning "gRPC call failed (attempt $retry_count/$max_retries), retrying in ${delay}s..."
            log debug "Error details: $grpc_output"
            sleep "$delay"
        fi
    done
    
    log error "gRPC call failed after $max_retries attempts"
    echo "$last_error"
    return 1
}

# Check if an error is retryable
is_retryable_error() {
    local error_output="$1"
    local exit_code="$2"
    
    # Network-related errors that are typically retryable
    local retryable_patterns=(
        "connection refused"
        "connection reset"
        "timeout"
        "network is unreachable"
        "temporary failure"
        "service unavailable"
        "internal server error"
        "bad gateway"
        "gateway timeout"
    )
    
    # Convert to lowercase for case-insensitive matching
    local lower_error
    lower_error=$(echo "$error_output" | tr '[:upper:]' '[:lower:]')
    
    for pattern in "${retryable_patterns[@]}"; do
        if [[ "$lower_error" == *"$pattern"* ]]; then
            return 0
        fi
    done
    
    # Check for specific gRPC status codes that are retryable
    case "$exit_code" in
        14|8|13|4)  # UNAVAILABLE, RESOURCE_EXHAUSTED, INTERNAL, DEADLINE_EXCEEDED
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Wait for service to become available
wait_for_service() {
    local address="$1"
    local timeout_seconds="${2:-30}"
    local check_interval="${3:-2}"
    
    log info "Waiting for service at $address (timeout: ${timeout_seconds}s)"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout_seconds))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        if check_service_health "$address"; then
            log success "Service is available at $address"
            return 0
        fi
        
        log debug "Service not ready, waiting ${check_interval}s..."
        sleep "$check_interval"
    done
    
    log error "Service at $address did not become available within ${timeout_seconds}s"
    return 1
}

# Check if a service is healthy
check_service_health() {
    local address="$1"
    
    # Try to connect to the gRPC service
    if timeout 5 grpcurl -plaintext "$address" list >/dev/null 2>&1; then
        return 0
    fi
    
    # Fallback: try to connect to the port
    local host
    local port
    host=$(echo "$address" | cut -d: -f1)
    port=$(echo "$address" | cut -d: -f2)
    
    if timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Handle network failures gracefully
handle_network_failure() {
    local error_message="$1"
    local test_file="$2"
    local retry_count="${3:-0}"
    
    log error "Network failure in test: $test_file"
    log error "Error: $error_message"
    
    if [[ $retry_count -gt 0 ]]; then
        log info "This was retry attempt $retry_count"
    fi
    
    # Check if we should suggest starting a test server
    if [[ "$error_message" == *"connection refused"* ]]; then
        log info "💡 Tip: Make sure your gRPC server is running"
        log info "   You can start a test server with: make up"
    fi
    
    # Check if we should suggest checking the address
    if [[ "$error_message" == *"network is unreachable"* ]]; then
        log info "💡 Tip: Check if the server address is correct"
        log info "   Current address: $(get_config 'default_address' 'localhost:4770')"
    fi
}

# Recover from test failures
recover_from_test_failure() {
    local test_file="$1"
    local error_message="$2"
    local max_recovery_attempts="${3:-2}"
    
    log warning "Attempting to recover from test failure: $test_file"
    
    local recovery_attempt=1
    
    while [[ $recovery_attempt -le $max_recovery_attempts ]]; do
        log info "Recovery attempt $recovery_attempt/$max_recovery_attempts"
        
        # Wait a bit before retrying
        sleep $((recovery_attempt * 2))
        
        # Try to run the test again
        if run_single_test "$test_file"; then
            log success "Test recovered successfully on attempt $recovery_attempt"
            return 0
        fi
        
        ((recovery_attempt++))
    done
    
    log error "Failed to recover test after $max_recovery_attempts attempts"
    return 1
}

# Get retry configuration from environment or config
get_retry_config() {
    local config_key="$1"
    local default_value="$2"
    
    case "$config_key" in
        "max_retries")
            echo "${MAX_RETRIES:-${default_value:-$DEFAULT_MAX_RETRIES}}"
            ;;
        "retry_delay")
            echo "${RETRY_DELAY:-${default_value:-$DEFAULT_RETRY_DELAY}}"
            ;;
        "backoff_multiplier")
            echo "${BACKOFF_MULTIPLIER:-${default_value:-$DEFAULT_BACKOFF_MULTIPLIER}}"
            ;;
        "max_retry_delay")
            echo "${MAX_RETRY_DELAY:-${default_value:-$DEFAULT_MAX_RETRY_DELAY}}"
            ;;
        *)
            echo "$default_value"
            ;;
    esac
}

# Export functions for use in other modules
export -f retry_with_backoff
export -f retry_grpc_call
export -f is_retryable_error
export -f wait_for_service
export -f check_service_health
export -f handle_network_failure
export -f recover_from_test_failure
export -f get_retry_config
