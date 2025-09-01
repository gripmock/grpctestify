#!/bin/bash

# json_assertions.sh - JSON/JQ Assertion Plugin
# Specialized plugin for JSON structure and value validation using jq expressions

# Plugin metadata
readonly PLUGIN_JSON_ASSERTIONS_VERSION="1.0.0"
readonly PLUGIN_JSON_ASSERTIONS_DESCRIPTION="JSON structure and value validation using jq expressions"
readonly PLUGIN_JSON_ASSERTIONS_AUTHOR="grpctestify-team"
readonly PLUGIN_JSON_ASSERTIONS_TYPE="assertion"

# Supported patterns (regex patterns this plugin handles)
readonly JSON_ASSERTION_PATTERNS=(
    '^\..*'                    # .field == "value"
    '^has\('                   # has("field")
    '^type\s*=='               # type == "string"
    '^length\s*[><=!]'         # length > 5
    '^contains\('              # contains("text")
    '^startswith\('            # startswith("prefix")
    '^endswith\('              # endswith("suffix")
    '^test\('                  # test("regex")
    '^map\('                   # map(.field)
    '^select\('                # select(.field > 0)
    '^sort_by\('               # sort_by(.field)
    '^group_by\('              # group_by(.type)
    '^min_by\('                # min_by(.score)
    '^max_by\('                # max_by(.score)
    '^unique\b'                # unique
    '^reverse\b'               # reverse
    '^flatten\b'               # flatten
    '^keys\b'                  # keys
    '^values\b'                # values
    '^empty\b'                 # empty check
    '^null\b'                  # null check
)

# Initialize JSON assertions plugin
json_assertions_init() {
    tlog debug "Initializing JSON assertions plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    tlog warning "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "json_assertions" "json_assertions_handler" "$PLUGIN_JSON_ASSERTIONS_DESCRIPTION" "assertion" ""
    
    # Register assertion patterns this plugin handles
    for pattern in "${JSON_ASSERTION_PATTERNS[@]}"; do
        assertion_register_pattern "json" "$pattern" "json_assertions_handler"
    done
    
    # Subscribe to assertion events
    event_subscribe "json_assertions" "assertion.json.*" "json_assertions_event_handler"
    
    tlog debug "JSON assertions plugin initialized successfully"
    return 0
}

# Main plugin handler
json_assertions_handler() {
    local command="$1"
    shift
    
    case "$command" in
        "evaluate")
            json_evaluate_assertion "$@"
            ;;
        "validate_syntax")
            json_validate_assertion_syntax "$@"
            ;;
        "supports_pattern")
            json_supports_pattern "$@"
            ;;
        "metadata")
            json_assertion_metadata
            ;;
        "health")
            json_assertions_health_check
            ;;
        *)
    tlog error "Unknown JSON assertions command: $command"
            return 1
            ;;
    esac
}

# Evaluate JSON assertion using jq
json_evaluate_assertion() {
    local assertion="$1"
    local response="$2"
    local context="$3"
    
    if [[ -z "$assertion" || -z "$response" ]]; then
    tlog error "json_evaluate_assertion: assertion and response required"
        return 1
    fi
    
    tlog debug "Evaluating JSON assertion: $assertion"
    
    # Extract metadata from context if provided
    local line_number=""
    local test_file=""
    if [[ -n "$context" ]]; then
        line_number=$(echo "$context" | jq -r '.line_number // ""' 2>/dev/null)
        test_file=$(echo "$context" | jq -r '.test_file // ""' 2>/dev/null)
    fi
    
    # Publish evaluation start event
    local event_data="{\"assertion\":\"$assertion\",\"line_number\":$line_number,\"test_file\":\"$test_file\"}"
    event_publish "assertion.json.evaluation.start" "$event_data" "$EVENT_PRIORITY_LOW" "json_assertions"
    
    # Validate JSON response first
    if ! echo "$response" | jq . >/dev/null 2>&1; then
    tlog error "Invalid JSON response for assertion evaluation"
        event_publish "assertion.json.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "json_assertions"
        return 1
    fi
    
    # Validate jq expression syntax
    if ! json_validate_jq_syntax "$assertion"; then
    tlog error "Invalid jq expression syntax: $assertion"
        event_publish "assertion.json.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "json_assertions"
        return 1
    fi
    
    # Execute jq expression with timeout and error handling
    local jq_result
    local jq_exit_code
    
    # Use timeout to prevent hanging on complex expressions
    if command -v timeout >/dev/null 2>&1; then
        jq_result=$(timeout 30 echo "$response" | jq -e "$assertion" 2>&1)
        jq_exit_code=$?
    else
        jq_result=$(echo "$response" | jq -e "$assertion" 2>&1)
        jq_exit_code=$?
    fi
    
    # Analyze result
    case $jq_exit_code in
        0)
            # Success: assertion evaluated to true/truthy
    tlog debug "JSON assertion passed: $assertion"
            event_publish "assertion.json.evaluation.success" "$event_data" "$EVENT_PRIORITY_LOW" "json_assertions"
            return 0
            ;;
        1)
            # jq evaluated successfully but result was false/null/empty
    tlog debug "JSON assertion failed (false result): $assertion"
            event_publish "assertion.json.evaluation.failure" "$event_data" "$EVENT_PRIORITY_NORMAL" "json_assertions"
            return 1
            ;;
        5)
            # jq couldn't parse the input
    tlog error "JSON parsing error in assertion: $assertion"
    tlog error "jq error: $jq_result"
            event_publish "assertion.json.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "json_assertions"
            return 1
            ;;
        124)
            # timeout
    tlog error "JSON assertion timed out: $assertion"
            event_publish "assertion.json.evaluation.timeout" "$event_data" "$EVENT_PRIORITY_HIGH" "json_assertions"
            return 1
            ;;
        *)
            # Other error
    tlog error "JSON assertion error (exit code $jq_exit_code): $assertion"
    tlog error "jq error: $jq_result"
            event_publish "assertion.json.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "json_assertions"
            return 1
            ;;
    esac
}

