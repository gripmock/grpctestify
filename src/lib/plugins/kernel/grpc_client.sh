#!/bin/bash

# grpc_client.sh - Core gRPC client plugin using microkernel architecture
# Migrated from legacy runner.sh gRPC execution logic

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
export PLUGIN_GRPC_CLIENT_VERSION="1.0.0"
export PLUGIN_GRPC_CLIENT_DESCRIPTION="Kernel gRPC client with microkernel integration"
export PLUGIN_GRPC_CLIENT_AUTHOR="grpctestify-team"
export PLUGIN_GRPC_CLIENT_TYPE="kernel"

# gRPC client configuration
GRPC_CLIENT_TIMEOUT="${GRPC_CLIENT_TIMEOUT:-30}"
GRPC_CLIENT_MAX_RETRIES="${GRPC_CLIENT_MAX_RETRIES:-3}"
GRPC_CLIENT_RETRY_DELAY="${GRPC_CLIENT_RETRY_DELAY:-1}"
GRPC_CLIENT_POOL_SIZE="${GRPC_CLIENT_POOL_SIZE:-4}"

# Initialize gRPC client plugin
grpc_client_init() {
    log_debug "Initializing gRPC client plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    log_warn "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Check required dependencies
    if ! command -v grpcurl >/dev/null 2>&1; then
    log_error "grpcurl is required but not installed"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "grpc_client" "grpc_client_handler" "$PLUGIN_GRPC_CLIENT_DESCRIPTION" "kernel" ""
    
    # Create resource pool for gRPC calls
    pool_create "grpc_calls" "$GRPC_CLIENT_POOL_SIZE"
    
    # Subscribe to gRPC-related events
    event_subscribe "grpc_client" "grpc.*" "grpc_client_event_handler"
    
    log_debug "gRPC client plugin initialized successfully"
    return 0
}

# Main gRPC client handler
grpc_client_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "execute_call")
            grpc_client_execute_call "${args[@]}"
            ;;
        "execute_calls")
            grpc_client_execute_calls "${args[@]}"
            ;;
        "validate_connection")
            grpc_client_validate_connection "${args[@]}"
            ;;
        "list_services")
            grpc_client_list_services "${args[@]}"
            ;;
        "describe_service")
            grpc_client_describe_service "${args[@]}"
            ;;
        *)
    log_error "Unknown gRPC client command: $command"
            return 1
            ;;
    esac
}

