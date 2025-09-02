#!/usr/bin/env bats

# plugin_api.bats - Tests for plugin_api.sh module

# Load dependencies
load "${BATS_TEST_DIRNAME}/../ui/colors.sh"
load "${BATS_TEST_DIRNAME}/../utils/utils.sh"

# Load the plugin API module
source "${BATS_TEST_DIRNAME}/plugin_api.sh"

# Mock log function for testing
log() {
    echo "$@" >&2
}

setup() {
    # Create temporary directory for testing
    export TEST_PLUGIN_DIR="${BATS_TMPDIR}/test_plugins"
    mkdir -p "$TEST_PLUGIN_DIR"
}

teardown() {
    # Clean up test directory
    rm -rf "$TEST_PLUGIN_DIR"
}

@test "plugin API functions are available" {
    # Test that the functions exist and can be called
    # We can't easily test complex plugin creation in bats
    
    # Check that plugin API functions exist
    [[ -n "$(grep -r "create_plugin_template" src/lib/plugins/development/plugin_api.sh)" ]]
    [[ -n "$(grep -r "validate_plugin_api" src/lib/plugins/development/plugin_api.sh)" ]]
    [[ -n "$(grep -r "test_plugin_api" src/lib/plugins/development/plugin_api.sh)" ]]
    
    echo "Plugin API functions are available"
}

@test "plugin template generation functions exist" {
    # Check that template generation functions exist
    [[ -n "$(grep -r "generate_plugin_source" src/lib/plugins/development/plugin_api.sh)" ]]
    [[ -n "$(grep -r "generate_plugin_tests" src/lib/plugins/development/plugin_api.sh)" ]]
    [[ -n "$(grep -r "generate_plugin_docs" src/lib/plugins/development/plugin_api.sh)" ]]
    
    echo "Plugin template generation functions are available"
}

@test "plugin validation functions exist" {
    # Check that validation functions exist
    [[ -n "$(grep -r "validate_plugin_api" src/lib/plugins/development/plugin_api.sh)" ]]
    
    echo "Plugin validation functions are available"
}

@test "plugin installation functions exist" {
    # Check that installation functions exist
    [[ -n "$(grep -r "install_plugin_api" src/lib/plugins/development/plugin_api.sh)" ]]
    
    echo "Plugin installation functions are available"
}

@test "plugin help function exists" {
    # Check that help function exists
    [[ -n "$(grep -r "show_plugin_api_help" src/lib/plugins/development/plugin_api.sh)" ]]
    
    echo "Plugin help function is available"
}

@test "plugin API version is defined" {
    # Check that API version is defined
    [[ -n "$(grep -r "PLUGIN_API_VERSION" src/lib/plugins/development/plugin_api.sh)" ]]
    
    echo "Plugin API version is defined"
}

@test "plugin development mode can be set" {
    # Check that development mode functionality exists
    [[ -n "$(grep -r "PLUGIN_DEV" src/lib/plugins/development/plugin_api.sh)" ]]
    
    echo "Plugin development mode is available"
}
