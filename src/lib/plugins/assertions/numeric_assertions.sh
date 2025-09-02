#!/bin/bash

# numeric_assertions.sh - Numeric Assertion Plugin
# Specialized plugin for numerical comparisons, ranges, and precision validation

# Plugin metadata
readonly PLUGIN_NUMERIC_ASSERTIONS_VERSION="1.0.0"
readonly PLUGIN_NUMERIC_ASSERTIONS_DESCRIPTION="Numerical comparisons, ranges, and precision validation"
readonly PLUGIN_NUMERIC_ASSERTIONS_AUTHOR="grpctestify-team"
readonly PLUGIN_NUMERIC_ASSERTIONS_TYPE="assertion"

# Supported patterns (regex patterns this plugin handles)
readonly NUMERIC_ASSERTION_PATTERNS=(
    '^@numeric:'               # @numeric:field:>10
    '^@number:'                # @number:field:==42
    '^@range:'                 # @range:score:80-100
    '^@precision:'             # @precision:price:2
    '^@decimal:'               # @decimal:value:2.5
    '^@integer:'               # @integer:count:>0
    '^@float:'                 # @float:ratio:<=1.0
    '^@percentage:'            # @percentage:rate:0-100
    '^@currency:'              # @currency:amount:>100.00
    '^@count:'                 # @count:items:>=5
    '^@sum:'                   # @sum:array:>1000
    '^@avg:'                   # @avg:scores:>=75
    '^@min:'                   # @min:values:>0
    '^@max:'                   # @max:limits:<=100
)

# Supported operators
readonly NUMERIC_OPERATORS=(
    "=="   # Equal
    "!="   # Not equal
    ">"    # Greater than
    ">="   # Greater than or equal
    "<"    # Less than
    "<="   # Less than or equal
    "~="   # Approximately equal (within tolerance)
)

# Initialize numeric assertions plugin
numeric_assertions_init() {
    tlog debug "Initializing numeric assertions plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    tlog warning "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "numeric_assertions" "numeric_assertions_handler" "$PLUGIN_NUMERIC_ASSERTIONS_DESCRIPTION" "assertion" ""
    
    # Register assertion patterns this plugin handles
    for pattern in "${NUMERIC_ASSERTION_PATTERNS[@]}"; do
        assertion_register_pattern "numeric" "$pattern" "numeric_assertions_handler"
    done
    
    # Subscribe to assertion events
    event_subscribe "numeric_assertions" "assertion.numeric.*" "numeric_assertions_event_handler"
    
    tlog debug "Numeric assertions plugin initialized successfully"
    return 0
}

# Main plugin handler
numeric_assertions_handler() {
    local command="$1"
    shift
    
    case "$command" in
        "evaluate")
            numeric_evaluate_assertion "$@"
            ;;
        "validate_syntax")
            numeric_validate_assertion_syntax "$@"
            ;;
        "supports_pattern")
            numeric_supports_pattern "$@"
            ;;
        "metadata")
            numeric_assertion_metadata
            ;;
        "health")
            numeric_assertions_health_check
            ;;
        *)
    tlog error "Unknown numeric assertions command: $command"
            return 1
            ;;
    esac
}

