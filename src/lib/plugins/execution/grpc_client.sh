#!/bin/bash

# grpc_client.sh - gRPC client functionality extracted from runner.sh
# Handles all gRPC communication and command building
# Part of modular execution plugin architecture

#######################################
# Format dry-run output beautifully
# Arguments:
#   1: Request data
#   2: Headers
#   Rest: Command array
# Outputs:
#   Formatted dry-run preview
#######################################
format_dry_run_output() {
    local request="$1"
    local headers="$2"
    shift 2
    local cmd=("$@")
    
    echo "🌟 DRY-RUN MODE - Command Preview:"
    echo "=================================="
    
    # Format command nicely
    local formatted_cmd="grpcurl"
    for arg in "${cmd[@]:1}"; do
        if [[ "$arg" =~ ^- ]]; then
            formatted_cmd="$formatted_cmd \\\\\n      $arg"
        elif [[ "$arg" == "localhost:"* || "$arg" =~ \. ]]; then
            formatted_cmd="$formatted_cmd \\\\\n      '$arg'"
        else
            formatted_cmd="$formatted_cmd '$arg'"
        fi
    done
    echo -e "📡 Command: $formatted_cmd"
    
    if [[ -n "$request" ]]; then
        echo "📤 Request Payload:"
        if command -v jq >/dev/null 2>&1 && echo "$request" | jq . >/dev/null 2>&1; then
            echo "$request" | jq -C . 2>/dev/null | sed 's/^/    /'
        else
            echo "$request" | sed 's/^/    /'
        fi
    else
        echo "📤 Request Payload: (empty)"
    fi
    
    if [[ -n "$headers" ]]; then
        echo "📋 Headers:"
        echo "$headers" | sed 's/^/    /'
    fi
    
    echo ""
}

#######################################
# Build and execute gRPC call
# Arguments:
#   1: address
#   2: endpoint
#   3: request data
#   4: headers
#   5: proto file (optional)
#   6: dry_run flag (optional)
# Returns:
#   gRPC call exit code
# Outputs:
#   gRPC response or error
#######################################
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
	tlog debug "📡 gRPC Command:"
        
        local formatted_cmd="grpcurl"
        for arg in "${cmd[@]:1}"; do
            if [[ "$arg" =~ ^- ]]; then
                formatted_cmd="$formatted_cmd \\\\\n      $arg"
            elif [[ "$arg" == "localhost:"* || "$arg" =~ \. ]]; then
                formatted_cmd="$formatted_cmd \\\\\n      '$arg'"
            else
                formatted_cmd="$formatted_cmd '$arg'"
            fi
        done
        echo -e "🔍    $formatted_cmd" >&2
        
        if [[ -n "$request" ]]; then
	tlog debug "📤 Request Payload:"
            # Pretty print JSON if possible, otherwise show as-is
            if command -v jq >/dev/null 2>&1 && echo "$request" | jq . >/dev/null 2>&1; then
                echo "$request" | jq -C . 2>/dev/null | sed 's/^/🔍    /' >&2
            else
                echo "$request" | sed 's/^/🔍    /' >&2
            fi
        else
	tlog debug "📤 Request Payload: (empty)"
        fi
    fi
    
    # Execute with request data using temporary file
    if [[ -n "$request" ]]; then
        # Create temporary file for request data
        local request_tmp=$(mktemp)
        # Use jq -c to compact JSON
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

#######################################
# Enhanced gRPC call with retry mechanism
# Arguments:
#   1: address
#   2: endpoint
#   3: request data
#   4: headers
#   5: proto file (optional)
#   6: dry_run flag (optional)
# Returns:
#   gRPC call exit code after retries
# Outputs:
#   gRPC response or error
#######################################
run_grpc_call_with_retry() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local proto_file="$5"
    local dry_run="${6:-false}"
    
    # Configuration
    local max_retries=3
    local retry_delay=1
    
    # Check if retries are disabled
    if is_no_retry; then
        max_retries=1
    fi
    
    local attempt=1
    while [[ $attempt -le $max_retries ]]; do
        # Execute gRPC call
        local output
        output=$(run_grpc_call "$address" "$endpoint" "$request" "$headers" "$proto_file" "$dry_run" 2>&1)
        local exit_code=$?
        
        # Success - return immediately
        if [[ $exit_code -eq 0 ]]; then
            echo "$output"
            return 0
        fi
        
        # Check if it's a retryable error
        if [[ $attempt -lt $max_retries && "$output" =~ (connection|timeout|unavailable|deadline|refused) ]]; then
	    tlog debug "Retry $attempt/$max_retries: gRPC call failed (retryable error), retrying in ${retry_delay}s..."
            sleep "$retry_delay"
            ((attempt++))
            retry_delay=$((retry_delay * 2))  # Exponential backoff
        else
            # Non-retryable error or max retries reached
            echo "$output"
            return $exit_code
        fi
    done
    
    # This should never be reached, but just in case
    echo "$output"
    return $exit_code
}

#######################################
# Check if service is healthy and available
# Arguments:
#   1: address (host:port)
# Returns:
#   0 if service is healthy, 1 otherwise
#######################################
check_service_health() {
    local address="$1"
    
    # Extract host and port
    local host="${address%:*}"
    local port="${address#*:}"
    
    # Quick connectivity check
    if command -v nc >/dev/null 2>&1; then
        # Use netcat for quick port check
        if ! nc -z "$host" "$port" 2>/dev/null; then
            return 1
        fi
    elif command -v timeout >/dev/null 2>&1; then
        # Use timeout with basic TCP check
        if ! timeout 2 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
            return 1
        else
            exec 3<&- 3>&- 2>/dev/null || true
        fi
    else
        # Basic TCP check without timeout
        if ! exec 3<>"/dev/tcp/$host/$port" 2>/dev/null; then
            return 1
        else
            exec 3<&- 3>&- 2>/dev/null || true
        fi
    fi
    
    return 0
}

# Export functions for use by other plugins
export -f run_grpc_call
export -f run_grpc_call_with_retry
export -f check_service_health
export -f format_dry_run_output
