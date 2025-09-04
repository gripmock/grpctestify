#!/bin/bash

# grpc_tls.sh - Enhanced TLS/mTLS Security Plugin with microkernel integration
# Migrated from legacy grpc_tls.sh with microkernel components

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
export PLUGIN_TLS_VERSION="1.0.0"
export PLUGIN_TLS_DESCRIPTION="Enhanced TLS/mTLS security with microkernel integration"
export PLUGIN_TLS_AUTHOR="grpctestify-team"
export PLUGIN_TLS_TYPE="security"

# TLS configuration constants
readonly TLS_MODE_PLAINTEXT="plaintext"
readonly TLS_MODE_TLS="tls"
readonly TLS_MODE_MTLS="mtls"
readonly TLS_MODE_INSECURE="insecure"

# Initialize TLS plugin
grpc_tls_init() {
    log_debug "Initializing TLS plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    log_warn "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "tls" "grpc_tls_handler" "$PLUGIN_TLS_DESCRIPTION" "internal" ""
    
    # Create resource pool for TLS operations
    pool_create "tls_operations" 2
    
    # Subscribe to TLS-related events
    event_subscribe "tls" "tls.*" "grpc_tls_event_handler"
    
    log_debug "TLS plugin initialized successfully"
    return 0
}

# Main TLS plugin handler
grpc_tls_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "parse_section")
            grpc_tls_parse_section "${args[@]}"
            ;;
        "generate_flags")
            grpc_tls_generate_flags "${args[@]}"
            ;;
        "validate_config")
            grpc_tls_validate_config "${args[@]}"
            ;;
        "validate_certificates")
            grpc_tls_validate_certificates "${args[@]}"
            ;;
        *)
    log_error "Unknown TLS command: $command"
            return 1
            ;;
    esac
}

# Parse TLS section from .gctf file with microkernel integration
grpc_tls_parse_section() {
    local test_file="$1"
    
    if [[ -z "$test_file" || ! -f "$test_file" ]]; then
    log_error "grpc_tls_parse_section: valid test_file required"
        return 1
    fi
    
    log_debug "Parsing TLS section from: $test_file"
    
    # Publish TLS parsing start event
    local parse_metadata
    parse_metadata=$(cat << EOF
{
  "test_file": "$test_file",
  "parser": "tls",
  "start_time": $(date +%s)
}
EOF
)
    event_publish "tls.parsing.start" "$parse_metadata" "$EVENT_PRIORITY_NORMAL" "tls"
    
    # Begin transaction for TLS parsing
    local tx_id
    tx_id=$(state_db_begin_transaction "tls_parsing_$(basename "$test_file")_$$")
    
    # Acquire resource for TLS parsing
    local resource_token
    resource_token=$(pool_acquire "tls_operations" 30)
    if [[ $? -ne 0 ]]; then
    log_error "Failed to acquire resource for TLS parsing"
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
    
    # Extract TLS section
    local tls_section
    tls_section=$(extract_tls_section "$test_file")
    local parsing_result=0
    
    if [[ -n "$tls_section" ]]; then
        local tls_config
        if tls_config=$(process_tls_configuration "$tls_section" "$test_file"); then
    log_debug "TLS configuration parsed successfully"
            
            # Store TLS configuration in state
            state_db_atomic "record_tls_config" "$test_file" "SUCCESS" "$tls_config"
            
            # Publish success event
            event_publish "tls.parsing.success" "{\"test_file\":\"$test_file\"}" "$EVENT_PRIORITY_NORMAL" "tls"
            
            # Output TLS configuration
            echo "$tls_config"
        else
            parsing_result=1
    log_error "TLS configuration parsing failed"
            
            # Store parsing failure
            state_db_atomic "record_tls_config" "$test_file" "FAILED" ""
            
            # Publish failure event
            event_publish "tls.parsing.failure" "{\"test_file\":\"$test_file\"}" "$EVENT_PRIORITY_HIGH" "tls"
        fi
    else
        # Default TLS configuration
        local default_config
        default_config=$(jq -n '{mode: "plaintext", flags: ["-plaintext"]}')
        
    log_debug "No TLS section found, using default plaintext configuration"
        echo "$default_config"
    fi
    
    # Release resource
    pool_release "tls_operations" "$resource_token"
    
    # Commit transaction
    state_db_commit_transaction "$tx_id"
    
    return $parsing_result
}

# Extract TLS section from .gctf file
extract_tls_section() {
    local test_file="$1"
    local tls_section=""
    local in_tls_section=false
    
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
    
    echo "$tls_section"
}