# Evaluate numeric assertion
numeric_evaluate_assertion() {
    local assertion="$1"
    local response="$2"
    local context="$3"
    
    if [[ -z "$assertion" || -z "$response" ]]; then
    tlog error "numeric_evaluate_assertion: assertion and response required"
        return 1
    fi
    
    tlog debug "Evaluating numeric assertion: $assertion"
    
    # Parse assertion format: @type:field:operation or @type:field:min-max
    local assertion_type field_path operation tolerance=""
    if ! numeric_parse_assertion "$assertion" assertion_type field_path operation tolerance; then
    tlog error "Failed to parse numeric assertion: $assertion"
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
    local event_data="{\"assertion\":\"$assertion\",\"type\":\"$assertion_type\",\"field\":\"$field_path\",\"operation\":\"$operation\",\"line_number\":$line_number,\"test_file\":\"$test_file\"}"
    event_publish "assertion.numeric.evaluation.start" "$event_data" "$EVENT_PRIORITY_LOW" "numeric_assertions"
    
    # Extract and validate field value from response
    local field_value
    if ! field_value=$(numeric_extract_field_value "$response" "$field_path" "$assertion_type"); then
    tlog error "Failed to extract numeric field '$field_path' from response"
        event_publish "assertion.numeric.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "numeric_assertions"
        return 1
    fi
    
    # Validate that field value is numeric
    if ! numeric_is_valid_number "$field_value"; then
    tlog error "Field value is not a valid number: $field_value"
        event_publish "assertion.numeric.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "numeric_assertions"
        return 1
    fi
    
    # Evaluate assertion based on type
    local result=0
    case "$assertion_type" in
        "numeric"|"number"|"decimal"|"integer"|"float")
            numeric_compare_values "$field_value" "$operation" "$tolerance"
            result=$?
            ;;
        "range")
            numeric_check_range "$field_value" "$operation"
            result=$?
            ;;
        "precision")
            numeric_check_precision "$field_value" "$operation"
            result=$?
            ;;
        "percentage")
            numeric_check_percentage "$field_value" "$operation"
            result=$?
            ;;
        "currency")
            numeric_check_currency "$field_value" "$operation"
            result=$?
            ;;
        "count"|"sum"|"avg"|"min"|"max")
            numeric_check_aggregation "$response" "$field_path" "$assertion_type" "$operation"
            result=$?
            ;;
        *)
    tlog error "Unknown numeric assertion type: $assertion_type"
            event_publish "assertion.numeric.evaluation.error" "$event_data" "$EVENT_PRIORITY_HIGH" "numeric_assertions"
            return 1
            ;;
    esac
    
    # Handle result
    if [[ $result -eq 0 ]]; then
    tlog debug "Numeric assertion passed: $assertion"
        event_publish "assertion.numeric.evaluation.success" "$event_data" "$EVENT_PRIORITY_LOW" "numeric_assertions"
        return 0
    else
    tlog debug "Numeric assertion failed: $assertion (value: $field_value)"
        event_publish "assertion.numeric.evaluation.failure" "$event_data" "$EVENT_PRIORITY_NORMAL" "numeric_assertions"
        return 1
    fi
}

# Parse assertion into components
numeric_parse_assertion() {
    local assertion="$1"
    local -n type_ref="$2"
    local -n field_ref="$3"
    local -n operation_ref="$4"
    local -n tolerance_ref="$5"
    
    # Remove @ prefix
    assertion="${assertion#@}"
    
    # Split by colons
    IFS=':' read -ra parts <<< "$assertion"
    
    if [[ ${#parts[@]} -lt 3 ]]; then
    tlog error "Invalid numeric assertion format: @$assertion"
        return 1
    fi
    
    type_ref="${parts[0]}"
    field_ref="${parts[1]}"
    operation_ref="${parts[2]}"
    
    # Check for tolerance in operation (e.g., ~=5:0.1)
    if [[ "$operation_ref" == *":"* ]]; then
        tolerance_ref="${operation_ref#*:}"
        operation_ref="${operation_ref%:*}"
    fi
    
    return 0
}

# Extract field value based on assertion type
numeric_extract_field_value() {
    local response="$1"
    local field_path="$2"
    local assertion_type="$3"
    
    case "$assertion_type" in
        "count")
            # Count array elements or object keys
            if [[ -n "$field_path" ]]; then
                echo "$response" | jq -r ".$field_path | length"
            else
                echo "$response" | jq -r "length"
            fi
            ;;
        "sum")
            # Sum array elements
            echo "$response" | jq -r ".$field_path | map(tonumber) | add"
            ;;
        "avg")
            # Average of array elements
            echo "$response" | jq -r ".$field_path | map(tonumber) | add / length"
            ;;
        "min")
            # Minimum value in array
            echo "$response" | jq -r ".$field_path | map(tonumber) | min"
            ;;
        "max")
            # Maximum value in array
            echo "$response" | jq -r ".$field_path | map(tonumber) | max"
            ;;
        *)
            # Regular field extraction
            echo "$response" | jq -r ".$field_path"
            ;;
    esac
}

# Check if value is a valid number
numeric_is_valid_number() {
    local value="$1"
    
    # Check for null or empty
    if [[ "$value" == "null" || -z "$value" ]]; then
        return 1
    fi
    
    # Use bc if available for precise checking
    if command -v bc >/dev/null 2>&1; then
        echo "$value" | bc -l >/dev/null 2>&1
        return $?
    else
        # Fallback to regex check
        [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$ ]]
    fi
}

