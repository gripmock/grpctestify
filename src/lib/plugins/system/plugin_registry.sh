#!/bin/bash

# plugin_registry_v2.sh - Enhanced plugin registry with microkernel integration
# Automatic discovery and initialization of v2 plugins

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/plugin_integration.sh"

# Registry metadata
readonly PLUGIN_REGISTRY_VERSION="1.0.0"
readonly PLUGIN_REGISTRY_DESCRIPTION="Enhanced plugin registry with microkernel integration"

# Plugin registry configuration
PLUGIN_REGISTRY_AUTO_DISCOVER="${PLUGIN_REGISTRY_AUTO_DISCOVER:-true}"
PLUGIN_REGISTRY_INIT_TIMEOUT="${PLUGIN_REGISTRY_INIT_TIMEOUT:-30}"
PLUGIN_REGISTRY_HEALTH_CHECK="${PLUGIN_REGISTRY_HEALTH_CHECK:-true}"

# Plugin registry state
declare -g -A PLUGIN_REGISTRY=()
declare -g -a PLUGIN_REGISTRY_LOAD_ORDER=()
declare -g PLUGIN_REGISTRY_INITIALIZED=false

# Initialize plugin registry v2
plugin_registry_init() {
    tlog debug "Initializing plugin registry v2..."
    
    # Ensure microkernel components are available
    if ! command -v plugin_register >/dev/null 2>&1; then
    tlog warning "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register registry itself as a plugin
    plugin_register "plugin_registry" "plugin_registry_handler" "$PLUGIN_REGISTRY_DESCRIPTION" "internal" ""
    
    # Create resource pool for plugin operations
    pool_create "plugin_registry" 5
    
    # Subscribe to plugin-related events
    event_subscribe "plugin_registry" "plugin.*" "plugin_registry_event_handler"
    event_subscribe "plugin_registry" "system.startup" "plugin_registry_startup_handler"
    
    # Initialize registry tracking state
    if command -v state_db_set >/dev/null 2>&1; then
        state_db_set "plugin_registry.version" "$PLUGIN_REGISTRY_VERSION"
        state_db_set "plugin_registry.plugins_discovered" "0"
        state_db_set "plugin_registry.plugins_initialized" "0"
        state_db_set "plugin_registry.initialization_failures" "0"
        state_db_set "plugin_registry.health_checks_performed" "0"
    fi
    
    # Auto-discover plugins if enabled
    if [[ "$PLUGIN_REGISTRY_AUTO_DISCOVER" == "true" ]]; then
        plugin_registry_discover_plugins
    fi
    
    PLUGIN_REGISTRY_INITIALIZED=true
    tlog debug "Plugin registry initialized successfully"
    return 0
}

# Main plugin registry handler
plugin_registry_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "discover_plugins")
            plugin_registry_discover_plugins "${args[@]}"
            ;;
        "register_plugin_v2")
            plugin_registry_register_plugin "${args[@]}"
            ;;
        "initialize_plugins")
            plugin_registry_initialize_plugins "${args[@]}"
            ;;
        "list_plugins")
            plugin_registry_list_plugins "${args[@]}"
            ;;
        "get_plugin_info")
            plugin_registry_get_plugin_info "${args[@]}"
            ;;
        "health_check")
            plugin_registry_health_check "${args[@]}"
            ;;
        "get_statistics")
            plugin_registry_get_statistics "${args[@]}"
            ;;
        *)
    tlog error "Unknown plugin registry command: $command"
            return 1
            ;;
    esac
}

# Auto-discover v2 plugins
plugin_registry_discover_plugins() {
    local plugin_dirs="${1:-}"
    
    tlog debug "Discovering v2 plugins..."
    
    # Default plugin directories
    if [[ -z "$plugin_dirs" ]]; then
        plugin_dirs="src/lib/plugins/performance src/lib/plugins/validation src/lib/plugins/security src/lib/plugins/kernel src/lib/plugins/assertions src/lib/plugins/reporters"
    fi
    
    # Publish discovery start event
    event_publish "plugin.discovery.start" "{\"plugin_dirs\":\"$plugin_dirs\"}" "$EVENT_PRIORITY_NORMAL" "plugin_registry"
    
    local discovered_count=0
    
    # Discover plugins in each directory
    for plugin_dir in $plugin_dirs; do
        if [[ -d "$plugin_dir" ]]; then
    tlog debug "Scanning directory for plugins: $plugin_dir"
            
            # Find all plugin files
            find "$plugin_dir" -name "*.sh" -type f | while read -r plugin_file; do
                if discover_and_register_plugin "$plugin_file"; then
                    ((discovered_count++))
    tlog debug "Discovered plugin: $plugin_file"
                fi
            done
        fi
    done
    
    # Update statistics
    increment_registry_counter "plugins_discovered" "$discovered_count"
    
    # Publish discovery complete event
    event_publish "plugin.discovery.complete" "{\"discovered_count\":$discovered_count}" "$EVENT_PRIORITY_NORMAL" "plugin_registry"
    
    tlog debug "Plugin discovery complete: $discovered_count plugins found"
    return 0
}

