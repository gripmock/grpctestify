#!/bin/bash

# plugin_hooks.sh - Advanced Plugin Lifecycle Hooks System
# Enables plugins to hook into various system events and stages
# Dramatically enhances plugin capabilities with event-driven architecture

# Hook registry for different lifecycle events
declare -g -A PLUGIN_HOOKS=()          # hook_name -> "plugin1:function1,plugin2:function2"
declare -g -A HOOK_PRIORITIES=()       # hook_name:plugin_name -> priority (1-100)
declare -g -A HOOK_CONDITIONS=()       # hook_name:plugin_name -> condition_function
declare -g -A HOOK_FILTERS=()          # hook_name:plugin_name -> filter_function
declare -g -A HOOK_CONTEXTS=()         # hook_name -> shared_context_data

# Available lifecycle hooks
readonly HOOK_SYSTEM_STARTUP="system.startup"
readonly HOOK_SYSTEM_SHUTDOWN="system.shutdown"
readonly HOOK_TEST_BEFORE="test.before"
readonly HOOK_TEST_AFTER="test.after"
readonly HOOK_TEST_SETUP="test.setup"
readonly HOOK_TEST_TEARDOWN="test.teardown"
readonly HOOK_GRPC_BEFORE="grpc.before"
readonly HOOK_GRPC_AFTER="grpc.after"
readonly HOOK_ASSERTION_BEFORE="assertion.before"
readonly HOOK_ASSERTION_AFTER="assertion.after"
readonly HOOK_RESULT_PROCESS="result.process"
readonly HOOK_ERROR_HANDLE="error.handle"
readonly HOOK_PLUGIN_LOAD="plugin.load"
readonly HOOK_PLUGIN_UNLOAD="plugin.unload"

#######################################
# Register a plugin hook
# Arguments:
#   1: hook_name - name of lifecycle hook
#   2: plugin_name - name of plugin
#   3: function_name - function to call
#   4: priority - priority (1-100, 50 is default)
#   5: condition_function - optional condition function
# Returns:
#   0 on success, 1 on error
#######################################
plugin_hook_register() {
    local hook_name="$1"
    local plugin_name="$2"
    local function_name="$3"
    local priority="${4:-50}"
    local condition_function="${5:-}"
    
    if [[ -z "$hook_name" || -z "$plugin_name" || -z "$function_name" ]]; then
	tlog error "plugin_hook_register: hook_name, plugin_name, and function_name required"
        return 1
    fi
    
    # Validate priority
    if [[ ! "$priority" =~ ^[0-9]+$ ]] || [[ "$priority" -lt 1 ]] || [[ "$priority" -gt 100 ]]; then
	tlog error "plugin_hook_register: priority must be 1-100"
        return 1
    fi
    
    # Add to hook registry
    local current_hooks="${PLUGIN_HOOKS[$hook_name]:-}"
    if [[ -n "$current_hooks" ]]; then
        PLUGIN_HOOKS[$hook_name]="$current_hooks,$plugin_name:$function_name"
    else
        PLUGIN_HOOKS[$hook_name]="$plugin_name:$function_name"
    fi
    
    # Store priority and condition
    HOOK_PRIORITIES["$hook_name:$plugin_name"]="$priority"
    if [[ -n "$condition_function" ]]; then
        HOOK_CONDITIONS["$hook_name:$plugin_name"]="$condition_function"
    fi
    
    tlog debug "Registered hook: $hook_name -> $plugin_name:$function_name (priority: $priority)"
    return 0
}

