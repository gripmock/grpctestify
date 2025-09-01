#!/bin/bash

# plugin_context.sh - Shared Plugin Context System
# Enables data sharing and communication between plugins
# Provides persistent and session-based data storage

# Context storage
declare -g -A PLUGIN_GLOBAL_CONTEXT=()    # Global shared data
declare -g -A PLUGIN_SESSION_CONTEXT=()   # Session-specific data
declare -g -A PLUGIN_TEST_CONTEXT=()      # Per-test data
declare -g -A PLUGIN_PRIVATE_CONTEXT=()   # Plugin-private data

# Context metadata
declare -g -A CONTEXT_TIMESTAMPS=()       # key -> last_modified_timestamp
declare -g -A CONTEXT_OWNERS=()           # key -> plugin_name
declare -g -A CONTEXT_PERMISSIONS=()      # key -> read_write|read_only|private

# Context scopes
readonly CONTEXT_SCOPE_GLOBAL="global"
readonly CONTEXT_SCOPE_SESSION="session"
readonly CONTEXT_SCOPE_TEST="test"
readonly CONTEXT_SCOPE_PRIVATE="private"

#######################################
# Set data in plugin context
# Arguments:
#   1: scope - context scope (global|session|test|private)
#   2: key - data key
#   3: value - data value
#   4: plugin_name - plugin setting the data
#   5: permission - read_write|read_only|private (default: read_write)
# Returns:
#   0 on success, 1 on error
#######################################
plugin_context_set() {
    local scope="$1"
    local key="$2"
    local value="$3"
    local plugin_name="$4"
    local permission="${5:-read_write}"
    
    if [[ -z "$scope" || -z "$key" || -z "$plugin_name" ]]; then
	tlog error "plugin_context_set: scope, key, and plugin_name required"
        return 1
    fi
    
    # Validate scope
    case "$scope" in
        "$CONTEXT_SCOPE_GLOBAL"|"$CONTEXT_SCOPE_SESSION"|"$CONTEXT_SCOPE_TEST"|"$CONTEXT_SCOPE_PRIVATE") ;;
        *)
	    tlog error "plugin_context_set: invalid scope '$scope'"
            return 1
            ;;
    esac
    
    # Check if key already exists and if plugin has permission to modify
    local full_key="${scope}:${key}"
    local existing_owner="${CONTEXT_OWNERS[$full_key]:-}"
    local existing_permission="${CONTEXT_PERMISSIONS[$full_key]:-read_write}"
    
    if [[ -n "$existing_owner" && "$existing_owner" != "$plugin_name" ]]; then
        if [[ "$existing_permission" == "read_only" || "$existing_permission" == "private" ]]; then
	    tlog error "plugin_context_set: permission denied for key '$key' (owned by $existing_owner, permission: $existing_permission)"
            return 1
        fi
    fi
    
    # Store data in appropriate context
    case "$scope" in
        "$CONTEXT_SCOPE_GLOBAL")
            PLUGIN_GLOBAL_CONTEXT[$key]="$value"
            ;;
        "$CONTEXT_SCOPE_SESSION")
            PLUGIN_SESSION_CONTEXT[$key]="$value"
            ;;
        "$CONTEXT_SCOPE_TEST")
            PLUGIN_TEST_CONTEXT[$key]="$value"
            ;;
        "$CONTEXT_SCOPE_PRIVATE")
            PLUGIN_PRIVATE_CONTEXT["${plugin_name}:${key}"]="$value"
            ;;
    esac
    
    # Store metadata
    CONTEXT_TIMESTAMPS[$full_key]=$(date +%s)
    CONTEXT_OWNERS[$full_key]="$plugin_name"
    CONTEXT_PERMISSIONS[$full_key]="$permission"
    
    tlog debug "Plugin context set: $scope:$key by $plugin_name (permission: $permission)"
    return 0
}

#######################################
# Get data from plugin context
# Arguments:
#   1: scope - context scope (global|session|test|private)
#   2: key - data key
#   3: plugin_name - plugin requesting the data
# Returns:
#   0 on success, 1 on error
# Outputs:
#   Data value
#######################################
plugin_context_get() {
    local scope="$1"
    local key="$2"
    local plugin_name="$3"
    
    if [[ -z "$scope" || -z "$key" || -z "$plugin_name" ]]; then
	tlog error "plugin_context_get: scope, key, and plugin_name required"
        return 1
    fi
    
    # Check permissions
    local full_key="${scope}:${key}"
    local owner="${CONTEXT_OWNERS[$full_key]:-}"
    local permission="${CONTEXT_PERMISSIONS[$full_key]:-read_write}"
    
    if [[ "$permission" == "private" && "$owner" != "$plugin_name" ]]; then
	tlog error "plugin_context_get: permission denied for private key '$key'"
        return 1
    fi
    
    # Retrieve data from appropriate context
    local value=""
    case "$scope" in
        "$CONTEXT_SCOPE_GLOBAL")
            value="${PLUGIN_GLOBAL_CONTEXT[$key]:-}"
            ;;
        "$CONTEXT_SCOPE_SESSION")
            value="${PLUGIN_SESSION_CONTEXT[$key]:-}"
            ;;
        "$CONTEXT_SCOPE_TEST")
            value="${PLUGIN_TEST_CONTEXT[$key]:-}"
            ;;
        "$CONTEXT_SCOPE_PRIVATE")
            value="${PLUGIN_PRIVATE_CONTEXT["${plugin_name}:${key}"]:-}"
            ;;
        *)
	    tlog error "plugin_context_get: invalid scope '$scope'"
            return 1
            ;;
    esac
    
    echo "$value"
    return 0
}

