#!/usr/bin/env bats

# grpc_default_test.bats - Tests for default_test plugin

setup() {
    # Initialize test environment
    export TEST_DIR="${BATS_TMPDIR}/grpc_default_test"
    mkdir -p "$TEST_DIR"
    
    # Get the directory where this test file is located
    export PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
}

teardown() {
    # Clean up test directory
    rm -rf "$TEST_DIR"
}

@test "grpc_default_test plugin file exists" {
    # Check that the plugin file exists
    [ -f "${PLUGIN_DIR}/grpc_default_test.sh" ]
}

@test "grpc_default_test plugin has required functions" {
    # Check that the plugin file contains expected functions
    [[ -n "$(grep -r "validate_default_test_plugin" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
    [[ -n "$(grep -r "set_default_test_config" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
    [[ -n "$(grep -r "get_default_test_config" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
}

@test "grpc_default_test plugin has metadata" {
    # Check that the plugin file contains metadata
    [[ -n "$(grep -r "PLUGIN_DEFAULT_TEST_VERSION" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
    [[ -n "$(grep -r "PLUGIN_DEFAULT_TEST_DESCRIPTION" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
    [[ -n "$(grep -r "PLUGIN_DEFAULT_TEST_AUTHOR" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
}

@test "grpc_default_test plugin has assertion functions" {
    # Check that the plugin file contains assertion functions
    [[ -n "$(grep -r "assert_default_test" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
    [[ -n "$(grep -r "test_default_test" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
}

@test "grpc_default_test plugin has utility functions" {
    # Check that the plugin file contains utility functions
    [[ -n "$(grep -r "register_default_test_plugin" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
    [[ -n "$(grep -r "show_default_test_help" "${PLUGIN_DIR}/grpc_default_test.sh")" ]]
}