#######################################
# Execute all registered hooks for an event
# Arguments:
#   1: hook_name - name of lifecycle hook
#   2: context_data - JSON context data (optional)
#   Rest: additional arguments passed to hook functions
# Returns:
#   0 on success, 1 if any hook failed
#######################################
plugin_hook_execute() {
    local hook_name="$1"
    local context_data="${2:-{}}"
    shift 2
    
    local hooks="${PLUGIN_HOOKS[$hook_name]:-}"
    if [[ -z "$hooks" ]]; then
	tlog debug "No hooks registered for: $hook_name"
        return 0
    fi
    
    # Store context data
    HOOK_CONTEXTS[$hook_name]="$context_data"
    
    # Parse and sort hooks by priority
    local hook_list=()
    IFS=',' read -ra hook_array <<< "$hooks"
    
    for hook_entry in "${hook_array[@]}"; do
        IFS=':' read -r plugin_name function_name <<< "$hook_entry"
        local priority="${HOOK_PRIORITIES["$hook_name:$plugin_name"]:-50}"
        hook_list+=("$priority:$plugin_name:$function_name")
    done
    
    # Sort by priority (higher priority first)
    IFS=$'\n' hook_list=($(sort -rn <<< "${hook_list[*]}"))
    
    tlog debug "Executing hooks for: $hook_name (${#hook_list[@]} hooks)"
    
    local failed_hooks=()
    for hook_entry in "${hook_list[@]}"; do
        IFS=':' read -r priority plugin_name function_name <<< "$hook_entry"
        
        # Check condition if specified
        local condition_function="${HOOK_CONDITIONS["$hook_name:$plugin_name"]:-}"
        if [[ -n "$condition_function" ]]; then
            if ! "$condition_function" "$context_data" "$@"; then
	        tlog debug "Hook condition not met: $plugin_name:$function_name"
                continue
            fi
        fi
        
        # Execute hook function
        tlog debug "Executing hook: $plugin_name:$function_name (priority: $priority)"
        
        if command -v "$function_name" >/dev/null 2>&1; then
            if ! "$function_name" "$context_data" "$@"; then
	        tlog warning "Hook failed: $plugin_name:$function_name"
                failed_hooks+=("$plugin_name:$function_name")
            fi
        else
	    tlog warning "Hook function not found: $function_name"
            failed_hooks+=("$plugin_name:$function_name")
        fi
    done
    
    if [[ ${#failed_hooks[@]} -gt 0 ]]; then
	tlog warning "Some hooks failed for $hook_name: ${failed_hooks[*]}"
        return 1
    fi
    
    return 0
}

#######################################
# Get hook context data
# Arguments:
#   1: hook_name - name of lifecycle hook
# Outputs:
#   Context data JSON
#######################################
plugin_hook_get_context() {
    local hook_name="$1"
    echo "${HOOK_CONTEXTS[$hook_name]:-{}}"
}

#######################################
# Set hook context data
# Arguments:
#   1: hook_name - name of lifecycle hook
#   2: context_data - JSON context data
#######################################
plugin_hook_set_context() {
    local hook_name="$1"
    local context_data="$2"
    HOOK_CONTEXTS[$hook_name]="$context_data"
}

#######################################
# List all registered hooks
# Outputs:
#   Hook information
#######################################
plugin_hook_list() {
    echo "Registered Plugin Hooks:"
    echo "========================"
    
    for hook_name in "${!PLUGIN_HOOKS[@]}"; do
        local hooks="${PLUGIN_HOOKS[$hook_name]}"
        echo "Hook: $hook_name"
        
        IFS=',' read -ra hook_array <<< "$hooks"
        for hook_entry in "${hook_array[@]}"; do
            IFS=':' read -r plugin_name function_name <<< "$hook_entry"
            local priority="${HOOK_PRIORITIES["$hook_name:$plugin_name"]:-50}"
            local condition="${HOOK_CONDITIONS["$hook_name:$plugin_name"]:-none}"
            echo "  - $plugin_name:$function_name (priority: $priority, condition: $condition)"
        done
        echo ""
    done
}

#######################################
# Unregister a plugin hook
# Arguments:
#   1: hook_name - name of lifecycle hook
#   2: plugin_name - name of plugin
# Returns:
#   0 on success, 1 on error
#######################################
plugin_hook_unregister() {
    local hook_name="$1"
    local plugin_name="$2"
    
    if [[ -z "$hook_name" || -z "$plugin_name" ]]; then
	tlog error "plugin_hook_unregister: hook_name and plugin_name required"
        return 1
    fi
    
    local current_hooks="${PLUGIN_HOOKS[$hook_name]:-}"
    if [[ -z "$current_hooks" ]]; then
        return 0  # Nothing to unregister
    fi
    
    # Remove from hook registry
    local new_hooks=""
    IFS=',' read -ra hook_array <<< "$current_hooks"
    
    for hook_entry in "${hook_array[@]}"; do
        IFS=':' read -r entry_plugin entry_function <<< "$hook_entry"
        if [[ "$entry_plugin" != "$plugin_name" ]]; then
            if [[ -n "$new_hooks" ]]; then
                new_hooks="$new_hooks,$hook_entry"
            else
                new_hooks="$hook_entry"
            fi
        fi
    done
    
    if [[ -n "$new_hooks" ]]; then
        PLUGIN_HOOKS[$hook_name]="$new_hooks"
    else
        unset PLUGIN_HOOKS[$hook_name]
    fi
    
    # Clean up related data
    unset HOOK_PRIORITIES["$hook_name:$plugin_name"]
    unset HOOK_CONDITIONS["$hook_name:$plugin_name"]
    
    tlog debug "Unregistered hook: $hook_name -> $plugin_name"
    return 0
}

# Export hook functions
export -f plugin_hook_register
export -f plugin_hook_execute
export -f plugin_hook_get_context
export -f plugin_hook_set_context
export -f plugin_hook_list
export -f plugin_hook_unregister


