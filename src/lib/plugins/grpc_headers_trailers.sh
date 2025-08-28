#!/bin/bash

# grpc_headers_trailers.sh - gRPC headers and trailers assertion plugin
# Usage: @header("name") == "value" or @trailer("name") | test("pattern")



# Function to assert gRPC response headers
assert_grpc_header() {
    local response="$1"
    local header_name="$2"
    local expected_value="$3"
    
    # Extract headers from gRPC response metadata
    # Headers are typically in the response metadata or context
    local actual_value
    if actual_value=$(echo "$response" | jq -r "._headers.\"$header_name\" // .headers.\"$header_name\" // .metadata.\"$header_name\" // empty" 2>/dev/null); then
        if [[ "$actual_value" == "null" || -z "$actual_value" ]]; then
            log error "Header '$header_name' not found in gRPC response"
            return 1
        fi
    else
        log error "Failed to parse gRPC response for header '$header_name'"
        return 1
    fi
    
    # Compare with expected value
    if [[ "$actual_value" == "$expected_value" ]]; then
        log debug "Header '$header_name' matches expected value: $expected_value"
        return 0
    else
        log error "Header '$header_name' mismatch - expected: '$expected_value', actual: '$actual_value'"
        return 1
    fi
}

# Function to assert gRPC response trailers
assert_grpc_trailer() {
    local response="$1"
    local trailer_name="$2"
    local expected_value="$3"
    
    # Extract trailers from gRPC response metadata
    # Trailers are typically in the response metadata or context
    local actual_value
    if actual_value=$(echo "$response" | jq -r "._trailers.\"$trailer_name\" // .trailers.\"$trailer_name\" // .metadata.\"$trailer_name\" // empty" 2>/dev/null); then
        if [[ "$actual_value" == "null" || -z "$actual_value" ]]; then
            log error "Trailer '$trailer_name' not found in gRPC response"
            return 1
        fi
    else
        log error "Failed to parse gRPC response for trailer '$trailer_name'"
        return 1
    fi
    
    # Compare with expected value
    if [[ "$actual_value" == "$expected_value" ]]; then
        log debug "Trailer '$trailer_name' matches expected value: $expected_value"
        return 0
    else
        log error "Trailer '$trailer_name' mismatch - expected: '$expected_value', actual: '$actual_value'"
        return 1
    fi
}



# Function to register gRPC Headers/Trailers plugin
register_grpc_headers_trailers_plugin() {
    register_plugin "header" "assert_grpc_header" "gRPC response header assertion" "internal"
    register_plugin "trailer" "assert_grpc_trailer" "gRPC response trailer assertion" "internal"

}

# Export functions
export -f register_grpc_headers_trailers_plugin
export -f assert_grpc_header
export -f assert_grpc_trailer

