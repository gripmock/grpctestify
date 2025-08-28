#!/bin/bash

# assertions.sh - Response comparison logic
# Simple, clear assertion functions



extract_asserts() {
    local test_file="$1"
    local section_name="$2"
    
    extract_section_awk "$test_file" "$section_name"
}

evaluate_asserts() {
    local response="$1"
    local asserts_file="$2"
    local response_index="$3"
    
    local line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Evaluate jq filter
        if ! echo "$response" | jq -e "$line" >/dev/null 2>&1; then
            echo "ASSERTS block failed at line $line_number: $line"
            echo "Response: $response"
            return 1
        fi
    done < "$asserts_file"
    
    return 0
}



