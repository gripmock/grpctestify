#!/bin/bash

# grpc_response_time.sh - Enhanced gRPC response time plugin with microkernel integration
# Migrated from legacy grpc_response_time.sh with microkernel components

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
readonly PLUGIN_RESPONSE_TIME_VERSION="1.0.0"
readonly PLUGIN_RESPONSE_TIME_DESCRIPTION="Enhanced gRPC response time monitoring with microkernel integration"
readonly PLUGIN_RESPONSE_TIME_AUTHOR="grpctestify-team"
readonly PLUGIN_RESPONSE_TIME_TYPE="performance"

# Response time thresholds and configuration
RESPONSE_TIME_WARNING_MS="${RESPONSE_TIME_WARNING_MS:-1000}"
RESPONSE_TIME_CRITICAL_MS="${RESPONSE_TIME_CRITICAL_MS:-5000}"
RESPONSE_TIME_SAMPLE_SIZE="${RESPONSE_TIME_SAMPLE_SIZE:-100}"

# Initialize response time monitoring plugin
grpc_response_time_init() {
    log_debug "Initializing gRPC response time monitoring plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    log_warn "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "response_time" "grpc_response_time_handler" "$PLUGIN_RESPONSE_TIME_DESCRIPTION" "internal" ""
    
    # Create resource pool for response time analysis
    pool_create "response_time_analysis" 2
    
    # Subscribe to performance-related events
    event_subscribe "response_time" "performance.*" "grpc_response_time_event_handler"
    event_subscribe "response_time" "grpc.call.*" "grpc_response_time_call_handler"
    
    # Initialize response time tracking state
    if command -v state_db_set >/dev/null 2>&1; then
        state_db_set "response_time.plugin_version" "$PLUGIN_RESPONSE_TIME_VERSION"
        state_db_set "response_time.samples_collected" "0"
        state_db_set "response_time.total_time" "0"
        state_db_set "response_time.min_time" "999999"
        state_db_set "response_time.max_time" "0"
    fi
    
    log_debug "gRPC response time monitoring plugin initialized successfully"
    return 0
}

# Main response time plugin handler
grpc_response_time_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "evaluate_assertion")
            grpc_response_time_evaluate_assertion "${args[@]}"
            ;;
        "track_response_time")
            grpc_response_time_track_response_time "${args[@]}"
            ;;
        "get_statistics")
            grpc_response_time_get_statistics "${args[@]}"
            ;;
        "analyze_performance")
            grpc_response_time_analyze_performance "${args[@]}"
            ;;
        "reset_statistics")
            grpc_response_time_reset_statistics "${args[@]}"
            ;;
        *)
    log_error "Unknown response time command: $command"
            return 1
            ;;
    esac
}

# Enhanced response time assertion with microkernel integration
grpc_response_time_evaluate_assertion() {
    local response="$1"
    local expected_time="$2"
    local assertion_context="${3:-{}}"
    
    if [[ -z "$response" || -z "$expected_time" ]]; then
    log_error "grpc_response_time_evaluate_assertion: response and expected_time required"
        return 1
    fi
    
    log_debug "Evaluating response time assertion: expected=$expected_time"
    
    # Publish assertion evaluation start event
    local assertion_metadata
    assertion_metadata=$(cat << EOF
{
  "expected_time": "$expected_time",
  "plugin": "response_time",
  "start_time": $(date +%s),
  "context": $assertion_context
}
EOF
)
    event_publish "performance.assertion.start" "$assertion_metadata" "$EVENT_PRIORITY_NORMAL" "response_time"
    
    # Begin transaction for assertion evaluation
    local tx_id
    tx_id=$(state_db_begin_transaction "response_time_assertion_$$")
    
    # Acquire resource for response time analysis
    local resource_token
    resource_token=$(pool_acquire "response_time_analysis" 30)
    if [[ $? -ne 0 ]]; then
    log_error "Failed to acquire resource for response time analysis"
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
    
    # Extract actual response time with enhanced methods
    local actual_time
    if ! actual_time=$(extract_response_time "$response"); then
    log_error "Failed to extract response time from response"
        pool_release "response_time_analysis" "$resource_token"
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
    
    # Perform enhanced response time evaluation
    local evaluation_result=0
    if evaluate_response_time "$actual_time" "$expected_time"; then
    log_debug "Response time assertion passed: ${actual_time}ms <= ${expected_time}ms"
        
        # Record successful assertion
        state_db_atomic "record_response_time_assertion" "$actual_time" "$expected_time" "PASS"
        
        # Publish success event
        event_publish "performance.assertion.success" "{\"actual_time\":$actual_time,\"expected_time\":\"$expected_time\"}" "$EVENT_PRIORITY_NORMAL" "response_time"
    else
        evaluation_result=1
    log_error "Response time assertion failed: ${actual_time}ms > ${expected_time}ms"
        
        # Record failed assertion
        state_db_atomic "record_response_time_assertion" "$actual_time" "$expected_time" "FAIL"
        
        # Publish failure event
        event_publish "performance.assertion.failure" "{\"actual_time\":$actual_time,\"expected_time\":\"$expected_time\"}" "$EVENT_PRIORITY_HIGH" "response_time"
    fi
    
    # Track response time for statistics
    track_response_time_sample "$actual_time"
    
    # Release resource
    pool_release "response_time_analysis" "$resource_token"
    
    # Commit transaction
    state_db_commit_transaction "$tx_id"
    
    return $evaluation_result
}

