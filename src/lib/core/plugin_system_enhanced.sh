#!/bin/bash

# plugin_system_enhanced.sh - Enhanced plugin system for extensible assertions
# Supports both embedded internal plugins and external plugin loading

# Plugin registry - stores available plugins (using globals for bashly compatibility)
declare -A PLUGIN_REGISTRY
declare -A PLUGIN_DESCRIPTIONS
declare -A PLUGIN_TYPES

# Plugin directories
EXTERNAL_PLUGIN_DIR="${EXTERNAL_PLUGIN_DIR:-~/.grpctestify/plugins}"

# Register a plugin
register_plugin() {
    local plugin_name="$1"
    local plugin_function="$2"
    local plugin_description="${3:-Custom assertion plugin}"
    local plugin_type="${4:-external}"
    
    if [[ -z "$plugin_name" || -z "$plugin_function" ]]; then
        log error "Plugin registration failed: name and function required"
        return 1
    fi
    
    if ! declare -f "$plugin_function" >/dev/null 2>&1; then
        log error "Plugin registration failed: function '$plugin_function' not found"
        return 1
    fi
    
    PLUGIN_REGISTRY["$plugin_name"]="$plugin_function"
    PLUGIN_DESCRIPTIONS["$plugin_name"]="$plugin_description"
    PLUGIN_TYPES["$plugin_name"]="$plugin_type"
    log debug "Registered $plugin_type plugin: $plugin_name -> $plugin_function"
    return 0
}

# Load embedded internal plugins (called during initialization)
load_internal_plugins() {
    log debug "Loading embedded internal plugins..."
    
    # Register internal plugins directly (these will be embedded in the final script)
    register_grpc_response_time_plugin
    register_asserts_plugin
    register_proto_plugin
    register_tls_plugin
    register_grpc_headers_trailers_plugin
    register_type_validation_plugin
    
    log info "Loaded ${#PLUGIN_REGISTRY[@]} internal plugins"
}

