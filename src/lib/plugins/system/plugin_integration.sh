#!/bin/bash

# plugin_integration.sh - Integration layer between plugins and microkernel
# Provides unified API for plugins to interact with microkernel components

# Source microkernel components
# These will be loaded by bashly automatically
# source "$(dirname "${BASH_SOURCE[0]}")/routine_manager.sh"
# source "$(dirname "${BASH_SOURCE[0]}")/resource_pool.sh"
# source "$(dirname "${BASH_SOURCE[0]}")/health_monitor.sh"
# source "$(dirname "${BASH_SOURCE[0]}")/event_system.sh"
# source "$(dirname "${BASH_SOURCE[0]}")/state_database.sh"
# source "$(dirname "${BASH_SOURCE[0]}")/routine_health.sh"

# Global plugin registry
declare -g -A PLUGIN_REGISTRY=()         # plugin_name -> plugin_info
declare -g -A PLUGIN_HANDLERS=()         # plugin_name -> handler_function
declare -g -A PLUGIN_DEPENDENCIES=()     # plugin_name -> dependency_list
declare -g -A PLUGIN_METADATA=()         # plugin_name -> metadata_json
declare -g -A PLUGIN_ROUTINES=()         # plugin_name -> routine_ids
declare -g -A PLUGIN_RESOURCES=()        # plugin_name -> resource_pool_names
declare -g PLUGIN_INTEGRATION_INITIALIZED=false  # Initialization guard

# Plugin lifecycle states
readonly PLUGIN_STATE_UNLOADED="unloaded"
readonly PLUGIN_STATE_LOADING="loading"
readonly PLUGIN_STATE_LOADED="loaded"
readonly PLUGIN_STATE_ACTIVE="active"
readonly PLUGIN_STATE_ERROR="error"
readonly PLUGIN_STATE_DISABLED="disabled"

# Initialize plugin integration system
plugin_integration_init() {
    # Check if already initialized
    if [[ "${PLUGIN_INTEGRATION_INITIALIZED:-false}" == "true" ]]; then
        tlog debug "Plugin integration system already initialized, skipping..."
        return 0
    fi
    
    tlog debug "Initializing plugin integration system..."
    
    # Initialize microkernel components
    if ! routine_health_init; then
    tlog error "Failed to initialize routine health system"
        return 1
    fi
    
    if ! event_system_init; then
    tlog error "Failed to initialize event system"
        return 1
    fi
    
    if ! state_db_init; then
    tlog error "Failed to initialize state database"
        return 1
    fi
    
    # Create default resource pools for plugins
    pool_create "plugin_execution" 4    # Default parallel plugin execution
    pool_create "plugin_io" 2           # Plugin I/O operations
    
    # Setup plugin event subscriptions
    event_subscribe "plugin_manager" "plugin.*" "plugin_event_handler"
    
    PLUGIN_INTEGRATION_INITIALIZED=true
    tlog debug "Plugin integration system initialized successfully"
    return 0
}

# Register a plugin with the microkernel
plugin_register() {
    local plugin_name="$1"
    local handler_function="$2"
    local plugin_description="$3"
    local plugin_type="${4:-external}"  # internal|external
    local dependencies="${5:-}"
    
    if [[ -z "$plugin_name" || -z "$handler_function" ]]; then
    tlog error "plugin_register: plugin_name and handler_function required"
        return 1
    fi
    
    # Check if handler function exists
    if ! command -v "$handler_function" >/dev/null 2>&1; then
    tlog error "Plugin handler function '$handler_function' not found"
        return 1
    fi
    
    tlog debug "Registering plugin '$plugin_name' with handler '$handler_function'"
    
    # Store plugin information
    PLUGIN_REGISTRY["$plugin_name"]="type:$plugin_type,description:$plugin_description,state:$PLUGIN_STATE_LOADED"
    PLUGIN_HANDLERS["$plugin_name"]="$handler_function"
    [[ -n "$dependencies" ]] && PLUGIN_DEPENDENCIES["$plugin_name"]="$dependencies"
    
    # Create plugin metadata
    local metadata
    metadata=$(cat << EOF
{
  "name": "$plugin_name",
  "description": "$plugin_description",
  "type": "$plugin_type",
  "handler": "$handler_function",
  "dependencies": "$dependencies",
  "registered_at": $(date +%s),
  "state": "$PLUGIN_STATE_LOADED"
}
EOF
)
    PLUGIN_METADATA["$plugin_name"]="$metadata"
    
    # Publish plugin registration event
    event_publish "plugin.registered" "$metadata" "$EVENT_PRIORITY_NORMAL" "plugin_manager"
    
    tlog debug "Plugin '$plugin_name' registered successfully"
    return 0
}