# Discover and register individual plugin
discover_and_register_plugin() {
    local plugin_file="$1"
    
    if [[ ! -f "$plugin_file" ]]; then
        return 1
    fi
    
    # Extract plugin name from filename
    local plugin_name
    plugin_name=$(basename "$plugin_file" .sh)
    
    # Check if plugin file contains initialization function
    if grep -q "${plugin_name}_init" "$plugin_file"; then
        # Register plugin in registry
        PLUGIN_REGISTRY["$plugin_name"]="$plugin_file"
        PLUGIN_REGISTRY_LOAD_ORDER+=("$plugin_name")
        
    tlog debug "Registered v2 plugin: $plugin_name (file: $plugin_file)"
        return 0
    else
    tlog warning "Plugin file does not contain expected init function: $plugin_file"
        return 1
    fi
}

# Register plugin manually
plugin_registry_register_plugin() {
    local plugin_name="$1"
    local plugin_file="$2"
    local plugin_priority="${3:-normal}"
    
    if [[ -z "$plugin_name" || -z "$plugin_file" ]]; then
    tlog error "plugin_registry_register_plugin: plugin_name and plugin_file required"
        return 1
    fi
    
    if [[ ! -f "$plugin_file" ]]; then
    tlog error "Plugin file not found: $plugin_file"
        return 1
    fi
    
    tlog debug "Manually registering v2 plugin: $plugin_name"
    
    # Register plugin in registry
    PLUGIN_REGISTRY["$plugin_name"]="$plugin_file"
    
    # Add to load order based on priority
    case "$plugin_priority" in
        "high")
            # Add to beginning of load order
            PLUGIN_REGISTRY_LOAD_ORDER=("$plugin_name" "${PLUGIN_REGISTRY_LOAD_ORDER[@]}")
            ;;
        "low")
            # Add to end of load order
            PLUGIN_REGISTRY_LOAD_ORDER+=("$plugin_name")
            ;;
        *)
            # Add to end (normal priority)
            PLUGIN_REGISTRY_LOAD_ORDER+=("$plugin_name")
            ;;
    esac
    
    tlog debug "Plugin registered successfully: $plugin_name"
    return 0
}

# Initialize all discovered plugins
plugin_registry_initialize_plugins() {
    local initialization_mode="${1:-parallel}"  # parallel, sequential
    local continue_on_failure="${2:-false}"
    
    tlog debug "Initializing v2 plugins (mode: $initialization_mode)..."
    
    # Publish initialization start event
    event_publish "plugin.initialization.start" "{\"mode\":\"$initialization_mode\",\"plugin_count\":${#PLUGIN_REGISTRY_LOAD_ORDER[@]}}" "$EVENT_PRIORITY_NORMAL" "plugin_registry"
    
    local initialized_count=0
    local failure_count=0
    
    case "$initialization_mode" in
        "parallel")
            initialize_plugins_parallel "$continue_on_failure" initialized_count failure_count
            ;;
        "sequential")
            initialize_plugins_sequential "$continue_on_failure" initialized_count failure_count
            ;;
        *)
    tlog error "Unknown initialization mode: $initialization_mode"
            return 1
            ;;
    esac
    
    # Update statistics
    increment_registry_counter "plugins_initialized" "$initialized_count"
    increment_registry_counter "initialization_failures" "$failure_count"
    
    # Publish initialization complete event
    local initialization_result
    initialization_result=$(cat << EOF
{
  "initialized_count": $initialized_count,
  "failure_count": $failure_count,
  "total_plugins": ${#PLUGIN_REGISTRY_LOAD_ORDER[@]}
}
EOF
)
    event_publish "plugin.initialization.complete" "$initialization_result" "$EVENT_PRIORITY_NORMAL" "plugin_registry"
    
    tlog debug "Plugin initialization complete: $initialized_count/$((initialized_count + failure_count)) plugins initialized"
    
    if [[ $failure_count -gt 0 && "$continue_on_failure" == "false" ]]; then
        return 1
    fi
    return 0
}

