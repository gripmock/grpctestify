#!/bin/bash

# runner.sh - Test execution logic
# Core test execution functionality

# Source response comparison utilities

run_grpc_call() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local proto_file="$5"
    
    # Build command array
    local cmd=("grpcurl" "-plaintext")
    

    if [[ -n "$proto_file" ]]; then
        cmd+=("-proto" "$proto_file")
    fi
    

    if [[ -n "$headers" ]]; then
        while IFS= read -r header; do
            if [[ -n "$header" ]]; then
                cmd+=("-H" "$header")
            fi
        done <<< "$headers"
    fi
    

    if [[ -n "$request" ]]; then
        cmd+=("-d" "$request")
    fi
    
    cmd+=("$address" "$endpoint")
    "${cmd[@]}" 2>&1
}

# Enhanced gRPC call with retry mechanism
run_grpc_call_with_retry() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local proto_file="$5"
    
    # Check if retry is disabled
    if is_no_retry; then
        log debug "Retry mechanism disabled, using direct gRPC call"
        run_grpc_call "$address" "$endpoint" "$request" "$headers" "$proto_file"
        return $?
    fi
    
    # Get retry configuration
    local max_retries="$(get_retry_count)"
    local retry_delay="$(get_retry_delay)"
    
    log debug "Using retry mechanism: max_retries=$max_retries, delay=${retry_delay}s"
    
    # Use the retry mechanism from error_recovery.sh
    retry_grpc_call "$address" "$endpoint" "$request" "$headers" "$max_retries"
}

compare_responses() {
    local expected="$1"
    local actual="$2"
    local options="$3"
    
    # Parse inline options
    local type="exact"
    local count="==1"
    local tolerance=""
    local tol_percent=""
    local redact=""
    local unordered_arrays="false"
    local unordered_arrays_paths=""
    local with_asserts="false"
    
    # Apply options if provided
    if [[ -n "$options" ]]; then
        while IFS='=' read -r key value; do
            case "$key" in
                "type")
                    type="$value"
                    ;;
                "count")
                    count="$value"
                    ;;
                "tolerance"*)
                    tolerance="$key=$value"
                    ;;
                "tol_percent"*)
                    tol_percent="$key=$value"
                    ;;
                "redact")
                    redact="$value"
                    ;;
                "unordered_arrays")
                    unordered_arrays="$value"
                    ;;
                "unordered_arrays_paths")
                    unordered_arrays_paths="$value"
                    ;;
                "with_asserts")
                    with_asserts="$value"
                    ;;
            esac
        done <<< "$options"
    fi
    
    # Apply redaction if specified
    if [[ -n "$redact" ]]; then
        local redact_paths="$(echo "$redact" | tr ',' ' ')"
        for path in $redact_paths; do
            expected="$(echo "$expected" | jq "del($path)")"
            actual="$(echo "$actual" | jq "del($path)")"
        done
    fi
    
    # Apply tolerance if specified
    if [[ -n "$tolerance" ]]; then
        if ! apply_tolerance_comparison "$expected" "$actual" "$tolerance"; then
            return 1
        fi
    fi
    
    # Apply percentage tolerance if specified
    if [[ -n "$tol_percent" ]]; then
        if ! apply_percentage_tolerance_comparison "$expected" "$actual" "$tol_percent"; then
            return 1
        fi
    fi
    
    # Apply unordered arrays normalization if specified
    if [[ "$unordered_arrays" == "true" ]]; then
        expected="$(echo "$expected" | jq -S .)"
        actual="$(echo "$actual" | jq -S .)"
    fi
    
    # Apply specific path unordered arrays normalization if specified
    if [[ -n "$unordered_arrays_paths" ]]; then
        local paths="$(echo "$unordered_arrays_paths" | tr ',' ' ')"
        for path in $paths; do
            expected="$(echo "$expected" | jq "$path |= sort")"
            actual="$(echo "$actual" | jq "$path |= sort")"
        done
    fi
    
    # Perform comparison based on type
    case "$type" in
        "exact")
            # Use jq to compare JSON responses if both are valid JSON
            if command -v jq >/dev/null 2>&1; then
                if echo "$actual" | jq . >/dev/null 2>&1 && echo "$expected" | jq . >/dev/null 2>&1; then
                    # Both are valid JSON, normalize and compare them (sort keys for order independence)
                    local normalized_actual="$(echo "$actual" | jq -S -c .)"
                    local normalized_expected="$(echo "$expected" | jq -S -c .)"
                    
                    if [[ "$normalized_actual" == "$normalized_expected" ]]; then
                        return 0
                    else
                        return 1
                    fi
                fi
            fi
            
            # Fallback to string comparison
            if [[ "$expected" == "$actual" ]]; then
                return 0
            else
                return 1
            fi
            ;;
        "partial")
            # Check if all keys in expected exist in actual with same values
            if echo "$actual" | jq -e --argjson expected "$expected" 'contains($expected)' >/dev/null 2>&1; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            log error "Unknown comparison type: $type"
            return 1
            ;;
    esac
}

