#!/bin/bash

# runner.sh - Test execution logic
# Core test execution functionality
# shellcheck disable=SC2155,SC2001,SC2076,SC2086,SC2034,SC2181,SC2317 # Variable handling, exit codes, unreachable code

# Detailed logging function for verbose mode
log_test_details() {
    local test_name="$1"
    local address="$2" 
    local endpoint="$3"
    local request="$4"
    local headers="$5"
    local expected_response="$6"
    local expected_error="$7"
    local actual_response="$8"
    local grpc_status="$9"
    local execution_time="${10}"
    
    if [[ "${LOG_LEVEL:-info}" == "debug" ]]; then
        log debug "════════════════════════════════════════"
        log debug "📋 TEST DETAILS: $test_name"
        log debug "════════════════════════════════════════"
        log debug "🌐 Target: $address$endpoint"
        
        if [[ -n "$headers" ]]; then
            log debug "📤 Headers:"
            # Optimized: avoid while read loop for simple logging
            log debug "    $headers"
        fi
        
        if [[ -n "$request" ]]; then
            log debug "📤 Request Data:"
            # Optimized: use direct output instead of line-by-line processing
            printf "%s\n" "$request" | sed 's/^/    /'
        else
            log debug "📤 Request: (empty)"
        fi
        
        log debug "⏱️  Execution Time: ${execution_time}s"
        log debug "🔢 gRPC Status Code: $grpc_status"
        
        if [[ -n "$actual_response" ]]; then
            log debug "📥 Actual Response:"
            # Optimized: use sed instead of while read
            printf "%s\n" "$actual_response" | sed 's/^/    /'
        else
            log debug "📥 Actual Response: (empty)"
        fi
        
        if [[ -n "$expected_response" ]]; then
            log debug "✅ Expected Response:"
            # Optimized: use sed instead of while read
            printf "%s\n" "$expected_response" | sed 's/^/    /'
        fi
        
        if [[ -n "$expected_error" ]]; then
            log debug "⚠️  Expected Error:"
            # Optimized: use sed instead of while read
            printf "%s\n" "$expected_error" | sed 's/^/    /'
        fi
        
        log debug "════════════════════════════════════════"
    fi
}

# Source response comparison utilities

# Helper function to log success messages only in non-dots mode
log_test_success() {
    local message="$1"
    local progress_mode="$2"
    
    if [[ "$progress_mode" != "dots" ]]; then
        log success "$message"
    fi
}