# Initialize plugins in parallel
initialize_plugins_parallel() {
    local continue_on_failure="$1"
    local -n init_count_ref=$2
    local -n fail_count_ref=$3
    
    local pids=()
    local plugin_results=()
    
    # Start initialization for all plugins
    for plugin_name in "${PLUGIN_REGISTRY_LOAD_ORDER[@]}"; do
        (
            initialize_single_plugin "$plugin_name"
        ) &
        pids+=($!)
        plugin_results+=("$plugin_name")
    done
    
    # Wait for all plugins to initialize
    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        local plugin_name="${plugin_results[$i]}"
        
        if wait "$pid"; then
            ((init_count_ref++))
    tlog debug "Plugin initialized successfully (parallel): $plugin_name"
        else
            ((fail_count_ref++))
    tlog error "Plugin initialization failed (parallel): $plugin_name"
            
            if [[ "$continue_on_failure" == "false" ]]; then
                # Kill remaining processes
                for remaining_pid in "${pids[@]}"; do
                    kill "$remaining_pid" 2>/dev/null || true
                done
                return 1
            fi
        fi
    done
    
    return 0
}

# Initialize plugins sequentially
initialize_plugins_sequential() {
    local continue_on_failure="$1"
    local -n init_count_ref=$2
    local -n fail_count_ref=$3
    
    for plugin_name in "${PLUGIN_REGISTRY_LOAD_ORDER[@]}"; do
        if initialize_single_plugin "$plugin_name"; then
            ((init_count_ref++))
    tlog debug "Plugin initialized successfully (sequential): $plugin_name"
        else
            ((fail_count_ref++))
    tlog error "Plugin initialization failed (sequential): $plugin_name"
            
            if [[ "$continue_on_failure" == "false" ]]; then
                return 1
            fi
        fi
    done
    
    return 0
}

# Initialize single plugin with timeout
initialize_single_plugin() {
    local plugin_name="$1"
    local plugin_file="${PLUGIN_REGISTRY[$plugin_name]}"
    
    if [[ -z "$plugin_file" ]]; then
    tlog error "Plugin file not found for: $plugin_name"
        return 1
    fi
    
    tlog debug "Initializing plugin: $plugin_name (file: $plugin_file)"
    
    # Acquire resource for plugin initialization
    local resource_token
    resource_token=$(pool_acquire "plugin_registry" "$PLUGIN_REGISTRY_INIT_TIMEOUT")
    if [[ $? -ne 0 ]]; then
    tlog error "Failed to acquire resource for plugin initialization: $plugin_name"
        return 1
    fi
    
    # Source plugin file
    if ! source "$plugin_file"; then
    tlog error "Failed to source plugin file: $plugin_file"
        pool_release "plugin_registry" "$resource_token"
        return 1
    fi
    
    # Call plugin init function
    local init_function="${plugin_name}_init"
    if command -v "$init_function" >/dev/null 2>&1; then
        # Run with timeout
        if timeout "$PLUGIN_REGISTRY_INIT_TIMEOUT" "$init_function"; then
    tlog debug "Plugin initialization successful: $plugin_name"
            pool_release "plugin_registry" "$resource_token"
            return 0
        else
    tlog error "Plugin initialization timeout or failure: $plugin_name"
            pool_release "plugin_registry" "$resource_token"
            return 1
        fi
    else
    tlog error "Plugin init function not found: $init_function"
        pool_release "plugin_registry" "$resource_token"
        return 1
    fi
}

