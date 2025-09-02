#!/bin/bash

# grpc_api_key.sh - API Key validation plugin for gRPC Testify
# Plugin Type: assertion
# API Version: 1.0.0

# Plugin metadata
PLUGIN_API_KEY_VERSION="1.0.0"
PLUGIN_API_KEY_DESCRIPTION="API key validation plugin for authentication headers"
PLUGIN_API_KEY_AUTHOR="Your Name <info@example.com>"

# Plugin configuration
declare -A PLUGIN_API_KEY_CONFIG=(
    ["timeout"]="30"
    ["strict_mode"]="false"
    ["debug"]="false"
    ["key_format"]="uuid"  # uuid, hex, base64, custom
    ["min_length"]="32"
    ["max_length"]="64"
)

# Main plugin assertion function
assert_api_key() {
    local response="$1"
    local parameter="$2"
    local expected_value="$3"
    local operation_type="${4:-equals}"
    
    # Validate inputs
    if [[ -z "$response" ]]; then
        log error "API Key plugin: Empty response"
        return 1
    fi
    
    if [[ -z "$parameter" ]]; then
        log error "API Key plugin: Parameter is required"
        return 1
    fi
    
    # Debug logging
    if [[ "${PLUGIN_API_KEY_CONFIG[debug]}" == "true" ]]; then
        log debug "API Key plugin: Processing parameter '$parameter'"
        log debug "API Key plugin: Expected value '$expected_value'"
        log debug "API Key plugin: Operation type '$operation_type'"
    fi
    
    # Extract API key from response
    local actual_value
    actual_value=$(extract_api_key_value "$response" "$parameter")
    
    if [[ -z "$actual_value" ]]; then
        log error "API Key plugin: Could not extract API key for parameter '$parameter'"
        return 1
    fi
    
    # Validate API key format if strict mode is enabled
    if [[ "${PLUGIN_API_KEY_CONFIG[strict_mode]}" == "true" ]]; then
        if ! validate_api_key_format "$actual_value"; then
            log error "API Key plugin: Invalid API key format: $actual_value"
            return 1
        fi
    fi
    
    # Perform assertion based on operation type
    case "$operation_type" in
        "equals"|"legacy")
            if [[ "$actual_value" == "$expected_value" ]]; then
                log debug "API Key assertion passed: '$parameter' == '$expected_value'"
                return 0
            else
                log error "API Key assertion failed: '$parameter' expected '$expected_value', got '$actual_value'"
                return 1
            fi
            ;;
        "test")
            if echo "$actual_value" | grep -qE "$expected_value"; then
                log debug "API Key test assertion passed: '$parameter' matches pattern '$expected_value'"
                return 0
            else
                log error "API Key test assertion failed: '$parameter' value '$actual_value' does not match pattern '$expected_value'"
                return 1
            fi
            ;;
        *)
            log error "API Key plugin: Unknown operation type '$operation_type'"
            return 1
            ;;
    esac
}

# Value extraction function
extract_api_key_value() {
    local response="$1"
    local parameter="$2"
    
    # Try different locations for API key
    local api_key=""
    
    # Try headers first (most common)
    api_key=$(echo "$response" | jq -r ".headers[\"$parameter\"] // empty" 2>/dev/null)
    
    # Try response body if not in headers
    if [[ -z "$api_key" ]]; then
        api_key=$(echo "$response" | jq -r ".auth.api_key // .$parameter // empty" 2>/dev/null)
    fi
    
    # Try authorization header parsing
    if [[ -z "$api_key" && "$parameter" == "authorization" ]]; then
        local auth_header=$(echo "$response" | jq -r '.headers.authorization // empty' 2>/dev/null)
        if [[ "$auth_header" =~ ^(Bearer|ApiKey)[[:space:]]+(.+)$ ]]; then
            api_key="${BASH_REMATCH[2]}"
        fi
    fi
    
    echo "$api_key"
}

# API key format validation
validate_api_key_format() {
    local api_key="$1"
    local format="${PLUGIN_API_KEY_CONFIG[key_format]}"
    local min_length="${PLUGIN_API_KEY_CONFIG[min_length]}"
    local max_length="${PLUGIN_API_KEY_CONFIG[max_length]}"
    
    # Check length constraints
    if [[ ${#api_key} -lt $min_length || ${#api_key} -gt $max_length ]]; then
        log error "API key length ${#api_key} is outside allowed range [$min_length, $max_length]"
        return 1
    fi
    
    # Validate format
    case "$format" in
        "uuid")
            [[ "$api_key" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
            ;;
        "hex")
            [[ "$api_key" =~ ^[0-9a-fA-F]+$ ]]
            ;;
        "base64")
            [[ "$api_key" =~ ^[A-Za-z0-9+/]+=*$ ]]
            ;;
        "alphanumeric")
            [[ "$api_key" =~ ^[A-Za-z0-9]+$ ]]
            ;;
        "custom")
            # Custom validation - override this in configuration
            true
            ;;
        *)
            log warning "Unknown API key format: $format, skipping format validation"
            true
            ;;
    esac
}

# Test function for @api_key(...) | test(...) syntax
test_api_key() {
    local response="$1"
    local parameter="$2"
    local pattern="$3"
    
    assert_api_key "$response" "$parameter" "$pattern" "test"
}

