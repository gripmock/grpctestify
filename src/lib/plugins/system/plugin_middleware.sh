#!/bin/bash

# plugin_middleware.sh - Plugin Middleware System
# Allows plugins to process requests/responses in pipeline fashion
# Dramatically enhances plugin capabilities for data transformation

# Middleware registry
declare -g -A MIDDLEWARE_CHAINS=()      # chain_name -> "plugin1:func1,plugin2:func2"
declare -g -A MIDDLEWARE_PRIORITIES=()  # chain_name:plugin_name -> priority
declare -g -A MIDDLEWARE_CONFIG=()      # chain_name:plugin_name -> config_json

# Predefined middleware chains
readonly MIDDLEWARE_REQUEST_CHAIN="request.process"
readonly MIDDLEWARE_RESPONSE_CHAIN="response.process"
readonly MIDDLEWARE_ASSERTION_CHAIN="assertion.process"
readonly MIDDLEWARE_ERROR_CHAIN="error.process"
readonly MIDDLEWARE_VALIDATION_CHAIN="validation.process"

#######################################
# Register middleware in a processing chain
# Arguments:
#   1: chain_name - middleware chain name
#   2: plugin_name - name of plugin
#   3: function_name - middleware function
#   4: priority - processing priority (1-100, higher = earlier)
#   5: config - optional configuration JSON
# Returns:
#   0 on success, 1 on error
#######################################
middleware_register() {
    local chain_name="$1"
    local plugin_name="$2"
    local function_name="$3"
    local priority="${4:-50}"
    local config="${5:-{}}"
    
    if [[ -z "$chain_name" || -z "$plugin_name" || -z "$function_name" ]]; then
	tlog error "middleware_register: chain_name, plugin_name, and function_name required"
        return 1
    fi
    
    # Validate priority
    if [[ ! "$priority" =~ ^[0-9]+$ ]] || [[ "$priority" -lt 1 ]] || [[ "$priority" -gt 100 ]]; then
	tlog error "middleware_register: priority must be 1-100"
        return 1
    fi
    
    # Validate function exists
    if ! command -v "$function_name" >/dev/null 2>&1; then
	tlog warning "middleware_register: function $function_name not found (may be loaded later)"
    fi
    
    # Add to middleware chain
    local current_chain="${MIDDLEWARE_CHAINS[$chain_name]:-}"
    local middleware_entry="$plugin_name:$function_name"
    
    if [[ -n "$current_chain" ]]; then
        MIDDLEWARE_CHAINS[$chain_name]="$current_chain,$middleware_entry"
    else
        MIDDLEWARE_CHAINS[$chain_name]="$middleware_entry"
    fi
    
    # Store priority and config
    MIDDLEWARE_PRIORITIES["$chain_name:$plugin_name"]="$priority"
    MIDDLEWARE_CONFIG["$chain_name:$plugin_name"]="$config"
    
    tlog debug "Registered middleware: $chain_name -> $plugin_name:$function_name (priority: $priority)"
    return 0
}

#######################################
# Execute middleware chain
# Arguments:
#   1: chain_name - middleware chain name
#   2: data - input data to process
#   3: context - processing context JSON
# Returns:
#   0 on success, 1 on error
# Outputs:
#   Processed data
#######################################
middleware_execute() {
    local chain_name="$1"
    local data="$2"
    local context="${3:-{}}"
    
    local chain="${MIDDLEWARE_CHAINS[$chain_name]:-}"
    if [[ -z "$chain" ]]; then
	tlog debug "No middleware registered for chain: $chain_name"
        echo "$data"
        return 0
    fi
    
    # Parse and sort middleware by priority
    local middleware_list=()
    IFS=',' read -ra middleware_array <<< "$chain"
    
    for middleware_entry in "${middleware_array[@]}"; do
        IFS=':' read -r plugin_name function_name <<< "$middleware_entry"
        local priority="${MIDDLEWARE_PRIORITIES["$chain_name:$plugin_name"]:-50}"
        middleware_list+=("$priority:$plugin_name:$function_name")
    done
    
    # Sort by priority (higher priority first)
    IFS=$'\n' middleware_list=($(sort -rn <<< "${middleware_list[*]}"))
    
    tlog debug "Executing middleware chain: $chain_name (${#middleware_list[@]} middleware)"
    
    local current_data="$data"
    local processed_context="$context"
    
    for middleware_entry in "${middleware_list[@]}"; do
        IFS=':' read -r priority plugin_name function_name <<< "$middleware_entry"
        
        local config="${MIDDLEWARE_CONFIG["$chain_name:$plugin_name"]:-{}}"
        
        tlog debug "Processing middleware: $plugin_name:$function_name (priority: $priority)"
        
        if command -v "$function_name" >/dev/null 2>&1; then
            # Execute middleware function
            # Middleware functions should accept: data, context, config
            # And return: processed_data
            local result
            if result=$("$function_name" "$current_data" "$processed_context" "$config" 2>/dev/null); then
                current_data="$result"
            else
	        tlog warning "Middleware failed: $plugin_name:$function_name"
                # Continue with original data on failure (resilient processing)
            fi
        else
	    tlog warning "Middleware function not found: $function_name"
        fi
    done
    
    echo "$current_data"
    return 0
}