# List all registered plugins
plugin_registry_list_plugins() {
    local output_format="${1:-table}"
    local filter="${2:-all}"  # all, initialized, failed
    
    case "$output_format" in
        "json")
            local plugins_json="["
            local first=true
            for plugin_name in "${PLUGIN_REGISTRY_LOAD_ORDER[@]}"; do
                local plugin_file="${PLUGIN_REGISTRY[$plugin_name]}"
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    plugins_json+=","
                fi
                plugins_json+="{\"name\":\"$plugin_name\",\"file\":\"$plugin_file\"}"
            done
            plugins_json+="]"
            echo "$plugins_json"
            ;;
        "table"|*)
            echo "Registered v2 Plugins:"
            echo "====================="
            printf "%-30s %-50s\n" "Plugin Name" "File Path"
            printf "%-30s %-50s\n" "----------" "---------"
            for plugin_name in "${PLUGIN_REGISTRY_LOAD_ORDER[@]}"; do
                local plugin_file="${PLUGIN_REGISTRY[$plugin_name]}"
                printf "%-30s %-50s\n" "$plugin_name" "$plugin_file"
            done
            ;;
    esac
}

# Get detailed plugin information
plugin_registry_get_plugin_info() {
    local plugin_name="$1"
    local output_format="${2:-json}"
    
    if [[ -z "$plugin_name" ]]; then
    tlog error "plugin_registry_get_plugin_info: plugin_name required"
        return 1
    fi
    
    local plugin_file="${PLUGIN_REGISTRY[$plugin_name]}"
    if [[ -z "$plugin_file" ]]; then
    tlog error "Plugin not found: $plugin_name"
        return 1
    fi
    
    case "$output_format" in
        "json")
            jq -n \
                --arg name "$plugin_name" \
                --arg file "$plugin_file" \
                --arg status "registered" \
                '{
                    name: $name,
                    file: $file,
                    status: $status,
                    registry_version: "v2.0.0"
                }'
            ;;
        "summary"|*)
            echo "Plugin Information:"
            echo "  Name: $plugin_name"
            echo "  File: $plugin_file"
            echo "  Status: registered"
            echo "  Registry: v2.0.0"
            ;;
    esac
}

# Perform health check on plugins
plugin_registry_health_check() {
    local plugin_name="${1:-all}"
    local output_format="${2:-summary}"
    
    tlog debug "Performing health check on plugins..."
    
    local healthy_count=0
    local unhealthy_count=0
    local health_results=()
    
    if [[ "$plugin_name" == "all" ]]; then
        # Check all plugins
        for registered_plugin in "${PLUGIN_REGISTRY_LOAD_ORDER[@]}"; do
            if check_single_plugin_health "$registered_plugin"; then
                ((healthy_count++))
                health_results+=("$registered_plugin:healthy")
            else
                ((unhealthy_count++))
                health_results+=("$registered_plugin:unhealthy")
            fi
        done
    else
        # Check specific plugin
        if check_single_plugin_health "$plugin_name"; then
            ((healthy_count++))
            health_results+=("$plugin_name:healthy")
        else
            ((unhealthy_count++))
            health_results+=("$plugin_name:unhealthy")
        fi
    fi
    
    # Update statistics
    increment_registry_counter "health_checks_performed"
    
    case "$output_format" in
        "json")
            local results_json="["
            local first=true
            for result in "${health_results[@]}"; do
                IFS=':' read -r plugin_name status <<< "$result"
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    results_json+=","
                fi
                results_json+="{\"plugin\":\"$plugin_name\",\"status\":\"$status\"}"
            done
            results_json+="]"
            echo "$results_json"
            ;;
        "summary"|*)
            echo "Plugin Health Check Results:"
            echo "  Healthy: $healthy_count"
            echo "  Unhealthy: $unhealthy_count"
            echo "  Total: $((healthy_count + unhealthy_count))"
            echo ""
            echo "Individual Results:"
            for result in "${health_results[@]}"; do
                IFS=':' read -r plugin_name status <<< "$result"
                echo "  $plugin_name: $status"
            done
            ;;
    esac
    
    return $((unhealthy_count > 0 ? 1 : 0))
}

# Check health of single plugin
check_single_plugin_health() {
    local plugin_name="$1"
    local plugin_file="${PLUGIN_REGISTRY[$plugin_name]}"
    
    if [[ -z "$plugin_file" ]]; then
        return 1
    fi
    
    # Basic health checks:
    # 1. File exists and is readable
    if [[ ! -r "$plugin_file" ]]; then
        return 1
    fi
    
    # 2. Init function exists (implies plugin was sourced successfully)
    local init_function="${plugin_name}_init"
    if ! command -v "$init_function" >/dev/null 2>&1; then
        return 1
    fi
    
    # 3. Plugin can respond to basic handler call (if available)
    local handler_function="${plugin_name}_handler"
    if command -v "$handler_function" >/dev/null 2>&1; then
        # Try a basic handler call with timeout
        if timeout 5 "$handler_function" "get_statistics" >/dev/null 2>&1; then
            return 0
        else
            # Handler exists but failed - plugin might be unhealthy
            return 1
        fi
    fi
    
    # Plugin has init function and file is readable - consider healthy
    return 0
}

