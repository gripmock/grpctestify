#!/bin/bash

# enhanced_plugin_api.sh - Enhanced Plugin API for maximal extensibility
# Provides comprehensive hooks and access points for plugins to extend any aspect of grpctestify

# Plugin API Version is defined in config.sh

# Plugin Hook Types
readonly HOOK_TYPE_FILTER="filter"           # Modify data passing through
readonly HOOK_TYPE_ACTION="action"           # Execute action at specific point
readonly HOOK_TYPE_PROVIDER="provider"       # Provide data/service
readonly HOOK_TYPE_LISTENER="listener"       # Listen to events
readonly HOOK_TYPE_MIDDLEWARE="middleware"   # Process requests/responses

# Global Hook Registry
declare -g -A PLUGIN_HOOKS=()              # hook_name -> array of plugin_handlers
declare -g -A PLUGIN_HOOK_PRIORITIES=()    # hook_name:plugin_name -> priority
declare -g -A PLUGIN_CAPABILITIES=()       # plugin_name -> capability_list

# Enhanced Plugin Registration with Capabilities
plugin_register_enhanced() {
    local plugin_name="$1"
    local plugin_handler="$2" 
    local plugin_description="$3"
    local plugin_type="${4:-external}"
    local capabilities="${5:-}"
    local hooks="${6:-}"
    
    # Basic registration
    plugin_register "$plugin_name" "$plugin_handler" "$plugin_description" "$plugin_type"
    
    # Register capabilities
    if [[ -n "$capabilities" ]]; then
        PLUGIN_CAPABILITIES["$plugin_name"]="$capabilities"
    tlog debug "Plugin '$plugin_name' registered with capabilities: $capabilities"
    fi
    
    # Register hooks if provided
    if [[ -n "$hooks" ]]; then
        IFS=',' read -ra HOOK_LIST <<< "$hooks"
        for hook_info in "${HOOK_LIST[@]}"; do
            IFS=':' read -r hook_name priority <<< "$hook_info"
            plugin_hook_register "$plugin_name" "$hook_name" "${priority:-50}"
        done
    fi
}

# Hook Registration System
plugin_hook_register() {
    local plugin_name="$1"
    local hook_name="$2"
    local priority="${3:-50}"
    
    # Initialize hook if not exists
    if [[ -z "${PLUGIN_HOOKS[$hook_name]:-}" ]]; then
        PLUGIN_HOOKS["$hook_name"]=""
    fi
    
    # Add plugin to hook with priority
    PLUGIN_HOOK_PRIORITIES["$hook_name:$plugin_name"]="$priority"
    
    # Add to hook list (will be sorted by priority later)
    if [[ -z "${PLUGIN_HOOKS[$hook_name]}" ]]; then
        PLUGIN_HOOKS["$hook_name"]="$plugin_name"
    else
        PLUGIN_HOOKS["$hook_name"]="${PLUGIN_HOOKS[$hook_name]},$plugin_name"
    fi
    
    tlog debug "Plugin '$plugin_name' registered for hook '$hook_name' with priority $priority"
}

# Execute Hook with Data Pipeline
plugin_hook_execute() {
    local hook_name="$1"
    local hook_type="$2"
    shift 2
    local hook_data="$*"
    
    # Get plugins for this hook, sorted by priority
    local hook_plugins
    hook_plugins=$(plugin_hook_get_sorted_plugins "$hook_name")
    
    if [[ -z "$hook_plugins" ]]; then
        # No plugins for this hook, return original data
        echo "$hook_data"
        return 0
    fi
    
    tlog debug "Executing hook '$hook_name' ($hook_type) with ${#hook_plugins[@]} plugins"
    
    local current_data="$hook_data"
    local plugin_result
    
    IFS=',' read -ra PLUGIN_LIST <<< "$hook_plugins"
    for plugin_name in "${PLUGIN_LIST[@]}"; do
        if plugin_exists "$plugin_name"; then
            case "$hook_type" in
                "$HOOK_TYPE_FILTER")
                    # Data flows through plugins, each can modify it
                    if plugin_result=$(plugin_execute "$plugin_name" "hook:$hook_name" "$current_data"); then
                        current_data="$plugin_result"
                    else
    tlog warning "Plugin '$plugin_name' failed in hook '$hook_name'"
                    fi
                    ;;
                "$HOOK_TYPE_ACTION")
                    # Plugins execute actions but don't modify data
                    plugin_execute "$plugin_name" "hook:$hook_name" "$current_data" >/dev/null
                    ;;
                "$HOOK_TYPE_PROVIDER")
                    # First successful plugin provides the data
                    if plugin_result=$(plugin_execute "$plugin_name" "hook:$hook_name" "$current_data"); then
                        echo "$plugin_result"
                        return 0
                    fi
                    ;;
                "$HOOK_TYPE_LISTENER")
                    # Plugins just receive notifications
                    plugin_execute "$plugin_name" "hook:$hook_name" "$current_data" &
                    ;;
                "$HOOK_TYPE_MIDDLEWARE")
                    # Complex middleware pattern
                    if plugin_result=$(plugin_execute "$plugin_name" "middleware:before:$hook_name" "$current_data"); then
                        current_data="$plugin_result"
                    fi
                    ;;
            esac
        fi
    done
    
    echo "$current_data"
}

