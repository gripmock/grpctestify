# Test State API Examples

This guide provides comprehensive examples of using the Test State API for plugin development and advanced test analytics.

## Overview

The Test State API provides centralized access to test execution data, allowing plugins to both read test results and contribute their own metadata. This enables rich analytics, custom reporting, and enhanced plugin functionality.

## Core State Structure

### Global Test State
```bash
# Core metrics accessible via test_state_get()
GRPCTESTIFY_STATE[total_tests]     # Total number of tests planned
GRPCTESTIFY_STATE[executed_tests]  # Tests actually executed
GRPCTESTIFY_STATE[passed_tests]    # Successfully passed tests
GRPCTESTIFY_STATE[failed_tests]    # Failed tests
GRPCTESTIFY_STATE[skipped_tests]   # Skipped tests
GRPCTESTIFY_STATE[start_time]      # Execution start time (ms)
GRPCTESTIFY_STATE[end_time]        # Execution end time (ms)
GRPCTESTIFY_STATE[execution_mode]  # Sequential/parallel mode
GRPCTESTIFY_STATE[parallel_jobs]   # Number of parallel jobs
```

### Test Results Array
```bash
# Each entry: "full_path|status|duration_ms|error_message|execution_time"
GRPCTESTIFY_TEST_RESULTS=(
    "/path/to/test1.gctf|PASS|150|Time to first byte: 10ms|1640995200000"
    "/path/to/test2.gctf|FAIL|500|Connection timeout|1640995201000"
)
```

## Reading State Data

### Basic Metrics
```bash
# Get specific state values
total_tests=$(test_state_get "total_tests")
passed_tests=$(test_state_get "passed_tests")
success_rate=$(test_state_get_success_rate)
duration=$(test_state_get_duration)

echo "Execution Summary:"
echo "  Total: $total_tests"
echo "  Passed: $passed_tests" 
echo "  Success Rate: $success_rate%"
echo "  Duration: ${duration}ms"
```

### Test Results Analysis
```bash
# Get all test results
readarray -t all_results < <(test_state_get_all_results)

# Process each test result
for result in "${all_results[@]}"; do
    IFS='|' read -r test_path status duration error_msg exec_time <<< "$result"
    
    echo "Test: $(basename "$test_path" .gctf)"
    echo "  Status: $status"
    echo "  Duration: ${duration}ms"
    echo "  Path: $test_path"
    [[ -n "$error_msg" ]] && echo "  Error: $error_msg"
done
```

### Failed Tests Details
```bash
# Get detailed failure information
readarray -t failed_details < <(test_state_get_failed_results)

for failure in "${failed_details[@]}"; do
    IFS='|' read -r test_name error_msg duration expected actual <<< "$failure"
    
    echo "Failed Test: $test_name"
    echo "  Error: $error_msg"
    echo "  Duration: ${duration}ms"
    [[ -n "$expected" ]] && echo "  Expected: $expected"
    [[ -n "$actual" ]] && echo "  Actual: $actual"
done
```

## Writing to State

### Recording Plugin Metadata
```bash
# Store global plugin metadata
test_state_set_plugin_metadata "performance_tracker" "total_requests" "1247"
test_state_set_plugin_metadata "performance_tracker" "avg_response_time" "85.4"
test_state_set_plugin_metadata "performance_tracker" "cache_hit_rate" "78.2"

# Store per-test metadata
test_state_set_test_metadata "$test_path" "performance_tracker" "ttfb" "12ms"
test_state_set_test_metadata "$test_path" "performance_tracker" "cache_status" "HIT"
```

### Recording Test Results
```bash
# Record a test result (usually done by core system)
test_state_record_result "$test_path" "PASS" "150" "" "$(date +%s%3N)"

# Record detailed failure information
test_state_record_failure "$test_path" "Connection timeout" "500" "200 OK" "500 Internal Server Error"
```

## Advanced Analytics Examples

### Performance Tracking Plugin
```bash
#!/bin/bash
# grpc_performance_tracker.sh

PLUGIN_PERFORMANCE_TRACKER_VERSION="1.0.0"
PLUGIN_PERFORMANCE_TRACKER_DESCRIPTION="Advanced performance monitoring"

# Track performance metrics per test
track_test_performance() {
    local test_path="$1"
    local start_time="$2"
    local end_time="$3"
    
    local duration=$((end_time - start_time))
    local ttfb=$(measure_time_to_first_byte "$test_path")
    
    # Store per-test metrics
    test_state_set_test_metadata "$test_path" "performance_tracker" "ttfb" "$ttfb"
    test_state_set_test_metadata "$test_path" "performance_tracker" "total_time" "$duration"
    
    # Update global metrics
    local current_total=$(test_state_get_plugin_metadata "performance_tracker" "total_requests" || echo "0")
    local new_total=$((current_total + 1))
    test_state_set_plugin_metadata "performance_tracker" "total_requests" "$new_total"
    
    # Calculate running average
    local current_avg=$(test_state_get_plugin_metadata "performance_tracker" "avg_duration" || echo "0")
    local new_avg=$(((current_avg * (new_total - 1) + duration) / new_total))
    test_state_set_plugin_metadata "performance_tracker" "avg_duration" "$new_avg"
}

# Generate performance report
generate_performance_report() {
    local total_requests=$(test_state_get_plugin_metadata "performance_tracker" "total_requests")
    local avg_duration=$(test_state_get_plugin_metadata "performance_tracker" "avg_duration")
    
    echo "Performance Report:"
    echo "  Total Requests: $total_requests"
    echo "  Average Duration: ${avg_duration}ms"
    
    # Find slowest tests
    echo "  Slowest Tests:"
    readarray -t all_results < <(test_state_get_all_results)
    
    # Sort by duration (descending) and show top 5
    printf '%s\n' "${all_results[@]}" | \
        sort -t'|' -k3 -nr | \
        head -5 | \
        while IFS='|' read -r test_path status duration error_msg exec_time; do
            echo "    $(basename "$test_path" .gctf): ${duration}ms"
        done
}
```