# Enhanced response time extraction
extract_response_time() {
    local response="$1"
    local actual_time=""
    
    # Try multiple response time fields with priority order
    local time_fields=("_response_time" "response_time" "duration" "time" "elapsed_ms" "latency_ms")
    
    for field in "${time_fields[@]}"; do
        if actual_time=$(echo "$response" | jq -r ".$field // empty" 2>/dev/null); then
            if [[ "$actual_time" != "null" && -n "$actual_time" && "$actual_time" =~ ^[0-9]+$ ]]; then
                echo "$actual_time"
                return 0
            fi
        fi
    done
    
    # Try to extract from gRPC metadata
    if actual_time=$(echo "$response" | jq -r '.metadata.response_time // .grpc_metadata.duration // empty' 2>/dev/null); then
        if [[ "$actual_time" != "null" && -n "$actual_time" && "$actual_time" =~ ^[0-9]+$ ]]; then
            echo "$actual_time"
            return 0
        fi
    fi
    
    # Try to extract from error response
    if actual_time=$(echo "$response" | jq -r '.error.response_time // empty' 2>/dev/null); then
        if [[ "$actual_time" != "null" && -n "$actual_time" && "$actual_time" =~ ^[0-9]+$ ]]; then
            echo "$actual_time"
            return 0
        fi
    fi
    
    log_error "Response time not found in gRPC response"
    return 1
}

