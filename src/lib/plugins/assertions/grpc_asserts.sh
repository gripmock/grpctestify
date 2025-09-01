#!/bin/bash

# grpc_asserts_coordinator.sh - Main Assertion Coordinator Plugin
# Orchestrates and routes assertions to specialized plugins

# Plugin metadata
readonly PLUGIN_COORDINATOR_VERSION="1.0.0"
readonly PLUGIN_COORDINATOR_DESCRIPTION="Main assertion coordinator with specialized plugin routing"
readonly PLUGIN_COORDINATOR_AUTHOR="grpctestify-team"
readonly PLUGIN_COORDINATOR_TYPE="assertion"

# Specialized assertion plugins registry
declare -g -A ASSERTION_PLUGINS=()
declare -g -A ASSERTION_PATTERNS=()

# Initialize assertion coordinator
grpc_asserts_coordinator_init() {
    tlog debug "Initializing assertion coordinator..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    tlog warning "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register main coordinator plugin
    plugin_register "grpc_asserts" "grpc_asserts_coordinator_handler" "$PLUGIN_COORDINATOR_DESCRIPTION" "internal" ""
    
    # Initialize specialized assertion plugins
    grpc_asserts_init_specialized_plugins
    
    # Subscribe to assertion events
    event_subscribe "grpc_asserts" "assertion.*" "grpc_asserts_coordinator_event_handler"
    
    tlog debug "Assertion coordinator initialized successfully"
    return 0
}

# Initialize specialized assertion plugins
grpc_asserts_init_specialized_plugins() {
    tlog debug "Initializing specialized assertion plugins..."
    
    local plugins_loaded=0
    
    # Initialize JSON assertions plugin
    if command -v json_assertions_init >/dev/null 2>&1; then
        if json_assertions_init; then
            assertion_register_specialized_plugin "json_assertions" "json_assertions_handler"
            ((plugins_loaded++))
    tlog debug "JSON assertions plugin loaded"
        else
    tlog warning "Failed to initialize JSON assertions plugin"
        fi
    else
    tlog warning "JSON assertions plugin not available"
    fi
    
    # Initialize regex assertions plugin
    if command -v regex_assertions_init >/dev/null 2>&1; then
        if regex_assertions_init; then
            assertion_register_specialized_plugin "regex_assertions" "regex_assertions_handler"
            ((plugins_loaded++))
    tlog debug "Regex assertions plugin loaded"
        else
    tlog warning "Failed to initialize regex assertions plugin"
        fi
    else
    tlog warning "Regex assertions plugin not available"
    fi
    
    # Initialize numeric assertions plugin
    if command -v numeric_assertions_init >/dev/null 2>&1; then
        if numeric_assertions_init; then
            assertion_register_specialized_plugin "numeric_assertions" "numeric_assertions_handler"
            ((plugins_loaded++))
    tlog debug "Numeric assertions plugin loaded"
        else
    tlog warning "Failed to initialize numeric assertions plugin"
        fi
    else
    tlog warning "Numeric assertions plugin not available"
    fi
    

    
    tlog debug "Specialized assertion plugins loaded: $plugins_loaded"
}

# Register specialized assertion plugin
assertion_register_specialized_plugin() {
    local plugin_name="$1"
    local handler_function="$2"
    
    ASSERTION_PLUGINS["$plugin_name"]="$handler_function"
    
    # Get supported patterns from the plugin
    if command -v "$handler_function" >/dev/null 2>&1; then
        local metadata
        if metadata=$("$handler_function" "metadata" 2>/dev/null); then
            local patterns
            patterns=$(echo "$metadata" | jq -r '.patterns[]? // empty' 2>/dev/null)
            
            while IFS= read -r pattern; do
                if [[ -n "$pattern" ]]; then
                    ASSERTION_PATTERNS["$pattern"]="$plugin_name"
    tlog debug "Registered pattern '$pattern' -> $plugin_name"
                fi
            done <<< "$patterns"
        fi
    fi
}

