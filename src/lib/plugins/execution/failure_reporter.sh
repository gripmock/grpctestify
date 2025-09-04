#!/bin/bash

# failure_reporter.sh - Test failure reporting and error handling
# Extracted from runner.sh for better modularity
# Handles error collection, formatting, and display

# Global array to store test failures for batch display
declare -g -a TEST_FAILURES=()

#######################################
# Store test failure for later display (reactive UI)
# Arguments:
#   1: test_name
#   2: error_msg
#   3: detail1 (optional)
#   4: detail2 (optional)
#   5: detail3 (optional)
#   6: detail4 (optional)
# Globals:
#   TEST_FAILURES - array to store failures
#######################################
store_test_failure() {
    local test_name="$1"
    local error_msg="$2"
    local detail1="$3"
    local detail2="$4"
    local detail3="${5:-}"
    local detail4="${6:-}"
    
    local failure_info="$error_msg"
    if [[ -n "$detail1" ]]; then
        failure_info="$failure_info:$detail1"
    fi
    if [[ -n "$detail2" ]]; then
        failure_info="$failure_info:$detail2"
    fi
    if [[ -n "$detail3" ]]; then
        failure_info="$failure_info:$detail3"
    fi
    if [[ -n "$detail4" ]]; then
        failure_info="$failure_info:$detail4"
    fi
    
    # Store in local array for backwards compatibility
    TEST_FAILURES+=("TEST_FAILED:$test_name:$error_msg")
    
    # Send to IO system via Plugin API
    if command -v plugin_io_error >/dev/null 2>&1; then
        # Use first parameter as test path (it should be full path)
        plugin_io_error "$test_name" "$failure_info"
    fi
}

#######################################
# Detailed logging function for verbose mode
# Arguments:
#   1: test_name
#   2: address
#   3: endpoint
#   4: request
#   5: response
#   6: headers (optional)
# Outputs:
#   Formatted test details
#######################################
log_test_details() {
    local test_name="$1"
    local address="$2" 
    local endpoint="$3"
    local request="$4"
    local response="$5"
    local headers="${6:-}"
    
    # Only show details in verbose mode
    if [[ "${verbose:-false}" != "true" ]]; then
        return 0
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════"
    echo "🧪 Test Details: $test_name"
    echo "════════════════════════════════════════════════════════════════════════"
    echo "🎯 Target: $address"
    echo "🔌 Endpoint: $endpoint"
    
    if [[ -n "$headers" && "$headers" != "null" ]]; then
        echo "📋 Headers:"
        echo "$headers" | sed 's/^/    /'
    fi
    
    if [[ -n "$request" && "$request" != "null" ]]; then
        echo "📤 Request:"
        if command -v jq >/dev/null 2>&1 && echo "$request" | jq . >/dev/null 2>&1; then
            echo "$request" | jq -C . 2>/dev/null | sed 's/^/    /' || echo "$request" | sed 's/^/    /'
        else
            echo "$request" | sed 's/^/    /'
        fi
    else
        echo "📤 Request: (empty)"
    fi
    
    if [[ -n "$response" && "$response" != "null" ]]; then
        echo "📥 Response:"
        if command -v jq >/dev/null 2>&1 && echo "$response" | jq . >/dev/null 2>&1; then
            echo "$response" | jq -C . 2>/dev/null | sed 's/^/    /' || echo "$response" | sed 's/^/    /'
        else
            echo "$response" | sed 's/^/    /'
        fi
    else
        echo "📥 Response: (empty)"
    fi
    
    echo ""
}

#######################################
# Handle network failure with appropriate error message
# Arguments:
#   1: failure_reason
#   2: test_file
# Globals:
#   Uses store_test_failure to record the error
#######################################
handle_network_failure() {
    local failure_reason="$1"
    local test_file="$2"
    local test_name="$(basename "$test_file" .gctf)"
    
    store_test_failure "$test_name" "Network failure" "$failure_reason" "$test_file"
    
    if [[ "${verbose:-false}" == "true" ]]; then
        echo "❌ Network failure in $test_name: $failure_reason"
    fi
}

#######################################
# Handle gRPC error with detailed information
# Arguments:
#   1: test_name
#   2: grpc_output
#   3: expected_error (optional)
# Returns:
#   0 if error was expected, 1 otherwise
#######################################
handle_grpc_error() {
    local test_name="$1"
    local grpc_output="$2"
    local expected_error="${3:-}"
    
    # Extract error details from gRPC output
    local error_code=""
    local error_message=""
    
    # Try to parse JSON error
    if command -v jq >/dev/null 2>&1 && echo "$grpc_output" | jq . >/dev/null 2>&1; then
        error_code=$(echo "$grpc_output" | jq -r '.code // empty' 2>/dev/null)
        error_message=$(echo "$grpc_output" | jq -r '.message // empty' 2>/dev/null)
    fi
    
    # Fallback to text parsing if JSON parsing fails
    if [[ -z "$error_code" ]]; then
        error_code=$(echo "$grpc_output" | grep -o 'code = [^,]*' | head -1 | cut -d' ' -f3 || echo "UNKNOWN")
        error_message=$(echo "$grpc_output" | grep -o 'desc = .*' | head -1 | cut -d' ' -f3- || echo "$grpc_output")
    fi
    
    # Check if this error was expected
    if [[ -n "$expected_error" && "$expected_error" != "null" ]]; then
        # Parse expected error
        local expected_code=""
        local expected_message=""
        
        if command -v jq >/dev/null 2>&1 && echo "$expected_error" | jq . >/dev/null 2>&1; then
            expected_code=$(echo "$expected_error" | jq -r '.code // empty' 2>/dev/null)
            expected_message=$(echo "$expected_error" | jq -r '.message // empty' 2>/dev/null)
        fi
        
        # Check if error matches expectation
        local error_matches=false
        if [[ -n "$expected_code" && "$expected_code" == "$error_code" ]]; then
            error_matches=true
        elif [[ -n "$expected_message" && "$error_message" =~ $expected_message ]]; then
            error_matches=true
        fi
        
        if [[ "$error_matches" == "true" ]]; then
	    log_debug "✅ Expected error received: $error_code - $error_message"
            return 0  # Expected error
        fi
    fi
    
    # Unexpected error
    store_test_failure "$test_name" "Unexpected gRPC error" "$error_code" "$error_message"
    
    if [[ "${verbose:-false}" == "true" ]]; then
        echo "❌ Unexpected gRPC error in $test_name:"
        echo "   Code: $error_code"
        echo "   Message: $error_message"
    fi
    
    return 1  # Unexpected error
}

#######################################
# Get all stored test failures
# Returns:
#   Array of failure messages
# Outputs:
#   Each failure on a separate line
#######################################
get_test_failures() {
    for failure in "${TEST_FAILURES[@]}"; do
        echo "$failure"
    done
}

#######################################
# Clear all stored test failures
# Globals:
#   TEST_FAILURES - cleared
#######################################
clear_test_failures() {
    TEST_FAILURES=()
}

#######################################
# Get failure count
# Returns:
#   Number of stored failures
# Outputs:
#   Failure count
#######################################
get_failure_count() {
    echo "${#TEST_FAILURES[@]}"
}

# Export functions for use by other plugins
export -f store_test_failure
export -f log_test_details
export -f handle_network_failure
export -f handle_grpc_error
export -f get_test_failures
export -f clear_test_failures
export -f get_failure_count


