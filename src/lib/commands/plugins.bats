#!/usr/bin/env bats

# plugins.bats - Tests for plugins.sh module

setup() {
    # Load configuration and dependencies
    source "${BATS_TEST_DIRNAME}/../kernel/config.sh"
    
    # Mock tlog function if not available
    if ! command -v tlog >/dev/null 2>&1; then
        tlog() { echo "MOCK_LOG: $*"; }
        export -f tlog
    fi
    
    # Mock other required functions
    if ! command -v expand_tilde >/dev/null 2>&1; then
        expand_tilde() { echo "$1"; }
        export -f expand_tilde
    fi
    
    if ! command -v ensure_directory >/dev/null 2>&1; then
        ensure_directory() { mkdir -p "$1" 2>/dev/null || true; }
        export -f ensure_directory
    fi
    
    if ! command -v error_required >/dev/null 2>&1; then
        error_required() { echo "Error: $1 is required" >&2; }
        export -f error_required
    fi
    
    if ! command -v show_plugin_api_help >/dev/null 2>&1; then
        show_plugin_api_help() { echo "Plugin API help"; }
        export -f show_plugin_api_help
    fi
    
    if ! command -v create_plugin_template >/dev/null 2>&1; then
        create_plugin_template() { echo "Plugin template created: $1"; return 0; }
        export -f create_plugin_template
    fi
    
    if ! command -v load_all_plugins >/dev/null 2>&1; then
        load_all_plugins() { echo "Plugins loaded"; }
        export -f load_all_plugins
    fi
    
    if ! command -v list_plugin_names >/dev/null 2>&1; then
        list_plugin_names() { echo "test_plugin"; }
        export -f list_plugin_names
    fi
    
    if ! command -v execute_plugin_assertion >/dev/null 2>&1; then
        execute_plugin_assertion() { echo "Plugin assertion executed"; return 0; }
        export -f execute_plugin_assertion
    fi
    
    # Mock PLUGIN_REGISTRY
    declare -gA PLUGIN_REGISTRY
    PLUGIN_REGISTRY["test_plugin"]="test_plugin_handler"
    
    # Load the plugins module
    source "${BATS_TEST_DIRNAME}/plugins.sh"
}

@test "list_plugins_command function lists plugins" {
    # Test plugin listing command
    run list_plugins_command
    [ $status -eq 0 ]
    [[ "$output" =~ "Available plugins" ]]
}

@test "create_plugin_command function creates plugins" {
    # Test plugin creation command
    run create_plugin_command "test_plugin"
    [ $status -eq 0 ]
    [[ "$output" =~ "Plugin template created" ]]
}

@test "test_plugin_command function tests plugins" {
    # Test plugin testing command
    run test_plugin_command "test_plugin" "test_args"
    [ $status -eq 0 ]
    [[ "$output" =~ "Plugin assertion executed" ]]
}

@test "handle_plugin_flags function handles plugin flags" {
    # Test plugin flag handling
    run handle_plugin_flags
    [ $status -eq 0 ]
}