# Main coordinator handler
grpc_asserts_coordinator_handler() {
    local test_file="$1"
    local responses_array="$2"
    local test_context="${3:-{}}"
    
    if [[ -z "$test_file" ]]; then
    tlog error "grpc_asserts_coordinator_handler: test_file required"
        return 1
    fi
    
    tlog debug "Processing assertions for test file: $test_file"
    
    # Publish assertion processing start event
    event_publish "assertion.processing.start" "{\"test_file\":\"$test_file\",\"coordinator\":\"grpc_asserts\"}" "$EVENT_PRIORITY_NORMAL" "grpc_asserts"
    
    # Extract ASSERTS section
    local asserts_section
    asserts_section="$(extract_asserts "$test_file" "ASSERTS")"
    
    if [[ -z "$asserts_section" ]]; then
    tlog debug "No assertions found in test file: $test_file"
        return 0
    fi
    
    # Process assertions with specialized plugins
    local result=0
    if process_assertions_coordinated "$asserts_section" "$responses_array" "$test_file" "$test_context"; then
    tlog debug "All assertions passed for test file: $test_file"
        event_publish "assertion.processing.success" "{\"test_file\":\"$test_file\",\"coordinator\":\"grpc_asserts\"}" "$EVENT_PRIORITY_NORMAL" "grpc_asserts"
    else
        result=1
    tlog error "One or more assertions failed for test file: $test_file"
        event_publish "assertion.processing.failure" "{\"test_file\":\"$test_file\",\"coordinator\":\"grpc_asserts\"}" "$EVENT_PRIORITY_HIGH" "grpc_asserts"
    fi
    
    return $result
}