# Enhanced response time evaluation with range support
evaluate_response_time() {
    local actual_time="$1"
    local expected_time="$2"
    
    # Parse expected time (support ranges like 500-2000, percentiles like p95:1000)
    if [[ "$expected_time" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        # Range evaluation: min-max
        local min_time="${BASH_REMATCH[1]}"
        local max_time="${BASH_REMATCH[2]}"
        
        if [[ $actual_time -ge $min_time && $actual_time -le $max_time ]]; then
    log_debug "Response time $actual_time ms is in range $min_time-$max_time ms"
            return 0
        else
    log_error "Response time $actual_time ms is not in range $min_time-$max_time ms"
            return 1
        fi
    elif [[ "$expected_time" =~ ^p([0-9]+):([0-9]+)$ ]]; then
        # Percentile evaluation: p95:1000
        local percentile="${BASH_REMATCH[1]}"
        local threshold="${BASH_REMATCH[2]}"
        
        # For now, treat as simple threshold (future: implement proper percentile tracking)
    log_debug "Percentile evaluation p$percentile: comparing $actual_time ms against $threshold ms"
        if [[ $actual_time -le $threshold ]]; then
            return 0
        else
    log_error "Response time $actual_time ms exceeds p$percentile threshold $threshold ms"
            return 1
        fi
    else
        # Simple threshold evaluation
        if [[ $actual_time -le $expected_time ]]; then
    log_debug "Response time $actual_time ms is within limit $expected_time ms"
            return 0
        else
    log_error "Response time $actual_time ms exceeds limit $expected_time ms"
            return 1
        fi
    fi
}

# Track response time for ongoing statistics
grpc_response_time_track_response_time() {
    local response_time="$1"
    local endpoint="${2:-unknown}"
    
    if [[ -z "$response_time" || ! "$response_time" =~ ^[0-9]+$ ]]; then
    log_warn "Invalid response time for tracking: $response_time"
        return 1
    fi
    
    track_response_time_sample "$response_time"
    
    # Store per-endpoint statistics if available
    if [[ -n "$endpoint" && "$endpoint" != "unknown" ]]; then
        local endpoint_key="endpoint_$(echo "$endpoint" | tr '/' '_' | tr '.' '_')"
        if command -v state_db_get >/dev/null 2>&1; then
            local current_count
            current_count=$(state_db_get "response_time.${endpoint_key}.count" || echo "0")
            local current_total
            current_total=$(state_db_get "response_time.${endpoint_key}.total" || echo "0")
            
            state_db_set "response_time.${endpoint_key}.count" "$((current_count + 1))"
            state_db_set "response_time.${endpoint_key}.total" "$((current_total + response_time))"
            state_db_set "response_time.${endpoint_key}.last_time" "$response_time"
        fi
    fi
    
    log_debug "Tracked response time: ${response_time}ms for endpoint: $endpoint"
}

# Track individual response time sample
track_response_time_sample() {
    local response_time="$1"
    
    if command -v state_db_get >/dev/null 2>&1; then
        # Update global statistics
        local samples_collected
        samples_collected=$(state_db_get "response_time.samples_collected" || echo "0")
        local total_time
        total_time=$(state_db_get "response_time.total_time" || echo "0")
        local min_time
        min_time=$(state_db_get "response_time.min_time" || echo "999999")
        local max_time
        max_time=$(state_db_get "response_time.max_time" || echo "0")
        
        # Update statistics
        state_db_set "response_time.samples_collected" "$((samples_collected + 1))"
        state_db_set "response_time.total_time" "$((total_time + response_time))"
        
        # Update min/max
        if [[ $response_time -lt $min_time ]]; then
            state_db_set "response_time.min_time" "$response_time"
        fi
        if [[ $response_time -gt $max_time ]]; then
            state_db_set "response_time.max_time" "$response_time"
        fi
        
        # Check against warning/critical thresholds
        if [[ $response_time -gt $RESPONSE_TIME_CRITICAL_MS ]]; then
            event_publish "performance.critical" "{\"response_time\":$response_time,\"threshold\":$RESPONSE_TIME_CRITICAL_MS}" "$EVENT_PRIORITY_CRITICAL" "response_time"
        elif [[ $response_time -gt $RESPONSE_TIME_WARNING_MS ]]; then
            event_publish "performance.warning" "{\"response_time\":$response_time,\"threshold\":$RESPONSE_TIME_WARNING_MS}" "$EVENT_PRIORITY_HIGH" "response_time"
        fi
    fi
}

# Get comprehensive response time statistics
grpc_response_time_get_statistics() {
    local format="${1:-json}"
    
    if command -v state_db_get >/dev/null 2>&1; then
        local samples_collected
        samples_collected=$(state_db_get "response_time.samples_collected" || echo "0")
        local total_time
        total_time=$(state_db_get "response_time.total_time" || echo "0")
        local min_time
        min_time=$(state_db_get "response_time.min_time" || echo "0")
        local max_time
        max_time=$(state_db_get "response_time.max_time" || echo "0")
        
        # Calculate average
        local avg_time=0
        if [[ $samples_collected -gt 0 ]]; then
            avg_time=$((total_time / samples_collected))
        fi
        
        case "$format" in
            "json")
                jq -n \
                    --argjson samples "$samples_collected" \
                    --argjson total "$total_time" \
                    --argjson min "$min_time" \
                    --argjson max "$max_time" \
                    --argjson avg "$avg_time" \
                    '{
                        samples: $samples,
                        total_time_ms: $total,
                        min_time_ms: $min,
                        max_time_ms: $max,
                        avg_time_ms: $avg,
                        plugin_version: "1.0.0"
                    }'
                ;;
            "summary")
                echo "Response Time Statistics:"
                echo "  Samples: $samples_collected"
                echo "  Average: ${avg_time}ms"
                echo "  Min: ${min_time}ms"
                echo "  Max: ${max_time}ms"
                echo "  Total: ${total_time}ms"
                ;;
        esac
    else
        echo '{"error": "State database not available"}'
    fi
}

