#!/bin/bash

# response_comparison.sh - Response comparison utilities
# shellcheck disable=SC2155 # Declare and assign separately - many simple variable assignments
# Handles comparison of gRPC responses with various options

# Compare responses with advanced options
compare_responses() {
    local expected="$1"
    local actual="$2"
    local options="${3:-}"
    
    # Parse options if provided
    local type="exact"
    local tolerance=""
    local tol_percent=""
    local partial="false"
    local redact=""
    local unordered_arrays="false"
    local unordered_arrays_paths=""
    
    if [[ -n "$options" ]]; then
        while IFS='=' read -r key value; do
            case "$key" in
                "type") type="$value" ;;
                "tolerance"*) tolerance="$key=$value" ;;
                "tol_percent"*) tol_percent="$key=$value" ;;
                "partial") 
                    # shellcheck disable=SC2034  # Reserved for future partial matching feature
                    partial="$value" ;;
                "redact") redact="$value" ;;
                "unordered_arrays") unordered_arrays="$value" ;;
                "unordered_arrays_paths") unordered_arrays_paths="$value" ;;
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
        if apply_tolerance_comparison "$expected" "$actual" "$tolerance"; then
            return 0
        fi
    fi
    
    # Apply percentage tolerance if specified
    if [[ -n "$tol_percent" ]]; then
        if apply_percentage_tolerance_comparison "$expected" "$actual" "$tol_percent"; then
            return 0
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
            if [[ "$actual" == "$expected" ]]; then
                return 0
            else
                return 1
            fi
            ;;
        "partial")
            # Check if expected is a subset of actual
            if command -v jq >/dev/null 2>&1; then
                if echo "$actual" | jq . >/dev/null 2>&1 && echo "$expected" | jq . >/dev/null 2>&1; then
                    # Use jq to check if expected is contained in actual
                    if jq -n --argjson actual "$actual" --argjson expected "$expected" \
                        '$actual | contains($expected)' | grep -q true; then
                        return 0
                    else
                        return 1
                    fi
                fi
            fi
            
            # Fallback to string containment
            if [[ "$actual" == *"$expected"* ]]; then
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
        local expected_val="$(echo "$expected" | jq -r "$path // empty" 2>/dev/null)"
        local actual_val="$(echo "$actual" | jq -r "$path // empty" 2>/dev/null)"
        
        # Check if both values are numeric
        if [[ "$expected_val" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$actual_val" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
            # Calculate absolute difference
            local diff="$(echo "$expected_val - $actual_val" | bc -l 2>/dev/null || echo "0")"
            local abs_diff="${diff#-}"
            
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
        local expected_val="$(echo "$expected" | jq -r "$path // empty" 2>/dev/null)"
        local actual_val="$(echo "$actual" | jq -r "$path // empty" 2>/dev/null)"
        
        # Check if both values are numeric
        if [[ "$expected_val" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$actual_val" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
            # Calculate percentage difference
            local diff="$(echo "$expected_val - $actual_val" | bc -l 2>/dev/null || echo "0")"
            local abs_diff="${diff#-}"
            local percent_diff="$(echo "scale=6; $abs_diff * 100 / $expected_val" | bc -l 2>/dev/null || echo "0")"
            
            # Check if percentage difference is within tolerance
            if (( $(echo "$percent_diff <= $tolerance_percent" | bc -l) )); then
                return 0
            else
                log debug "Percentage tolerance comparison failed for path $path: expected=$expected_val, actual=$actual_val, percent_diff=$percent_diff%, tolerance=$tolerance_percent%"
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
