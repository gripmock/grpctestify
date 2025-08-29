#!/bin/bash

# Enhanced Asserts Plugin for grpctestify
# Handles advanced assertion types including indexed assertions
# shellcheck disable=SC2155 # Declare and assign separately - many simple variable assignments

# Function to register Enhanced Asserts plugin
register_asserts_plugin() {
    register_plugin "asserts" "evaluate_enhanced_asserts" "Enhanced assertions with inline types" "internal"
}

# Function to evaluate enhanced assertions
evaluate_enhanced_asserts() {
    local test_file="$1"
    local responses_array="$2"
    
    # Extract ASSERTS section using existing utility
    local asserts_section
    asserts_section="$(extract_asserts "$test_file" "ASSERTS")"
    
    if [[ -z "$asserts_section" ]]; then
        return 0  # No asserts to evaluate
    fi
    
    # Process enhanced assertions
    process_enhanced_asserts "$asserts_section" "$responses_array"
}

# Function to process enhanced assertions with inline types
process_enhanced_asserts() {
    local asserts_section="$1"
    local responses_array="$2"
    local line_number=0
    
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Process different assertion types
        if [[ "$line" =~ ^\[([0-9*]+)\][[:space:]]+(.+)$ ]]; then
            # Indexed assertion: [index] assertion
            process_indexed_assertion "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$responses_array" "$line_number"
        elif [[ "$line" =~ ^@([a-zA-Z_][a-zA-Z0-9_]*):(.+)$ ]]; then
            # Plugin assertion: @plugin_name:args
            process_plugin_assertion "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$responses_array" "$line_number"
        # type:typename syntax removed - use @typename() plugins instead
        elif [[ "$line" =~ ^\[([0-9*]+)\]@([a-zA-Z_][a-zA-Z0-9_]*):(.+)$ ]]; then
            # Indexed plugin assertion: [index]@plugin_name:args
            process_indexed_plugin_assertion "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "$responses_array" "$line_number"
        # [index]type:typename syntax removed - use @typename() plugins instead
        else
            # Regular jq assertion
            process_regular_assertion "$line" "$responses_array" "$line_number"
        fi
    done <<< "$asserts_section"
}

# Function to process indexed assertion
process_indexed_assertion() {
    local index="$1"
    local assertion="$2"
    local responses_array="$3"
    local line_number="$4"
    
    if [[ "$index" == "*" ]]; then
        # Apply to all responses
        local response_count=$(echo "$responses_array" | jq 'length')
        for i in $(seq 0 $((response_count - 1))); do
            local response=$(echo "$responses_array" | jq -r ".[$i]")
            if ! evaluate_single_assertion "$assertion" "$response"; then
                echo "ASSERTS failed at line $line_number (response $((i+1))): $assertion"
                echo "Response: $response"
                return 1
            fi
        done
    else
        # Apply to specific response (1-based index)
        local response_index=$((index - 1))
        local response_count=$(echo "$responses_array" | jq 'length')
        
        if [[ $response_index -ge 0 && $response_index -lt $response_count ]]; then
            local response=$(echo "$responses_array" | jq -r ".[$response_index]")
            if ! evaluate_single_assertion "$assertion" "$response"; then
                echo "ASSERTS failed at line $line_number (response $((response_index+1))): $assertion"
                echo "Response: $response"
                return 1
            fi
        else
            echo "ASSERTS failed at line $line_number: Invalid index $index (available: 1-$response_count)"
            return 1
        fi
    fi
}

# Function to process plugin assertion
process_plugin_assertion() {
    local plugin_name="$1"
    local args="$2"
    local responses_array="$3"
    local line_number="$4"
    
    # Get the first response for plugin evaluation
    local response=$(echo "$responses_array" | jq -r '.[0]')
    
    if ! execute_plugin_assertion "$plugin_name" "$response" "$args"; then
        echo "ASSERTS failed at line $line_number: @$plugin_name:$args"
        echo "Response: $response"
        return 1
    fi
}

# type:typename functions removed - use @typename() plugins instead

# Function to process indexed plugin assertion
process_indexed_plugin_assertion() {
    local index="$1"
    local plugin_name="$2"
    local args="$3"
    local responses_array="$4"
    local line_number="$5"
    
    if [[ "$index" == "*" ]]; then
        # Apply to all responses
        local response_count=$(echo "$responses_array" | jq 'length')
        for i in $(seq 0 $((response_count - 1))); do
            local response=$(echo "$responses_array" | jq -r ".[$i]")
            if ! execute_plugin_assertion "$plugin_name" "$response" "$args"; then
                echo "ASSERTS failed at line $line_number (response $((i+1))): [$index]@$plugin_name:$args"
                echo "Response: $response"
                return 1
            fi
        done
    else
        # Apply to specific response (1-based index)
        local response_index=$((index - 1))
        local response_count=$(echo "$responses_array" | jq 'length')
        
        if [[ $response_index -ge 0 && $response_index -lt $response_count ]]; then
            local response=$(echo "$responses_array" | jq -r ".[$response_index]")
            if ! execute_plugin_assertion "$plugin_name" "$response" "$args"; then
                echo "ASSERTS failed at line $line_number (response $((response_index+1))): [$index]@$plugin_name:$args"
                echo "Response: $response"
                return 1
            fi
        else
            echo "ASSERTS failed at line $line_number: Invalid index $index (available: 1-$response_count)"
            return 1
        fi
    fi
}

# process_indexed_type_assertion removed - use @typename() plugins instead

# Function to process regular assertion
process_regular_assertion() {
    local assertion="$1"
    local responses_array="$2"
    local line_number="$3"
    
    # Get the first response for regular assertion
    local response=$(echo "$responses_array" | jq -r '.[0]')
    
    if ! evaluate_single_assertion "$assertion" "$response"; then
        echo "ASSERTS failed at line $line_number: $assertion"
        echo "Response: $response"
        return 1
    fi
}

# Function to evaluate single assertion
evaluate_single_assertion() {
    local assertion="$1"
    local response="$2"
    
    # Check if it's a jq filter
    if echo "$response" | jq -e "$assertion" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to execute plugin assertion
execute_plugin_assertion() {
    local plugin_name="$1"
    local response="$2"
    local args="$3"
    
    # Get plugin function
    local plugin_func=$(get_plugin_function "$plugin_name")
    if [[ -n "$plugin_func" ]]; then
        if $plugin_func "$response" "$args"; then
            return 0
        else
            return 1
        fi
    else
        echo "Plugin $plugin_name not found"
        return 1
    fi
}

# evaluate_type_assertion removed - use @typename() plugins instead

# Export functions
export -f register_asserts_plugin
export -f evaluate_enhanced_asserts
export -f process_enhanced_asserts
export -f process_indexed_assertion
export -f process_plugin_assertion
export -f process_indexed_plugin_assertion
export -f process_regular_assertion
export -f evaluate_single_assertion
export -f execute_plugin_assertion

# Register the plugin
register_asserts_plugin
