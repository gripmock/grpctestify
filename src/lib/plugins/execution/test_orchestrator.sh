#!/bin/bash

# test_orchestrator.sh - Core test execution orchestration
# CLEAN ARCHITECTURE: Delegates to specialized plugins
# - grpc_client.sh: gRPC communication
# - failure_reporter.sh: Error handling and reporting
# - json_comparator.sh: JSON comparison logic
# shellcheck disable=SC2155,SC2001,SC2076,SC2086,SC2034,SC2181,SC2317

#######################################
# Main test execution function - REFACTORED
# Arguments:
#   1: test_file - path to test file
#   2: progress_mode - progress display mode
# Returns:
#   0 on success, 1 on failure
#######################################
run_test() {
    local test_file="$1"
    local progress_mode="${2:-none}"
    
    # Use full path for unique identification and short name for display
    local test_full_path
    case "$test_file" in
        /*)
            test_full_path="$test_file"
            ;;
        *)
            # Portable absolute path resolution without external readlink/realpath
            local base_dir
            base_dir=$(pwd)
            # Remove any leading ./ from relative path
            local clean_path="$test_file"
            clean_path="${clean_path#./}"
            test_full_path="$base_dir/$clean_path"
            ;;
    esac
    local test_name="$(basename "$test_file" .gctf)"
    
    # Only show test header in non-dots mode
    if [[ "$progress_mode" != "dots" ]]; then
        tlog debug "Test: $test_name"
    fi
    
    # Parse test file
    local test_data="$(parse_test_file "$test_file")"
    if [[ $? -ne 0 ]]; then
        handle_error "${ERROR_VALIDATION}" "Failed to parse test file: $test_file"
        return 1
    fi
    
    # Extract test components
    local address=$(echo "$test_data" | jq -r '.address')
    local endpoint=$(echo "$test_data" | jq -r '.endpoint')
    local request=$(echo "$test_data" | jq -r '.request')
    local response=$(echo "$test_data" | jq -r '.response')
    local error=$(echo "$test_data" | jq -r '.error')
    local headers=$(echo "$test_data" | jq -r '.headers')
    
    # Validate required components
    if [[ -z "$endpoint" ]]; then
        handle_error "${ERROR_VALIDATION}" "Missing ENDPOINT in $test_file"
        return 1
    fi
    
    # Check if we have ASSERTS (priority over RESPONSE)
    local asserts_content=$(extract_asserts "$test_file" "ASSERTS")
    
    if [[ -z "$response" && -z "$error" && -z "$asserts_content" ]]; then
        return 1
    fi
    
    # Set default address if not provided  
    if [[ -z "$address" ]]; then
        address="${GRPCTESTIFY_ADDRESS:-localhost:4770}"
    fi
    
    # Network health check - DELEGATED to grpc_client.sh
    if ! is_no_retry; then
	tlog debug "🔍 Checking service availability at $address/"
        if ! check_service_health "$address"; then
	    tlog error "Network failure: Service at $address is not available"
            handle_network_failure "Service unavailable" "$test_file"
            return 1
        fi
    fi
    
    # Execute gRPC call with retry mechanism  
    local start_time=$(native_timestamp_ms 2>/dev/null || echo $(($(date +%s) * 1000)))
    local grpc_output
    local grpc_status
    
    # Get dry-run flag
    local dry_run="false"
    if [[ "${args[--dry-run]:-}" == "1" ]]; then
        dry_run="true"
        # Set expectations for dry-run
        if [[ -n "$error" && "$error" != "null" ]]; then
            export GRPCTESTIFY_DRY_RUN_EXPECT_ERROR="true"
        else
            export GRPCTESTIFY_DRY_RUN_EXPECT_ERROR="false"
            if [[ -n "$response" && "$response" != "null" ]]; then
                export GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE="$response"
            fi
        fi
    fi
    
    # Handle dry-run mode first - don't execute real calls
    if [[ "$dry_run" == "true" ]]; then
        local end_time=$(native_timestamp_ms 2>/dev/null || echo $(($(date +%s) * 1000)))
        local duration=$((end_time - start_time))
        
        # Generate dry-run preview output
        grpc_output=$(format_dry_run_output "$request" "$headers" "grpcurl" "-plaintext" "-d" "@" "$address" "$endpoint")
        grpc_status=0
        
        # Show preview in verbose mode
        if [[ "${verbose:-false}" == "true" ]]; then
            echo "$grpc_output" >&2
        fi
        
        echo "PASSED (dry-run preview, ${duration}ms)"
        return 0
    fi
    
    # DELEGATED: Use enhanced gRPC call with retry mechanism
    grpc_output=$(run_grpc_call_with_retry "$address" "$endpoint" "$request" "$headers" "" "$dry_run")
    grpc_status=$?
    
    local end_time=$(native_timestamp_ms 2>/dev/null || echo $(($(date +%s) * 1000)))
    local duration=$((end_time - start_time))
    
    # DELEGATED: Log test details to failure_reporter.sh
    log_test_details "$test_name" "$address" "$endpoint" "$request" "$grpc_output" "$headers"
    
    # Test result validation
    local test_result="PASSED"
    
    # Handle gRPC errors first
    if [[ $grpc_status -ne 0 ]]; then
        # DELEGATED: Error handling to failure_reporter.sh
        if handle_grpc_error "$test_name" "$grpc_output" "$error"; then
            test_result="PASSED"  # Expected error
        else
            test_result="FAILED"  # Unexpected error
        fi
    else
        # Success response - validate against expectations
        if [[ -n "$response" && "$response" != "null" ]]; then
            # DELEGATED: JSON comparison to json_comparator.sh
            if ! compare_json_detailed "$grpc_output" "$response" "exact" "$test_name"; then
                store_test_failure "$test_name" "Response mismatch" "$grpc_output" "$response"
                test_result="FAILED"
            fi
        fi
        
        # Handle ASSERTS if present
        if [[ -n "$asserts_content" ]]; then
            if ! validate_grpc_asserts "$grpc_output" "$asserts_content" "$test_name"; then
                test_result="FAILED"
            fi
        fi
        
        # If we expected an error but got success
        if [[ -n "$error" && "$error" != "null" ]]; then
            store_test_failure "$test_name" "Expected error but got success" "$grpc_output"
            test_result="FAILED"
        fi
    fi
    
    # Update progress via Plugin API
    if command -v plugin_io_progress >/dev/null 2>&1; then
        local symbol="."
        case "$test_result" in
            "PASSED") symbol="." ;;
            "FAILED") symbol="F" ;;
            "ERROR") symbol="E" ;;
            "SKIPPED") symbol="S" ;;
        esac
        plugin_io_progress "$test_full_path" "$test_result" "$symbol"
    fi
    
    # Store test result via Plugin API
    if command -v plugin_io_result >/dev/null 2>&1; then
        plugin_io_result "$test_full_path" "$test_result" "$duration" "$grpc_output"
    fi
    
    # Return appropriate exit code
    case "$test_result" in
        "PASSED") return 0 ;;
        "FAILED") return 1 ;;
        "ERROR") return 2 ;;
        "SKIPPED") return 3 ;;
        *) return 1 ;;
    esac
}

#######################################
# Validate gRPC assertions
# Arguments:
#   1: grpc_output - actual gRPC response
#   2: asserts_content - assertions to validate
#   3: test_name - test name for error reporting
# Returns:
#   0 if all assertions pass, 1 if any fail
#######################################
validate_grpc_asserts() {
    local grpc_output="$1"
    local asserts_content="$2"
    local test_name="$3"
    
    # Parse and execute assertions
    local assertion_failed=false
    
    while IFS= read -r assertion; do
        [[ -z "$assertion" ]] && continue
        
        # Remove leading/trailing whitespace
        assertion=$(echo "$assertion" | xargs)
        
        # Skip comments and empty lines
        [[ "$assertion" =~ ^# ]] && continue
        [[ -z "$assertion" ]] && continue
        
        # Execute assertion using assertion plugins
        if ! execute_assertion "$grpc_output" "$assertion" "$test_name"; then
            assertion_failed=true
        fi
    done <<< "$asserts_content"
    
    if [[ "$assertion_failed" == "true" ]]; then
        return 1
    else
        return 0
    fi
}

#######################################
# Execute individual assertion
# Arguments:
#   1: grpc_output - actual response
#   2: assertion - assertion statement
#   3: test_name - test name for error reporting
# Returns:
#   0 if assertion passes, 1 if fails
#######################################
execute_assertion() {
    local grpc_output="$1"
    local assertion="$2"
    local test_name="$3"
    
    # Try different assertion plugins
    if command -v assert_grpc >/dev/null 2>&1; then
        assert_grpc "$grpc_output" "$assertion" "$test_name"
        return $?
    elif command -v assert_json >/dev/null 2>&1; then
        assert_json "$grpc_output" "$assertion" "$test_name"
        return $?
    else
        # Fallback to basic assertion
	tlog warning "No assertion plugins available for: $assertion"
        return 0
    fi
}

# Export main functions
export -f run_test
export -f validate_grpc_asserts
export -f execute_assertion