# Get plugins for hook sorted by priority
plugin_hook_get_sorted_plugins() {
    local hook_name="$1"
    local hook_plugins="${PLUGIN_HOOKS[$hook_name]:-}"
    
    if [[ -z "$hook_plugins" ]]; then
        return 0
    fi
    
    # Simple priority sort (higher priority = earlier execution)
    IFS=',' read -ra PLUGIN_LIST <<< "$hook_plugins"
    local sorted_plugins=()
    
    # Create array of plugin:priority pairs
    local plugin_priorities=()
    for plugin_name in "${PLUGIN_LIST[@]}"; do
        local priority="${PLUGIN_HOOK_PRIORITIES[$hook_name:$plugin_name]:-50}"
        plugin_priorities+=("$priority:$plugin_name")
    done
    
    # Sort by priority (descending)
    IFS=$'\n' plugin_priorities=($(sort -nr <<< "${plugin_priorities[*]}"))
    
    # Extract plugin names
    for entry in "${plugin_priorities[@]}"; do
        IFS=':' read -r _ plugin_name <<< "$entry"
        sorted_plugins+=("$plugin_name")
    done
    
    # Join with commas
    local result
    printf -v result '%s,' "${sorted_plugins[@]}"
    echo "${result%,}"
}

# Comprehensive Hook Points for grpctestify

