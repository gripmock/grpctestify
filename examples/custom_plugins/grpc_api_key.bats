#!/usr/bin/env bats

# grpc_api_key.bats - Tests for API key validation plugin

# Load the plugin
load './grpc_api_key.sh'

# Mock log function for testing
log() {
    echo "$@" >&2
}

setup() {
    # Initialize plugin configuration for each test
    PLUGIN_API_KEY_CONFIG=(
        ["timeout"]="30"
        ["strict_mode"]="false"
        ["debug"]="false"
        ["key_format"]="uuid"
        ["min_length"]="32"
        ["max_length"]="64"
    )
}

@test "api_key plugin loads without errors" {
    # Test plugin loading
    run validate_api_key_plugin
    [ $status -eq 0 ]
}

@test "api_key plugin has required metadata" {
    # Test version
    [ -n "$PLUGIN_API_KEY_VERSION" ]
    [ "$PLUGIN_API_KEY_VERSION" = "1.0.0" ]
    
    # Test description
    [ -n "$PLUGIN_API_KEY_DESCRIPTION" ]
    
    # Test author
    [ -n "$PLUGIN_API_KEY_AUTHOR" ]
}

@test "api_key plugin configuration works" {
    # Set configuration
    run set_api_key_config "debug" "true"
    [ $status -eq 0 ]
    
    # Get configuration
    run get_api_key_config "debug"
    [ $status -eq 0 ]
    [ "$output" = "true" ]
    
    # Set timeout
    run set_api_key_config "timeout" "60"
    [ $status -eq 0 ]
    
    run get_api_key_config "timeout"
    [ $status -eq 0 ]
    [ "$output" = "60" ]
}

@test "api_key plugin configuration validation" {
    # Invalid timeout
    run set_api_key_config "timeout" "invalid"
    [ $status -ne 0 ]
    
    # Invalid boolean
    run set_api_key_config "strict_mode" "maybe"
    [ $status -ne 0 ]
    
    # Invalid key format
    run set_api_key_config "key_format" "invalid_format"
    [ $status -ne 0 ]
    
    # Invalid length
    run set_api_key_config "min_length" "0"
    [ $status -ne 0 ]
}

@test "extract_api_key_value extracts from headers" {
    local test_response='{"headers": {"x-api-key": "test-key-123"}}'
    
    run extract_api_key_value "$test_response" "x-api-key"
    [ $status -eq 0 ]
    [ "$output" = "test-key-123" ]
}

@test "extract_api_key_value extracts from auth field" {
    local test_response='{"auth": {"api_key": "auth-key-456"}}'
    
    run extract_api_key_value "$test_response" "api_key"
    [ $status -eq 0 ]
    [ "$output" = "auth-key-456" ]
}

@test "extract_api_key_value extracts from authorization header" {
    local test_response='{"headers": {"authorization": "Bearer token123"}}'
    
    run extract_api_key_value "$test_response" "authorization"
    [ $status -eq 0 ]
    [ "$output" = "token123" ]
    
    # Test ApiKey format
    local test_response2='{"headers": {"authorization": "ApiKey api-key-789"}}'
    run extract_api_key_value "$test_response2" "authorization"
    [ $status -eq 0 ]
    [ "$output" = "api-key-789" ]
}

@test "validate_api_key_format validates UUID format" {
    set_api_key_config "key_format" "uuid"
    set_api_key_config "min_length" "36"
    set_api_key_config "max_length" "36"
    
    # Valid UUID
    run validate_api_key_format "550e8400-e29b-41d4-a716-446655440000"
    [ $status -eq 0 ]
    
    # Invalid UUID
    run validate_api_key_format "invalid-uuid"
    [ $status -ne 0 ]
}

@test "validate_api_key_format validates hex format" {
    set_api_key_config "key_format" "hex"
    set_api_key_config "min_length" "32"
    set_api_key_config "max_length" "32"
    
    # Valid hex
    run validate_api_key_format "abcdef1234567890abcdef1234567890"
    [ $status -eq 0 ]
    
    # Invalid hex (contains non-hex characters)
    run validate_api_key_format "xyz123"
    [ $status -ne 0 ]
}

@test "validate_api_key_format validates base64 format" {
    set_api_key_config "key_format" "base64"
    set_api_key_config "min_length" "32"
    set_api_key_config "max_length" "64"
    
    # Valid base64
    run validate_api_key_format "SGVsbG8gV29ybGQhIFRoaXMgaXMgYSB0ZXN0IGtleQ=="
    [ $status -eq 0 ]
    
    # Invalid base64 (contains invalid characters)
    run validate_api_key_format "invalid@base64!"
    [ $status -ne 0 ]
}

