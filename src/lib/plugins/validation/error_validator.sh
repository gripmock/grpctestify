#!/bin/bash

# error_validator.sh - Error validation utilities
# Extracted from runner.sh for better modularity
# Handles validation of expected vs actual errors

#######################################
# Validate that actual error matches expected error from ERROR section
# Arguments:
#   1: expected_error - expected error from test file
#   2: actual_error - actual error from gRPC call
# Returns:
#   0 if error matches expectation, 1 otherwise
#######################################
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

#######################################
# Enhanced error validation with detailed reporting
# Arguments:
#   1: expected_error - expected error from test file
#   2: actual_error - actual error from gRPC call
#   3: test_name - test name for error reporting
# Returns:
#   0 if error matches expectation, 1 otherwise
# Outputs:
#   Detailed validation results in verbose mode
#######################################
validate_error_detailed() {
    local expected_error="$1"
    local actual_error="$2"
    local test_name="$3"
    
    if validate_expected_error "$expected_error" "$actual_error"; then
        if [[ "${verbose:-false}" == "true" ]]; then
            log_debug "✅ Error validation passed in $test_name"
        fi
        return 0
    else
        # Detailed error reporting
        if [[ "${verbose:-false}" == "true" ]]; then
            log_error "❌ Error validation failed in $test_name"
            echo "Expected error:"
            echo "$expected_error" | jq -C . 2>/dev/null | sed 's/^/    /' || echo "$expected_error" | sed 's/^/    /'
            echo "Actual error:"
            echo "$actual_error" | sed 's/^/    /'
        fi
        return 1
    fi
}

#######################################
# Parse error structure for validation
# Arguments:
#   1: error_data - error data (JSON or plain text)
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   Parsed error components (JSON)
#######################################
parse_error_structure() {
    local error_data="$1"
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required for error parsing but not installed"
        return 1
    fi
    
    # Try to parse as JSON first
    if echo "$error_data" | jq . >/dev/null 2>&1; then
        echo "$error_data"
        return 0
    else
        # Convert plain text to JSON structure
        jq -n \
            --arg message "$error_data" \
            --arg code "UNKNOWN" \
            '{
                message: $message,
                code: $code,
                type: "plain_text"
            }'
        return $?
    fi
}

#######################################
# Extract error code from error message
# Arguments:
#   1: error_message - error message to parse
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   Extracted error code
#######################################
extract_error_code() {
    local error_message="$1"
    
    # Common gRPC error patterns
    if echo "$error_message" | grep -q "code = [0-9]*"; then
        echo "$error_message" | grep -o "code = [0-9]*" | head -1 | cut -d' ' -f3
        return 0
    elif echo "$error_message" | grep -q "Code: [0-9]*"; then
        echo "$error_message" | grep -o "Code: [0-9]*" | head -1 | cut -d' ' -f2
        return 0
    else
        echo "UNKNOWN"
        return 1
    fi
}

# Export functions for use by other plugins
export -f validate_expected_error
export -f validate_error_detailed
export -f parse_error_structure
export -f extract_error_code