# Compare numeric values
numeric_compare_values() {
    local value="$1"
    local operation="$2"
    local tolerance="$3"
    
    # Parse operator and expected value
    local operator=""
    local expected=""
    
    for op in "${NUMERIC_OPERATORS[@]}"; do
        if [[ "$operation" == "$op"* ]]; then
            operator="$op"
            expected="${operation#$op}"
            break
        fi
    done
    
    if [[ -z "$operator" || -z "$expected" ]]; then
    tlog error "Invalid numeric operation: $operation"
        return 1
    fi
    
    # Validate expected value is numeric
    if ! numeric_is_valid_number "$expected"; then
    tlog error "Expected value is not numeric: $expected"
        return 1
    fi
    
    # Perform comparison
    case "$operator" in
        "==")
            if [[ -n "$tolerance" ]]; then
                numeric_approximately_equal "$value" "$expected" "$tolerance"
            else
                numeric_equal "$value" "$expected"
            fi
            ;;
        "!=")
            ! numeric_equal "$value" "$expected"
            ;;
        ">")
            numeric_greater_than "$value" "$expected"
            ;;
        ">=")
            numeric_greater_equal "$value" "$expected"
            ;;
        "<")
            numeric_less_than "$value" "$expected"
            ;;
        "<=")
            numeric_less_equal "$value" "$expected"
            ;;
        "~=")
            local default_tolerance="${tolerance:-0.001}"
            numeric_approximately_equal "$value" "$expected" "$default_tolerance"
            ;;
        *)
    tlog error "Unknown numeric operator: $operator"
            return 1
            ;;
    esac
}

# Check if value is in range (format: min-max)
numeric_check_range() {
    local value="$1"
    local range="$2"
    
    if [[ "$range" != *"-"* ]]; then
    tlog error "Invalid range format: $range (expected min-max)"
        return 1
    fi
    
    local min_val="${range%-*}"
    local max_val="${range#*-}"
    
    if ! numeric_is_valid_number "$min_val" || ! numeric_is_valid_number "$max_val"; then
    tlog error "Invalid range values: $range"
        return 1
    fi
    
    numeric_greater_equal "$value" "$min_val" && numeric_less_equal "$value" "$max_val"
}

