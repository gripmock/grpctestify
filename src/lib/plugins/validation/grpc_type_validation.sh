#!/bin/bash

# grpc_type_validation.sh - Enhanced type validation plugin with microkernel integration
# Migrated from legacy grpc_type_validation.sh with microkernel components

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
readonly PLUGIN_TYPE_VALIDATION_VERSION="1.0.0"
readonly PLUGIN_TYPE_VALIDATION_DESCRIPTION="Enhanced type validation with microkernel integration"
readonly PLUGIN_TYPE_VALIDATION_AUTHOR="grpctestify-team"
readonly PLUGIN_TYPE_VALIDATION_TYPE="validation"

# Type validation configuration
TYPE_VALIDATION_STRICT="${TYPE_VALIDATION_STRICT:-false}"
TYPE_VALIDATION_CACHE_SIZE="${TYPE_VALIDATION_CACHE_SIZE:-1000}"

# Initialize type validation plugin
grpc_type_validation_init() {
    log_debug "Initializing type validation plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    log_warn "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "type_validation" "grpc_type_validation_handler" "$PLUGIN_TYPE_VALIDATION_DESCRIPTION" "internal" ""
    
    # Create resource pool for type validation
    pool_create "type_validation" 3
    
    # Subscribe to validation-related events
    event_subscribe "type_validation" "validation.*" "grpc_type_validation_event_handler"
    
    # Initialize type validation tracking state
    if command -v state_db_set >/dev/null 2>&1; then
        state_db_set "type_validation.plugin_version" "$PLUGIN_TYPE_VALIDATION_VERSION"
        state_db_set "type_validation.validations_performed" "0"
        state_db_set "type_validation.validation_failures" "0"
        state_db_set "type_validation.cache_hits" "0"
        state_db_set "type_validation.cache_misses" "0"
    fi
    
    log_debug "Type validation plugin initialized successfully"
    return 0
}

# Main type validation plugin handler
grpc_type_validation_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "validate_uuid")
            grpc_type_validation_validate_uuid "${args[@]}"
            ;;
        "validate_timestamp")
            grpc_type_validation_validate_timestamp "${args[@]}"
            ;;
        "validate_email")
            grpc_type_validation_validate_email "${args[@]}"
            ;;
        "validate_url")
            grpc_type_validation_validate_url "${args[@]}"
            ;;
        "validate_ip")
            grpc_type_validation_validate_ip "${args[@]}"
            ;;
        "validate_custom_pattern")
            grpc_type_validation_validate_custom_pattern "${args[@]}"
            ;;
        "validate_json_schema")
            grpc_type_validation_validate_json_schema "${args[@]}"
            ;;
        "get_statistics")
            grpc_type_validation_get_statistics "${args[@]}"
            ;;
        *)
    log_error "Unknown type validation command: $command"
            return 1
            ;;
    esac
}