### Test Directory Analytics
```bash
# Get tests grouped by directory
test_state_get_tests_by_directory "detailed"

# Example output:
# Directory: /path/to/real-time-chat/tests
#   Total: 9, Passed: 9, Failed: 0, Skipped: 0
#   Tests:
#     send_message: PASS
#     get_messages: PASS
#     asserts_functionality_test: PASS
#     comprehensive_functionality_test: PASS
#     ...
```

### Test Execution Timeline
```bash
# Get chronological test execution order
test_state_get_timeline "human"

# Example output:
# Test Execution Timeline:
#   10:30:45 user_creation: PASS (150ms)
#   10:30:45 user_update: PASS (98ms)
#   10:30:46 user_deletion: FAIL (500ms)
#   ...
```

## Test Information Lookup

### Get Detailed Test Information
```bash
# Look up test by name or path pattern
test_state_get_test_info "user_creation" "human"

# Example output:
# Test Information:
#   Full Path: /path/to/real-time-chat/tests/send_message.gctf
#   Short Name: send_message
#   Relative Path: examples/basic-examples/real-time-chat/tests/send_message.gctf
#   Directory: /path/to/real-time-chat/tests
#   Status: PASS
#   Duration: 150ms
#   Execution Time: 1640995200150

# Get as JSON for programmatic use
test_state_get_test_info "user_creation" "json"
```

### Test Path Normalization
```bash
# Normalize test names to full paths
full_path=$(normalize_test_name "user_creation.gctf")
echo "Full path: $full_path"

# Get display components
short_name=$(get_test_short_name "$full_path")
directory=$(get_test_directory "$full_path") 
relative_path=$(get_test_relative_path "$full_path")

echo "Short name: $short_name"
echo "Directory: $directory"
echo "Relative path: $relative_path"
```

## Integration with Reports

### Enhanced JSON Report with Plugin Data
```bash
# Generate JSON report including plugin metadata
generate_json_report_from_state() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
{
    "test_execution": {
        "summary": $(test_state_get_stats "json"),
        "duration_ms": $(test_state_get_duration),
        "success_rate": $(test_state_get_success_rate)
    },
    "test_results": $(test_state_get_all_results "json"),
    "failed_tests": $(test_state_get_failed_results "json"),
    "plugin_metadata": $(test_state_get_all_plugin_metadata "json"),
    "execution_timeline": $(test_state_get_timeline "json")
}
EOF
}
```

### Custom Plugin Report Integration
```bash
# Plugin hook for report enhancement
enhance_report_with_plugin_data() {
    local report_format="$1"
    local output_file="$2"
    
    case "$report_format" in
        "junit")
            # Add plugin metadata as XML properties
            add_plugin_metadata_to_junit "$output_file"
            ;;
        "json")
            # Merge plugin data into JSON structure
            merge_plugin_data_to_json "$output_file"
            ;;
    esac
}
```

## Best Practices

### 1. Plugin Metadata Naming
```bash
# Use consistent naming conventions
test_state_set_plugin_metadata "my_plugin" "metric_name" "value"
test_state_set_test_metadata "$test_path" "my_plugin" "test_metric" "value"

# Avoid conflicts with other plugins
namespace="security_validator"
test_state_set_plugin_metadata "$namespace" "violations_found" "3"
```

### 2. Error Handling
```bash
# Always check if state functions are available
if command -v test_state_get >/dev/null 2>&1; then
    total_tests=$(test_state_get "total_tests")
else
    echo "Test state API not available" >&2
    return 1
fi
```

### 3. Performance Considerations
```bash
# Cache frequently accessed data
if [[ -z "$_cached_total_tests" ]]; then
    _cached_total_tests=$(test_state_get "total_tests")
fi

# Use batch operations when possible
test_state_set_plugin_metadata "batch_plugin" "metric1" "value1"
test_state_set_plugin_metadata "batch_plugin" "metric2" "value2"
test_state_set_plugin_metadata "batch_plugin" "metric3" "value3"
```

### 4. State Lifecycle
```bash
# Initialize plugin state
plugin_init() {
    test_state_set_plugin_metadata "my_plugin" "initialized" "true"
    test_state_set_plugin_metadata "my_plugin" "start_time" "$(date +%s%3N)"
}

# Finalize plugin state
plugin_finalize() {
    local end_time=$(date +%s%3N)
    local start_time=$(test_state_get_plugin_metadata "my_plugin" "start_time")
    local plugin_duration=$((end_time - start_time))
    
    test_state_set_plugin_metadata "my_plugin" "execution_time" "$plugin_duration"
    test_state_set_plugin_metadata "my_plugin" "finalized" "true"
}
```

This API enables powerful analytics, custom reporting, and sophisticated plugin functionality while maintaining clean separation of concerns and data integrity.