# Analyze performance trends
grpc_response_time_analyze_performance() {
    local analysis_type="${1:-basic}"
    
    case "$analysis_type" in
        "basic")
            grpc_response_time_get_statistics "summary"
            ;;
        "detailed")
            echo "=== Detailed Performance Analysis ==="
            grpc_response_time_get_statistics "summary"
            
            echo ""
            echo "Thresholds:"
            echo "  Warning: ${RESPONSE_TIME_WARNING_MS}ms"
            echo "  Critical: ${RESPONSE_TIME_CRITICAL_MS}ms"
            
            # Check if we have state database access for trend analysis
            if command -v state_db_get >/dev/null 2>&1; then
                local max_time
                max_time=$(state_db_get "response_time.max_time" || echo "0")
                local avg_time
                local samples_collected
                samples_collected=$(state_db_get "response_time.samples_collected" || echo "0")
                local total_time
                total_time=$(state_db_get "response_time.total_time" || echo "0")
                
                if [[ $samples_collected -gt 0 ]]; then
                    avg_time=$((total_time / samples_collected))
                    
                    echo ""
                    echo "Performance Assessment:"
                    if [[ $max_time -gt $RESPONSE_TIME_CRITICAL_MS ]]; then
                        echo "  Status: ❌ CRITICAL - Peak response time exceeds threshold"
                    elif [[ $avg_time -gt $RESPONSE_TIME_WARNING_MS ]]; then
                        echo "  Status: ⚠️  WARNING - Average response time high"
                    else
                        echo "  Status: ✅ GOOD - Response times within acceptable range"
                    fi
                fi
            fi
            ;;
    esac
}

# Reset response time statistics
grpc_response_time_reset_statistics() {
    log_debug "Resetting response time statistics..."
    
    if command -v state_db_set >/dev/null 2>&1; then
        state_db_set "response_time.samples_collected" "0"
        state_db_set "response_time.total_time" "0"
        state_db_set "response_time.min_time" "999999"
        state_db_set "response_time.max_time" "0"
        
    log_debug "Response time statistics reset successfully"
        return 0
    else
    log_warn "State database not available for reset, using fallback"
        return 1
    fi
}

# Response time event handler
grpc_response_time_event_handler() {
    local event_message="$1"
    
    log_debug "Response time plugin received event: $event_message"
    
    # Handle performance-related events
    # This could be used for:
    # - Real-time performance alerting
    # - Trend analysis and prediction
    # - Adaptive threshold adjustment
    # - Performance regression detection
    
    return 0
}

# gRPC call event handler for automatic response time tracking
grpc_response_time_call_handler() {
    local event_message="$1"
    
    # Extract response time from gRPC call events
    local response_time
    response_time=$(echo "$event_message" | jq -r '.duration // empty' 2>/dev/null)
    local endpoint
    endpoint=$(echo "$event_message" | jq -r '.endpoint // empty' 2>/dev/null)
    
    if [[ -n "$response_time" && "$response_time" != "null" ]]; then
        grpc_response_time_track_response_time "$response_time" "$endpoint"
    fi
    
    return 0
}

# State database helper functions
record_response_time_assertion() {
    local actual_time="$1"
    local expected_time="$2"
    local result="$3"
    
    local assertion_key="response_time_assertion_$(date +%s)"
    GRPCTESTIFY_STATE["${assertion_key}_actual"]="$actual_time"
    GRPCTESTIFY_STATE["${assertion_key}_expected"]="$expected_time"
    GRPCTESTIFY_STATE["${assertion_key}_result"]="$result"
    GRPCTESTIFY_STATE["${assertion_key}_timestamp"]="$(date +%s)"
    
    return 0
}

# Legacy compatibility functions
assert_grpc_response_time() {
    grpc_response_time_evaluate_assertion "$@"
}

evaluate_grpc_response_time() {
    grpc_response_time_evaluate_assertion "$@"
}

# Export functions
export -f grpc_response_time_init grpc_response_time_handler grpc_response_time_evaluate_assertion
export -f extract_response_time evaluate_response_time grpc_response_time_track_response_time
export -f track_response_time_sample grpc_response_time_get_statistics grpc_response_time_analyze_performance
export -f grpc_response_time_reset_statistics grpc_response_time_event_handler grpc_response_time_call_handler
export -f record_response_time_assertion assert_grpc_response_time evaluate_grpc_response_time