#######################################
# Create middleware chain for request processing
# Used by execution plugins to allow transformation
# Arguments:
#   1: request_data - original request
#   2: test_context - test context
# Returns:
#   Processed request data
#######################################
middleware_process_request() {
    local request_data="$1"
    local test_context="$2"
    
    middleware_execute "$MIDDLEWARE_REQUEST_CHAIN" "$request_data" "$test_context"
}

#######################################
# Create middleware chain for response processing
# Arguments:
#   1: response_data - gRPC response
#   2: test_context - test context
# Returns:
#   Processed response data
#######################################
middleware_process_response() {
    local response_data="$1"
    local test_context="$2"
    
    middleware_execute "$MIDDLEWARE_RESPONSE_CHAIN" "$response_data" "$test_context"
}

#######################################
# Create middleware chain for assertion processing
# Arguments:
#   1: assertion_data - assertion to process
#   2: test_context - test context
# Returns:
#   Processed assertion
#######################################
middleware_process_assertion() {
    local assertion_data="$1"
    local test_context="$2"
    
    middleware_execute "$MIDDLEWARE_ASSERTION_CHAIN" "$assertion_data" "$test_context"
}

#######################################
# List all middleware chains
# Outputs:
#   Middleware chain information
#######################################
middleware_list() {
    echo "Registered Middleware Chains:"
    echo "============================="
    
    for chain_name in "${!MIDDLEWARE_CHAINS[@]}"; do
        local chain="${MIDDLEWARE_CHAINS[$chain_name]}"
        echo "Chain: $chain_name"
        
        # Parse and sort by priority for display
        local middleware_list=()
        IFS=',' read -ra middleware_array <<< "$chain"
        
        for middleware_entry in "${middleware_array[@]}"; do
            IFS=':' read -r plugin_name function_name <<< "$middleware_entry"
            local priority="${MIDDLEWARE_PRIORITIES["$chain_name:$plugin_name"]:-50}"
            middleware_list+=("$priority:$plugin_name:$function_name")
        done
        
        IFS=$'\n' middleware_list=($(sort -rn <<< "${middleware_list[*]}"))
        
        for middleware_entry in "${middleware_list[@]}"; do
            IFS=':' read -r priority plugin_name function_name <<< "$middleware_entry"
            echo "  - $plugin_name:$function_name (priority: $priority)"
        done
        echo ""
    done
}

#######################################
# Unregister middleware from chain
# Arguments:
#   1: chain_name - middleware chain name
#   2: plugin_name - name of plugin
# Returns:
#   0 on success, 1 on error
#######################################
middleware_unregister() {
    local chain_name="$1"
    local plugin_name="$2"
    
    if [[ -z "$chain_name" || -z "$plugin_name" ]]; then
	tlog error "middleware_unregister: chain_name and plugin_name required"
        return 1
    fi
    
    local current_chain="${MIDDLEWARE_CHAINS[$chain_name]:-}"
    if [[ -z "$current_chain" ]]; then
        return 0  # Nothing to unregister
    fi
    
    # Remove from middleware chain
    local new_chain=""
    IFS=',' read -ra middleware_array <<< "$current_chain"
    
    for middleware_entry in "${middleware_array[@]}"; do
        IFS=':' read -r entry_plugin entry_function <<< "$middleware_entry"
        if [[ "$entry_plugin" != "$plugin_name" ]]; then
            if [[ -n "$new_chain" ]]; then
                new_chain="$new_chain,$middleware_entry"
            else
                new_chain="$middleware_entry"
            fi
        fi
    done
    
    if [[ -n "$new_chain" ]]; then
        MIDDLEWARE_CHAINS[$chain_name]="$new_chain"
    else
        unset MIDDLEWARE_CHAINS[$chain_name]
    fi
    
    # Clean up related data
    unset MIDDLEWARE_PRIORITIES["$chain_name:$plugin_name"]
    unset MIDDLEWARE_CONFIG["$chain_name:$plugin_name"]
    
    tlog debug "Unregistered middleware: $chain_name -> $plugin_name"
    return 0
}

# Export middleware functions
export -f middleware_register
export -f middleware_execute
export -f middleware_process_request
export -f middleware_process_response
export -f middleware_process_assertion
export -f middleware_list
export -f middleware_unregister