run_test() {
    local test_file="$1"
    local progress_mode="${2:-none}"
    local test_name="$(basename "$test_file" .gctf)"
    
    log section "Test: $test_name"
    
    # Parse test file
    local test_data="$(parse_test_file "$test_file")"
    if [[ $? -ne 0 ]]; then
        handle_error $ERROR_VALIDATION "Failed to parse test file: $test_file"
        return 1
    fi
    
    # Extract test components
    local address=$(echo "$test_data" | jq -r '.address')
    local endpoint=$(echo "$test_data" | jq -r '.endpoint')
    local request=$(echo "$test_data" | jq -r '.request')
    local response=$(echo "$test_data" | jq -r '.response')
    local error=$(echo "$test_data" | jq -r '.error')
    local headers=$(echo "$test_data" | jq -r '.request_headers')
    
    # Validate required components
    if [[ -z "$endpoint" ]]; then
        handle_error $ERROR_VALIDATION "Missing ENDPOINT in $test_file"
        return 1
    fi
    
    # Check if we have ASSERTS (priority over RESPONSE)
    local asserts_content=$(extract_asserts "$test_file" "ASSERTS")
    
    if [[ -z "$response" && -z "$error" && -z "$asserts_content" ]]; then
        handle_error $ERROR_VALIDATION "Missing RESPONSE, ERROR, or ASSERTS in $test_file"
        return 1
    fi
    
    # Set default address if not provided
    if [[ -z "$address" ]]; then
        address="localhost:4770"
    fi
    
    # Check service availability before running test (if retry is enabled)
    if ! is_no_retry; then
        log debug "Checking service availability at $address"
        if ! check_service_health "$address"; then
            log warning "Service at $address is not available, attempting to wait for it..."
            if ! wait_for_service "$address" 30 2; then
                log error "Service at $address is not available after waiting"
                handle_network_failure "Service unavailable" "$test_file"

                return 1
            fi
        fi
    fi
    
    # Execute gRPC call with retry mechanism
    local start_time=$(date +%s%3N)
    local grpc_output
    local grpc_status
    
    # Use enhanced gRPC call with retry mechanism
    grpc_output=$(run_grpc_call_with_retry "$address" "$endpoint" "$request" "$headers" "")
    grpc_status=$?
    
    local end_time=$(date +%s%3N)
    local execution_time=$((end_time - start_time))
    
    # Handle network failures gracefully
    if [[ $grpc_status -ne 0 ]]; then
        handle_network_failure "$grpc_output" "$test_file"
    fi
    
    # Check if we have ASSERTS (highest priority - works with both success and error responses)
    local actual_array="[$grpc_output]"
    if evaluate_asserts_with_plugins "$test_file" "$actual_array" 2>/dev/null; then
        # ASSERTS passed - test successful (regardless of gRPC status)
        if [[ $grpc_status -ne 0 ]]; then
            log success "TEST PASSED: $test_name (expected error, $execution_time ms)"

        else
            log success "TEST PASSED: $test_name ($execution_time ms)"

        fi
        print_progress "." "$progress_mode"
        return 0
    fi
    
    # No ASSERTS or they failed, check gRPC status
    if [[ $grpc_status -ne 0 ]]; then
        if [[ -n "$error" ]]; then
            # Expected error case
            log success "TEST PASSED: $test_name (expected error, $execution_time ms)"
            print_progress "." "$progress_mode"

            return 0
        else
            # Unexpected error - use error recovery if available
            if declare -f handle_network_failure >/dev/null 2>&1; then
                handle_network_failure "$grpc_output" "$test_file" "0"
            else
                log error "gRPC request failed with status $grpc_status"
                log error "Response: $grpc_output"
            fi
            print_progress "F" "$progress_mode"

            return 1
        fi
    fi
    
    # Success case - check RESPONSE
    if [[ -n "$response" ]]; then
        # Extract RESPONSE header to get inline options
        local response_header=$(extract_section_header "$test_file" "RESPONSE")
        local response_options=$(parse_inline_options "$response_header")
        
        if compare_responses "$response" "$grpc_output" "$response_options"; then
            # Check if with_asserts is enabled
            local with_asserts="false"
            if [[ -n "$response_options" ]]; then
                while IFS='=' read -r key value; do
                    if [[ "$key" == "with_asserts" ]]; then
                        with_asserts="$value"
                        break
                    fi
                done <<< "$response_options"
            fi
            
            # If with_asserts is enabled, run ASSERTS on the same response
            if [[ "$with_asserts" == "true" && -n "$asserts_content" ]]; then
                local actual_array="[$grpc_output]"
                if ! evaluate_asserts_with_plugins "$test_file" "$actual_array" 2>/dev/null; then
                    log error "TEST FAILED: $test_name - ASSERTS failed ($execution_time ms)"
                    print_progress "F" "$progress_mode"
                    return 1
                fi
            fi
            
            log success "TEST PASSED: $test_name ($execution_time ms)"
            print_progress "." "$progress_mode"

            return 0
        else
            log error "TEST FAILED: $test_name ($execution_time ms)"
            log error "--- Expected ---"
            printf "%s\n" "$response"
            log error "+++ Actual +++"
            printf "%s\n" "$grpc_output"
            print_progress "F" "$progress_mode"
    
            return 1
        fi
    else
        # No RESPONSE and no ASSERTS - test passes (no validation)
        log success "TEST PASSED: $test_name ($execution_time ms)"
        print_progress "." "$progress_mode"
        

        return 0
    fi
    

    return 0
}