# Get registry statistics
plugin_registry_get_statistics() {
    local format="${1:-json}"
    
    local total_plugins=${#PLUGIN_REGISTRY_LOAD_ORDER[@]}
    
    if command -v state_db_get >/dev/null 2>&1; then
        local plugins_discovered
        plugins_discovered=$(state_db_get "plugin_registry.plugins_discovered" || echo "0")
        local plugins_initialized
        plugins_initialized=$(state_db_get "plugin_registry.plugins_initialized" || echo "0")
        local initialization_failures
        initialization_failures=$(state_db_get "plugin_registry.initialization_failures" || echo "0")
        local health_checks_performed
        health_checks_performed=$(state_db_get "plugin_registry.health_checks_performed" || echo "0")
        
        case "$format" in
            "json")
                jq -n \
                    --argjson total "$total_plugins" \
                    --argjson discovered "$plugins_discovered" \
                    --argjson initialized "$plugins_initialized" \
                    --argjson failures "$initialization_failures" \
                    --argjson health_checks "$health_checks_performed" \
                    --argjson registry_initialized "$([[ "$PLUGIN_REGISTRY_INITIALIZED" == "true" ]] && echo "true" || echo "false")" \
                    '{
                        total_plugins: $total,
                        plugins_discovered: $discovered,
                        plugins_initialized: $initialized,
                        initialization_failures: $failures,
                        health_checks_performed: $health_checks,
                        registry_initialized: $registry_initialized,
                        registry_version: "v2.0.0"
                    }'
                ;;
            "summary")
                echo "Plugin Registry Statistics:"
                echo "  Total plugins: $total_plugins"
                echo "  Discovered: $plugins_discovered"
                echo "  Initialized: $plugins_initialized"
                echo "  Init failures: $initialization_failures"
                echo "  Health checks: $health_checks_performed"
                echo "  Registry initialized: $PLUGIN_REGISTRY_INITIALIZED"
                ;;
        esac
    else
        echo '{"error": "State database not available"}'
    fi
}

# Increment registry counter
increment_registry_counter() {
    local counter_name="$1"
    local increment="${2:-1}"
    
    if command -v state_db_get >/dev/null 2>&1; then
        local current_value
        current_value=$(state_db_get "plugin_registry.$counter_name" || echo "0")
        state_db_set "plugin_registry.$counter_name" "$((current_value + increment))"
    fi
}

# Plugin registry event handler
plugin_registry_event_handler() {
    local event_message="$1"
    
    tlog debug "Plugin registry received event: $event_message"
    
    # Handle plugin-related events
    # This could be used for:
    # - Dynamic plugin loading/unloading
    # - Plugin dependency management
    # - Plugin performance monitoring
    # - Automatic plugin updates
    
    return 0
}

# System startup event handler
plugin_registry_startup_handler() {
    local event_message="$1"
    
    tlog debug "Plugin registry received startup event"
    
    # Auto-initialize plugins on system startup
    if [[ "$PLUGIN_REGISTRY_AUTO_DISCOVER" == "true" && "$PLUGIN_REGISTRY_INITIALIZED" == "true" ]]; then
        plugin_registry_initialize_plugins "parallel" "true"
    fi
    
    return 0
}

# Convenience functions for external use
discover_plugins() {
    plugin_registry_discover_plugins "$@"
}

initialize_plugins() {
    plugin_registry_initialize_plugins "$@"
}

list_plugins() {
    plugin_registry_list_plugins "$@"
}

# Export functions
export -f plugin_registry_init plugin_registry_handler plugin_registry_discover_plugins
export -f discover_and_register_plugin plugin_registry_register_plugin plugin_registry_initialize_plugins
export -f initialize_plugins_parallel initialize_plugins_sequential initialize_single_plugin
export -f plugin_registry_list_plugins plugin_registry_get_plugin_info plugin_registry_health_check
export -f check_single_plugin_health plugin_registry_get_statistics increment_registry_counter
export -f plugin_registry_event_handler plugin_registry_startup_handler
export -f discover_plugins initialize_plugins list_plugins