# Enhanced UUID validation with microkernel integration
grpc_type_validation_validate_uuid() {
    local value="$1"
    local version="${2:-any}"
    local validation_context="${3:-{}}"
    
    if [[ -z "$value" ]]; then
    log_error "grpc_type_validation_validate_uuid: value required"
        return 1
    fi
    
    log_debug "Validating UUID: $value (version: $version)"
    
    # Check cache first
    local cache_key="uuid_${value}_${version}"
    if validation_cache_get "$cache_key"; then
        increment_validation_counter "cache_hits"
        return 0
    fi
    
    # Publish validation start event
    local validation_metadata
    validation_metadata=$(cat << EOF
{
  "type": "uuid",
  "value": "$value",
  "version": "$version",
  "plugin": "type_validation",
  "start_time": $(date +%s),
  "context": $validation_context
}
EOF
)
    event_publish "validation.type.start" "$validation_metadata" "$EVENT_PRIORITY_NORMAL" "type_validation"
    
    # Begin transaction for validation
    local tx_id
    tx_id=$(state_db_begin_transaction "uuid_validation_$$")
    
    # Acquire resource for validation
    local resource_token
    resource_token=$(pool_acquire "type_validation" 30)
    if [[ $? -ne 0 ]]; then
    log_error "Failed to acquire resource for UUID validation"
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
    
    # Perform enhanced UUID validation
    local validation_result=0
    if validate_uuid "$value" "$version"; then
    log_debug "UUID validation passed: $value"
        
        # Cache successful validation
        validation_cache_set "$cache_key" "true"
        
        # Record successful validation
        state_db_atomic "record_type_validation" "uuid" "$value" "PASS"
        
        # Publish success event
        event_publish "validation.type.success" "{\"type\":\"uuid\",\"value\":\"$value\"}" "$EVENT_PRIORITY_NORMAL" "type_validation"
    else
        validation_result=1
    log_error "UUID validation failed: $value"
        
        # Cache failed validation
        validation_cache_set "$cache_key" "false"
        
        # Record failed validation
        state_db_atomic "record_type_validation" "uuid" "$value" "FAIL"
        
        # Publish failure event
        event_publish "validation.type.failure" "{\"type\":\"uuid\",\"value\":\"$value\"}" "$EVENT_PRIORITY_HIGH" "type_validation"
    fi
    
    # Update validation statistics
    increment_validation_counter "validations_performed"
    increment_validation_counter "cache_misses"
    if [[ $validation_result -ne 0 ]]; then
        increment_validation_counter "validation_failures"
    fi
    
    # Release resource
    pool_release "type_validation" "$resource_token"
    
    # Commit transaction
    state_db_commit_transaction "$tx_id"
    
    return $validation_result
}

# Enhanced UUID validation implementation
validate_uuid() {
    local value="$1"
    local version="${2:-any}"
    
    # Basic UUID format check (8-4-4-4-12 hex digits)
    if [[ ! "$value" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        return 1
    fi
    
    # Version-specific validation
    if [[ "$version" != "any" ]]; then
        local version_digit="${value:14:1}"
        case "$version" in
            "v1"|"1") [[ "$version_digit" == "1" ]] || return 1 ;;
            "v4"|"4") [[ "$version_digit" == "4" ]] || return 1 ;;
            "v5"|"5") [[ "$version_digit" == "5" ]] || return 1 ;;
            *) return 1 ;;
        esac
    fi
    
    return 0
}

# Enhanced timestamp validation with microkernel integration
grpc_type_validation_validate_timestamp() {
    local value="$1"
    local format="${2:-iso8601}"  # iso8601, rfc3339, unix, custom
    local validation_context="${3:-{}}"
    
    if [[ -z "$value" ]]; then
    log_error "grpc_type_validation_validate_timestamp: value required"
        return 1
    fi
    
    log_debug "Validating timestamp: $value (format: $format)"
    
    # Check cache first
    local cache_key="timestamp_${value}_${format}"
    if validation_cache_get "$cache_key"; then
        increment_validation_counter "cache_hits"
        return 0
    fi
    
    # Perform enhanced timestamp validation
    local validation_result=0
    case "$format" in
        "iso8601")
            validate_iso8601 "$value" || validation_result=1
            ;;
        "rfc3339")
            validate_rfc3339 "$value" || validation_result=1
            ;;
        "unix")
            validate_unix_timestamp "$value" || validation_result=1
            ;;
        *)
    log_error "Unknown timestamp format: $format"
            validation_result=1
            ;;
    esac
    
    # Cache and record result
    if [[ $validation_result -eq 0 ]]; then
        validation_cache_set "$cache_key" "true"
        state_db_atomic "record_type_validation" "timestamp_$format" "$value" "PASS"
    log_debug "Timestamp validation passed: $value"
    else
        validation_cache_set "$cache_key" "false"
        state_db_atomic "record_type_validation" "timestamp_$format" "$value" "FAIL"
    log_error "Timestamp validation failed: $value"
    fi
    
    # Update statistics
    increment_validation_counter "validations_performed"
    increment_validation_counter "cache_misses"
    if [[ $validation_result -ne 0 ]]; then
        increment_validation_counter "validation_failures"
    fi
    
    return $validation_result
}

# ISO 8601 timestamp validation
validate_iso8601() {
    local value="$1"
    local strict="${TYPE_VALIDATION_STRICT:-false}"
    
    if [[ "$strict" == "true" ]]; then
        # Strict ISO 8601: YYYY-MM-DDTHH:MM:SS[.sss]Z or YYYY-MM-DDTHH:MM:SS[.sss]±HH:MM
        [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,3})?(Z|[+-][0-9]{2}:[0-9]{2})$ ]]
    else
        # Relaxed timestamp format
        [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]
    fi
}