# Plugin configuration functions
set_api_key_config() {
    local key="$1"
    local value="$2"
    
    if [[ -z "$key" ]]; then
        log error "API Key plugin: Configuration key is required"
        return 1
    fi
    
    # Validate configuration values
    case "$key" in
        "timeout")
            if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
                log error "API Key plugin: Invalid timeout value: $value"
                return 1
            fi
            ;;
        "strict_mode"|"debug")
            if [[ ! "$value" =~ ^(true|false)$ ]]; then
                log error "API Key plugin: Invalid boolean value for $key: $value"
                return 1
            fi
            ;;
        "key_format")
            if [[ ! "$value" =~ ^(uuid|hex|base64|alphanumeric|custom)$ ]]; then
                log error "API Key plugin: Invalid key format: $value"
                return 1
            fi
            ;;
        "min_length"|"max_length")
            if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
                log error "API Key plugin: Invalid length value: $value"
                return 1
            fi
            ;;
    esac
    
    PLUGIN_API_KEY_CONFIG["$key"]="$value"
    log debug "API Key plugin: Configuration '$key' set to '$value'"
}

get_api_key_config() {
    local key="$1"
    
    if [[ -z "$key" ]]; then
        log error "API Key plugin: Configuration key is required"
        return 1
    fi
    
    echo "${PLUGIN_API_KEY_CONFIG[$key]}"
}

# Plugin validation function
validate_api_key_plugin() {
    local issues=()
    
    # Check required functions
    if ! declare -f extract_api_key_value >/dev/null; then
        issues+=("Missing extract_api_key_value function")
    fi
    
    if ! declare -f assert_api_key >/dev/null; then
        issues+=("Missing assert_api_key function")
    fi
    
    # Check configuration
    if [[ -z "$PLUGIN_API_KEY_VERSION" ]]; then
        issues+=("Missing plugin version")
    fi
    
    if [[ -z "$PLUGIN_API_KEY_DESCRIPTION" ]]; then
        issues+=("Missing plugin description")
    fi
    
    # Validate configuration values
    local min_length="${PLUGIN_API_KEY_CONFIG[min_length]}"
    local max_length="${PLUGIN_API_KEY_CONFIG[max_length]}"
    
    if [[ $min_length -gt $max_length ]]; then
        issues+=("min_length ($min_length) cannot be greater than max_length ($max_length)")
    fi
    
    # Report issues
    if [[ ${#issues[@]} -gt 0 ]]; then
        log error "API Key plugin validation failed:"
        for issue in "${issues[@]}"; do
            log error "  - $issue"
        done
        return 1
    fi
    
    log success "API Key plugin validation passed"
    return 0
}

# Plugin registration function
register_api_key_plugin() {
    # Validate plugin before registration
    if ! validate_api_key_plugin; then
        log error "Cannot register API Key plugin: validation failed"
        return 1
    fi
    
    # Register with plugin system
    register_plugin "api_key" "assert_api_key" "$PLUGIN_API_KEY_DESCRIPTION" "external"
    
    log info "API Key plugin registered successfully (version $PLUGIN_API_KEY_VERSION)"
}

# Plugin help function
show_api_key_help() {
    cat << 'HELP_EOF'
API Key Plugin Help
==================

Usage in test files:
  @api_key("x-api-key") == "expected_key"
  @api_key("authorization") | test("^Bearer [A-Za-z0-9+/]+=*$")
  @api_key("x-custom-key") | test("^[0-9a-f-]{36}$")

Configuration:
  Set configuration: set_api_key_config "key" "value"
  Get configuration: get_api_key_config "key"

Available configuration options:
  timeout         30                # Request timeout in seconds
  strict_mode     false             # Enable strict API key format validation
  debug           false             # Enable debug logging
  key_format      uuid              # Expected key format (uuid|hex|base64|alphanumeric|custom)
  min_length      32                # Minimum key length
  max_length      64                # Maximum key length

Examples:
  # Basic API key validation
  @api_key("x-api-key") == "abc123def456"
  
  # Authorization header validation
  @api_key("authorization") | test("^Bearer [A-Za-z0-9+/]+={0,2}$")
  
  # UUID format API key
  @api_key("x-session-id") | test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
  
  # Combined with other assertions
  @api_key("x-api-key") | test("^[a-f0-9]{32}$") and .user.authenticated == true

Configuration examples:
  # Enable strict UUID validation
  set_api_key_config "strict_mode" "true"
  set_api_key_config "key_format" "uuid"
  
  # Custom key format
  set_api_key_config "key_format" "custom"
  set_api_key_config "min_length" "24"
  set_api_key_config "max_length" "48"

The plugin will automatically look for API keys in:
1. Response headers (most common)
2. Response body auth fields
3. Authorization header parsing (Bearer/ApiKey tokens)

For more information, see the plugin documentation.
HELP_EOF
}

# Export plugin functions
export -f assert_api_key
export -f test_api_key
export -f extract_api_key_value
export -f validate_api_key_format
export -f set_api_key_config
export -f get_api_key_config
export -f validate_api_key_plugin
export -f register_api_key_plugin
export -f show_api_key_help
