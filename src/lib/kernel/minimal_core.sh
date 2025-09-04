#!/bin/bash

# minimal_core.sh - Minimal Kernel Core for grpctestify
# Contains only essential microkernel components with enhanced plugin loading

# Core kernel version
readonly KERNEL_VERSION="1.0.0"
readonly KERNEL_NAME="grpctestify-microkernel"

# Essential kernel components (MINIMIZED - moved others to plugins)
readonly ESSENTIAL_COMPONENTS=(
    "system_api"        # Core system abstractions (FIRST - needed by others)
    "routine_manager"
    "resource_pool" 
    "health_monitor"
    "event_system"
    "state_database"
    "routine_health"
    "process_manager"
    "config"
    "portability"
    "posix_compat"
    "native_utils"
)

# Plugin directories to scan (ordered by load priority)
readonly PLUGIN_DIRECTORIES=(
    "src/lib/plugins/kernel"     # Core business logic plugins
    "src/lib/plugins/system"     # System plugins (registry, etc.)
    "src/lib/plugins/ui"         # UI plugins
    "src/lib/plugins/utils"      # Utility plugins
    "src/lib/plugins/execution"  # Execution plugins
    # "src/lib/plugins/reports"    # Removed: non-existent directory
    "src/lib/plugins/development" # Development plugins
    "src/lib/plugins/validation" # Validation plugins
    "src/lib/plugins/performance" # Performance plugins
    "src/lib/plugins/security"   # Security plugins
    "src/lib/plugins/assertions" # Assertion plugins
    "src/lib/plugins/reporters"  # Reporter plugins
)

# Kernel state
declare -g KERNEL_INITIALIZED=false
declare -g KERNEL_COMPONENTS_LOADED=()
declare -g KERNEL_PLUGINS_LOADED=()

# Simple logging function that avoids ALL conflicts with system commands
tlog() {
    local level="$1"
    shift
    # Only show debug if explicitly enabled
    if [[ "$level" == "debug" && "${DEBUG:-}" != "true" && "${GRPCTESTIFY_DEBUG:-}" != "true" ]]; then
        return 0
    fi
    case "$level" in
        error) printf "❌ ERROR: %s\n" "$*" >&2 ;;
        warn)  printf "⚠️  WARN: %s\n" "$*" >&2 ;;
        info)  printf "ℹ️  INFO: %s\n" "$*" ;;
        debug) printf "🐛 DEBUG: %s\n" "$*" ;;
        *)     printf "%s: %s\n" "$level" "$*" ;;
    esac
}

# Initialize minimal kernel core
kernel_init() {
    # Initialize logging system first to avoid conflicts with system log command
    if command -v init_logging_io >/dev/null 2>&1; then
        init_logging_io
    fi
    
    log_debug "🚀 Initializing grpctestify microkernel v$KERNEL_VERSION..."
    
    # Load essential kernel components first
    if ! kernel_load_essential_components; then
        log_error "Failed to load essential kernel components"
        return 1
    fi
    
    # Initialize plugin integration system with enhanced API
    if ! plugin_integration_init; then
        log_error "Failed to initialize plugin integration system"
        return 1
    fi
    
    # Auto-discover and load all plugins
    if ! kernel_load_all_plugins; then
        log_error "Failed to load plugins"
        return 1
    fi
    
    KERNEL_INITIALIZED=true
    log_debug "✅ Microkernel initialized successfully"
    log_debug "Loaded components: ${KERNEL_COMPONENTS_LOADED[*]}"
    log_debug "Loaded plugins: ${KERNEL_PLUGINS_LOADED[*]}"
    
    return 0
}

# Load essential kernel components
kernel_load_essential_components() {
    log_debug "Loading essential kernel components..."
    
    for component in "${ESSENTIAL_COMPONENTS[@]}"; do
        if ! kernel_load_component "$component"; then
    log_error "Failed to load essential component: $component"
            return 1
        fi
        KERNEL_COMPONENTS_LOADED+=("$component")
    done
    
    log_debug "Essential components loaded successfully"
    return 0
}

# Load a single kernel component
kernel_load_component() {
    local component="$1"
    local component_file="src/lib/kernel/${component}.sh"
    
    if [[ ! -f "$component_file" ]]; then
    log_error "Component file not found: $component_file"
        return 1
    fi
    
    # Components are loaded by bashly automatically, just verify they're available
    local init_function="${component}_init"
    if command -v "$init_function" >/dev/null 2>&1; then
        if ! "$init_function"; then
    log_error "Failed to initialize component: $component"
            return 1
        fi
    log_debug "Component initialized: $component"
    else
    log_debug "Component loaded (no init function): $component"
    fi
    
    return 0
}

# Load all plugins from plugin directories
kernel_load_all_plugins() {
    log_debug "Auto-discovering and loading plugins..."
    
    # Initialize enhanced plugin API first
    if command -v plugin_register_enhanced >/dev/null 2>&1; then
    log_debug "Enhanced plugin API available"
    else
    log_warn "Enhanced plugin API not available, using basic API"
    fi
    
    local total_plugins=0
    local loaded_plugins=0
    
    # Scan each plugin directory in order
    for plugin_dir in "${PLUGIN_DIRECTORIES[@]}"; do
        if [[ -d "$plugin_dir" ]]; then
    log_debug "Scanning plugin directory: $plugin_dir"
            
            # Find all .sh files that look like plugins
            while IFS= read -r -d '' plugin_file; do
                ((total_plugins++))
                
                local plugin_name
                plugin_name=$(basename "$plugin_file" .sh)
                
                if kernel_load_plugin "$plugin_file" "$plugin_name"; then
                    ((loaded_plugins++))
                    KERNEL_PLUGINS_LOADED+=("$plugin_name")
                fi
            done < <(find "$plugin_dir" -name "*.sh" -type f -print0)
        else
    log_debug "Plugin directory not found: $plugin_dir"
        fi
    done
    
    log_debug "Plugin discovery complete: $loaded_plugins/$total_plugins plugins loaded"
    return 0
}