# Validate jq expression syntax
json_validate_jq_syntax() {
    local expression="$1"
    
    # Test compilation without execution
    echo '{}' | jq -n "$expression" >/dev/null 2>&1
    return $?
}

# Validate assertion syntax for this plugin
json_validate_assertion_syntax() {
    local assertion="$1"
    
    if [[ -z "$assertion" ]]; then
    tlog error "Empty assertion"
        return 1
    fi
    
    # Check if this plugin supports the pattern
    if ! json_supports_pattern "$assertion"; then
    tlog error "Assertion pattern not supported by JSON plugin: $assertion"
        return 1
    fi
    
    # Validate jq syntax
    if ! json_validate_jq_syntax "$assertion"; then
    tlog error "Invalid jq syntax: $assertion"
        return 1
    fi
    
    return 0
}

# Check if plugin supports given assertion pattern
json_supports_pattern() {
    local assertion="$1"
    
    for pattern in "${JSON_ASSERTION_PATTERNS[@]}"; do
        if [[ "$assertion" =~ $pattern ]]; then
            return 0
        fi
    done
    
    return 1
}

# Get plugin metadata
json_assertion_metadata() {
    cat << EOF
{
  "name": "json_assertions",
  "version": "$PLUGIN_JSON_ASSERTIONS_VERSION",
  "description": "$PLUGIN_JSON_ASSERTIONS_DESCRIPTION",
  "author": "$PLUGIN_JSON_ASSERTIONS_AUTHOR",
  "type": "$PLUGIN_JSON_ASSERTIONS_TYPE",
  "patterns": $(printf '%s\n' "${JSON_ASSERTION_PATTERNS[@]}" | jq -R . | jq -s .),
  "capabilities": [
    "jq_expression_evaluation",
    "json_path_validation",
    "type_checking",
    "array_operations",
    "object_operations",
    "string_operations",
    "numeric_operations"
  ],
  "dependencies": ["jq"],
  "examples": [
    ".field == \"value\"",
    ".array | length > 5",
    "has(\"required_field\")",
    ".nested.object.value | contains(\"text\")",
    "type == \"object\"",
    ".items | map(.id) | unique | length == (.items | length)"
  ]
}
EOF
}

# Health check for the plugin
json_assertions_health_check() {
    local status="healthy"
    local issues=()
    
    # Check jq availability
    if ! command -v jq >/dev/null 2>&1; then
        status="unhealthy"
        issues+=("jq command not available")
    fi
    
    # Test basic jq functionality
    if ! echo '{"test": true}' | jq -e '.test' >/dev/null 2>&1; then
        status="unhealthy"
        issues+=("jq basic functionality test failed")
    fi
    
    # Test timeout command if available
    if command -v timeout >/dev/null 2>&1; then
        if ! timeout 1 echo '{}' | jq . >/dev/null 2>&1; then
            issues+=("timeout command not working properly")
        fi
    else
        issues+=("timeout command not available (non-critical)")
    fi
    
    # Output health status
    local health_report
    health_report=$(cat << EOF
{
  "plugin": "json_assertions",
  "status": "$status",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .),
  "dependencies": {
    "jq": "$(command -v jq >/dev/null 2>&1 && echo "available" || echo "missing")",
    "timeout": "$(command -v timeout >/dev/null 2>&1 && echo "available" || echo "missing")"
  }
}
EOF
)
    
    echo "$health_report"
    [[ "$status" == "healthy" ]]
}

# Event handler for JSON assertion events
json_assertions_event_handler() {
    local event_type="$1"
    local event_data="$2"
    
    tlog debug "JSON assertions plugin received event: $event_type"
    
    # Handle different event types
    case "$event_type" in
        "assertion.json.performance.monitor")
            # Monitor performance of JSON assertions
            json_monitor_performance "$event_data"
            ;;
        "assertion.json.cache.clear")
            # Clear any internal caches
            json_clear_caches
            ;;
        *)
    tlog debug "Unhandled event type: $event_type"
            ;;
    esac
    
    return 0
}

# Performance monitoring helper
json_monitor_performance() {
    local event_data="$1"
    
    # Extract performance metrics from event data
    local assertion=$(echo "$event_data" | jq -r '.assertion // ""')
    local execution_time=$(echo "$event_data" | jq -r '.execution_time // 0')
    
    # Log slow assertions
    if [[ $(echo "$execution_time > 1000" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
    tlog warning "Slow JSON assertion detected (${execution_time}ms): $assertion"
    fi
}

# Clear internal caches
json_clear_caches() {
    # Currently no caches implemented, but placeholder for future optimization
    tlog debug "JSON assertions caches cleared"
}

# Assertion pattern registration helper (if available)
assertion_register_pattern() {
    local plugin_type="$1"
    local pattern="$2"
    local handler="$3"
    
    # This function should be provided by the assertion engine
    # For now, just log the registration attempt
    tlog debug "Registering assertion pattern: $plugin_type -> $pattern -> $handler"
}

# Export functions
export -f json_assertions_init json_assertions_handler json_evaluate_assertion
export -f json_validate_assertion_syntax json_supports_pattern json_assertion_metadata
export -f json_assertions_health_check json_assertions_event_handler
export -f json_validate_jq_syntax json_monitor_performance json_clear_caches