# Execute plugin with microkernel integration
plugin_execute() {
    local plugin_name="$1"
    shift
    local args=("$@")
    
    if [[ -z "$plugin_name" ]]; then
    tlog error "plugin_execute: plugin_name required"
        return 1
    fi
    
    # Check if plugin is registered
    local handler_function="${PLUGIN_HANDLERS[$plugin_name]:-}"
    if [[ -z "$handler_function" ]]; then
    tlog error "Plugin '$plugin_name' not registered"
        return 1
    fi
    
    tlog debug "Executing plugin '$plugin_name' with microkernel integration"
    
    # Update plugin state
    plugin_set_state "$plugin_name" "$PLUGIN_STATE_ACTIVE"
    
    # Acquire resource for plugin execution
    local resource_token
    resource_token=$(pool_acquire "plugin_execution" 30)
    if [[ $? -ne 0 ]]; then
    tlog error "Failed to acquire execution resource for plugin '$plugin_name'"
        plugin_set_state "$plugin_name" "$PLUGIN_STATE_ERROR"
        return 1
    fi
    
    # Execute plugin in monitored routine
    local routine_id
    routine_id=$(plugin_execute_monitored "$plugin_name" "$handler_function" "${args[@]}")
    local exit_code=$?
    
    # Release resource
    pool_release "plugin_execution" "$resource_token"
    
    # Update plugin state based on execution result
    if [[ $exit_code -eq 0 ]]; then
        plugin_set_state "$plugin_name" "$PLUGIN_STATE_LOADED"
    tlog debug "Plugin '$plugin_name' executed successfully"
    else
        plugin_set_state "$plugin_name" "$PLUGIN_STATE_ERROR"
    tlog error "Plugin '$plugin_name' execution failed with exit code $exit_code"
    fi
    
    return $exit_code
}

# Execute plugin in monitored routine
plugin_execute_monitored() {
    local plugin_name="$1"
    local handler_function="$2"
    shift 2
    local args=("$@")
    
    # Create wrapper command for plugin execution
    local plugin_command="plugin_execution_wrapper '$plugin_name' '$handler_function'"
    for arg in "${args[@]}"; do
        plugin_command="$plugin_command '$(printf '%q' "$arg")'"
    done
    
    # Spawn monitored routine
    local routine_id
    routine_id=$(routine_spawn_monitored "$plugin_command" "plugin_${plugin_name}_$$" "command" "true" 30 3)
    
    if [[ $? -ne 0 ]]; then
    tlog error "Failed to spawn monitored routine for plugin '$plugin_name'"
        return 1
    fi
    
    # Track routine for this plugin
    local current_routines="${PLUGIN_ROUTINES[$plugin_name]:-}"
    if [[ -z "$current_routines" ]]; then
        PLUGIN_ROUTINES["$plugin_name"]="$routine_id"
    else
        PLUGIN_ROUTINES["$plugin_name"]="$current_routines,$routine_id"
    fi
    
    # Wait for routine completion
    local wait_result
    routine_wait "$routine_id" 60  # 1 minute timeout
    wait_result=$?
    
    # Remove routine from tracking
    plugin_remove_routine "$plugin_name" "$routine_id"
    
    return $wait_result
}

