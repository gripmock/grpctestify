#!/usr/bin/env bats

# plugin_api.bats - Tests for plugin_api.sh module

# Load dependencies
load "${BATS_TEST_DIRNAME}/../core/colors.sh"
load "${BATS_TEST_DIRNAME}/../core/utils.sh"

# Load the plugin API module
load "${BATS_TEST_DIRNAME}/plugin_api.sh"

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

@test "create_plugin_template creates valid plugin with valid name" {
    run create_plugin_template "test_plugin" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 0 ]
    
    # Check if plugin file was created
    [ -f "$TEST_PLUGIN_DIR/grpc_test_plugin.sh" ]
    [ -f "$TEST_PLUGIN_DIR/grpc_test_plugin.bats" ]
    
    # Check plugin file contains expected content
    grep -q "PLUGIN_TEST_PLUGIN_VERSION" "$TEST_PLUGIN_DIR/grpc_test_plugin.sh"
    grep -q "register_test_plugin_plugin" "$TEST_PLUGIN_DIR/grpc_test_plugin.sh"
}

@test "create_plugin_template fails with invalid plugin name" {
    # Test with uppercase letters
    run create_plugin_template "TestPlugin" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 1 ]
    
    # Test with spaces
    run create_plugin_template "test plugin" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 1 ]
    
    # Test with special characters
    run create_plugin_template "test-plugin" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 1 ]
    
    # Test starting with number
    run create_plugin_template "1test" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 1 ]
}

@test "create_plugin_template fails with empty plugin name" {
    run create_plugin_template "" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 1 ]
    [[ "$output" =~ "Plugin name is required" ]]
}

@test "create_plugin_template uses default values correctly" {
    run create_plugin_template "default_test"
    [ $status -eq 0 ]
    
    # Should create in default plugins directory
    [ -f "plugins/grpc_default_test.sh" ]
    [ -f "plugins/grpc_default_test.bats" ]
    
    # Clean up
    rm -f "plugins/grpc_default_test.sh" "plugins/grpc_default_test.bats"
}

@test "create_plugin_template creates different plugin types" {
    # Test assertion type
    run create_plugin_template "assert_test" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 0 ]
    grep -q "Plugin Type: assertion" "$TEST_PLUGIN_DIR/grpc_assert_test.sh"
    
    # Test validation type  
    run create_plugin_template "valid_test" "validation" "$TEST_PLUGIN_DIR"
    [ $status -eq 0 ]
    grep -q "Plugin Type: validation" "$TEST_PLUGIN_DIR/grpc_valid_test.sh"
    
    # Test utility type
    run create_plugin_template "util_test" "utility" "$TEST_PLUGIN_DIR"
    [ $status -eq 0 ]
    grep -q "Plugin Type: utility" "$TEST_PLUGIN_DIR/grpc_util_test.sh"
}

@test "created plugin template contains required components" {
    run create_plugin_template "component_test" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 0 ]
    
    local plugin_file="$TEST_PLUGIN_DIR/grpc_component_test.sh"
    local test_file="$TEST_PLUGIN_DIR/grpc_component_test.bats"
    
    # Check plugin file structure
    grep -q "#!/bin/bash" "$plugin_file"
    grep -q "PLUGIN_COMPONENT_TEST_VERSION" "$plugin_file"
    grep -q "PLUGIN_COMPONENT_TEST_DESCRIPTION" "$plugin_file"
    grep -q "PLUGIN_COMPONENT_TEST_AUTHOR" "$plugin_file"
    grep -q "info@babichev.net" "$plugin_file"
    grep -q "register_component_test_plugin" "$plugin_file"
    grep -q "export -f" "$plugin_file"
    
    # Check test file structure
    grep -q "#!/usr/bin/env bats" "$test_file"
    grep -q "@test" "$test_file"
    grep -q "load" "$test_file"
}

@test "created plugin template has correct permissions" {
    run create_plugin_template "perm_test" "assertion" "$TEST_PLUGIN_DIR"
    [ $status -eq 0 ]
    
    # Check if files are executable
    [ -x "$TEST_PLUGIN_DIR/grpc_perm_test.sh" ]
    [ -x "$TEST_PLUGIN_DIR/grpc_perm_test.bats" ]
}

@test "plugin template handles directory creation" {
    local new_dir="$TEST_PLUGIN_DIR/new_subdir"
    
    run create_plugin_template "dir_test" "assertion" "$new_dir"
    [ $status -eq 0 ]
    
    # Should create directory and files
    [ -d "$new_dir" ]
    [ -f "$new_dir/grpc_dir_test.sh" ]
    [ -f "$new_dir/grpc_dir_test.bats" ]
}

@test "plugin API version is defined" {
    [ -n "$PLUGIN_API_VERSION" ]
    [[ "$PLUGIN_API_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "plugin development mode can be set" {
    export GRPCTESTIFY_PLUGIN_DEV="true"
    source "${BATS_TEST_DIRNAME}/plugin_api.sh"
    [ "$PLUGIN_DEV_MODE" = "true" ]
    
    unset GRPCTESTIFY_PLUGIN_DEV
    source "${BATS_TEST_DIRNAME}/plugin_api.sh"
    [ "$PLUGIN_DEV_MODE" = "false" ]
}
