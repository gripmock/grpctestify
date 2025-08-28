#!/bin/bash

# validation.sh - Input validation utilities
# Simple, clear validation functions



validate_address() {
    local address="$1"
    # Validate address format: hostname:port (e.g., localhost:4770, api.example.com:443)
    if ! echo "$address" | grep -qE '^[a-zA-Z0-9.-]+:[0-9]+$'; then
        handle_error ${ERROR_VALIDATION:-7} "Invalid ADDRESS format: $address" "validate_address"
        return ${ERROR_VALIDATION:-7}
    fi
    return 0
}

validate_json() {
    local json="$1"
    local context="$2"
    
    if ! echo "$json" | jq empty 2>/dev/null; then
        handle_error ${ERROR_VALIDATION:-7} "Invalid JSON in $context section" "validate_json"
        return ${ERROR_VALIDATION:-7}
    fi
    return 0
}

validate_file_exists() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        handle_error ${ERROR_FILE_NOT_FOUND:-3} "File not found: $file" "validate_file_exists"
        return ${ERROR_FILE_NOT_FOUND:-3}
    fi
    return 0
}

validate_directory_exists() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        log error "Directory not found: $dir"
        return 1
    fi
    return 0
}

validate_positive_integer() {
    local value="$1"
    local name="$2"
    
    if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
        echo "Error: $name must be a positive integer, got: $value" >&2
        return 1
    fi
    return 0
}

validate_endpoint() {
    local endpoint="$1"
    # Validate gRPC endpoint format: package.Service/Method (e.g., grpc.health.v1.Health/Check)
    if ! echo "$endpoint" | grep -qE '^[a-zA-Z0-9.]+/[a-zA-Z0-9]+$'; then
        log error "Invalid ENDPOINT format: $endpoint"
        return 1
    fi
    return 0
}

validate_parallel_jobs() {
    local jobs="$1"
    validate_positive_integer "$jobs" "Parallel jobs"
}

validate_progress_mode() {
    local mode="$1"
    case "$mode" in
        "none"|"dots")
            return 0
            ;;
        *)
            log error "Invalid progress mode: $mode (must be none or dots)"
            return 1
            ;;
    esac
}

validate_test_file() {
    local file="$1"
    
    if [[ ! -e "$file" ]]; then
        log error "Test file does not exist: $file"
        return 1
    fi
    
    if [[ ! "$file" =~ \.gctf$ ]]; then
        log error "Test file must have .gctf extension: $file"
        return 1
    fi
    
    return 0
}

# Dependencies are now handled by bashly configuration