# Process assertions with specialized plugin routing
process_assertions_coordinated() {
    local asserts_section="$1"
    local responses_array="$2"
    local test_file="$3"
    local test_context="$4"
    local line_number=0
    local assertion_count=0
    local failed_assertions=0
    
    tlog debug "Processing assertions with specialized plugin routing..."
    
    while IFS= read -r line; do
        ((line_number++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        ((assertion_count++))
    tlog debug "Processing assertion $assertion_count at line $line_number: $line"
        
        # Create assertion context
        local assertion_context
        assertion_context=$(cat << EOF
{
  "line_number": $line_number,
  "test_file": "$test_file",
  "assertion_count": $assertion_count,
  "test_context": $test_context
}
EOF
)
        
        # Route assertion to appropriate specialized plugin
        local assertion_result=0
        if [[ "$line" =~ ^\[([0-9*]+)\][[:space:]]+(.+)$ ]]; then
            # Indexed assertion: [index] assertion
            local index="${BASH_REMATCH[1]}"
            local assertion="${BASH_REMATCH[2]}"
            
            if ! process_indexed_assertion_coordinated "$index" "$assertion" "$responses_array" "$assertion_context"; then
                assertion_result=1
            fi
        elif [[ "$line" =~ ^@([a-zA-Z_][a-zA-Z0-9_]*):(.+)$ ]]; then
            # Plugin assertion: @plugin_name:args (handled by external plugins)
            if ! process_external_plugin_assertion "$line" "$responses_array" "$assertion_context"; then
                assertion_result=1
            fi
        elif [[ "$line" =~ ^\[([0-9*]+)\][[:space:]]*@([a-zA-Z_][a-zA-Z0-9_]*):(.+)$ ]]; then
            # Indexed plugin assertion: [index]@plugin_name:args
            local index="${BASH_REMATCH[1]}"
            local plugin_assertion="@${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
            
            if ! process_indexed_external_plugin_assertion "$index" "$plugin_assertion" "$responses_array" "$assertion_context"; then
                assertion_result=1
            fi
        else
            # Standard assertion - route to specialized plugin
            if ! process_standard_assertion_coordinated "$line" "$responses_array" "$assertion_context"; then
                assertion_result=1
            fi
        fi
        
        # Track failed assertions
        if [[ $assertion_result -ne 0 ]]; then
            ((failed_assertions++))
        fi
        
    done <<< "$asserts_section"
    
    tlog debug "Processed $assertion_count assertions, $failed_assertions failed"
    
    # Return success only if no assertions failed
    [[ $failed_assertions -eq 0 ]]
}

# Process indexed assertion with specialized routing
process_indexed_assertion_coordinated() {
    local index="$1"
    local assertion="$2"
    local responses_array="$3"
    local assertion_context="$4"
    
    tlog debug "Processing indexed assertion [$index]: $assertion"
    
    # Determine response(s) to use based on index
    local target_responses
    if [[ "$index" == "*" ]]; then
        # Apply to all responses
        target_responses="$responses_array"
    else
        # Apply to specific response
        target_responses=$(echo "$responses_array" | jq -c ".[$index:$((index+1))]")
        if [[ "$target_responses" == "[]" || "$target_responses" == "null" ]]; then
            local line_number
            line_number=$(echo "$assertion_context" | jq -r '.line_number')
            echo "ASSERTS failed at line $line_number: No response at index $index"
            return 1
        fi
    fi
    
    # Route assertion to specialized plugin
    route_assertion_to_specialized_plugin "$assertion" "$target_responses" "$assertion_context"
}

# Process standard assertion with specialized routing
process_standard_assertion_coordinated() {
    local assertion="$1"
    local responses_array="$2"
    local assertion_context="$3"
    
    tlog debug "Processing standard assertion: $assertion"
    
    # Use first response for standard assertions
    local response
    response=$(echo "$responses_array" | jq -r '.[0]')
    
    # Route assertion to specialized plugin
    route_assertion_to_specialized_plugin "$assertion" "[$response]" "$assertion_context"
}

# Route assertion to appropriate specialized plugin
route_assertion_to_specialized_plugin() {
    local assertion="$1"
    local responses_array="$2"
    local assertion_context="$3"
    
    # Find matching specialized plugin
    local matched_plugin=""
    for pattern in "${!ASSERTION_PATTERNS[@]}"; do
        if [[ "$assertion" =~ $pattern ]]; then
            matched_plugin="${ASSERTION_PATTERNS[$pattern]}"
    tlog debug "Assertion '$assertion' matched pattern '$pattern' -> $matched_plugin"
            break
        fi
    done
    
    if [[ -n "$matched_plugin" ]]; then
        # Route to specialized plugin
        local handler="${ASSERTION_PLUGINS[$matched_plugin]}"
        if command -v "$handler" >/dev/null 2>&1; then
            local response
            response=$(echo "$responses_array" | jq -r '.[0]')
            
            if "$handler" "evaluate" "$assertion" "$response" "$assertion_context"; then
    tlog debug "Specialized plugin $matched_plugin handled assertion successfully"
                return 0
            else
                local line_number
                line_number=$(echo "$assertion_context" | jq -r '.line_number // "unknown"')
                echo "ASSERTS failed at line $line_number: $assertion"
                echo "Response: $response"
                return 1
            fi
        else
    tlog warning "Handler $handler for plugin $matched_plugin not available"
        fi
    fi
    
    # Fallback to legacy assertion evaluation
    tlog debug "Using legacy assertion evaluation for: $assertion"
    process_legacy_assertion "$assertion" "$responses_array" "$assertion_context"
}

# Process external plugin assertion (e.g., response time, headers)
process_external_plugin_assertion() {
    local assertion="$1"
    local responses_array="$2"
    local assertion_context="$3"
    
    # Extract plugin name from assertion
    local plugin_name
    plugin_name=$(echo "$assertion" | sed 's/^@\([^:]*\):.*/\1/')
    
    tlog debug "Processing external plugin assertion: $plugin_name"
    
    # Check if plugin exists in registry
    if ! plugin_exists "$plugin_name"; then
    tlog warning "External plugin '$plugin_name' not found in registry"
        return 1
    fi
    
    # Use first response for plugin assertions
    local response
    response=$(echo "$responses_array" | jq -r '.[0]')
    
    # Extract arguments
    local args
    args=$(echo "$assertion" | sed 's/^@[^:]*://')
    
    # Execute external plugin
    if plugin_execute "$plugin_name" "evaluate_assertion" "$response" "$args" "$assertion_context"; then
    tlog debug "External plugin assertion succeeded: $assertion"
        return 0
    else
        local line_number
        line_number=$(echo "$assertion_context" | jq -r '.line_number // "unknown"')
        echo "ASSERTS failed at line $line_number: $assertion"
        echo "Response: $response"
        return 1
    fi
}

# Process indexed external plugin assertion
process_indexed_external_plugin_assertion() {
    local index="$1"
    local assertion="$2"
    local responses_array="$3"
    local assertion_context="$4"
    
    tlog debug "Processing indexed external plugin assertion [$index]: $assertion"
    
    # Determine response to use based on index
    local response
    if [[ "$index" == "*" ]]; then
        # For wildcard, test against all responses (use first for now)
        response=$(echo "$responses_array" | jq -r '.[0]')
    else
        response=$(echo "$responses_array" | jq -r ".[$index]")
        if [[ "$response" == "null" ]]; then
            local line_number
            line_number=$(echo "$assertion_context" | jq -r '.line_number')
            echo "ASSERTS failed at line $line_number: No response at index $index"
            return 1
        fi
    fi
    
    # Process as external plugin assertion with specific response
    process_external_plugin_assertion "$assertion" "[$response]" "$assertion_context"
}

# Fallback to legacy assertion evaluation
process_legacy_assertion() {
    local assertion="$1"
    local responses_array="$2"
    local assertion_context="$3"
    
    tlog debug "Processing legacy assertion: $assertion"
    
    # Use first response for legacy evaluation
    local response
    response=$(echo "$responses_array" | jq -r '.[0]')
    
    # Use legacy evaluation function if available
    if command -v evaluate_assertion_expression >/dev/null 2>&1; then
        if evaluate_assertion_expression "$assertion" "$response"; then
            return 0
        else
            local line_number
            line_number=$(echo "$assertion_context" | jq -r '.line_number // "unknown"')
            echo "ASSERTS failed at line $line_number: $assertion"
            echo "Response: $response"
            return 1
        fi
    else
    tlog warning "Legacy assertion evaluation not available, using fallback"
        return 1
    fi
}

# Event handler for coordination events
grpc_asserts_coordinator_event_handler() {
    local event_type="$1"
    local event_data="$2"
    
    tlog debug "Assertion coordinator received event: $event_type"
    
    # Forward events to specialized plugins
    for plugin_name in "${!ASSERTION_PLUGINS[@]}"; do
        local handler="${ASSERTION_PLUGINS[$plugin_name]}"
        if command -v "${handler%_handler}_event_handler" >/dev/null 2>&1; then
            "${handler%_handler}_event_handler" "$event_type" "$event_data"
        fi
    done
    
    return 0
}

# Get coordinator statistics
grpc_asserts_get_coordinator_stats() {
    local stats
    stats=$(cat << EOF
{
  "coordinator_version": "$PLUGIN_COORDINATOR_VERSION",
  "specialized_plugins": $(printf '%s\n' "${!ASSERTION_PLUGINS[@]}" | jq -R . | jq -s .),
  "registered_patterns": $(printf '%s\n' "${!ASSERTION_PATTERNS[@]}" | jq -R . | jq -s . | jq 'length'),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
)
    
    echo "$stats"
}

# Export coordinator functions
export -f grpc_asserts_coordinator_init grpc_asserts_coordinator_handler
export -f grpc_asserts_init_specialized_plugins assertion_register_specialized_plugin
export -f process_assertions_coordinated process_indexed_assertion_coordinated
export -f process_standard_assertion_coordinated route_assertion_to_specialized_plugin
export -f process_external_plugin_assertion process_indexed_external_plugin_assertion
export -f process_legacy_assertion grpc_asserts_coordinator_event_handler
export -f grpc_asserts_get_coordinator_stats

# Maintain backward compatibility by aliasing to coordinator functions
alias grpc_asserts_init="grpc_asserts_coordinator_init"
alias grpc_asserts_handler="grpc_asserts_coordinator_handler"
