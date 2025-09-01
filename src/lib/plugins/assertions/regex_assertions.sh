#!/bin/bash

# regex_assertions.sh - Regex Pattern Assertion Plugin
# Specialized plugin for pattern matching and text validation using regular expressions

# Plugin metadata
readonly PLUGIN_REGEX_ASSERTIONS_VERSION="1.0.0"
readonly PLUGIN_REGEX_ASSERTIONS_DESCRIPTION="Pattern matching and text validation using regular expressions"
readonly PLUGIN_REGEX_ASSERTIONS_AUTHOR="grpctestify-team"
readonly PLUGIN_REGEX_ASSERTIONS_TYPE="assertion"

# Supported patterns (regex patterns this plugin handles)
readonly REGEX_ASSERTION_PATTERNS=(
    '^@regex:'                 # @regex:field:^[A-Z]{3}-\d{4}$
    '^@pattern:'               # @pattern:message:error.*not found
    '^@match:'                 # @match:text:exact string
    '^@contains:'              # @contains:field:substring
    '^@starts_with:'           # @starts_with:field:prefix
    '^@ends_with:'             # @ends_with:field:suffix
    '^@not_match:'             # @not_match:field:pattern
    '^@case_insensitive:'      # @case_insensitive:field:pattern
    '^@multiline:'             # @multiline:field:pattern
    '^@word_boundary:'         # @word_boundary:field:word
)

# Initialize regex assertions plugin
regex_assertions_init() {
    tlog debug "Initializing regex assertions plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    tlog warning "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "regex_assertions" "regex_assertions_handler" "$PLUGIN_REGEX_ASSERTIONS_DESCRIPTION" "assertion" ""
    
    # Register assertion patterns this plugin handles
    for pattern in "${REGEX_ASSERTION_PATTERNS[@]}"; do
        assertion_register_pattern "regex" "$pattern" "regex_assertions_handler"
    done
    
    # Subscribe to assertion events
    event_subscribe "regex_assertions" "assertion.regex.*" "regex_assertions_event_handler"
    
    tlog debug "Regex assertions plugin initialized successfully"
    return 0
}

# Main plugin handler
regex_assertions_handler() {
    local command="$1"
    shift
    
    case "$command" in
        "evaluate")
            regex_evaluate_assertion "$@"
            ;;
        "validate_syntax")
            regex_validate_assertion_syntax "$@"
            ;;
        "supports_pattern")
            regex_supports_pattern "$@"
            ;;
        "metadata")
            regex_assertion_metadata
            ;;
        "health")
            regex_assertions_health_check
            ;;
        *)
    tlog error "Unknown regex assertions command: $command"
            return 1
            ;;
    esac
}

