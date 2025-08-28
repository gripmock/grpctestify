#!/usr/bin/env bats

# plugin_system_enhanced.bats - Tests for plugin_system_enhanced.sh module

# Load the plugin system module
load "${BATS_TEST_DIRNAME}/plugin_system_enhanced.sh"

@test "register_plugin function registers plugins" {
    # Test plugin registration
    run register_plugin "test_plugin" "Test plugin description"
    [ $status -eq 0 ]
}

@test "load_internal_plugins function loads internal plugins" {
    # Test internal plugin loading
    run load_internal_plugins
    [ $status -eq 0 ]
}

@test "load_all_plugins function loads all plugins" {
    # Test all plugin loading
    run load_all_plugins
    [ $status -eq 0 ]
}

@test "execute_plugin_assertion function executes plugin assertions" {
    # Test plugin assertion execution
    run execute_plugin_assertion "test_plugin" '{"test": "data"}' "test_args"
    [ $status -ne 0 ]  # Expected to fail for non-existent plugin
}

@test "parse_plugin_assertion function parses plugin assertions" {
    # Test plugin assertion parsing
    run parse_plugin_assertion "@test_plugin:arg1:arg2"
    [ $status -eq 0 ]
}

@test "evaluate_asserts_with_plugins function evaluates assertions with plugins" {
    # Test assertion evaluation with plugins
    local response='{"test": "data"}'
    local asserts='@test_plugin:arg1'
    
    run evaluate_asserts_with_plugins "$asserts" "$response"
    [ $status -ne 0 ]  # Expected to fail for non-existent plugin
}

@test "list_plugins function lists plugins" {
    # Test plugin listing
    run list_plugins
    [ $status -eq 0 ]
}

@test "create_plugin_template function creates plugin templates" {
    # Test plugin template creation
    run create_plugin_template "test_plugin"
    [ $status -eq 0 ]
}