# Process TLS configuration with enhanced validation
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
    local tls_flags=()
    
    # Parse configuration line by line
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Parse key=value pairs
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes from value
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            
            case "$key" in
                "mode")
                    mode="$value"
                    ;;
                "insecure")
                    insecure="$value"
                    ;;
                "cacert"|"ca_cert"|"ca-cert")
                    cacert="$value"
                    ;;
                "cert"|"client_cert"|"client-cert")
                    cert="$value"
                    ;;
                "key"|"client_key"|"client-key")
                    key="$value"
                    ;;
                "servername"|"server_name"|"server-name")
                    servername="$value"
                    ;;
                "authority")
                    authority="$value"
                    ;;
                *)
    log_warn "Unknown TLS configuration key: $key"
                    ;;
            esac
        fi
    done <<< "$config"
    
    # Generate TLS flags based on mode
    case "$mode" in
        "$TLS_MODE_PLAINTEXT"|"")
            tls_flags+=("-plaintext")
            mode="$TLS_MODE_PLAINTEXT"
            ;;
        "$TLS_MODE_TLS")
            if [[ "$insecure" == "true" ]]; then
                tls_flags+=("-insecure")
            fi
            [[ -n "$cacert" ]] && tls_flags+=("-cacert" "$cacert")
            [[ -n "$servername" ]] && tls_flags+=("-servername" "$servername")
            [[ -n "$authority" ]] && tls_flags+=("-authority" "$authority")
            ;;
        "$TLS_MODE_MTLS")
            [[ -n "$cacert" ]] && tls_flags+=("-cacert" "$cacert")
            [[ -n "$cert" ]] && tls_flags+=("-cert" "$cert")
            [[ -n "$key" ]] && tls_flags+=("-key" "$key")
            [[ -n "$servername" ]] && tls_flags+=("-servername" "$servername")
            [[ -n "$authority" ]] && tls_flags+=("-authority" "$authority")
            ;;
        "$TLS_MODE_INSECURE")
            tls_flags+=("-insecure")
            mode="$TLS_MODE_TLS"
            ;;
        *)
    log_error "Unknown TLS mode: $mode"
            return 1
            ;;
    esac
    
    # Validate certificate files if specified
    if ! validate_certificate_files "$cacert" "$cert" "$key"; then
    log_error "TLS certificate validation failed"
        return 1
    fi
    
    # Build comprehensive TLS configuration JSON
    jq -n \
        --arg mode "$mode" \
        --argjson flags "$(printf '%s\n' "${tls_flags[@]}" | jq -R . | jq -s .)" \
        --arg cacert "$cacert" \
        --arg cert "$cert" \
        --arg key "$key" \
        --arg servername "$servername" \
        --arg authority "$authority" \
        --arg insecure "$insecure" \
        --arg test_file "$test_file" \
        '{
            mode: $mode,
            flags: $flags,
            certificates: {
                ca_cert: ($cacert // null),
                client_cert: ($cert // null),
                client_key: ($key // null)
            },
            options: {
                server_name: ($servername // null),
                authority: ($authority // null),
                insecure: ($insecure == "true")
            },
            metadata: {
                test_file: $test_file,
                parsed_at: now,
                plugin: "tls"
            }
        }'
}

# Generate TLS flags for grpcurl command
grpc_tls_generate_flags() {
    local tls_config="$1"
    
    if [[ -z "$tls_config" ]]; then
        echo '[]'
        return 0
    fi
    
    # Extract flags from TLS configuration
    echo "$tls_config" | jq -r '.flags[]?' 2>/dev/null || echo ""
}

# Validate TLS configuration
grpc_tls_validate_config() {
    local tls_config="$1"
    
    if [[ -z "$tls_config" ]]; then
    log_error "TLS configuration is empty"
        return 1
    fi
    
    # Validate JSON structure
    if ! echo "$tls_config" | jq . >/dev/null 2>&1; then
    log_error "Invalid JSON in TLS configuration"
        return 1
    fi
    
    # Validate required fields
    local mode
    mode=$(echo "$tls_config" | jq -r '.mode // ""')
    if [[ -z "$mode" ]]; then
    log_error "Missing TLS mode in configuration"
        return 1
    fi
    
    # Validate mode-specific requirements
    case "$mode" in
        "$TLS_MODE_MTLS")
            local cert
            cert=$(echo "$tls_config" | jq -r '.certificates.client_cert // ""')
            local key
            key=$(echo "$tls_config" | jq -r '.certificates.client_key // ""')
            
            if [[ -z "$cert" || -z "$key" ]]; then
    log_error "mTLS mode requires both client certificate and key"
                return 1
            fi
            ;;
        "$TLS_MODE_PLAINTEXT"|"$TLS_MODE_TLS"|"$TLS_MODE_INSECURE")
            # Valid modes
            ;;
        *)
    log_error "Invalid TLS mode: $mode"
            return 1
            ;;
    esac
    
    log_debug "TLS configuration validation passed"
    return 0
}