# Beautiful dry-run formatter
format_dry_run_output() {
    local cmd=("$@")
    local request="$1"
    local headers="$2"
    shift 2
    local command_parts=("${@}")
    
    echo ""
    log info "🔍 DRY-RUN MODE: Command Preview"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Extract endpoint from command for display
    local endpoint=""
    for arg in "${command_parts[@]}"; do
        if [[ "$arg" =~ \. ]]; then
            endpoint="$arg"
            break
        fi
    done
    
    if [[ -n "$endpoint" ]]; then
        log section "🎯 Target Endpoint"
        echo "   $endpoint"
        echo ""
    fi
    
    # Command section
    log section "📡 gRPC Command"
    printf "   %s" "${command_parts[0]}"
    for arg in "${command_parts[@]:1}"; do
        if [[ "$arg" =~ ^- ]]; then
            printf " \\\\\n      %s" "$arg"
        else
            printf " \\\\\n      '%s'" "$arg"
        fi
    done
    echo ""
    echo ""
    
    # Headers section (if any)
    if [[ -n "$headers" ]]; then
        log section "📋 Request Headers"
        echo "$headers" | jq -C . 2>/dev/null || echo "   $headers"
        echo ""
    fi
    
    # Request data section
    if [[ -n "$request" ]]; then
        log section "📤 Request Data"
        
        # Check if this is streaming (multiple JSON objects separated by newlines)
        # Count actual JSON objects, not just lines
        local json_count=0
        while IFS= read -r line; do
            if [[ -n "$line" && "$line" =~ ^\{.*\}$ ]]; then
                ((json_count++))
            fi
        done <<< "$request"
        
        if [[ $json_count -gt 1 ]]; then
            log info "   🔄 Streaming Request (Multiple Messages):"
            local msg_num=1
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    echo "   ┌─ Message $msg_num ─┐"
                    if command -v jq >/dev/null 2>&1; then
                        echo "$line" | jq -C . 2>/dev/null | sed 's/^/   │ /' || echo "   │ $line"
                    else
                        echo "   │ $line"
                    fi
                    echo "   └──────────────────┘"
                    ((msg_num++))
                fi
            done <<< "$request"
        else
            # Single request
            if command -v jq >/dev/null 2>&1; then
                # Pretty print JSON with colors if jq available
                echo "$request" | jq -C . 2>/dev/null || {
                    echo "   ┌─ Raw Request Data ─┐"
                    while IFS= read -r line; do echo "   │ $line"; done <<< "$request"
                    echo "   └────────────────────┘"
                }
            else
                echo "   ┌─ Request Data ─┐"
                while IFS= read -r line; do echo "   │ $line"; done <<< "$request"
                echo "   └────────────────┘"
            fi
        fi
        echo ""
    fi
    
    # Show what would be returned
    if [[ -n "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE:-}" && "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}" != "null" ]]; then
        log section "📥 Expected Response (Simulated)"
        echo "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}" | jq -C . 2>/dev/null || echo "   ${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}"
        echo ""
    elif [[ "${GRPCTESTIFY_DRY_RUN_EXPECT_ERROR:-false}" == "true" ]]; then
        log section "⚠️ Expected Error (Simulated)"
        echo '   {"code": 999, "message": "DRY-RUN: Simulated gRPC error"}'
        echo ""
    fi
    
    # Execution note
    log info "✨ This command would be executed in normal mode"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

run_grpc_call() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local proto_file="$5"
    local dry_run="${6:-false}"
    
    # Build command array
    local cmd=("grpcurl" "-plaintext" "-format-error")
    
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
        # Critical fix: Use stdin (-d @) for multiple REQUEST sections to preserve JSON properly
        cmd+=("-d" "@")
    fi
    
    cmd+=("$address" "$endpoint")
    
    # Dry-run mode: show beautiful formatted command preview
    if [[ "$dry_run" == "true" ]]; then
        format_dry_run_output "$request" "$headers" "${cmd[@]}"
        # Return appropriate response based on test expectations
        # If we expect an error (detected by caller), simulate gRPC error
        if [[ "${GRPCTESTIFY_DRY_RUN_EXPECT_ERROR:-false}" == "true" ]]; then
            echo '{"code": 999, "message": "DRY-RUN: Simulated gRPC error", "details": []}'
            return 1
        else
            # If there's an expected response, return it; otherwise return dry-run status
            if [[ -n "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE:-}" && "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}" != "null" ]]; then
                echo "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}"
            else
                # Return structured JSON response for compatibility
                echo '{"dry_run": true, "message": "Command preview completed", "status": "success"}'
            fi
            return 0
        fi
    fi
    
    # Only show debug info in verbose mode or non-dots progress mode
    if [[ "${verbose:-false}" == "true" || "${LOG_LEVEL:-info}" == "debug" ]]; then
        echo "DEBUG: Final command: ${cmd[*]}" >&2
        echo "DEBUG: Request data being sent to stdin:" >&2
        echo ">>>>>>>" >&2
        echo "$request" >&2
        echo "<<<<<<<<" >&2
    fi
    
    # Execute with request data using temporary file (following v0.0.13 approach)
    if [[ -n "$request" ]]; then
        # Create temporary file for request data (like v0.0.13)
        local request_tmp=$(mktemp)
        # Use jq -c to compact JSON like v0.0.13 does
        echo "$request" | jq -c . > "$request_tmp"
        
        # Execute grpcurl with file input
        "${cmd[@]}" < "$request_tmp" 2>&1
        local exit_code=$?
        
        # Clean up temporary file
        rm -f "$request_tmp"
        return $exit_code
    else
        "${cmd[@]}" 2>&1
    fi
}