@test "validate_api_key_format checks length constraints" {
    set_api_key_config "key_format" "alphanumeric"
    set_api_key_config "min_length" "10"
    set_api_key_config "max_length" "20"
    
    # Too short
    run validate_api_key_format "short"
    [ $status -ne 0 ]
    
    # Too long
    run validate_api_key_format "thiskeyveryverylongerthantwentycharacters"
    [ $status -ne 0 ]
    
    # Just right
    run validate_api_key_format "perfectlength"
    [ $status -eq 0 ]
}

@test "assert_api_key works with valid input" {
    local test_response='{"headers": {"x-api-key": "test-key-123"}}'
    
    # Equals assertion
    run assert_api_key "$test_response" "x-api-key" "test-key-123" "equals"
    [ $status -eq 0 ]
    
    # Test assertion
    run assert_api_key "$test_response" "x-api-key" "test-key-[0-9]+" "test"
    [ $status -eq 0 ]
}

@test "assert_api_key fails with invalid input" {
    local test_response='{"headers": {"x-api-key": "wrong-key"}}'
    
    # Wrong value
    run assert_api_key "$test_response" "x-api-key" "expected-key" "equals"
    [ $status -ne 0 ]
    
    # Wrong pattern
    run assert_api_key "$test_response" "x-api-key" "^expected-" "test"
    [ $status -ne 0 ]
}

@test "assert_api_key handles missing keys" {
    local test_response='{"headers": {"other-header": "value"}}'
    
    # Missing key should fail
    run assert_api_key "$test_response" "x-api-key" "any-value" "equals"
    [ $status -ne 0 ]
}

@test "assert_api_key handles empty response" {
    # Empty response should fail
    run assert_api_key "" "x-api-key" "any-value" "equals"
    [ $status -ne 0 ]
    
    # Missing parameter should fail
    run assert_api_key '{"headers": {}}' "" "any-value" "equals"
    [ $status -ne 0 ]
}

@test "assert_api_key strict mode validation" {
    set_api_key_config "strict_mode" "true"
    set_api_key_config "key_format" "uuid"
    set_api_key_config "min_length" "36"
    set_api_key_config "max_length" "36"
    
    # Valid UUID in strict mode
    local test_response='{"headers": {"x-api-key": "550e8400-e29b-41d4-a716-446655440000"}}'
    run assert_api_key "$test_response" "x-api-key" "550e8400-e29b-41d4-a716-446655440000" "equals"
    [ $status -eq 0 ]
    
    # Invalid format in strict mode should fail
    local test_response2='{"headers": {"x-api-key": "invalid-format"}}'
    run assert_api_key "$test_response2" "x-api-key" "invalid-format" "equals"
    [ $status -ne 0 ]
}

@test "test_api_key function works" {
    local test_response='{"headers": {"x-api-key": "test123"}}'
    
    # Pattern matching
    run test_api_key "$test_response" "x-api-key" "^test[0-9]+$"
    [ $status -eq 0 ]
    
    # Pattern not matching
    run test_api_key "$test_response" "x-api-key" "^wrong"
    [ $status -ne 0 ]
}

@test "plugin registration works" {
    # Mock register_plugin function
    register_plugin() {
        echo "Registering plugin: $1"
        return 0
    }
    
    # Test plugin registration
    run register_api_key_plugin
    [ $status -eq 0 ]
}

@test "plugin validation catches configuration issues" {
    # Test conflicting min/max lengths
    set_api_key_config "min_length" "50"
    set_api_key_config "max_length" "40"
    
    run validate_api_key_plugin
    [ $status -ne 0 ]
}

@test "plugin help is available" {
    # Test help function
    run show_api_key_help
    [ $status -eq 0 ]
    [[ "$output" =~ "API Key Plugin Help" ]]
    [[ "$output" =~ "@api_key" ]]
}

@test "plugin handles unknown operation types" {
    local test_response='{"headers": {"x-api-key": "test-key"}}'
    
    run assert_api_key "$test_response" "x-api-key" "test-key" "unknown_operation"
    [ $status -ne 0 ]
}

@test "plugin handles complex authorization headers" {
    # Test Bearer token with complex format
    local test_response='{"headers": {"authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token"}}'
    
    run extract_api_key_value "$test_response" "authorization"
    [ $status -eq 0 ]
    [ "$output" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token" ]
}