# Validate certificate files
validate_certificate_files() {
    local cacert="$1"
    local cert="$2"
    local key="$3"
    
    # Validate CA certificate
    if [[ -n "$cacert" ]]; then
        if [[ ! -f "$cacert" ]]; then
    log_error "CA certificate file not found: $cacert"
            return 1
        fi
        if [[ ! -r "$cacert" ]]; then
    log_error "CA certificate file not readable: $cacert"
            return 1
        fi
    fi
    
    # Validate client certificate
    if [[ -n "$cert" ]]; then
        if [[ ! -f "$cert" ]]; then
    log_error "Client certificate file not found: $cert"
            return 1
        fi
        if [[ ! -r "$cert" ]]; then
    log_error "Client certificate file not readable: $cert"
            return 1
        fi
    fi
    
    # Validate client key
    if [[ -n "$key" ]]; then
        if [[ ! -f "$key" ]]; then
    log_error "Client key file not found: $key"
            return 1
        fi
        if [[ ! -r "$key" ]]; then
    log_error "Client key file not readable: $key"
            return 1
        fi
    fi
    
    return 0
}

# Validate certificates using openssl (if available)
grpc_tls_validate_certificates() {
    local tls_config="$1"
    
    if [[ -z "$tls_config" ]]; then
        return 0
    fi
    
    # Check if openssl is available
    if ! command -v openssl >/dev/null 2>&1; then
    log_debug "openssl not available, skipping certificate validation"
        return 0
    fi
    
    # Extract certificate paths
    local cacert
    cacert=$(echo "$tls_config" | jq -r '.certificates.ca_cert // ""')
    local cert
    cert=$(echo "$tls_config" | jq -r '.certificates.client_cert // ""')
    local key
    key=$(echo "$tls_config" | jq -r '.certificates.client_key // ""')
    
    # Validate CA certificate
    if [[ -n "$cacert" && -f "$cacert" ]]; then
        if ! openssl x509 -in "$cacert" -noout -text >/dev/null 2>&1; then
    log_error "Invalid CA certificate format: $cacert"
            return 1
        fi
    log_debug "CA certificate validation passed: $cacert"
    fi
    
    # Validate client certificate
    if [[ -n "$cert" && -f "$cert" ]]; then
        if ! openssl x509 -in "$cert" -noout -text >/dev/null 2>&1; then
    log_error "Invalid client certificate format: $cert"
            return 1
        fi
    log_debug "Client certificate validation passed: $cert"
    fi
    
    # Validate client key
    if [[ -n "$key" && -f "$key" ]]; then
        if ! openssl rsa -in "$key" -noout -check >/dev/null 2>&1; then
    log_error "Invalid client key format: $key"
            return 1
        fi
    log_debug "Client key validation passed: $key"
    fi
    
    # Validate certificate-key pair
    if [[ -n "$cert" && -n "$key" && -f "$cert" && -f "$key" ]]; then
        local cert_modulus
        cert_modulus=$(openssl x509 -noout -modulus -in "$cert" 2>/dev/null)
        local key_modulus
        key_modulus=$(openssl rsa -noout -modulus -in "$key" 2>/dev/null)
        
        if [[ "$cert_modulus" != "$key_modulus" ]]; then
    log_error "Client certificate and key do not match"
            return 1
        fi
    log_debug "Certificate-key pair validation passed"
    fi
    
    return 0
}

# TLS event handler
grpc_tls_event_handler() {
    local event_message="$1"
    
    log_debug "TLS plugin received event: $event_message"
    
    # Handle TLS-related events
    # This could be used for:
    # - TLS configuration monitoring
    # - Certificate expiration tracking
    # - Security audit logging
    # - Performance impact analysis
    
    return 0
}

# State database helper functions
record_tls_config() {
    local test_file
    test_file="$1"
    local status
    status="$2"
    local config
    config="$3"
    
    # shellcheck disable=SC2034
    local tls_key
    tls_key="tls_config_$(basename "$test_file")"
    # shellcheck disable=SC2034
    GRPCTESTIFY_STATE["${tls_key}_status"]="$status"
    # shellcheck disable=SC2034
    GRPCTESTIFY_STATE["${tls_key}_timestamp"]="$(date +%s)"
    # shellcheck disable=SC2034
    [[ -n "$config" ]] && GRPCTESTIFY_STATE["${tls_key}_config"]="$config"
    
    return 0
}

# Export functions
export -f grpc_tls_init grpc_tls_handler grpc_tls_parse_section
export -f extract_tls_section process_tls_configuration grpc_tls_generate_flags
export -f grpc_tls_validate_config validate_certificate_files grpc_tls_validate_certificates
export -f grpc_tls_event_handler record_tls_config