# Execute a single gRPC call with microkernel integration
grpc_client_execute_call() {
    local call_config="$1"
    local execution_options="${2:-{}}"
    
    if [[ -z "$call_config" ]]; then
    log_error "grpc_client_execute_call: call_config required"
        return 1
    fi
    
    # Parse call configuration
    local address
    address=$(echo "$call_config" | jq -r '.address // "localhost:4770"')
    local endpoint
    endpoint=$(echo "$call_config" | jq -r '.endpoint')
    local request
    request=$(echo "$call_config" | jq -r '.request // ""')
    local headers
    headers=$(echo "$call_config" | jq -r '.headers // ""')
    local request_headers
    request_headers=$(echo "$call_config" | jq -r '.request_headers // ""')
    local proto_config
    proto_config=$(echo "$call_config" | jq -r '.proto // ""')
    local tls_config
    tls_config=$(echo "$call_config" | jq -r '.tls // ""')
    
    # Parse execution options
    local dry_run
    dry_run=$(echo "$execution_options" | jq -r '.dry_run // false')
    local timeout
    timeout=$(echo "$execution_options" | jq -r '.timeout // "30"')
    local enable_retry
    enable_retry=$(echo "$execution_options" | jq -r '.enable_retry // true')
    
    if [[ -z "$endpoint" ]]; then
    log_error "Missing endpoint in gRPC call configuration"
        return 1
    fi
    
    log_debug "Executing gRPC call: $endpoint on $address"

    # Allow override via plugin: plugin_grpc_client_execute(call_config_json, execution_options_json)
    if command -v plugin_grpc_client_execute >/dev/null 2>&1; then
        log_debug "Delegating gRPC execution to override plugin"
        local plugin_out
        if plugin_out=$(plugin_grpc_client_execute "$call_config" "$execution_options"); then
            echo "$plugin_out"
            return 0
        else
            # If plugin reports failure, propagate non-zero but continue to record below
            echo "$plugin_out"
            return 1
        fi
    fi
    
    # Publish gRPC call start event
    local call_metadata
    call_metadata=$(cat << EOF
{
  "address": "$address",
  "endpoint": "$endpoint",
  "client": "grpc_client",
  "start_time": $(date +%s),
  "dry_run": $dry_run
}
EOF
)
    event_publish "grpc.call.start" "$call_metadata" "$EVENT_PRIORITY_NORMAL" "grpc_client"
    
    # Begin transaction for gRPC call
    local tx_id
    tx_id=$(state_db_begin_transaction "grpc_call_${endpoint//\//_}_$$")
    
    # Acquire resource for gRPC call
    local resource_token
    resource_token=$(pool_acquire "grpc_calls" "$timeout")
    if [[ $? -ne 0 ]]; then
    log_error "Failed to acquire resource for gRPC call: $endpoint"
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
    
    # Execute gRPC call with monitoring
    local call_result=0
    local start_time
    start_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
    local response
    
    if enable_retry && [[ "$enable_retry" == "true" ]]; then
        response=$(execute_grpc_call_with_retry "$address" "$endpoint" "$request" "$headers" "$request_headers" "$proto_config" "$tls_config" "$dry_run" "$timeout")
        call_result=$?
    else
        response=$(execute_grpc_call "$address" "$endpoint" "$request" "$headers" "$request_headers" "$proto_config" "$tls_config" "$dry_run" "$timeout")
        call_result=$?
    fi
    
    local end_time
    end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
    local duration=$((end_time - start_time))
    
    # Record call result
    if [[ $call_result -eq 0 ]]; then
    log_debug "gRPC call succeeded: $endpoint (${duration}ms)"
        
        # Store successful call
        state_db_atomic "record_grpc_call" "$endpoint" "SUCCESS" "$duration" "$response"
        
        # Publish success event
        event_publish "grpc.call.success" "{\"endpoint\":\"$endpoint\",\"duration\":$duration}" "$EVENT_PRIORITY_NORMAL" "grpc_client"
        
        # Output response
        echo "$response"
    else
    log_error "gRPC call failed: $endpoint (${duration}ms)"
        
        # Store failed call
        state_db_atomic "record_grpc_call" "$endpoint" "FAILED" "$duration" "$response"
        
        # Publish failure event
        event_publish "grpc.call.failure" "{\"endpoint\":\"$endpoint\",\"duration\":$duration}" "$EVENT_PRIORITY_HIGH" "grpc_client"
    fi
    
    # Release resource
    pool_release "grpc_calls" "$resource_token"
    
    # Commit transaction
    state_db_commit_transaction "$tx_id"
    
    return $call_result
}

# Execute gRPC call with enhanced error handling
execute_grpc_call() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local request_headers="$5"
    local proto_config="$6"
    local tls_config="$7"
    local dry_run="$8"
    local timeout="$9"
    
    # Combine headers and request_headers into array of -H pairs
    local header_args=()
    local all_headers=""
    [[ -n "$headers" ]] && all_headers="$headers"
    if [[ -n "$request_headers" ]]; then
        all_headers+=$'\n'
    fi
    if [[ -n "$request_headers" ]]; then
        all_headers+="$request_headers"
    fi
    if [[ -n "$all_headers" ]]; then
        while IFS= read -r h; do
            [[ -z "$h" || "$h" =~ ^[[:space:]]*$ ]] && continue
            header_args+=("-H" "$h")
        done <<< "$all_headers"
    fi
    
    # Build grpcurl argv via shared helper
    local has_request="0"
    [[ -n "$request" ]] && has_request="1"
    build_grpcurl_args "$address" "$endpoint" "$tls_config" "$proto_config" header_args "$has_request"
    
    # Dry-run: preview the exact command (one line)
    if [[ "$dry_run" == "true" ]]; then
        render_grpcurl_preview "$request" "${GRPCURL_ARGS[@]}"
        # Simulated output path remains same as before (no execution)
        if [[ -n "${GRPCTESTIFY_DRY_RUN_EXPECT_ERROR:-}" && "${GRPCTESTIFY_DRY_RUN_EXPECT_ERROR}" == "true" ]]; then
            echo '{"code": 999, "message": "DRY-RUN: Simulated gRPC error", "details": []}'
            return 1
        fi
        if [[ -n "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE:-}" && "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}" != "null" ]]; then
            echo "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}"
        else
            echo '{"dry_run": true, "message": "Command preview completed", "status": "success"}'
        fi
        return 0
    fi
    
    # Execute via shared helper with timeout (trace timing)
    local out
    out=$( execute_grpcurl_argv "${timeout:-30}" "$request" "${GRPCTESTIFY_GRPC_DEBUG:+-v}" "${GRPCURL_ARGS[@]}" )
    local status=$?
    echo "$out"
    return $status
}