#######################################
# Check if context key exists
# Arguments:
#   1: scope - context scope
#   2: key - data key
#   3: plugin_name - plugin checking existence
# Returns:
#   0 if exists, 1 if not
#######################################
plugin_context_exists() {
    local scope="$1"
    local key="$2"
    local plugin_name="$3"
    
    # Check permissions first
    local full_key="${scope}:${key}"
    local permission="${CONTEXT_PERMISSIONS[$full_key]:-read_write}"
    local owner="${CONTEXT_OWNERS[$full_key]:-}"
    
    if [[ "$permission" == "private" && "$owner" != "$plugin_name" ]]; then
        return 1  # Act as if it doesn't exist for private data
    fi
    
    case "$scope" in
        "$CONTEXT_SCOPE_GLOBAL")
            [[ -n "${PLUGIN_GLOBAL_CONTEXT[$key]:-}" ]]
            ;;
        "$CONTEXT_SCOPE_SESSION")
            [[ -n "${PLUGIN_SESSION_CONTEXT[$key]:-}" ]]
            ;;
        "$CONTEXT_SCOPE_TEST")
            [[ -n "${PLUGIN_TEST_CONTEXT[$key]:-}" ]]
            ;;
        "$CONTEXT_SCOPE_PRIVATE")
            [[ -n "${PLUGIN_PRIVATE_CONTEXT["${plugin_name}:${key}"]:-}" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

#######################################
# Clear test-specific context data
# Called at the beginning/end of each test
#######################################
plugin_context_clear_test() {
    tlog debug "Clearing test context data"
    
    # Clear test context
    PLUGIN_TEST_CONTEXT=()
    
    # Clear test-related metadata
    for full_key in "${!CONTEXT_TIMESTAMPS[@]}"; do
        if [[ "$full_key" =~ ^test: ]]; then
            unset CONTEXT_TIMESTAMPS[$full_key]
            unset CONTEXT_OWNERS[$full_key]
            unset CONTEXT_PERMISSIONS[$full_key]
        fi
    done
}

#######################################
# Clear session-specific context data
# Called when session ends
#######################################
plugin_context_clear_session() {
    tlog debug "Clearing session context data"
    
    # Clear session context
    PLUGIN_SESSION_CONTEXT=()
    
    # Clear session-related metadata
    for full_key in "${!CONTEXT_TIMESTAMPS[@]}"; do
        if [[ "$full_key" =~ ^session: ]]; then
            unset CONTEXT_TIMESTAMPS[$full_key]
            unset CONTEXT_OWNERS[$full_key]
            unset CONTEXT_PERMISSIONS[$full_key]
        fi
    done
}

#######################################
# List all context data accessible to a plugin
# Arguments:
#   1: plugin_name - plugin requesting the list
# Outputs:
#   Context data information
#######################################
plugin_context_list() {
    local plugin_name="$1"
    
    echo "Plugin Context Data for: $plugin_name"
    echo "====================================="
    
    # Global context
    echo "Global Context:"
    for key in "${!PLUGIN_GLOBAL_CONTEXT[@]}"; do
        local full_key="global:$key"
        local permission="${CONTEXT_PERMISSIONS[$full_key]:-read_write}"
        local owner="${CONTEXT_OWNERS[$full_key]:-unknown}"
        
        if [[ "$permission" != "private" || "$owner" == "$plugin_name" ]]; then
            echo "  $key = ${PLUGIN_GLOBAL_CONTEXT[$key]} (owner: $owner, permission: $permission)"
        fi
    done
    
    # Session context
    echo "Session Context:"
    for key in "${!PLUGIN_SESSION_CONTEXT[@]}"; do
        local full_key="session:$key"
        local permission="${CONTEXT_PERMISSIONS[$full_key]:-read_write}"
        local owner="${CONTEXT_OWNERS[$full_key]:-unknown}"
        
        if [[ "$permission" != "private" || "$owner" == "$plugin_name" ]]; then
            echo "  $key = ${PLUGIN_SESSION_CONTEXT[$key]} (owner: $owner, permission: $permission)"
        fi
    done
    
    # Test context
    echo "Test Context:"
    for key in "${!PLUGIN_TEST_CONTEXT[@]}"; do
        local full_key="test:$key"
        local permission="${CONTEXT_PERMISSIONS[$full_key]:-read_write}"
        local owner="${CONTEXT_OWNERS[$full_key]:-unknown}"
        
        if [[ "$permission" != "private" || "$owner" == "$plugin_name" ]]; then
            echo "  $key = ${PLUGIN_TEST_CONTEXT[$key]} (owner: $owner, permission: $permission)"
        fi
    done
    
    # Private context (only this plugin's data)
    echo "Private Context:"
    for full_key in "${!PLUGIN_PRIVATE_CONTEXT[@]}"; do
        if [[ "$full_key" =~ ^${plugin_name}: ]]; then
            local key="${full_key#${plugin_name}:}"
            echo "  $key = ${PLUGIN_PRIVATE_CONTEXT[$full_key]}"
        fi
    done
}

#######################################
# Share data between plugins (convenience function)
# Arguments:
#   1: from_plugin - source plugin
#   2: to_plugin - target plugin  
#   3: key - data key
#   4: value - data value
# Returns:
#   0 on success, 1 on error
#######################################
plugin_context_share() {
    local from_plugin="$1"
    local to_plugin="$2"
    local key="$3"
    local value="$4"
    
    # Store in global context with read_write permission
    plugin_context_set "$CONTEXT_SCOPE_GLOBAL" "${from_plugin}_to_${to_plugin}_${key}" "$value" "$from_plugin" "read_write"
}

# Export context functions
export -f plugin_context_set
export -f plugin_context_get
export -f plugin_context_exists
export -f plugin_context_clear_test
export -f plugin_context_clear_session
export -f plugin_context_list
export -f plugin_context_share


