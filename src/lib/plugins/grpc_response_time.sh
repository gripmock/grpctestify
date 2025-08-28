#!/bin/bash

# grpc_response_time.sh - gRPC response time assertion plugin
# Usage: @grpc_response_time:1000 (max milliseconds) or @grpc_response_time:500-2000 (range)

assert_grpc_response_time() {
    local response="$1"
    local expected_time="$2"
    
    # For gRPC, response time is typically measured by the runner and passed as metadata
    # Extract response time from response metadata or context
    local actual_time
    if actual_time=$(echo "$response" | jq -r '._response_time // .response_time // .duration // .time // empty' 2>/dev/null); then
        if [[ "$actual_time" == "null" || -z "$actual_time" ]]; then
            log error "Response time not found in gRPC response metadata"
            return 1
        fi
    else
        log error "Failed to parse gRPC response for response time"
        return 1
    fi
    
    # Parse expected time (support ranges like 500-2000)
    if [[ "$expected_time" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local min_time="${BASH_REMATCH[1]}"
        local max_time="${BASH_REMATCH[2]}"
        
        if [[ $actual_time -ge $min_time && $actual_time -le $max_time ]]; then
            log debug "gRPC response time $actual_time ms is in range $min_time-$max_time ms"
            return 0
        else
            log error "gRPC response time $actual_time ms is not in range $min_time-$max_time ms"
            return 1
        fi
    else
        # Single max time
        if [[ $actual_time -le $expected_time ]]; then
            log debug "gRPC response time $actual_time ms is within limit $expected_time ms"
            return 0
        else
            log error "gRPC response time $actual_time ms exceeds limit $expected_time ms"
            return 1
        fi
    fi
}