# Plugin execution wrapper
plugin_execution_wrapper() {
    local plugin_name="$1"
    local handler_function="$2"
    shift 2
    local args=("$@")
    
    # Setup plugin context
    export PLUGIN_NAME="$plugin_name"
    export PLUGIN_ROUTINE_ID="${routine_id:-unknown}"
    
    # Publish plugin execution start event
    event_publish "plugin.execution.start" "{\"plugin\":\"$plugin_name\",\"routine\":\"$PLUGIN_ROUTINE_ID\"}" "$EVENT_PRIORITY_NORMAL" "$plugin_name"
    
    # Execute the actual plugin handler
    local exit_code=0
    if "$handler_function" "${args[@]}"; then
    tlog debug "Plugin '$plugin_name' handler executed successfully"
        # Publish success event
        event_publish "plugin.execution.success" "{\"plugin\":\"$plugin_name\",\"routine\":\"$PLUGIN_ROUTINE_ID\"}" "$EVENT_PRIORITY_NORMAL" "$plugin_name"
    else
        exit_code=$?
    tlog error "Plugin '$plugin_name' handler failed with exit code $exit_code"
        # Publish failure event
        event_publish "plugin.execution.failure" "{\"plugin\":\"$plugin_name\",\"routine\":\"$PLUGIN_ROUTINE_ID\",\"exit_code\":$exit_code}" "$EVENT_PRIORITY_HIGH" "$plugin_name"
    fi
    
    return $exit_code
}

# Set plugin state
plugin_set_state() {
    local plugin_name="$1"
    local new_state="$2"
    
    if [[ -z "$plugin_name" || -z "$new_state" ]]; then
    tlog error "plugin_set_state: plugin_name and new_state required"
        return 1
    fi
    
    local current_info="${PLUGIN_REGISTRY[$plugin_name]:-}"
    if [[ -z "$current_info" ]]; then
    tlog error "Plugin '$plugin_name' not found in registry"
        return 1
    fi
    
    # Update state in registry
    local updated_info
    updated_info=$(echo "$current_info" | sed "s/state:[^,]*/state:$new_state/")
    PLUGIN_REGISTRY["$plugin_name"]="$updated_info"
    
    # Update metadata
    local updated_metadata
    updated_metadata=$(echo "${PLUGIN_METADATA[$plugin_name]}" | sed "s/\"state\": \"[^\"]*\"/\"state\": \"$new_state\"/")
    PLUGIN_METADATA["$plugin_name"]="$updated_metadata"
    
    # Publish state change event
    event_publish "plugin.state.changed" "{\"plugin\":\"$plugin_name\",\"state\":\"$new_state\"}" "$EVENT_PRIORITY_NORMAL" "plugin_manager"
    
    tlog debug "Plugin '$plugin_name' state changed to '$new_state'"
    return 0
}

# Get plugin state
plugin_get_state() {
    local plugin_name="$1"
    
    if [[ -z "$plugin_name" ]]; then
    tlog error "plugin_get_state: plugin_name required"
        return 1
    fi
    
    local plugin_info="${PLUGIN_REGISTRY[$plugin_name]:-}"
    if [[ -z "$plugin_info" ]]; then
        echo "$PLUGIN_STATE_UNLOADED"
        return 1
    fi
    
    # Extract state from plugin info
    echo "$plugin_info" | sed -n 's/.*state:\([^,]*\).*/\1/p'
    return 0
}

# Remove routine from plugin tracking
plugin_remove_routine() {
    local plugin_name="$1"
    local routine_id="$2"
    
    local current_routines="${PLUGIN_ROUTINES[$plugin_name]:-}"
    if [[ -z "$current_routines" ]]; then
        return 0
    fi
    
    # Remove routine from comma-separated list
    local new_routines=""
    IFS=',' read -ra ADDR <<< "$current_routines"
    for routine in "${ADDR[@]}"; do
        if [[ "$routine" != "$routine_id" ]]; then
            [[ -z "$new_routines" ]] && new_routines="$routine" || new_routines="$new_routines,$routine"
        fi
    done
    
    if [[ -z "$new_routines" ]]; then
        unset PLUGIN_ROUTINES["$plugin_name"]
    else
        PLUGIN_ROUTINES["$plugin_name"]="$new_routines"
    fi
    
    return 0
}