# RFC 3339 timestamp validation
validate_rfc3339() {
    local value="$1"
    # RFC 3339: YYYY-MM-DDTHH:MM:SS[.sss]Z or YYYY-MM-DDTHH:MM:SS[.sss]±HH:MM
    [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$ ]]
}

# Unix timestamp validation
validate_unix_timestamp() {
    local value="$1"
    # Unix timestamp (10 digits for seconds, 13 for milliseconds)
    [[ "$value" =~ ^[0-9]{10}([0-9]{3})?$ ]]
}

# Enhanced email validation with microkernel integration
grpc_type_validation_validate_email() {
    local value="$1"
    local validation_context="${2:-{}}"
    
    if [[ -z "$value" ]]; then
    log_error "grpc_type_validation_validate_email: value required"
        return 1
    fi
    
    log_debug "Validating email: $value"
    
    # Check cache first
    local cache_key="email_${value}"
    if validation_cache_get "$cache_key"; then
        increment_validation_counter "cache_hits"
        return 0
    fi
    
    # Perform email validation
    local validation_result=0
    if validate_email "$value"; then
        validation_cache_set "$cache_key" "true"
        state_db_atomic "record_type_validation" "email" "$value" "PASS"
    log_debug "Email validation passed: $value"
    else
        validation_result=1
        validation_cache_set "$cache_key" "false"
        state_db_atomic "record_type_validation" "email" "$value" "FAIL"
    log_error "Email validation failed: $value"
    fi
    
    # Update statistics
    increment_validation_counter "validations_performed"
    increment_validation_counter "cache_misses"
    if [[ $validation_result -ne 0 ]]; then
        increment_validation_counter "validation_failures"
    fi
    
    return $validation_result
}

