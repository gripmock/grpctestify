#!/bin/bash

# TLS Plugin for grpctestify
# Handles TLS/mTLS configuration and grpcurl flag generation
# Thread-safe implementation using local variables

# Function to register TLS plugin
register_tls_plugin() {
    register_plugin "tls" "parse_tls_section" "TLS/mTLS configuration handler" "internal"
}

# Function to parse TLS section from .gctf file
parse_tls_section() {
    local test_file="$1"
    local tls_section=""
    local in_tls_section=false
    
    # Parse TLS section from file
    while IFS= read -r line; do
        if [[ "$line" =~ ^---[[:space:]]*TLS[[:space:]]*--- ]]; then
            in_tls_section=true
            continue
        elif [[ "$line" =~ ^---[[:space:]]*[A-Z]+[[:space:]]*--- ]]; then
            in_tls_section=false
            continue
        elif [[ "$in_tls_section" == true ]]; then
            tls_section+="$line"$'\n'
        fi
    done < "$test_file"
    
    if [[ -n "$tls_section" ]]; then
        process_tls_configuration "$tls_section" "$test_file"
    else
        # Default behavior: TLS with insecure
        echo "default-insecure-tls|-insecure"
    fi
}

# Function to process TLS configuration
process_tls_configuration() {
    local config="$1"
    local test_file="$2"
    local mode=""
    local insecure=""
    local cacert=""
    local cert=""
    local key=""
    local servername=""
    local authority=""
    
    # Parse key=value pairs
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key_name="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            case "$key_name" in
                "mode")
                    mode="$value"
                    ;;
                "insecure")
                    insecure="$value"
                    ;;
                "cacert")
                    cacert="$value"
                    ;;
                "cert")
                    cert="$value"
                    ;;
                "key")
                    key="$value"
                    ;;
                "servername")
                    servername="$value"
                    ;;
                "authority")
                    authority="$value"
                    ;;
            esac
        fi
    done <<< "$config"
    
    # Determine mode if not specified
    if [[ -z "$mode" ]]; then
        if [[ -n "$cert" || -n "$key" ]]; then
            mode="mtls"
        else
            mode="tls"
        fi
    fi
    
    # Validate configuration
    validate_tls_configuration "$mode" "$insecure" "$cert" "$key"
    
    # Generate TLS flags
    generate_tls_flags "$mode" "$insecure" "$cacert" "$cert" "$key" "$servername" "$authority" "$test_file"
}

# Function to validate TLS configuration
validate_tls_configuration() {
    local mode="$1"
    local insecure="$2"
    local cert="$3"
    local key="$4"
    
    # Check for invalid combinations
    if [[ "$mode" == "plaintext" && ("$insecure" == "true" || "$insecure" == "false" || -n "$cert" || -n "$key") ]]; then
        error "TLS options not allowed with mode=plaintext"
        exit 1
    fi
    
    # Check for mTLS without cert/key
    if [[ "$mode" == "mtls" && (-z "$cert" || -z "$key") ]]; then
        error "mTLS mode requires both cert and key"
        exit 1
    fi
}

# Function to generate TLS flags
generate_tls_flags() {
    local mode="$1"
    local insecure="$2"
    local cacert="$3"
    local cert="$4"
    local key="$5"
    local servername="$6"
    local authority="$7"
    local test_file="$8"
    
    local tls_flags=""
    
    case "$mode" in
        "plaintext")
            tls_flags="-plaintext"
            ;;
        "tls"|"mtls")
            # Add TLS flags (no -plaintext)
            if [[ "$insecure" == "true" ]]; then
                tls_flags+=" -insecure"
            fi
            
            # Handle certificates - resolve paths (support ENV variables)
            if [[ -n "$cacert" ]]; then
                local resolved_cacert=$(resolve_tls_path "$cacert")
                tls_flags+=" -cacert $resolved_cacert"
            fi
            
            if [[ -n "$cert" ]]; then
                local resolved_cert=$(resolve_tls_path "$cert")
                tls_flags+=" -cert $resolved_cert"
            fi
            
            if [[ -n "$key" ]]; then
                local resolved_key=$(resolve_tls_path "$key")
                tls_flags+=" -key $resolved_key"
            fi
            
            if [[ -n "$servername" ]]; then
                tls_flags+=" -servername $servername"
            fi
            
            if [[ -n "$authority" ]]; then
                tls_flags+=" -authority $authority"
            fi
            ;;
    esac
    
    # Trim leading space
    tls_flags=$(echo "$tls_flags" | sed 's/^[[:space:]]*//')
    
    # Return mode and flags as pipe-separated string
    echo "$mode|$tls_flags"
}

# Function to resolve certificate/key paths (support ENV variables)
resolve_tls_path() {
    local path="$1"
    
    # If path starts with $, treat as ENV variable
    if [[ "$path" =~ ^\$([A-Z_][A-Z0-9_]*) ]]; then
        local env_var="${BASH_REMATCH[1]}"
        if [[ -n "${!env_var}" ]]; then
            # Check if it's a file path or inline content
            if [[ -f "${!env_var}" ]]; then
                echo "${!env_var}"
            else
                # Treat as inline PEM content, create temp file
                create_temp_pem_from_env "$env_var"
            fi
        else
            error "Environment variable $env_var is not set"
            exit 1
        fi
    else
        echo "$path"
    fi
}

# Function to create temporary PEM file from ENV variable
create_temp_pem_from_env() {
    local env_var="$1"
    local temp_file=$(mktemp)
    
    echo "${!env_var}" > "$temp_file"
    
    # Register cleanup on exit
    trap "rm -f '$temp_file'" EXIT
    
    echo "$temp_file"
}

# Function to get TLS summary for verbose logging
get_tls_summary() {
    local tls_result="$1"
    local mode=$(echo "$tls_result" | cut -d'|' -f1)
    local flags=$(echo "$tls_result" | cut -d'|' -f2)
    local flag_count=$(echo "$flags" | wc -w)
    echo "mode=$mode, flags=$flag_count"
}

# Function to get TLS flags for grpcurl
get_tls_flags() {
    local tls_result="$1"
    echo "$tls_result" | cut -d'|' -f2
}

# Export functions
export -f register_tls_plugin
export -f parse_tls_section
export -f process_tls_configuration
export -f validate_tls_configuration
export -f generate_tls_flags
export -f resolve_tls_path
export -f create_temp_pem_from_env
export -f get_tls_summary
export -f get_tls_flags

# Register the plugin
register_tls_plugin