# Apply tolerance comparison for numeric values
apply_tolerance_comparison() {
    local expected="$1"
    local actual="$2"
    local tolerance_spec="$3"
    
    # Parse tolerance specification: tolerance[path]=value
    if [[ "$tolerance_spec" =~ ^tolerance\[(.+)\]=(.+)$ ]]; then
        local path="${BASH_REMATCH[1]}"
        local tolerance_value="${BASH_REMATCH[2]}"
        
        # Extract expected and actual values at the specified path
        local expected_val=$(echo "$expected" | jq -r "$path // empty" 2>/dev/null)
        local actual_val=$(echo "$actual" | jq -r "$path // empty" 2>/dev/null)
        
        # Check if both values are numeric
        if [[ "$expected_val" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$actual_val" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
            # Calculate absolute difference
            local diff=$(echo "$expected_val - $actual_val" | bc -l 2>/dev/null || echo "0")
            local abs_diff=$(echo "$diff" | sed 's/^-//')
            
            # Check if difference is within tolerance
            if (( $(echo "$abs_diff <= $tolerance_value" | bc -l) )); then
                return 0
            else
                log debug "Tolerance comparison failed for path $path: expected=$expected_val, actual=$actual_val, diff=$abs_diff, tolerance=$tolerance_value"
                return 1
            fi
        else
            log debug "Tolerance comparison skipped for path $path: non-numeric values (expected=$expected_val, actual=$actual_val)"
            return 0
        fi
    else
        log error "Invalid tolerance specification: $tolerance_spec"
        return 1
    fi
}

# Apply percentage tolerance comparison for numeric values
apply_percentage_tolerance_comparison() {
    local expected="$1"
    local actual="$2"
    local tol_percent_spec="$3"
    
    # Parse tolerance specification: tol_percent[path]=value
    if [[ "$tol_percent_spec" =~ ^tol_percent\[(.+)\]=(.+)$ ]]; then
        local path="${BASH_REMATCH[1]}"
        local tolerance_percent="${BASH_REMATCH[2]}"
        
        # Extract expected and actual values at the specified path
        local expected_val=$(echo "$expected" | jq -r "$path // empty" 2>/dev/null)
        local actual_val=$(echo "$actual" | jq -r "$path // empty" 2>/dev/null)
        
        # Check if both values are numeric
        if [[ "$expected_val" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$actual_val" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
            # Calculate percentage difference
            local diff=$(echo "$expected_val - $actual_val" | bc -l 2>/dev/null || echo "0")
            local abs_diff=$(echo "$diff" | sed 's/^-//')
            local percent_diff=$(echo "scale=6; $abs_diff * 100 / $expected_val" | bc -l 2>/dev/null || echo "0")
            
            # Check if percentage difference is within tolerance
            if (( $(echo "$percent_diff <= $tolerance_percent" | bc -l) )); then
                return 0
            else
                log debug "Percentage tolerance comparison failed for path $path: expected=$expected_val, actual=$actual_val, diff=$percent_diff%, tolerance=$tolerance_percent%"
                return 1
            fi
        else
            log debug "Percentage tolerance comparison skipped for path $path: non-numeric values (expected=$expected_val, actual=$actual_val)"
            return 0
        fi
    else
        log error "Invalid percentage tolerance specification: $tol_percent_spec"
        return 1
    fi
}
