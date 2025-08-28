#!/bin/bash

# parser.sh - Test file parsing
# Simple, efficient parsing functions

extract_section() {
    local test_file="$1"
    local section="$2"
    
    extract_section_awk "$test_file" "$section" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

parse_test_file() {
    local test_file="$1"
    
    # Extract all sections
    local address
    address="$(extract_section "$test_file" "ADDRESS")"
    local endpoint
    endpoint="$(extract_section "$test_file" "ENDPOINT")"
    local request
    request="$(extract_section "$test_file" "REQUEST")"
    local response
    response="$(extract_section "$test_file" "RESPONSE")"
    local error
    error="$(extract_section "$test_file" "ERROR")"
    local headers
    headers="$(extract_section "$test_file" "HEADERS")"
    local request_headers
    request_headers="$(extract_section "$test_file" "REQUEST_HEADERS")"
    # RESPONSE_HEADERS and RESPONSE_TRAILERS removed - use @header()/@trailer() assertions instead
    
    # Set defaults for backward compatibility
    if [[ -z "$address" ]]; then
        # Use environment variable if available, otherwise use default
        address="${GRPCTESTIFY_ADDRESS:-localhost:4770}"
    fi
    
    if [[ -z "$endpoint" ]]; then
        log error "Missing ENDPOINT section in $test_file"
        return 1
    fi
    
    # RESPONSE is optional if ERROR is present (backward compatibility)
    # Both can be empty for some test cases
    
    # Return structured data using jq for proper JSON escaping
    jq -n \
        --arg address "$address" \
        --arg endpoint "$endpoint" \
        --arg request "$request" \
        --arg response "$response" \
        --arg error "$error" \
        --arg headers "$headers" \
        --arg request_headers "$request_headers" \
        '{
            address: $address,
            endpoint: $endpoint,
            request: $request,
            response: $response,
            error: $error,
            headers: $headers,
            request_headers: $request_headers
        }'
}

parse_inline_options() {
    local header="$1"
    
    # Extract options from header: --- RESPONSE key=value ... ---
    if [[ "$header" =~ ---[[:space:]]*RESPONSE[[:space:]]+(.+)[[:space:]]*--- ]]; then
        local options_str="${BASH_REMATCH[1]}"
        
        # Simple approach: split by spaces and process each token
        local tokens=()
        local in_quotes=false
        local current_token=""
        
        # Tokenize the options string, respecting quotes
        for ((i=0; i<${#options_str}; i++)); do
            local char="${options_str:$i:1}"
            
            if [[ "$char" == '"' ]]; then
                in_quotes=$((!in_quotes))
                current_token+="$char"
            elif [[ "$char" == ' ' && $in_quotes -eq 0 ]]; then
                if [[ -n "$current_token" ]]; then
                    tokens+=("$current_token")
                    current_token=""
                fi
            else
                current_token+="$char"
            fi
        done
        
        # Add the last token if any
        if [[ -n "$current_token" ]]; then
            tokens+=("$current_token")
        fi
        
        # Process each token as key=value pair or standalone flags
        for token in "${tokens[@]}"; do
            if [[ "$token" =~ ^([a-zA-Z_][a-zA-Z0-9_]*(\[[^\]]*\])?)=(.*)$ ]]; then
                # Key=value format
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[3]}"
                
                # Remove quotes from value
                value="${value%\"}"
                value="${value#\"}"
                
                echo "$key=$value"
            elif [[ "$token" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)$ ]]; then
                # Standalone flag (e.g., with_asserts)
                echo "${BASH_REMATCH[1]}=true"
            fi
        done
    fi
}