# Execute gRPC call with retry mechanism
execute_grpc_call_with_retry() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local request_headers="$5"
    local proto_config="$6"
    local tls_config="$7"
    local dry_run="$8"
    local timeout="$9"
    
    local max_retries="${GRPC_CLIENT_MAX_RETRIES}"
    local retry_delay="${GRPC_CLIENT_RETRY_DELAY}"
    local attempt=0
    
    log_debug "🔄 Using retry mechanism: max_retries=$max_retries, delay=${retry_delay}s"
    
    while [[ $attempt -le $max_retries ]]; do
        if [[ $attempt -gt 0 ]]; then
    log_debug "Retry attempt $attempt/$max_retries for $endpoint"
            sleep "$retry_delay"
            # Exponential backoff
            retry_delay=$((retry_delay * 2))
        fi
        
        local response
        if response=$(execute_grpc_call "$address" "$endpoint" "$request" "$headers" "$request_headers" "$proto_config" "$tls_config" "$dry_run" "$timeout"); then
            echo "$response"
            return 0
        fi
        
        ((attempt++))
    done
    
    log_error "gRPC call failed after $max_retries retries: $endpoint"
    return 1
}

# Execute multiple gRPC calls (for streaming or batch operations)
grpc_client_execute_calls() {
    local test_file="$1"
    local test_components="$2"
    
    if [[ -z "$test_file" || -z "$test_components" ]]; then
    log_error "grpc_client_execute_calls: test_file and test_components required"
        return 1
    fi
    
    # Extract gRPC call configuration from test components
    local grpc_calls
    grpc_calls=$(echo "$test_components" | jq -r '.grpc_calls')
    
    if [[ -z "$grpc_calls" || "$grpc_calls" == "null" ]]; then
    log_error "No gRPC calls configuration found in test components"
        return 1
    fi
    
    # Execute the gRPC call
    grpc_client_execute_call "$grpc_calls" "{\"dry_run\": ${dry_run:-false}}"
}

# Validate gRPC connection
grpc_client_validate_connection() {
    local address="$1"
    local timeout="${2:-5}"
    
    if [[ -z "$address" ]]; then
    log_error "grpc_client_validate_connection: address required"
        return 1
    fi
    
    log_debug "Validating gRPC connection to: $address"
    
    # Try to list services as a connection test
    if grpcurl -plaintext -max-time "$timeout" "$address" list >/dev/null 2>&1; then
    log_debug "gRPC connection validated successfully: $address"
        return 0
    else
    log_error "gRPC connection validation failed: $address"
        return 1
    fi
}

# List available gRPC services
grpc_client_list_services() {
    local address="$1"
    local timeout="${2:-10}"
    
    if [[ -z "$address" ]]; then
    log_error "grpc_client_list_services: address required"
        return 1
    fi
    
    log_debug "Listing gRPC services on: $address"
    
    grpcurl -plaintext -max-time "$timeout" "$address" list 2>/dev/null
}

# Describe a specific gRPC service
grpc_client_describe_service() {
    local address="$1"
    local service="$2"
    local timeout="${3:-10}"
    
    if [[ -z "$address" || -z "$service" ]]; then
    log_error "grpc_client_describe_service: address and service required"
        return 1
    fi
    
    log_debug "Describing gRPC service: $service on $address"
    
    grpcurl -plaintext -max-time "$timeout" "$address" describe "$service" 2>/dev/null
}

