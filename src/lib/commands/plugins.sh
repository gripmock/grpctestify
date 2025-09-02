#!/bin/bash

# plugins.sh - Plugin management commands
# shellcheck disable=SC2155,SC2148,SC2034 # Variable assignments, shebang detection, unused variables

# Dynamically list plugins
list_internal_plugins_dynamic() {
    local plugins=()
    
    # Scan for plugin handlers
    if command -v grpc_response_time_handler >/dev/null 2>&1; then
        plugins+=("grpc_response_time (performance)|Enhanced gRPC response time monitoring")
    fi
    
    if command -v grpc_headers_trailers_handler >/dev/null 2>&1; then
        plugins+=("grpc_headers_trailers (validation)|Enhanced headers/trailers validation")
    fi
    
    if command -v grpc_type_validation_handler >/dev/null 2>&1; then
        plugins+=("grpc_type_validation (validation)|Enhanced type validation")
    fi
    
    if command -v grpc_proto_handler >/dev/null 2>&1; then
        plugins+=("grpc_proto (validation)|Enhanced proto contracts validation")
    fi
    
    if command -v grpc_json_reporter_handler >/dev/null 2>&1; then
        plugins+=("grpc_json_reporter (reporters)|Enhanced JSON test reporting")
    fi
    
    if command -v grpc_junit_reporter_handler >/dev/null 2>&1; then
        plugins+=("grpc_junit_reporter (reporters)|Enhanced JUnit XML reporting")
    fi
    
    if command -v grpc_tls_handler >/dev/null 2>&1; then
        plugins+=("grpc_tls (security)|Enhanced TLS/mTLS security")
    fi
    
    if command -v grpc_asserts_handler >/dev/null 2>&1; then
        plugins+=("grpc_asserts (assertions)|Enhanced assertion system")
    fi
    
    # Core microkernel plugins
    if command -v test_executor_handler >/dev/null 2>&1; then
        plugins+=("test_executor (core)|Core test execution engine")
    fi
    
    if command -v file_parser_handler >/dev/null 2>&1; then
        plugins+=("file_parser (core)|Core .gctf file parser")
    fi
    
    if command -v grpc_client_handler >/dev/null 2>&1; then
        plugins+=("grpc_client (core)|Core gRPC client")
    fi
    
    if command -v plugin_registry_handler >/dev/null 2>&1; then
        plugins+=("plugin_registry (system)|Plugin registry and discovery")
    fi
    
    # Display found plugins
    if [[ ${#plugins[@]} -eq 0 ]]; then
        echo "  No plugins loaded"
    else
        for plugin_info in "${plugins[@]}"; do
            IFS='|' read -r plugin_name plugin_desc <<< "$plugin_info"
            echo "  - $plugin_name"
            echo "    $plugin_desc"
            echo ""
        done
    fi
}

# List available plugins
list_plugins_command() {
    local plugin_type="${1:-all}"
    
    echo "Available plugins:"
    echo ""
    
    # Dynamically list v2 plugins
    echo "V2 Plugins (Microkernel Architecture):"
    list_internal_plugins_dynamic
    echo ""
    
    # Check for external plugins
    local plugin_dir="${EXTERNAL_PLUGIN_DIR:-~/.grpctestify/plugins}"
    plugin_dir="${plugin_dir/#\~/$HOME}"
    
    if [[ -d "$plugin_dir" ]]; then
        local external_plugins=()
        while IFS= read -r -d '' plugin_file; do
            external_plugins+=("$plugin_file")
        done < <(find "$plugin_dir" -name "*.sh" -type f -print0 2>/dev/null)
        
        if [[ ${#external_plugins[@]} -gt 0 ]]; then
            echo "External plugins (${#external_plugins[@]} found in $plugin_dir):"
            for plugin_file in "${external_plugins[@]}"; do
                local plugin_name=$(basename "$plugin_file" .sh)
                # Remove grpc_ prefix if present
                if [[ "$plugin_name" =~ ^grpc_(.+)$ ]]; then
                    plugin_name="${BASH_REMATCH[1]}"
                fi
                echo "  - $plugin_name (external)"
            done
        else
            echo "No external plugins found in $plugin_dir"
        fi
    else
        echo "External plugin directory not found: $plugin_dir"
    fi
}

# Create a new plugin template
create_plugin_command() {
    local plugin_name="$1"
    
    if [[ -z "$plugin_name" ]]; then
        error_required "Plugin name"
        show_plugin_api_help
        return 1
    fi
    
    # Convert to lowercase and validate
    plugin_name=$(echo "$plugin_name" | tr '[:upper:]' '[:lower:]')
    
    if [[ ! "$plugin_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
    tlog error "Invalid plugin name: $plugin_name"
    tlog error "Plugin name must start with lowercase letter and contain only lowercase letters, numbers, and underscores"
        return 1
    fi
    
    # Create plugin directory
    local plugin_dir="${EXTERNAL_PLUGIN_DIR:-~/.grpctestify/plugins}"
    plugin_dir="${plugin_dir/#\~/$HOME}"
    ensure_directory "$plugin_dir"
    
    # Use official Plugin API to create template
    tlog debug "Creating plugin template using Plugin API..."
    create_plugin_template "$plugin_name" "assertion" "$plugin_dir"
}

# Test a plugin assertion
test_plugin_command() {
    local plugin_name="$1"
    local assertion_args="$2"
    
    if [[ -z "$plugin_name" || -z "$assertion_args" ]]; then
    tlog error "Plugin name and assertion arguments are required"
        return 1
    fi
    
    # Load all plugins first
    load_all_plugins
    
    # Check if plugin exists
    if [[ -z "${PLUGIN_REGISTRY[$plugin_name]:-}" ]]; then
    tlog error "Plugin not found: $plugin_name"
    tlog info "Available plugins: $(list_plugin_names)"
        return 1
    fi
    
    # Create a test response
    local test_response='{"test": "data", "_grpc_status": "0", "_response_time": "100"}'
    
    tlog debug "Testing plugin: $plugin_name"
    tlog debug "Arguments: $assertion_args"
    tlog debug "Test response: $test_response"
    
    if execute_plugin_assertion "$plugin_name" "$test_response" "$assertion_args"; then
        tlog debug "Plugin assertion passed"
        return 0
    else
    tlog error "Plugin assertion failed"
        return 1
    fi
}

# Handle global plugin flags
handle_plugin_flags() {
    if [[ "$FLAG_LIST_PLUGINS" == "true" ]]; then
        list_plugins_command "all"
        exit 0
    fi
    
    if [[ -n "$FLAG_CREATE_PLUGIN" ]]; then
        create_plugin_command "$FLAG_CREATE_PLUGIN"
        exit 0
    fi
}

# Export functions for use in other modules
export -f list_plugins_command
export -f create_plugin_command
export -f test_plugin_command
export -f handle_plugin_flags