# Enhanced gRPC call with retry mechanism
run_grpc_call_with_retry() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local proto_file="$5"
    local dry_run="${6:-false}"
    
    # Check if retry is disabled
    if is_no_retry; then
        log debug "Retry mechanism disabled, using direct gRPC call"
        run_grpc_call "$address" "$endpoint" "$request" "$headers" "$proto_file" "$dry_run"
        return $?
    fi
    
    # Get retry configuration
    local max_retries="$(get_retry_count)"
    local retry_delay="$(get_retry_delay)"
    
    log debug "Using retry mechanism: max_retries=$max_retries, delay=${retry_delay}s"
    
    # Use the retry mechanism from error_recovery.sh
    retry_grpc_call "$address" "$endpoint" "$request" "$headers" "$max_retries" "$dry_run"
}

# Validate that actual error matches expected error from ERROR section
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
                    # shellcheck disable=SC2034  # Reserved for future counting features
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
    
    # Only show test header in non-dots mode
    if [[ "$progress_mode" != "dots" ]]; then
        log section "Test: $test_name"
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
        handle_error "${ERROR_VALIDATION}" "Missing RESPONSE, ERROR, or ASSERTS in $test_file"
        return 1
    fi
    
    # Set default address if not provided  
    # This should not happen if parser.sh works correctly
    if [[ -z "$address" ]]; then
        if [[ -n "$GRPCTESTIFY_ADDRESS" ]]; then
            address="$GRPCTESTIFY_ADDRESS"
        else
            address="localhost:4770"
        fi
    fi
    
    # Network failures should ALWAYS = FAIL (not expected error)
    # Quick check without waiting - following PROMPT.md principle
    if ! is_no_retry; then
        log debug "Checking service availability at $address"
        if ! check_service_health "$address"; then
            log error "Network failure: Service at $address is not available"
            handle_network_failure "Service unavailable" "$test_file"
            return 1
        fi
    fi
    
    # Execute gRPC call with retry mechanism
    local start_time=$(date +%s)
    local grpc_output
    local grpc_status
    
    # Get dry-run flag
    local dry_run="false"
    if [[ "${args[--dry-run]:-}" == "1" ]]; then
        dry_run="true"
        # Set expectations for dry-run based on test sections
        if [[ -n "$error" && "$error" != "null" ]]; then
            export GRPCTESTIFY_GRPCTESTIFY_DRY_RUN_EXPECT_ERROR="true"
        else
            export GRPCTESTIFY_GRPCTESTIFY_DRY_RUN_EXPECT_ERROR="false"
            # If there's expected response, pass it to dry-run
            if [[ -n "$response" && "$response" != "null" ]]; then
                export GRPCTESTIFY_GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE="$response"
            fi
        fi
    fi
    
    # Use enhanced gRPC call with retry mechanism
    grpc_output=$(run_grpc_call_with_retry "$address" "$endpoint" "$request" "$headers" "" "$dry_run")
    grpc_status=$?
    

    
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    
    # Special handling for dry-run mode - check if output contains dry-run indicator
    if [[ "$dry_run" == "true" ]] || [[ "$grpc_output" =~ "dry_run.*true" ]] || [[ "$grpc_output" =~ "Command preview completed" ]]; then
        # Show the actual dry-run output in verbose mode
        if [[ "${verbose:-false}" == "true" ]]; then
            echo "$grpc_output" >&2
        fi
        log_test_success "TEST PASSED: $test_name (dry-run preview, ${execution_time}s)" "$progress_mode"
        print_progress "." "$progress_mode"
        return 0
    fi
    
    # Follow v0.0.13 logic: Check ERROR section first (highest priority)
    if [[ -n "$error" ]]; then
        # ERROR section is present - we expect gRPC to fail
        if [[ $grpc_status -eq 0 ]]; then
            log error "TEST FAILED: $test_name - Expected gRPC error but request succeeded (${execution_time}s)"
            print_progress "F" "$progress_mode"
            return 1
        fi
        
        # Validate that the actual error matches expected
        if validate_expected_error "$error" "$grpc_output"; then
            log_test_success "TEST PASSED: $test_name (expected error, ${execution_time}s)" "$progress_mode"
            log_test_details "$test_name" "$address" "$endpoint" "$request" "$headers" "" "$error" "$grpc_output" "$grpc_status" "$execution_time"
            print_progress "." "$progress_mode"
            return 0
        else
            log error "TEST FAILED: $test_name - Error doesn't match expected (${execution_time}s)"
            log error "Expected: $error"
            log error "Actual: $grpc_output"
            log_test_details "$test_name" "$address" "$endpoint" "$request" "$headers" "" "$error" "$grpc_output" "$grpc_status" "$execution_time"
            print_progress "F" "$progress_mode"
            return 1
        fi
    fi
    
    # No ERROR section - check if we have ASSERTS
    local asserts_content=$(extract_section "$test_file" "ASSERTS")
    if [[ -n "$asserts_content" ]]; then
        # We have ASSERTS - evaluate them
        local actual_array="[$grpc_output]"
        if evaluate_asserts_with_plugins "$test_file" "$actual_array" 2>/dev/null; then
            # ASSERTS passed - test successful regardless of gRPC status
            if [[ $grpc_status -eq 0 ]]; then
                log_test_success "TEST PASSED: $test_name (${execution_time}s)" "$progress_mode"
            else
                log_test_success "TEST PASSED: $test_name (expected error, ${execution_time}s)" "$progress_mode"
            fi
            log_test_details "$test_name" "$address" "$endpoint" "$request" "$headers" "" "" "$grpc_output" "$grpc_status" "$execution_time"
            print_progress "." "$progress_mode"
            return 0
        else
            # ASSERTS failed
            log error "TEST FAILED: $test_name - ASSERTS failed (${execution_time}s)"
            log_test_details "$test_name" "$address" "$endpoint" "$request" "$headers" "" "" "$grpc_output" "$grpc_status" "$execution_time"
            print_progress "F" "$progress_mode"
            return 1
        fi
    fi
    
    # No ERROR section and no ASSERTS - must have RESPONSE section
    # Check gRPC status first
    if [[ $grpc_status -ne 0 ]]; then
        log error "TEST FAILED: $test_name - Unexpected gRPC error (${execution_time}s)"
        log error "gRPC Status: $grpc_status"
        log error "Response: $grpc_output"
        log_test_details "$test_name" "$address" "$endpoint" "$request" "$headers" "$response" "" "$grpc_output" "$grpc_status" "$execution_time"
        print_progress "F" "$progress_mode"
        return 1
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
                    log error "TEST FAILED: $test_name - ASSERTS failed (${execution_time}s)"
                    print_progress "F" "$progress_mode"
                    return 1
                fi
            fi
            
            log_test_success "TEST PASSED: $test_name (${execution_time}s)" "$progress_mode"
            log_test_details "$test_name" "$address" "$endpoint" "$request" "$headers" "$response" "" "$grpc_output" "$grpc_status" "$execution_time"
            print_progress "." "$progress_mode"
            
            # Debug output (v0.0.13 compatibility)
            log debug "Test passed, continuing to next test"

            return 0
        else
            log error "TEST FAILED: $test_name (${execution_time}s)"
            log error "--- Expected ---"
            printf "%s\n" "$response"
            log error "+++ Actual +++"
            printf "%s\n" "$grpc_output"
            log_test_details "$test_name" "$address" "$endpoint" "$request" "$headers" "$response" "" "$grpc_output" "$grpc_status" "$execution_time"
            print_progress "F" "$progress_mode"
    
            return 1
        fi
    else
        # No RESPONSE and no ASSERTS - test passes (no validation)
        log_test_success "TEST PASSED: $test_name (${execution_time}s)" "$progress_mode"
        print_progress "." "$progress_mode"
        
        # Debug output (v0.0.13 compatibility)
        log debug "Test passed, continuing to next test"

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
