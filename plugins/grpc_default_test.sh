#!/bin/bash

# grpc_default_test.sh - Default_test plugin for gRPC Testify
# Plugin Type: assertion
# API Version: 

# Plugin metadata
PLUGIN_DEFAULT_TEST_VERSION=""
PLUGIN_DEFAULT_TEST_DESCRIPTION="Description of default_test plugin"
PLUGIN_DEFAULT_TEST_AUTHOR="Your Name <info@example.com>"

# Plugin configuration (using centralized config)
declare -A PLUGIN_DEFAULT_TEST_CONFIG=(
    ["timeout"]="$PLUGIN_TIMEOUT"
    ["strict_mode"]="$PLUGIN_STRICT_MODE"
    ["debug"]="$PLUGIN_DEBUG"
    ["max_retries"]="$PLUGIN_MAX_RETRIES"
)

# Main plugin assertion function
assert_default_test() {
    local response="$1"
    local parameter="$2"
    local expected_value="$3"
    local operation_type="${4:-equals}"
    
    # Validate inputs
    if [[ -z "$response" ]]; then
    tlog error "Default_test plugin: Empty response"
        return 1
    fi
    
    if [[ -z "$parameter" ]]; then
    tlog error "Default_test plugin: Parameter is required"
        return 1
    fi
    
    # Validate parameter name (security check)
    if [[ ! "$parameter" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    tlog error "Default_test plugin: Invalid parameter name '$parameter'"
        return 1
    fi
    
    # Validate response is valid JSON (basic check)
    if [[ "$response" != "{}" ]] && ! echo "$response" | jq empty >/dev/null 2>&1; then
    tlog error "Default_test plugin: Invalid JSON response"
        return 1
    fi
    
    # Debug logging
    if [[ "${PLUGIN_DEFAULT_TEST_CONFIG[debug]}" == "true" ]]; then
    tlog debug "Default_test plugin: Processing parameter '$parameter'"
    tlog debug "Default_test plugin: Expected value '$expected_value'"
    tlog debug "Default_test plugin: Operation type '$operation_type'"
    fi
    
    # Extract value from response
    local actual_value
    case "$operation_type" in
        "equals"|"legacy")
            actual_value=$(extract_default_test_value "$response" "$parameter")
            ;;
        "test")
            actual_value=$(extract_default_test_value "$response" "$parameter")
            ;;
        *)
    tlog error "Default_test plugin: Unknown operation type '$operation_type'"
            return 1
            ;;
    esac
    
    if [[ -z "$actual_value" ]]; then
    tlog error "Default_test plugin: Could not extract value for parameter '$parameter'"
        return 1
    fi
    
    # Perform assertion based on operation type
    case "$operation_type" in
        "equals"|"legacy")
            if [[ "$actual_value" == "$expected_value" ]]; then
    tlog debug "Default_test assertion passed: '$parameter' == '$expected_value'"
                return 0
            else
    tlog error "Default_test assertion failed: '$parameter' expected '$expected_value', got '$actual_value'"
                return 1
            fi
            ;;
        "test")
            if echo "$actual_value" | grep -qE "$expected_value"; then
    tlog debug "Default_test test assertion passed: '$parameter' matches pattern '$expected_value'"
                return 0
            else
    tlog error "Default_test test assertion failed: '$parameter' value '$actual_value' does not match pattern '$expected_value'"
                return 1
            fi
            ;;
    esac
}

# Value extraction function (customize based on your plugin's needs)
extract_default_test_value() {
    local response="$1"
    local parameter="$2"
    
    # Generic value extraction - customize based on your plugin's needs
    # Common patterns:
    # - Headers: echo "$response" | jq -r ".headers[\"$parameter\"] // empty"
    # - Fields: echo "$response" | jq -r ".$parameter // empty"  
    # - Nested: echo "$response" | jq -r ".data.$parameter // empty"
    
    # Default implementation extracts field directly
    echo "$response" | jq -r ".$parameter // empty" 2>/dev/null || echo ""
}

# Test function for @default_test(...) | test(...) syntax
test_default_test() {
    local response="$1"
    local parameter="$2"
    local pattern="$3"
    
    assert_default_test "$response" "$parameter" "$pattern" "test"
}

# Plugin configuration functions
set_default_test_config() {
    local key="$1"
    local value="$2"
    
    if [[ -z "$key" ]]; then
    tlog error "Default_test plugin: Configuration key is required"
        return 1
    fi
    
    PLUGIN_DEFAULT_TEST_CONFIG["$key"]="$value"
    tlog debug "Default_test plugin: Configuration '$key' set to '$value'"
}

get_default_test_config() {
    local key="$1"
    
    if [[ -z "$key" ]]; then
    tlog error "Default_test plugin: Configuration key is required"
        return 1
    fi
    
    echo "${PLUGIN_DEFAULT_TEST_CONFIG[$key]}"
}

# Plugin validation function
validate_default_test_plugin() {
    local issues=()
    
    # Check required functions
    if ! declare -f extract_default_test_value >/dev/null; then
        issues+=("Missing extract_default_test_value function")
    fi
    
    if ! declare -f assert_default_test >/dev/null; then
        issues+=("Missing assert_default_test function")
    fi
    
    # Check configuration
    if [[ -z "${PLUGIN_DEFAULT_TEST_VERSION}" ]]; then
        issues+=("Missing plugin version")
    fi
    
    if [[ -z "${PLUGIN_DEFAULT_TEST_DESCRIPTION}" ]]; then
        issues+=("Missing plugin description")
    fi
    
    # Report issues
    if [[ ${#issues[@]} -gt 0 ]]; then
    tlog error "Default_test plugin validation failed:"
        for issue in "${issues[@]}"; do
    tlog error "  - $issue"
        done
        return 1
    fi
    
    tlog debug "Default_test plugin validation passed"
    return 0
}

# Plugin registration function
register_default_test_plugin() {
    # Validate plugin before registration
    if ! validate_default_test_plugin; then
    tlog error "Cannot register default_test plugin: validation failed"
        return 1
    fi
    
    # Register with plugin system
    register_plugin "default_test" "assert_default_test" "${PLUGIN_DEFAULT_TEST_DESCRIPTION}" "external"
    
    tlog debug "Default_test plugin registered successfully (version ${PLUGIN_DEFAULT_TEST_VERSION})"
}

# Plugin help function
show_default_test_help() {
    cat << 'HELP_EOF'
Default_test Plugin Help
=======================

Usage in test files:
  @default_test("parameter") == "expected_value"
  @default_test("parameter") | test("regex_pattern")

Configuration:
  Set configuration: set_default_test_config "key" "value"
  Get configuration: get_default_test_config "key"

Available configuration options:
  $key:                ${PLUGIN_DEFAULT_TEST_CONFIG[$key]}

Examples:
  # Basic assertion
  @default_test("field") == "expected"
  
  # Pattern matching
  @default_test("field") | test("^[0-9]+$")
  
  # Combined with jq
  @default_test("field") == "value" and .other_field == "test"

For more information, see the plugin documentation.
HELP_EOF
}

# Export plugin functions
export -f assert_default_test
export -f test_default_test
export -f extract_default_test_value
export -f set_default_test_config
export -f get_default_test_config
export -f validate_default_test_plugin
export -f register_default_test_plugin
export -f show_default_test_help
