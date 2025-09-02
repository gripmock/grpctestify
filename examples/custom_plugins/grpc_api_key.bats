#!/usr/bin/env bats

# grpc_api_key.bats - Tests for API Key plugin

setup() {
    # Initialize test environment
    export TEST_DIR="${BATS_TMPDIR}/grpc_api_key_test"
    mkdir -p "$TEST_DIR"
    
    # Get the directory where this test file is located
    export PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
}

teardown() {
    # Clean up test directory
    rm -rf "$TEST_DIR"
}

@test "api_key plugin file exists" {
    # Check that the plugin file exists
    [ -f "${PLUGIN_DIR}/grpc_api_key.sh" ]
}

@test "api_key plugin has required functions" {
    # Check that the plugin file contains expected functions
    [[ -n "$(grep -r "set_api_key_config" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "get_api_key_config" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "extract_api_key_value" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
}

@test "api_key plugin has metadata" {
    # Check that the plugin file contains metadata
    [[ -n "$(grep -r "PLUGIN_API_KEY_VERSION" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "PLUGIN_API_KEY_DESCRIPTION" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "PLUGIN_API_KEY_AUTHOR" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
}

@test "api_key plugin has validation functions" {
    # Check that the plugin file contains validation functions
    [[ -n "$(grep -r "validate_api_key_format" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "assert_api_key" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
}

@test "api_key plugin has utility functions" {
    # Check that the plugin file contains utility functions
    [[ -n "$(grep -r "test_api_key" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "register_api_key_plugin" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "show_api_key_help" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
}

@test "api_key plugin has configuration options" {
    # Check that the plugin file contains configuration options
    [[ -n "$(grep -r "key_format" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "min_length" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "max_length" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
    [[ -n "$(grep -r "strict_mode" "${PLUGIN_DIR}/grpc_api_key.sh")" ]]
}