# Check decimal precision
numeric_check_precision() {
    local value="$1"
    local expected_precision="$2"
    
    if ! numeric_is_valid_number "$expected_precision"; then
    tlog error "Invalid precision value: $expected_precision"
        return 1
    fi
    
    # Count decimal places
    local decimal_places=0
    if [[ "$value" == *"."* ]]; then
        local decimal_part="${value#*.}"
        decimal_places=${#decimal_part}
    fi
    
    [[ $decimal_places -eq $expected_precision ]]
}

# Check percentage range (0-100)
numeric_check_percentage() {
    local value="$1"
    local operation="$2"
    
    # First check if it's a valid percentage
    if ! numeric_greater_equal "$value" "0" || ! numeric_less_equal "$value" "100"; then
    tlog error "Value is not a valid percentage: $value"
        return 1
    fi
    
    # Then apply the operation
    numeric_compare_values "$value" "$operation" ""
}

# Check currency format and value
numeric_check_currency() {
    local value="$1"
    local operation="$2"
    
    # Remove currency symbols and validate
    local numeric_value="$value"
    numeric_value="${numeric_value//[$,]/}"  # Remove $ and ,
    
    if ! numeric_is_valid_number "$numeric_value"; then
    tlog error "Invalid currency value: $value"
        return 1
    fi
    
    # Apply operation to numeric value
    numeric_compare_values "$numeric_value" "$operation" ""
}

# Check aggregation operations
numeric_check_aggregation() {
    local response="$1"
    local field_path="$2"
    local aggregation_type="$3"
    local operation="$4"
    
    local aggregated_value
    aggregated_value=$(numeric_extract_field_value "$response" "$field_path" "$aggregation_type")
    
    if ! numeric_is_valid_number "$aggregated_value"; then
    tlog error "Aggregation resulted in non-numeric value: $aggregated_value"
        return 1
    fi
    
    numeric_compare_values "$aggregated_value" "$operation" ""
}

# Numeric comparison functions using bc or awk
numeric_equal() {
    local a="$1" b="$2"
    if command -v bc >/dev/null 2>&1; then
        [[ $(echo "$a == $b" | bc -l) == "1" ]]
    else
        awk "BEGIN { exit !($a == $b) }"
    fi
}

numeric_greater_than() {
    local a="$1" b="$2"
    if command -v bc >/dev/null 2>&1; then
        [[ $(echo "$a > $b" | bc -l) == "1" ]]
    else
        awk "BEGIN { exit !($a > $b) }"
    fi
}

numeric_greater_equal() {
    local a="$1" b="$2"
    if command -v bc >/dev/null 2>&1; then
        [[ $(echo "$a >= $b" | bc -l) == "1" ]]
    else
        awk "BEGIN { exit !($a >= $b) }"
    fi
}

numeric_less_than() {
    local a="$1" b="$2"
    if command -v bc >/dev/null 2>&1; then
        [[ $(echo "$a < $b" | bc -l) == "1" ]]
    else
        awk "BEGIN { exit !($a < $b) }"
    fi
}

numeric_less_equal() {
    local a="$1" b="$2"
    if command -v bc >/dev/null 2>&1; then
        [[ $(echo "$a <= $b" | bc -l) == "1" ]]
    else
        awk "BEGIN { exit !($a <= $b) }"
    fi
}

numeric_approximately_equal() {
    local a="$1" b="$2" tolerance="$3"
    if command -v bc >/dev/null 2>&1; then
        local diff
        diff=$(echo "scale=10; if ($a >= $b) $a - $b else $b - $a" | bc -l)
        [[ $(echo "$diff <= $tolerance" | bc -l) == "1" ]]
    else
        awk "BEGIN { diff = ($a >= $b) ? $a - $b : $b - $a; exit !(diff <= $tolerance) }"
    fi
}

# Validate assertion syntax for this plugin
numeric_validate_assertion_syntax() {
    local assertion="$1"
    
    if [[ -z "$assertion" ]]; then
    tlog error "Empty assertion"
        return 1
    fi
    
    # Check if this plugin supports the pattern
    if ! numeric_supports_pattern "$assertion"; then
    tlog error "Assertion pattern not supported by numeric plugin: $assertion"
        return 1
    fi
    
    # Parse and validate components
    local assertion_type field_path operation tolerance=""
    if ! numeric_parse_assertion "$assertion" assertion_type field_path operation tolerance; then
    tlog error "Invalid assertion format: $assertion"
        return 1
    fi
    
    # Validate operation format
    if ! numeric_validate_operation "$assertion_type" "$operation"; then
    tlog error "Invalid operation for type $assertion_type: $operation"
        return 1
    fi
    
    return 0
}

# Validate operation format
numeric_validate_operation() {
    local assertion_type="$1"
    local operation="$2"
    
    case "$assertion_type" in
        "range")
            [[ "$operation" == *"-"* ]]
            ;;
        "precision")
            numeric_is_valid_number "$operation" && [[ "$operation" =~ ^[0-9]+$ ]]
            ;;
        *)
            # Check if operation starts with a valid operator
            local found_operator=false
            for op in "${NUMERIC_OPERATORS[@]}"; do
                if [[ "$operation" == "$op"* ]]; then
                    found_operator=true
                    local expected="${operation#$op}"
                    numeric_is_valid_number "$expected"
                    return $?
                fi
            done
            [[ "$found_operator" == "true" ]]
            ;;
    esac
}

# Check if plugin supports given assertion pattern
numeric_supports_pattern() {
    local assertion="$1"
    
    for pattern in "${NUMERIC_ASSERTION_PATTERNS[@]}"; do
        if [[ "$assertion" =~ $pattern ]]; then
            return 0
        fi
    done
    
    return 1
}

