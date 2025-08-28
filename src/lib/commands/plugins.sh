#!/bin/bash

# plugins.sh - Plugin management commands

# List available plugins
list_plugins_command() {
    local plugin_type="${1:-all}"
    
    echo "Available plugins:"
    echo ""
    
    # List internal plugins directly without loading
    echo "Internal plugins:"
    echo "  - grpc_response_time (response_time) -> evaluate_grpc_response_time"
    echo "    Evaluate gRPC response time assertions"
    echo ""
    echo "  - asserts (asserts) -> evaluate_enhanced_asserts"
    echo "    Enhanced assertions with inline types"
    echo ""
    echo "  - proto (proto) -> evaluate_proto_asserts"
    echo "    Protocol buffer field assertions"
    echo ""
    echo "  - tls (tls) -> evaluate_tls_asserts"
    echo "    TLS/SSL certificate assertions"
    echo ""
    
    # Check for external plugins
    local plugin_dir="${EXTERNAL_PLUGIN_DIR:-~/.grpctestify/plugins}"
    plugin_dir=$(expand_tilde "$plugin_dir")
    
    if [[ -d "$plugin_dir" ]]; then
        local external_plugins=()
        while IFS= read -r -d '' plugin_file; do
            external_plugins+=("$plugin_file")
        done < <(find "$plugin_dir" -name "*.sh" -type f -print0 2>/dev/null)
        
        if [[ ${#external_plugins[@]} -gt 0 ]]; then
            echo "External plugins (${#external_plugins[@]} found in $plugin_dir):"
            for plugin_file in "${external_plugins[@]}"; do
                local plugin_name=$(basename "$plugin_file" .sh)
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
        log error "Invalid plugin name: $plugin_name"
        log error "Plugin name must start with lowercase letter and contain only lowercase letters, numbers, and underscores"
        return 1
    fi
    
    # Create plugin directory
    local plugin_dir="${EXTERNAL_PLUGIN_DIR:-~/.grpctestify/plugins}"
    plugin_dir=$(expand_tilde "$plugin_dir")
    ensure_directory "$plugin_dir"
    
    # Use official Plugin API to create template
    log info "Creating plugin template using Plugin API..."
    create_plugin_template "$plugin_name" "assertion" "$plugin_dir"
}

# Test a plugin assertion
test_plugin_command() {
    local plugin_name="$1"
    local assertion_args="$2"
    
    if [[ -z "$plugin_name" || -z "$assertion_args" ]]; then
        log error "Plugin name and assertion arguments are required"
        return 1
    fi
    
    # Load all plugins first
    load_all_plugins
    
    # Check if plugin exists
    if [[ -z "${PLUGIN_REGISTRY[$plugin_name]:-}" ]]; then
        log error "Plugin not found: $plugin_name"
        log info "Available plugins: $(list_plugin_names)"
        return 1
    fi
    
    # Create a test response
    local test_response='{"test": "data", "_grpc_status": "0", "_response_time": "100"}'
    
    log info "Testing plugin: $plugin_name"
    log info "Arguments: $assertion_args"
    log info "Test response: $test_response"
    
    if execute_plugin_assertion "$plugin_name" "$test_response" "$assertion_args"; then
        log success "Plugin assertion passed"
        return 0
    else
        log error "Plugin assertion failed"
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