# Evaluate regex assertion
regex_evaluate_assertion() {
    local assertion="$1"
    local response="$2"
    local context="$3"
    
    if [[ -z "$assertion" || -z "$response" ]]; then
    tlog error "regex_evaluate_assertion: assertion and response required"
        return 1
    fi
    
    tlog debug "Evaluating regex assertion: $assertion"
    
    # Parse assertion format: @type:field:pattern or @type:pattern
    local assertion_type field_path pattern flags=""
    if ! regex_parse_assertion "$assertion" assertion_type field_path pattern flags; then
    tlog error "Failed to parse regex assertion: $assertion"
        return 1
    fi
    
    # Extract metadata from context if provided
    local line_number=""
    local test_file=""
    if [[ -n "$context" ]]; then
        line_number=$(echo "$context" | jq -r '.line_number // ""' 2>/dev/null)
        test_file=$(echo "$context" | jq -r '.test_file // ""' 2>/dev/null)
    fi
    
    # Publish evaluation start event
    local event_data="{\"assertion\":\"$assertion\",\"type\":\"$assertion_type\",\"field\":\"$field_path\",\"pattern\":\"$pattern\",\"line_number\":$line_number,\"test_file\":\"$test_file\"}"
    event_publish "assertion.regex.evaluation.start" "$event_data" "$EVENT_PRIORITY_LOW" "regex_assertions"
    
    # Extract field value from response
    local field_value
    if [[ -n "$field_path" ]]; then
        if ! field_value=$(echo "$response" | jq -r ".$field_path" 2>/dev/null); then
    tlog error "Failed to extract field '$field_path' from response"
            event_publish "assertion.regex.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "regex_assertions"
            return 1
        fi
    else
        # Use entire response as string
        field_value="$response"
    fi
    
    # Handle null/empty values
    if [[ "$field_value" == "null" || -z "$field_value" ]]; then
        case "$assertion_type" in
            "not_match"|"not_contains")
                # For negative assertions, null/empty is considered a pass
    tlog debug "Regex assertion passed (null/empty value): $assertion"
                event_publish "assertion.regex.evaluation.success" "$event_data" "$EVENT_PRIORITY_LOW" "regex_assertions"
                return 0
                ;;
            *)
    tlog debug "Regex assertion failed (null/empty value): $assertion"
                event_publish "assertion.regex.evaluation.failure" "$event_data" "$EVENT_PRIORITY_NORMAL" "regex_assertions"
                return 1
                ;;
        esac
    fi
    
    # Evaluate assertion based on type
    local result=0
    case "$assertion_type" in
        "regex")
            regex_test_pattern "$field_value" "$pattern" "$flags"
            result=$?
            ;;
        "pattern")
            regex_test_pattern "$field_value" "$pattern" "$flags"
            result=$?
            ;;
        "match")
            [[ "$field_value" == "$pattern" ]]
            result=$?
            ;;
        "contains")
            [[ "$field_value" == *"$pattern"* ]]
            result=$?
            ;;
        "starts_with")
            [[ "$field_value" == "$pattern"* ]]
            result=$?
            ;;
        "ends_with")
            [[ "$field_value" == *"$pattern" ]]
            result=$?
            ;;
        "not_match")
            [[ "$field_value" != "$pattern" ]]
            result=$?
            ;;
        "case_insensitive")
            regex_test_pattern "$field_value" "$pattern" "i"
            result=$?
            ;;
        "multiline")
            regex_test_pattern "$field_value" "$pattern" "m"
            result=$?
            ;;
        "word_boundary")
            regex_test_pattern "$field_value" "\\b$pattern\\b" ""
            result=$?
            ;;
        *)
    tlog error "Unknown regex assertion type: $assertion_type"
            event_publish "assertion.regex.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "regex_assertions"
            return 1
            ;;
    esac
    
    # Handle result
    if [[ $result -eq 0 ]]; then
    tlog debug "Regex assertion passed: $assertion"
        event_publish "assertion.regex.evaluation.success" "$event_data" "$EVENT_PRIORITY_LOW" "regex_assertions"
        return 0
    else
    tlog debug "Regex assertion failed: $assertion"
        event_publish "assertion.regex.evaluation.failure" "$event_data" "$EVENT_PRIORITY_NORMAL" "regex_assertions"
        return 1
    fi
}