# Get plugin metadata
numeric_assertion_metadata() {
    cat << EOF
{
  "name": "numeric_assertions",
  "version": "$PLUGIN_NUMERIC_ASSERTIONS_VERSION",
  "description": "$PLUGIN_NUMERIC_ASSERTIONS_DESCRIPTION",
  "author": "$PLUGIN_NUMERIC_ASSERTIONS_AUTHOR",
  "type": "$PLUGIN_NUMERIC_ASSERTIONS_TYPE",
  "patterns": $(printf '%s\n' "${NUMERIC_ASSERTION_PATTERNS[@]}" | jq -R . | jq -s .),
  "operators": $(printf '%s\n' "${NUMERIC_OPERATORS[@]}" | jq -R . | jq -s .),
  "capabilities": [
    "numeric_comparisons",
    "range_validation",
    "precision_checking",
    "percentage_validation",
    "currency_validation",
    "array_aggregation",
    "approximate_equality"
  ],
  "dependencies": ["bc (optional, awk fallback available)", "jq"],
  "examples": [
    "@numeric:age:>=18",
    "@range:score:80-100",
    "@precision:price:2",
    "@percentage:completion:>50",
    "@count:items:==5",
    "@sum:amounts:>1000.00",
    "@avg:ratings:>=4.5",
    "@currency:total:>=100.00"
  ]
}
EOF
}

# Health check for the plugin
numeric_assertions_health_check() {
    local status="healthy"
    local issues=()
    
    # Check jq availability
    if ! command -v jq >/dev/null 2>&1; then
        status="unhealthy"
        issues+=("jq command not available")
    fi
    
    # Check calculation tools
    if ! command -v bc >/dev/null 2>&1 && ! command -v awk >/dev/null 2>&1; then
        status="unhealthy"
        issues+=("Neither bc nor awk available for calculations")
    fi
    
    # Test basic numeric operations
    if ! numeric_is_valid_number "42.5"; then
        status="unhealthy"
        issues+=("Basic number validation not working")
    fi
    
    if ! numeric_equal "1" "1"; then
        status="unhealthy"
        issues+=("Numeric equality comparison not working")
    fi
    
    # Output health status
    local health_report
    health_report=$(cat << EOF
{
  "plugin": "numeric_assertions",
  "status": "$status",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .),
  "dependencies": {
    "jq": "$(command -v jq >/dev/null 2>&1 && echo "available" || echo "missing")",
    "bc": "$(command -v bc >/dev/null 2>&1 && echo "available" || echo "missing")",
    "awk": "$(command -v awk >/dev/null 2>&1 && echo "available" || echo "missing")"
  }
}
EOF
)
    
    echo "$health_report"
    [[ "$status" == "healthy" ]]
}

# Event handler for numeric assertion events
numeric_assertions_event_handler() {
    local event_type="$1"
    local event_data="$2"
    
    tlog debug "Numeric assertions plugin received event: $event_type"
    
    # Handle different event types
    case "$event_type" in
        "assertion.numeric.performance.monitor")
            numeric_monitor_performance "$event_data"
            ;;
        "assertion.numeric.precision.check")
            numeric_check_precision_requirements "$event_data"
            ;;
        *)
    tlog debug "Unhandled event type: $event_type"
            ;;
    esac
    
    return 0
}

# Performance monitoring helper
numeric_monitor_performance() {
    local event_data="$1"
    
    local assertion=$(echo "$event_data" | jq -r '.assertion // ""')
    local execution_time=$(echo "$event_data" | jq -r '.execution_time // 0')
    
    # Log slow assertions
    if [[ $(echo "$execution_time > 200" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
    tlog warning "Slow numeric assertion detected (${execution_time}ms): $assertion"
    fi
}

# Precision checking helper
numeric_check_precision_requirements() {
    local event_data="$1"
    
    local values
    values=$(echo "$event_data" | jq -r '.values[]? // empty')
    
    while IFS= read -r value; do
        if ! numeric_is_valid_number "$value"; then
    tlog warning "Non-numeric value detected in precision check: $value"
        fi
    done <<< "$values"
}

# Export functions
export -f numeric_assertions_init numeric_assertions_handler numeric_evaluate_assertion
export -f numeric_validate_assertion_syntax numeric_supports_pattern numeric_assertion_metadata
export -f numeric_assertions_health_check numeric_assertions_event_handler
export -f numeric_parse_assertion numeric_extract_field_value numeric_is_valid_number
export -f numeric_compare_values numeric_check_range numeric_check_precision
export -f numeric_check_percentage numeric_check_currency numeric_check_aggregation
export -f numeric_equal numeric_greater_than numeric_greater_equal
export -f numeric_less_than numeric_less_equal numeric_approximately_equal