# Configuration Hooks
plugin_hook_config_load() {
    plugin_hook_execute "config.load" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_config_validate() {
    plugin_hook_execute "config.validate" "$HOOK_TYPE_FILTER" "$@"
}

# Test Discovery Hooks
plugin_hook_test_discovery_start() {
    plugin_hook_execute "test.discovery.start" "$HOOK_TYPE_ACTION" "$@"
}

plugin_hook_test_file_filter() {
    plugin_hook_execute "test.file.filter" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_test_file_parse() {
    plugin_hook_execute "test.file.parse" "$HOOK_TYPE_FILTER" "$@"
}

# Test Execution Hooks
plugin_hook_test_before_suite() {
    plugin_hook_execute "test.before.suite" "$HOOK_TYPE_ACTION" "$@"
}

plugin_hook_test_before_each() {
    plugin_hook_execute "test.before.each" "$HOOK_TYPE_ACTION" "$@"
}

plugin_hook_test_execute() {
    plugin_hook_execute "test.execute" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_test_after_each() {
    plugin_hook_execute "test.after.each" "$HOOK_TYPE_ACTION" "$@"
}

plugin_hook_test_after_suite() {
    plugin_hook_execute "test.after.suite" "$HOOK_TYPE_ACTION" "$@"
}

# gRPC Communication Hooks
plugin_hook_grpc_request_prepare() {
    plugin_hook_execute "grpc.request.prepare" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_grpc_request_send() {
    plugin_hook_execute "grpc.request.send" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_grpc_response_receive() {
    plugin_hook_execute "grpc.response.receive" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_grpc_response_validate() {
    plugin_hook_execute "grpc.response.validate" "$HOOK_TYPE_FILTER" "$@"
}

# Assertion Hooks
plugin_hook_assertion_before() {
    plugin_hook_execute "assertion.before" "$HOOK_TYPE_ACTION" "$@"
}

plugin_hook_assertion_execute() {
    plugin_hook_execute "assertion.execute" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_assertion_after() {
    plugin_hook_execute "assertion.after" "$HOOK_TYPE_ACTION" "$@"
}

# Reporting Hooks
plugin_hook_report_generate() {
    plugin_hook_execute "report.generate" "$HOOK_TYPE_ACTION" "$@"
}

plugin_hook_report_format() {
    plugin_hook_execute "report.format" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_report_output() {
    plugin_hook_execute "report.output" "$HOOK_TYPE_ACTION" "$@"
}

# UI/UX Hooks
plugin_hook_ui_progress_update() {
    plugin_hook_execute "ui.progress.update" "$HOOK_TYPE_ACTION" "$@"
}

plugin_hook_ui_message_format() {
    plugin_hook_execute "ui.message.format" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_ui_error_display() {
    plugin_hook_execute "ui.error.display" "$HOOK_TYPE_ACTION" "$@"
}

# State Management Hooks
plugin_hook_state_read() {
    plugin_hook_execute "state.read" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_state_write() {
    plugin_hook_execute "state.write" "$HOOK_TYPE_FILTER" "$@"
}

plugin_hook_state_change() {
    plugin_hook_execute "state.change" "$HOOK_TYPE_LISTENER" "$@"
}

# Error Handling Hooks
plugin_hook_error_occurred() {
    plugin_hook_execute "error.occurred" "$HOOK_TYPE_LISTENER" "$@"
}

plugin_hook_error_recovery() {
    plugin_hook_execute "error.recovery" "$HOOK_TYPE_PROVIDER" "$@"
}

# Cleanup Hooks
plugin_hook_cleanup_start() {
    plugin_hook_execute "cleanup.start" "$HOOK_TYPE_ACTION" "$@"
}

plugin_hook_cleanup_complete() {
    plugin_hook_execute "cleanup.complete" "$HOOK_TYPE_ACTION" "$@"
}

# Plugin Capability System
plugin_has_capability() {
    local plugin_name="$1"
    local capability="$2"
    
    local capabilities="${PLUGIN_CAPABILITIES[$plugin_name]:-}"
    [[ "$capabilities" == *"$capability"* ]]
}

plugin_list_capabilities() {
    local plugin_name="$1"
    echo "${PLUGIN_CAPABILITIES[$plugin_name]:-none}"
}

# Enhanced Plugin Information
plugin_info_enhanced() {
    local plugin_name="$1"
    
    if ! plugin_exists "$plugin_name"; then
        echo "Plugin '$plugin_name' not found"
        return 1
    fi
    
    echo "Plugin: $plugin_name"
    echo "Status: $(plugin_get_state "$plugin_name")"
    echo "Capabilities: $(plugin_list_capabilities "$plugin_name")"
    
    # List hooks this plugin is registered for
    echo "Hooks:"
    for hook_name in "${!PLUGIN_HOOKS[@]}"; do
        if [[ "${PLUGIN_HOOKS[$hook_name]}" == *"$plugin_name"* ]]; then
            local priority="${PLUGIN_HOOK_PRIORITIES[$hook_name:$plugin_name]:-50}"
            echo "  - $hook_name (priority: $priority)"
        fi
    done
}

# Export enhanced plugin API functions
export -f plugin_register_enhanced plugin_hook_register plugin_hook_execute
export -f plugin_hook_get_sorted_plugins plugin_has_capability plugin_list_capabilities
export -f plugin_info_enhanced

# Export all hook functions
export -f plugin_hook_config_load plugin_hook_config_validate
export -f plugin_hook_test_discovery_start plugin_hook_test_file_filter plugin_hook_test_file_parse
export -f plugin_hook_test_before_suite plugin_hook_test_before_each plugin_hook_test_execute
export -f plugin_hook_test_after_each plugin_hook_test_after_suite
export -f plugin_hook_grpc_request_prepare plugin_hook_grpc_request_send
export -f plugin_hook_grpc_response_receive plugin_hook_grpc_response_validate
export -f plugin_hook_assertion_before plugin_hook_assertion_execute plugin_hook_assertion_after
export -f plugin_hook_report_generate plugin_hook_report_format plugin_hook_report_output
export -f plugin_hook_ui_progress_update plugin_hook_ui_message_format plugin_hook_ui_error_display
export -f plugin_hook_state_read plugin_hook_state_write plugin_hook_state_change
export -f plugin_hook_error_occurred plugin_hook_error_recovery
export -f plugin_hook_cleanup_start plugin_hook_cleanup_complete