# Load a single plugin
kernel_load_plugin() {
    local plugin_file="$1"
    local plugin_name="$2"
    
    log_debug "Loading plugin: $plugin_name from $plugin_file"
    
    # Check if plugin has an init function
    local init_function="${plugin_name}_init"
    if ! command -v "$init_function" >/dev/null 2>&1; then
        # Try alternative naming patterns
        init_function="${plugin_name}_plugin_init"
        if ! command -v "$init_function" >/dev/null 2>&1; then
    log_debug "No init function found for plugin: $plugin_name (skipping)"
            return 1
        fi
    fi
    
    # Initialize the plugin
    if "$init_function"; then
    log_debug "Plugin loaded successfully: $plugin_name"
        
        # Trigger plugin loaded event
        if command -v event_publish >/dev/null 2>&1; then
            event_publish "kernel.plugin.loaded" "{\"plugin\":\"$plugin_name\",\"file\":\"$plugin_file\"}" "$EVENT_PRIORITY_NORMAL" "kernel"
        fi
        
        return 0
    else
    log_warn "Failed to initialize plugin: $plugin_name"
        return 1
    fi
}

# Get kernel status and statistics
kernel_status() {
    local status="initialized"
    if [[ "$KERNEL_INITIALIZED" != "true" ]]; then
        status="not_initialized"
    fi
    
    cat << EOF
{
  "kernel": {
    "name": "$KERNEL_NAME",
    "version": "$KERNEL_VERSION",
    "status": "$status",
    "components_loaded": ${#KERNEL_COMPONENTS_LOADED[@]},
    "plugins_loaded": ${#KERNEL_PLUGINS_LOADED[@]},
    "essential_components": [$(printf '"%s",' "${ESSENTIAL_COMPONENTS[@]}" | sed 's/,$//')],
    "loaded_components": [$(printf '"%s",' "${KERNEL_COMPONENTS_LOADED[@]}" | sed 's/,$//')],
    "loaded_plugins": [$(printf '"%s",' "${KERNEL_PLUGINS_LOADED[@]}" | sed 's/,$//')]
  }
}
EOF
}

# Kernel health check
kernel_health_check() {
    local health_status="healthy"
    local issues=()
    
    # Check essential components
    for component in "${ESSENTIAL_COMPONENTS[@]}"; do
        local health_function="${component}_health_check"
        if command -v "$health_function" >/dev/null 2>&1; then
            if ! "$health_function" >/dev/null 2>&1; then
                health_status="degraded"
                issues+=("component_$component")
            fi
        fi
    done
    
    # Check plugin system
    if ! command -v plugin_register >/dev/null 2>&1; then
        health_status="critical"
        issues+=("plugin_system")
    fi
    
    cat << EOF
{
  "status": "$health_status",
  "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')],
  "timestamp": $(date +%s)
}
EOF
}

# Graceful kernel shutdown
kernel_shutdown() {
    log_debug "🛑 Shutting down grpctestify microkernel..."
    
    # Trigger shutdown event for plugins
    if command -v event_publish >/dev/null 2>&1; then
        event_publish "kernel.shutdown" "{}" "$EVENT_PRIORITY_HIGH" "kernel"
    fi
    
    # Cleanup plugins in reverse order
    local plugin
    for ((i=${#KERNEL_PLUGINS_LOADED[@]}-1; i>=0; i--)); do
        plugin="${KERNEL_PLUGINS_LOADED[i]}"
        local cleanup_function="${plugin}_cleanup"
        if command -v "$cleanup_function" >/dev/null 2>&1; then
            "$cleanup_function" || true
        fi
    done
    
    # Cleanup essential components in reverse order
    local component
    for ((i=${#KERNEL_COMPONENTS_LOADED[@]}-1; i>=0; i--)); do
        component="${KERNEL_COMPONENTS_LOADED[i]}"
        local cleanup_function="${component}_cleanup"
        if command -v "$cleanup_function" >/dev/null 2>&1; then
            "$cleanup_function" || true
        fi
    done
    
    KERNEL_INITIALIZED=false
    log_debug "✅ Microkernel shutdown complete"
}

# Enhanced plugin discovery for external directories
kernel_discover_external_plugins() {
    local external_dir="${1:-${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}}"
    
    if [[ -d "$external_dir" ]]; then
    log_debug "Scanning external plugin directory: $external_dir"
        
        while IFS= read -r -d '' plugin_file; do
            local plugin_name
            plugin_name=$(basename "$plugin_file" .sh)
            
            if kernel_load_plugin "$plugin_file" "$plugin_name"; then
                KERNEL_PLUGINS_LOADED+=("$plugin_name")
    log_debug "Loaded external plugin: $plugin_name"
            fi
        done < <(find "$external_dir" -name "*.sh" -type f -print0)
    fi
}

# Export kernel functions
export -f tlog kernel_init kernel_load_essential_components kernel_load_component
export -f kernel_load_all_plugins kernel_load_plugin kernel_status
export -f kernel_health_check kernel_shutdown kernel_discover_external_plugins