# Load external plugins from directory
load_external_plugins() {
    local plugin_dir="$1"
    
    if [[ -z "$plugin_dir" ]]; then
        plugin_dir="$EXTERNAL_PLUGIN_DIR"
    fi
    
    # Expand tilde
    plugin_dir=$(expand_tilde "$plugin_dir")
    
    if [[ ! -d "$plugin_dir" ]]; then
        log debug "External plugin directory not found: $plugin_dir"
        return 0
    fi
    
    log info "Loading external plugins from: $plugin_dir"
    
    # Source all .sh files in plugin directory
    local loaded_count=0
    for plugin_file in "$plugin_dir"/*.sh; do
        if [[ -f "$plugin_file" ]]; then
            log debug "Loading external plugin: $(basename "$plugin_file")"
            if source "$plugin_file"; then
                ((loaded_count++))
            else
                log error "Failed to load external plugin: $(basename "$plugin_file")"
            fi
        fi
    done
    
    log info "Loaded $loaded_count external plugins"
}

# Load all plugins (internal + external)
load_all_plugins() {
    load_internal_plugins
    load_external_plugins
}

# Execute plugin assertion
execute_plugin_assertion() {
    local plugin_name="$1"
    local response="$2"
    local header_name="$3"
    local expected_value="$4"
    local operation_type="$5"
    
    if [[ -z "${PLUGIN_REGISTRY[$plugin_name]:-}" ]]; then
        log error "Plugin not found: $plugin_name"
        log info "Available plugins: $(list_plugin_names)"
        return 1
    fi
    
    local plugin_function="${PLUGIN_REGISTRY[$plugin_name]}"
    local plugin_type="${PLUGIN_TYPES[$plugin_name]}"
    
    log debug "Executing $plugin_type plugin: $plugin_name with header: $header_name, value: $expected_value, operation: $operation_type"
    
    # Execute plugin function with appropriate arguments based on operation type
    case "$operation_type" in
        "equals"|"exists")
            if ! "$plugin_function" "$response" "$header_name" "$expected_value"; then
                log error "Plugin assertion failed: $plugin_name"
                return 1
            fi
            ;;
        "test")
            if ! "$plugin_function" "$response" "$header_name" "$expected_value"; then
                log error "Plugin pattern test failed: $plugin_name"
                return 1
            fi
            ;;
        "legacy")
            # Legacy format - pass header_name as args
            if ! "$plugin_function" "$response" "$header_name"; then
                log error "Plugin assertion failed: $plugin_name"
                return 1
            fi
            ;;
        *)
            log error "Unknown operation type: $operation_type"
            return 1
            ;;
    esac
    
    return 0
}

# Parse plugin assertion syntax: @plugin_name:args or @plugin_name("args") operation
parse_plugin_assertion() {
    local assertion_line="$1"
    
    # Support new function-style syntax: @header("name") == "value" or @trailer("name") | test("pattern")
    if [[ "$assertion_line" =~ ^@([a-zA-Z_][a-zA-Z0-9_]*)\(\"([^\"]*)\"\)[[:space:]]*(.*)$ ]]; then
        local plugin_name="${BASH_REMATCH[1]}"
        local header_name="${BASH_REMATCH[2]}"
        local operation="${BASH_REMATCH[3]}"
        
        # Parse operation type and expected value
        if [[ "$operation" =~ ^==[[:space:]]*\"([^\"]*)\"$ ]]; then
            # Equality check: @header("name") == "value"
            local expected_value="${BASH_REMATCH[1]}"
            echo "$plugin_name|$header_name|$expected_value|equals"
        elif [[ "$operation" =~ ^\|[[:space:]]*test\(\"([^\"]*)\"\)$ ]]; then
            # Pattern test: @header("name") | test("pattern")
            local pattern="${BASH_REMATCH[1]}"
            echo "test_$plugin_name|$header_name|$pattern|test"
        else
            # Simple existence check: @header("name")
            echo "$plugin_name|$header_name||exists"
        fi
        return 0
    fi
    
    # Support legacy colon syntax: @plugin_name:args
    if [[ "$assertion_line" =~ ^@([a-zA-Z_][a-zA-Z0-9_]*):(.+)$ ]]; then
        local plugin_name="${BASH_REMATCH[1]}"
        local plugin_args="${BASH_REMATCH[2]}"
        echo "$plugin_name|$plugin_args||legacy"
        return 0
    fi
    
    return 1
}

# Enhanced assertion evaluator with plugin support
evaluate_asserts_with_plugins() {
    local test_file="$1"
    local responses_array="$2"
    
    # Extract ASSERT sections
    local asserts_content=$(extract_asserts "$test_file" "ASSERTS")
    
    if [[ -z "$asserts_content" ]]; then
        return 0  # No asserts to evaluate
    fi
    
    # Create temporary file for asserts
    local asserts_file=$(mktemp)
    echo "$asserts_content" > "$asserts_file"
    
    # Load all plugins if not already loaded
    if [[ ${#PLUGIN_REGISTRY[@]} -eq 0 ]]; then
        load_all_plugins
    fi
    
    # Evaluate asserts against responses
    local response_count=$(echo "$responses_array" | jq 'length')
    
    if [[ $response_count -eq 1 ]]; then
        # Single response - apply asserts to it
        local response=$(echo "$responses_array" | jq -r '.[0]')
        if ! evaluate_asserts_enhanced "$response" "$asserts_file" 1; then
            rm -f "$asserts_file"
            return 1
        fi
    else
        # Multiple responses - apply asserts to each
        for i in $(seq 0 $((response_count - 1))); do
            local response=$(echo "$responses_array" | jq -r ".[$i]")
            if ! evaluate_asserts_enhanced "$response" "$asserts_file" $((i+1)); then
                rm -f "$asserts_file"
                return 1
            fi
        done
    fi
    
    # Cleanup
    rm -f "$asserts_file"
    return 0
}

# Enhanced assertion evaluator that supports both jq and plugins
evaluate_asserts_enhanced() {
    local response="$1"
    local asserts_file="$2"
    local response_index="$3"
    
    local line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Check if it's a plugin assertion
        if plugin_info=$(parse_plugin_assertion "$line"); then
            IFS='|' read -r plugin_name header_name expected_value operation_type <<< "$plugin_info"
            
            if ! execute_plugin_assertion "$plugin_name" "$response" "$header_name" "$expected_value" "$operation_type"; then
                echo "ASSERTS block failed at line $line_number: $line"
                echo "Response: $response"
                return 1
            fi
        else
            # Standard jq filter
            if ! echo "$response" | jq -e "$line" >/dev/null 2>&1; then
                echo "ASSERTS block failed at line $line_number: $line"
                echo "Response: $response"
                return 1
            fi
        fi
    done < "$asserts_file"
    
    return 0
}

# List available plugins
list_plugins() {
    # Load all plugins first
    load_all_plugins
    
    if [[ ${#PLUGIN_REGISTRY[@]} -eq 0 ]]; then
        echo "No plugins registered"
        return 0
    fi
    
    echo "Available plugins:"
    for plugin_name in "${!PLUGIN_REGISTRY[@]}"; do
        local plugin_function="${PLUGIN_REGISTRY[$plugin_name]}"
        local plugin_description="${PLUGIN_DESCRIPTIONS[$plugin_name]}"
        local plugin_type="${PLUGIN_TYPES[$plugin_name]}"
        echo "  - $plugin_name ($plugin_type) -> $plugin_function"
        echo "    $plugin_description"
    done
}

# List plugin names only
list_plugin_names() {
    local names=()
    for plugin_name in "${!PLUGIN_REGISTRY[@]}"; do
        names+=("$plugin_name")
    done
    echo "${names[*]}"
}

# Plugin development helpers
create_plugin_template() {
    local plugin_name="$1"
    local plugin_file="$EXTERNAL_PLUGIN_DIR/${plugin_name}.sh"
    
    if [[ -z "$plugin_name" ]]; then
        log error "Plugin name required"
        return 1
    fi
    
    # Create plugin directory if it doesn't exist
    ensure_directory "$EXTERNAL_PLUGIN_DIR"
    
    # Create plugin template
    cat > "$plugin_file" << EOF
#!/bin/bash

# ${plugin_name}.sh - Custom assertion plugin
# Usage: @${plugin_name}:args

# Plugin function - must be named assert_${plugin_name}
assert_${plugin_name}() {
    local response="\$1"
    local args="\$2"
    
    # Parse arguments
    # Example: args could be "key=value,other=value2"
    
    # Your custom assertion logic here
    # Return 0 for success, 1 for failure
    
    log debug "Executing ${plugin_name} assertion with args: \$args"
    log debug "Response: \$response"
    
    # Example assertion - replace with your logic
    if [[ -n "\$response" ]]; then
        return 0
    else
        return 1
    fi
}

# Register the plugin
register_plugin "${plugin_name}" "assert_${plugin_name}" "Custom ${plugin_name} assertion" "external"
EOF
    
    chmod +x "$plugin_file"
    log success "Created external plugin template: $plugin_file"
    return 0
}

# Internal plugin registration functions (these will be embedded in the final script)

# Plugin registration functions (moved from individual plugin files for bashly embedding)

# Register Enhanced Asserts plugin
register_asserts_plugin() {
    register_plugin "asserts" "evaluate_enhanced_asserts" "Enhanced assertions with inline types" "internal"
}

# Register Proto plugin
register_proto_plugin() {
    register_plugin "proto" "parse_proto_section" "Proto contracts and descriptor files handler" "internal"
}

# Register TLS plugin
register_tls_plugin() {
    register_plugin "tls" "parse_tls_section" "TLS/mTLS configuration handler" "internal"
}

register_grpc_response_time_plugin() {
    # gRPC response time assertion plugin
    # Usage: @grpc_response_time:1000 (max milliseconds) or @grpc_response_time:500-2000 (range)
    
    assert_grpc_response_time() {
        local response="$1"
        local expected_time="$2"
        
        # Extract response time from response metadata or context
        local actual_time
        if actual_time=$(echo "$response" | jq -r '._response_time // .response_time // .duration // .time // empty' 2>/dev/null); then
            if [[ "$actual_time" == "null" || -z "$actual_time" ]]; then
                log error "Response time not found in gRPC response metadata"
                return 1
            fi
        else
            log error "Failed to parse gRPC response for response time"
            return 1
        fi
        
        # Parse expected time (support ranges like 500-2000)
        if [[ "$expected_time" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local min_time="${BASH_REMATCH[1]}"
            local max_time="${BASH_REMATCH[2]}"
            
            if [[ $actual_time -ge $min_time && $actual_time -le $max_time ]]; then
                log debug "gRPC response time $actual_time ms is in range $min_time-$max_time ms"
                return 0
            else
                log error "gRPC response time $actual_time ms is not in range $min_time-$max_time ms"
                return 1
            fi
        else
            # Single max time
            if [[ $actual_time -le $expected_time ]]; then
                log debug "gRPC response time $actual_time ms is within limit $expected_time ms"
                return 0
            else
                log error "gRPC response time $actual_time ms exceeds limit $expected_time ms"
                return 1
            fi
        fi
    }
    
    register_plugin "grpc_response_time" "assert_grpc_response_time" "gRPC response time assertion" "internal"
}




# Export functions for use in other modules
export -f register_plugin
export -f load_internal_plugins
export -f load_external_plugins
export -f load_all_plugins
export -f execute_plugin_assertion
export -f parse_plugin_assertion
export -f evaluate_asserts_with_plugins
export -f evaluate_asserts_enhanced
export -f list_plugins
export -f list_plugin_names
export -f create_plugin_template
export -f register_grpc_response_time_plugin
export -f register_asserts_plugin
export -f register_proto_plugin
export -f register_tls_plugin
