#!/usr/bin/env bats

# plugins.bats - Tests for plugins.sh module

# Load the plugins module
load "/load "${BATS_TEST_DIRNAME}/plugins.sh'"

@test "list_plugins_command function lists plugins" {
    # Test plugin listing command
    run list_plugins_command
    [ $status -eq 0 ]
}

@test "create_plugin_command function creates plugins" {
    # Test plugin creation command
    run create_plugin_command "test_plugin"
    [ $status -eq 0 ]
}

@test "test_plugin_command function tests plugins" {
    # Test plugin testing command
    run test_plugin_command "test_plugin"
    [ $status -eq 0 ]
}

@test "handle_plugin_flags function handles plugin flags" {
    # Test plugin flag handling
    run handle_plugin_flags
    [ $status -eq 0 ]
}