# Email validation implementation
validate_email() {
    local value="$1"
    # RFC 5322 compliant email regex (simplified)
        [[ "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Enhanced URL validation with microkernel integration
grpc_type_validation_validate_url() {
    local value="$1"
    local schemes="${2:-http,https}"  # Allowed schemes
    local validation_context="${3:-{}}"
    
    if [[ -z "$value" ]]; then
    log_error "grpc_type_validation_validate_url: value required"
        return 1
    fi
    
    log_debug "Validating URL: $value (schemes: $schemes)"
    
    # Check cache first
    local cache_key="url_${value}_${schemes}"
    if validation_cache_get "$cache_key"; then
        increment_validation_counter "cache_hits"
        return 0
    fi
    
    # Perform URL validation
    local validation_result=0
    if validate_url "$value" "$schemes"; then
        validation_cache_set "$cache_key" "true"
        state_db_atomic "record_type_validation" "url" "$value" "PASS"
    log_debug "URL validation passed: $value"
    else
        validation_result=1
        validation_cache_set "$cache_key" "false"
        state_db_atomic "record_type_validation" "url" "$value" "FAIL"
    log_error "URL validation failed: $value"
    fi
    
    # Update statistics
    increment_validation_counter "validations_performed"
    increment_validation_counter "cache_misses"
    if [[ $validation_result -ne 0 ]]; then
        increment_validation_counter "validation_failures"
    fi
    
    return $validation_result
}

# URL validation implementation
validate_url() {
    local value="$1"
    local schemes="$2"
    
    # Extract scheme from URL
    local scheme
    if [[ "$value" =~ ^([a-zA-Z][a-zA-Z0-9+.-]*):// ]]; then
        scheme="${BASH_REMATCH[1]}"
    else
        return 1  # No valid scheme found
    fi
    
    # Check if scheme is allowed
    IFS=',' read -ra allowed_schemes <<< "$schemes"
    local scheme_allowed=false
    for allowed_scheme in "${allowed_schemes[@]}"; do
        if [[ "${scheme,,}" == "${allowed_scheme,,}" ]]; then
            scheme_allowed=true
            break
        fi
    done
    
    if [[ "$scheme_allowed" != "true" ]]; then
        return 1
    fi
    
    # Basic URL format validation
    [[ "$value" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]
}

# Enhanced IP address validation
grpc_type_validation_validate_ip() {
    local value="$1"
    local version="${2:-any}"  # ipv4, ipv6, any
    local validation_context="${3:-{}}"
    
    if [[ -z "$value" ]]; then
    log_error "grpc_type_validation_validate_ip: value required"
        return 1
    fi
    
    log_debug "Validating IP address: $value (version: $version)"
    
    local validation_result=0
    case "$version" in
        "ipv4")
            validate_ipv4 "$value" || validation_result=1
            ;;
        "ipv6")
            validate_ipv6 "$value" || validation_result=1
            ;;
        "any")
            if ! validate_ipv4 "$value" && ! validate_ipv6 "$value"; then
                validation_result=1
            fi
            ;;
        *)
    log_error "Unknown IP version: $version"
            validation_result=1
            ;;
    esac
    
    # Record result
    if [[ $validation_result -eq 0 ]]; then
        state_db_atomic "record_type_validation" "ip_$version" "$value" "PASS"
    log_debug "IP validation passed: $value"
    else
        state_db_atomic "record_type_validation" "ip_$version" "$value" "FAIL"
    log_error "IP validation failed: $value"
    fi
    
    increment_validation_counter "validations_performed"
    if [[ $validation_result -ne 0 ]]; then
        increment_validation_counter "validation_failures"
    fi
    
    return $validation_result
}

# IPv4 validation
validate_ipv4() {
    local value="$1"
    if [[ "$value" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        local octet1="${BASH_REMATCH[1]}"
        local octet2="${BASH_REMATCH[2]}"
        local octet3="${BASH_REMATCH[3]}"
        local octet4="${BASH_REMATCH[4]}"
    
        # Check if each octet is in valid range (0-255)
        [[ $octet1 -le 255 && $octet2 -le 255 && $octet3 -le 255 && $octet4 -le 255 ]]
    else
        return 1
    fi
}

# IPv6 validation (simplified)
validate_ipv6() {
    local value="$1"
    # Simplified IPv6 regex - full validation would be much more complex
    [[ "$value" =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]
}

# Custom pattern validation
grpc_type_validation_validate_custom_pattern() {
    local value="$1"
    local pattern="$2"
    local validation_context="${3:-{}}"
    
    if [[ -z "$value" || -z "$pattern" ]]; then
    log_error "grpc_type_validation_validate_custom_pattern: value and pattern required"
        return 1
    fi
    
    log_debug "Validating custom pattern: $value against $pattern"
    
    local validation_result=0
    if [[ "$value" =~ $pattern ]]; then
        state_db_atomic "record_type_validation" "custom_pattern" "$value" "PASS"
    log_debug "Custom pattern validation passed: $value"
    else
        validation_result=1
        state_db_atomic "record_type_validation" "custom_pattern" "$value" "FAIL"
    log_error "Custom pattern validation failed: $value"
    fi
    
    increment_validation_counter "validations_performed"
    if [[ $validation_result -ne 0 ]]; then
        increment_validation_counter "validation_failures"
    fi
    
    return $validation_result
}

# Simple validation cache implementation
validation_cache_get() {
    local key="$1"
    # Simple cache using state database
    if command -v state_db_get >/dev/null 2>&1; then
        local cached_result
        cached_result=$(state_db_get "validation_cache.$key" 2>/dev/null)
        [[ "$cached_result" == "true" ]]
    else
        return 1  # Cache miss if no state database
    fi
}

validation_cache_set() {
    local key="$1"
    local value="$2"
    # Simple cache using state database
    if command -v state_db_set >/dev/null 2>&1; then
        state_db_set "validation_cache.$key" "$value"
    fi
}

# Get validation statistics
grpc_type_validation_get_statistics() {
    local format="${1:-json}"
    
    if command -v state_db_get >/dev/null 2>&1; then
        local validations_performed
        validations_performed=$(state_db_get "type_validation.validations_performed" || echo "0")
        local validation_failures
        validation_failures=$(state_db_get "type_validation.validation_failures" || echo "0")
        local cache_hits
        cache_hits=$(state_db_get "type_validation.cache_hits" || echo "0")
        local cache_misses
        cache_misses=$(state_db_get "type_validation.cache_misses" || echo "0")
        
        local success_rate=0
        local cache_hit_rate=0
        if [[ $validations_performed -gt 0 ]]; then
            success_rate=$(echo "scale=2; ($validations_performed - $validation_failures) * 100 / $validations_performed" | bc 2>/dev/null || echo "0")
        fi
        if [[ $((cache_hits + cache_misses)) -gt 0 ]]; then
            cache_hit_rate=$(echo "scale=2; $cache_hits * 100 / ($cache_hits + $cache_misses)" | bc 2>/dev/null || echo "0")
        fi
    
    case "$format" in
            "json")
                jq -n \
                    --argjson validations "$validations_performed" \
                    --argjson failures "$validation_failures" \
                    --argjson cache_hits "$cache_hits" \
                    --argjson cache_misses "$cache_misses" \
                    --argjson success_rate "$success_rate" \
                    --argjson cache_hit_rate "$cache_hit_rate" \
                    '{
                        validations_performed: $validations,
                        validation_failures: $failures,
                        success_rate: $success_rate,
                        cache_hits: $cache_hits,
                        cache_misses: $cache_misses,
                        cache_hit_rate: $cache_hit_rate,
                        plugin_version: "1.0.0"
                    }'
                ;;
            "summary")
                echo "Type Validation Statistics:"
                echo "  Validations performed: $validations_performed"
                echo "  Failures: $validation_failures"
                echo "  Success rate: ${success_rate}%"
                echo "  Cache hits: $cache_hits"
                echo "  Cache misses: $cache_misses"
                echo "  Cache hit rate: ${cache_hit_rate}%"
            ;;
    esac
    else
        echo '{"error": "State database not available"}'
    fi
}

# Increment validation counter
increment_validation_counter() {
    local counter_name="$1"
    
    if command -v state_db_get >/dev/null 2>&1; then
        local current_value
        current_value=$(state_db_get "type_validation.$counter_name" || echo "0")
        state_db_set "type_validation.$counter_name" "$((current_value + 1))"
    fi
}

# Type validation event handler
grpc_type_validation_event_handler() {
    local event_message="$1"
    
    log_debug "Type validation plugin received event: $event_message"
    
    # Handle validation-related events
    # This could be used for:
    # - Validation performance monitoring
    # - Type usage pattern analysis
    # - Dynamic validation rule updates
    # - Validation error trending
    
        return 0
}

# State database helper functions
record_type_validation() {
    local type="$1"
    local value="$2"
    local result="$3"
    
    local validation_key="type_validation_${type}_$(date +%s)"
    GRPCTESTIFY_STATE["${validation_key}_type"]="$type"
    GRPCTESTIFY_STATE["${validation_key}_value"]="$value"
    GRPCTESTIFY_STATE["${validation_key}_result"]="$result"
    GRPCTESTIFY_STATE["${validation_key}_timestamp"]="$(date +%s)"
    
    return 0
}

# Legacy compatibility functions
validate_uuid() {
    validate_uuid "$@"
}

validate_iso8601() {
    validate_iso8601 "$@"
}

validate_rfc3339() {
    validate_rfc3339 "$@"
}

validate_email() {
    validate_email "$@"
}

validate_url() {
    validate_url "$@"
}

validate_ipv4() {
    validate_ipv4 "$@"
}

validate_ipv6() {
    validate_ipv6 "$@"
}

# Export functions
export -f grpc_type_validation_init grpc_type_validation_handler grpc_type_validation_validate_uuid
export -f grpc_type_validation_validate_timestamp grpc_type_validation_validate_email grpc_type_validation_validate_url
export -f grpc_type_validation_validate_ip grpc_type_validation_validate_custom_pattern validate_uuid
export -f validate_iso8601 validate_rfc3339 validate_unix_timestamp validate_email
export -f validate_url validate_ipv4 validate_ipv6 validation_cache_get validation_cache_set
export -f grpc_type_validation_get_statistics increment_validation_counter grpc_type_validation_event_handler
export -f record_type_validation validate_uuid validate_iso8601 validate_rfc3339
export -f validate_email validate_url validate_ipv4 validate_ipv6