# List all registered plugins
plugin_list() {
    local format="${1:-summary}"  # summary|detailed|json
    
    if [[ ${#PLUGIN_REGISTRY[@]} -eq 0 ]]; then
        echo "No plugins registered"
        return 0
    fi
    
    case "$format" in
        "summary")
            printf "%-20s %-15s %-10s %-30s\n" "PLUGIN_NAME" "STATE" "TYPE" "DESCRIPTION"
            printf "%-20s %-15s %-10s %-30s\n" "--------------------" "---------------" "----------" "------------------------------"
            
            for plugin_name in "${!PLUGIN_REGISTRY[@]}"; do
                local plugin_info="${PLUGIN_REGISTRY[$plugin_name]}"
                local state
                local plugin_type
                local description
                
                state=$(echo "$plugin_info" | sed -n 's/.*state:\([^,]*\).*/\1/p')
                plugin_type=$(echo "$plugin_info" | sed -n 's/.*type:\([^,]*\).*/\1/p')
                description=$(echo "$plugin_info" | sed -n 's/.*description:\([^,]*\).*/\1/p')
                
                # Truncate description if too long
                [[ ${#description} -gt 30 ]] && description="${description:0:27}..."
                
                printf "%-20s %-15s %-10s %-30s\n" "$plugin_name" "$state" "$plugin_type" "$description"
            done
            ;;
        "detailed")
            for plugin_name in "${!PLUGIN_REGISTRY[@]}"; do
                local plugin_info="${PLUGIN_REGISTRY[$plugin_name]}"
                local handler="${PLUGIN_HANDLERS[$plugin_name]}"
                local dependencies="${PLUGIN_DEPENDENCIES[$plugin_name]:-none}"
                local routines="${PLUGIN_ROUTINES[$plugin_name]:-none}"
                
                echo "Plugin: $plugin_name"
                echo "  Info: $plugin_info"
                echo "  Handler: $handler"
                echo "  Dependencies: $dependencies"
                echo "  Active Routines: $routines"
                echo
            done
            ;;
        "json")
            echo "["
            local first=true
            for plugin_name in "${!PLUGIN_REGISTRY[@]}"; do
                [[ "$first" == "true" ]] && first=false || echo ","
                echo "  ${PLUGIN_METADATA[$plugin_name]}"
            done
            echo "]"
            ;;
    esac
}

# Plugin event handler
plugin_event_handler() {
    local event_message="$1"
    
    # Simple event logging for now
    tlog debug "Plugin event received: $event_message"
    
    # Could implement more sophisticated event handling here
    # - Plugin dependency resolution
    # - Automatic plugin restart on failure
    # - Plugin health monitoring
    
    return 0
}

# Check if plugin exists
plugin_exists() {
    local plugin_name="$1"
    [[ -n "${PLUGIN_REGISTRY[$plugin_name]:-}" ]]
}

# Get plugin statistics
plugin_stats() {
    local total_plugins=${#PLUGIN_REGISTRY[@]}
    local active_plugins=0
    local error_plugins=0
    local total_routines=0
    
    for plugin_name in "${!PLUGIN_REGISTRY[@]}"; do
        local state
        state=$(plugin_get_state "$plugin_name")
        
        case "$state" in
            "$PLUGIN_STATE_ACTIVE") ((active_plugins++)) ;;
            "$PLUGIN_STATE_ERROR") ((error_plugins++)) ;;
        esac
        
        local routines="${PLUGIN_ROUTINES[$plugin_name]:-}"
        if [[ -n "$routines" ]]; then
            local routine_count
            routine_count=$(echo "$routines" | tr ',' '\n' | wc -l)
            total_routines=$((total_routines + routine_count))
        fi
    done
    
    echo "Total Plugins: $total_plugins, Active: $active_plugins, Error: $error_plugins, Active Routines: $total_routines"
}

# Cleanup plugin integration system
plugin_integration_cleanup() {
    tlog debug "Cleaning up plugin integration system..."
    
    # Stop all plugin routines
    for plugin_name in "${!PLUGIN_ROUTINES[@]}"; do
        local routines="${PLUGIN_ROUTINES[$plugin_name]}"
        if [[ -n "$routines" ]]; then
            IFS=',' read -ra ADDR <<< "$routines"
            for routine_id in "${ADDR[@]}"; do
                routine_kill "$routine_id" 2>/dev/null || true
            done
        fi
    done
    
    # Cleanup microkernel components
    routine_health_cleanup
    event_system_cleanup
    state_db_cleanup
    
    tlog debug "Plugin integration system cleaned up"
}

# Export functions
export -f plugin_integration_init plugin_register plugin_execute plugin_execute_monitored
export -f plugin_execution_wrapper plugin_set_state plugin_get_state plugin_remove_routine
export -f plugin_list plugin_event_handler plugin_exists plugin_stats plugin_integration_cleanup