# Parse assertion into components
regex_parse_assertion() {
    local assertion="$1"
    local -n type_ref="$2"
    local -n field_ref="$3"
    local -n pattern_ref="$4"
    local -n flags_ref="$5"
    
    # Remove @ prefix
    assertion="${assertion#@}"
    
    # Split by colons
    IFS=':' read -ra parts <<< "$assertion"
    
    if [[ ${#parts[@]} -lt 2 ]]; then
    tlog error "Invalid assertion format: @$assertion"
        return 1
    fi
    
    type_ref="${parts[0]}"
    
    if [[ ${#parts[@]} -eq 2 ]]; then
        # Format: @type:pattern
        field_ref=""
        pattern_ref="${parts[1]}"
    elif [[ ${#parts[@]} -eq 3 ]]; then
        # Format: @type:field:pattern
        field_ref="${parts[1]}"
        pattern_ref="${parts[2]}"
    elif [[ ${#parts[@]} -eq 4 ]]; then
        # Format: @type:field:pattern:flags
        field_ref="${parts[1]}"
        pattern_ref="${parts[2]}"
        flags_ref="${parts[3]}"
    else
        # Join remaining parts as pattern (in case pattern contains colons)
        field_ref="${parts[1]}"
        pattern_ref="${parts[2]}"
        for ((i=3; i<${#parts[@]}; i++)); do
            pattern_ref="$pattern_ref:${parts[i]}"
        done
    fi
    
    return 0
}

# Test regex pattern with flags
regex_test_pattern() {
    local text="$1"
    local pattern="$2"
    local flags="$3"
    
    # Use different approaches based on available tools
    if command -v grep >/dev/null 2>&1; then
        local grep_flags=""
        
        # Convert flags to grep format
        [[ "$flags" == *"i"* ]] && grep_flags="${grep_flags}i"
        [[ "$flags" == *"m"* ]] && grep_flags="${grep_flags}m"
        
        if [[ -n "$grep_flags" ]]; then
            echo "$text" | grep -q${grep_flags} "$pattern"
        else
            echo "$text" | grep -q "$pattern"
        fi
    else
        # Fallback to bash regex (limited functionality)
        if [[ "$flags" == *"i"* ]]; then
            # Case insensitive comparison
            local lower_text lower_pattern
            lower_text=$(echo "$text" | tr '[:upper:]' '[:lower:]')
            lower_pattern=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
            [[ "$lower_text" =~ $lower_pattern ]]
        else
            [[ "$text" =~ $pattern ]]
        fi
    fi
}

# Validate assertion syntax for this plugin
regex_validate_assertion_syntax() {
    local assertion="$1"
    
    if [[ -z "$assertion" ]]; then
    tlog error "Empty assertion"
        return 1
    fi
    
    # Check if this plugin supports the pattern
    if ! regex_supports_pattern "$assertion"; then
    tlog error "Assertion pattern not supported by regex plugin: $assertion"
        return 1
    fi
    
    # Parse and validate components
    local assertion_type field_path pattern flags=""
    if ! regex_parse_assertion "$assertion" assertion_type field_path pattern flags; then
    tlog error "Invalid assertion format: $assertion"
        return 1
    fi
    
    # Validate regex pattern syntax
    if [[ "$assertion_type" == "regex" || "$assertion_type" == "pattern" ]]; then
        if ! regex_validate_pattern_syntax "$pattern"; then
    tlog error "Invalid regex pattern: $pattern"
            return 1
        fi
    fi
    
    return 0
}

# Validate regex pattern syntax
regex_validate_pattern_syntax() {
    local pattern="$1"
    
    # Test pattern compilation
    if command -v grep >/dev/null 2>&1; then
        echo "" | grep -q "$pattern" 2>/dev/null
        return $?
    else
        # Basic validation for bash regex
        if [[ "$pattern" == *'[' && "$pattern" != *']'* ]]; then
            return 1  # Unclosed bracket
        fi
        if [[ "$pattern" == *'(' && "$pattern" != *')'* ]]; then
            return 1  # Unclosed parenthesis
        fi
        return 0
    fi
}

# Check if plugin supports given assertion pattern
regex_supports_pattern() {
    local assertion="$1"
    
    for pattern in "${REGEX_ASSERTION_PATTERNS[@]}"; do
        if [[ "$assertion" =~ $pattern ]]; then
            return 0
        fi
    done
    
    return 1
}

# Get plugin metadata
regex_assertion_metadata() {
    cat << EOF
{
  "name": "regex_assertions",
  "version": "$PLUGIN_REGEX_ASSERTIONS_VERSION",
  "description": "$PLUGIN_REGEX_ASSERTIONS_DESCRIPTION",
  "author": "$PLUGIN_REGEX_ASSERTIONS_AUTHOR",
  "type": "$PLUGIN_REGEX_ASSERTIONS_TYPE",
  "patterns": $(printf '%s\n' "${REGEX_ASSERTION_PATTERNS[@]}" | jq -R . | jq -s .),
  "capabilities": [
    "regex_pattern_matching",
    "string_contains_checking",
    "prefix_suffix_validation",
    "case_insensitive_matching",
    "multiline_patterns",
    "word_boundary_matching",
    "negative_matching"
  ],
  "dependencies": ["grep (optional, bash regex fallback available)"],
  "examples": [
    "@regex:id:^[A-Z]{3}-\\\\d{4}$",
    "@pattern:message:error.*not found",
    "@contains:name:John",
    "@starts_with:email:admin@",
    "@ends_with:url:.com",
    "@case_insensitive:status:success",
    "@not_match:field:forbidden_value"
  ]
}
EOF
}

# Health check for the plugin
regex_assertions_health_check() {
    local status="healthy"
    local issues=()
    
    # Test basic regex functionality
    if ! echo "test" | grep -q "test" 2>/dev/null; then
        if ! [[ "test" =~ test ]]; then
            status="unhealthy"
            issues+=("Neither grep nor bash regex working")
        else
            issues+=("grep not available, using bash regex fallback")
        fi
    fi
    
    # Test pattern validation
    if ! regex_validate_pattern_syntax "^test$"; then
        status="degraded"
        issues+=("Pattern validation not working properly")
    fi
    
    # Output health status
    local health_report
    health_report=$(cat << EOF
{
  "plugin": "regex_assertions",
  "status": "$status",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .),
  "dependencies": {
    "grep": "$(command -v grep >/dev/null 2>&1 && echo "available" || echo "missing")",
    "bash_regex": "available"
  }
}
EOF
)
    
    echo "$health_report"
    [[ "$status" == "healthy" ]]
}

# Event handler for regex assertion events
regex_assertions_event_handler() {
    local event_type="$1"
    local event_data="$2"
    
    tlog debug "Regex assertions plugin received event: $event_type"
    
    # Handle different event types
    case "$event_type" in
        "assertion.regex.performance.monitor")
            # Monitor performance of regex assertions
            regex_monitor_performance "$event_data"
            ;;
        "assertion.regex.pattern.validate")
            # Validate regex patterns
            regex_validate_patterns "$event_data"
            ;;
        *)
    tlog debug "Unhandled event type: $event_type"
            ;;
    esac
    
    return 0
}

# Performance monitoring helper
regex_monitor_performance() {
    local event_data="$1"
    
    # Extract performance metrics from event data
    local assertion=$(echo "$event_data" | jq -r '.assertion // ""')
    local execution_time=$(echo "$event_data" | jq -r '.execution_time // 0')
    
    # Log slow assertions
    if [[ $(echo "$execution_time > 500" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
    tlog warning "Slow regex assertion detected (${execution_time}ms): $assertion"
    fi
}

# Pattern validation helper
regex_validate_patterns() {
    local event_data="$1"
    
    local patterns
    patterns=$(echo "$event_data" | jq -r '.patterns[]? // empty')
    
    while IFS= read -r pattern; do
        if ! regex_validate_pattern_syntax "$pattern"; then
    tlog warning "Invalid regex pattern detected: $pattern"
        fi
    done <<< "$patterns"
}

# Export functions
export -f regex_assertions_init regex_assertions_handler regex_evaluate_assertion
export -f regex_validate_assertion_syntax regex_supports_pattern regex_assertion_metadata
export -f regex_assertions_health_check regex_assertions_event_handler
export -f regex_parse_assertion regex_test_pattern regex_validate_pattern_syntax
export -f regex_monitor_performance regex_validate_patterns