# Format dry-run output
format_dry_run_output() {
    local request="$1"
    local headers="$2"
    shift 2
    local cmd=("$@")
    
    echo "🔍 DRY-RUN: gRPC Command Preview"
    echo "================================"
    
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
    echo -e "$formatted_cmd"
    
    if [[ -n "$headers" ]]; then
        echo ""
        echo "📋 Headers:"
        echo "$headers" | sed 's/^/    /'
    fi
    
    if [[ -n "$request" ]]; then
        echo ""
        echo "📤 Request Payload:"
        if command -v jq >/dev/null 2>&1 && echo "$request" | jq . >/dev/null 2>&1; then
            echo "$request" | jq . | sed 's/^/    /'
        else
            echo "$request" | sed 's/^/    /'
        fi
    fi
    echo "================================"
}

# Format debug output
format_grpc_debug_output() {
    local request="$1"
    local headers="$2"
    shift 2
    local cmd=("$@")
    
    # Format command nicely with line breaks for readability
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
    log_debug "📤 Request Payload:"
        # Pretty print JSON if possible, otherwise show as-is
        if command -v jq >/dev/null 2>&1 && echo "$request" | jq . >/dev/null 2>&1; then
            echo "$request" | jq -C . 2>/dev/null | sed 's/^/🔍    /' >&2
        else
            echo "$request" | sed 's/^/🔍    /' >&2
        fi
    else
    log_debug "📤 Request Payload: (empty)"
    fi
}

# gRPC client event handler
grpc_client_event_handler() {
    local event_message="$1"
    
    log_debug "gRPC client received event: $event_message"
    
    # Handle gRPC-related events
    # This could be used for:
    # - gRPC call performance monitoring
    # - Connection pool management
    # - Failure pattern analysis
    # - Load balancing decisions
    
    return 0
}

# State database helper functions
record_grpc_call() {
    local endpoint
    endpoint="$1"
    local status
    status="$2"
    local duration
    duration="$3"
    local response
    response="$4"
    
    # shellcheck disable=SC2034
    local call_key
    call_key="grpc_call_${endpoint//\//_}"
    # shellcheck disable=SC2034
    GRPCTESTIFY_STATE["${call_key}_status"]="$status"
    # shellcheck disable=SC2034
    GRPCTESTIFY_STATE["${call_key}_duration"]="$duration"
    # shellcheck disable=SC2034
    GRPCTESTIFY_STATE["${call_key}_timestamp"]="$(date +%s)"
    # shellcheck disable=SC2034
    [[ -n "$response" ]] && GRPCTESTIFY_STATE["${call_key}_response"]="$response"
    
    return 0
}

# Legacy compatibility functions
run_grpc_call() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local proto_file="$5"
    local dry_run="${6:-false}"
    
    # Convert to new format
    local call_config
    call_config=$(jq -n \
        --arg address "$address" \
        --arg endpoint "$endpoint" \
        --arg request "$request" \
        --arg headers "$headers" \
        --arg proto "$proto_file" \
        '{
            address: $address,
            endpoint: $endpoint,
            request: $request,
            headers: $headers,
            proto: {mode: "file", file: $proto}
        }')
    
    local execution_options
    execution_options=$(jq -n --argjson dry_run "$dry_run" '{dry_run: $dry_run}')
    
    grpc_client_execute_call "$call_config" "$execution_options"
}

run_grpc_call_with_retry() {
    local address="$1"
    local endpoint="$2"
    local request="$3"
    local headers="$4"
    local proto_file="$5"
    local dry_run="${6:-false}"
    
    # Convert to new format with retry enabled
    local call_config
    call_config=$(jq -n \
        --arg address "$address" \
        --arg endpoint "$endpoint" \
        --arg request "$request" \
        --arg headers "$headers" \
        --arg proto "$proto_file" \
        '{
            address: $address,
            endpoint: $endpoint,
            request: $request,
            headers: $headers,
            proto: {mode: "file", file: $proto}
        }')
    
    local execution_options
    execution_options=$(jq -n --argjson dry_run "$dry_run" '{dry_run: $dry_run, enable_retry: true}')
    
    grpc_client_execute_call "$call_config" "$execution_options"
}

# Export functions
export -f grpc_client_init grpc_client_handler grpc_client_execute_call
export -f execute_grpc_call execute_grpc_call_with_retry grpc_client_execute_calls
export -f grpc_client_validate_connection grpc_client_list_services grpc_client_describe_service
export -f format_dry_run_output format_grpc_debug_output grpc_client_event_handler
export -f record_grpc_call run_grpc_call run_grpc_call_with_retry
