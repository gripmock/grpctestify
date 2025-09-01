#!/bin/bash

# grpc_performance_tracker.sh - Example plugin demonstrating state write API
# Tracks performance metrics and stores them in centralized state

PLUGIN_NAME="grpc_performance_tracker"
PLUGIN_DESCRIPTION="Tracks performance metrics and response times"
PLUGIN_TYPE="analytics"

# Register the plugin
register_plugin "$PLUGIN_NAME" "performance_track_test" "$PLUGIN_DESCRIPTION" "internal"

# Track performance for a test (called by hooks)
performance_track_test() {
    local test_name="$1"
    local duration_ms="$2"
    local status="$3"
    local response_size="${4:-0}"
    
    # Store performance metadata
    test_state_set_test_metadata "$test_name" "$PLUGIN_NAME" "duration_ms" "$duration_ms"
    test_state_set_test_metadata "$test_name" "$PLUGIN_NAME" "response_size" "$response_size"
    test_state_set_test_metadata "$test_name" "$PLUGIN_NAME" "timestamp" "$(date -Iseconds)"
    
    # Update global performance statistics
    update_performance_stats "$duration_ms" "$status" "$response_size"
    
    log debug "Performance tracked for $test_name: ${duration_ms}ms, ${response_size} bytes"
}

# Update global performance statistics
update_performance_stats() {
    local duration_ms="$1"
    local status="$2"
    local response_size="$3"
    
    # Get current stats
    local total_duration=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "total_duration" || echo "0")
    local total_tests=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "total_tests" || echo "0")
    local min_duration=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "min_duration" || echo "$duration_ms")
    local max_duration=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "max_duration" || echo "$duration_ms")
    local total_response_size=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "total_response_size" || echo "0")
    
    # Update statistics
    total_duration=$((total_duration + duration_ms))
    total_tests=$((total_tests + 1))
    total_response_size=$((total_response_size + response_size))
    
    if [[ $duration_ms -lt $min_duration ]]; then
        min_duration=$duration_ms
    fi
    
    if [[ $duration_ms -gt $max_duration ]]; then
        max_duration=$duration_ms
    fi
    
    # Calculate average
    local avg_duration=$((total_duration / total_tests))
    
    # Store updated stats
    test_state_set_plugin_metadata "$PLUGIN_NAME" "total_duration" "$total_duration"
    test_state_set_plugin_metadata "$PLUGIN_NAME" "total_tests" "$total_tests"
    test_state_set_plugin_metadata "$PLUGIN_NAME" "min_duration" "$min_duration"
    test_state_set_plugin_metadata "$PLUGIN_NAME" "max_duration" "$max_duration"
    test_state_set_plugin_metadata "$PLUGIN_NAME" "avg_duration" "$avg_duration"
    test_state_set_plugin_metadata "$PLUGIN_NAME" "total_response_size" "$total_response_size"
    
    # Track by status
    local status_key="${status}_count"
    local current_count=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "$status_key" || echo "0")
    test_state_set_plugin_metadata "$PLUGIN_NAME" "$status_key" "$((current_count + 1))"
}

# Generate performance report section
generate_performance_report() {
    local format="${1:-human}"
    
    local total_tests=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "total_tests")
    
    if [[ -z "$total_tests" || "$total_tests" == "0" ]]; then
        echo "No performance data available"
        return
    fi
    
    local min_duration=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "min_duration")
    local max_duration=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "max_duration")
    local avg_duration=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "avg_duration")
    local total_response_size=$(test_state_get_plugin_metadata "$PLUGIN_NAME" "total_response_size")
    local avg_response_size=$((total_response_size / total_tests))
    
    case "$format" in
        "json")
            cat << EOF
{
    "performance_metrics": {
        "total_tests": $total_tests,
        "duration_ms": {
            "min": $min_duration,
            "max": $max_duration,
            "avg": $avg_duration
        },
        "response_size_bytes": {
            "total": $total_response_size,
            "avg": $avg_response_size
        }
    }
}
EOF
            ;;
        *)
            echo ""
            echo "📈 Performance Metrics:"
            echo "   Tests analyzed: $total_tests"
            echo "   Duration (ms):"
            echo "     Min: ${min_duration}ms"
            echo "     Max: ${max_duration}ms"  
            echo "     Avg: ${avg_duration}ms"
            echo "   Response size:"
            echo "     Total: ${total_response_size} bytes"
            echo "     Avg: ${avg_response_size} bytes"
            ;;
    esac
}

# Hook: Called after each test execution
performance_post_test_hook() {
    local test_name="$1"
    local status="$2"
    local duration_ms="$3"
    local response_data="$4"
    
    # Calculate response size (simplified)
    local response_size=${#response_data}
    
    # Track performance
    performance_track_test "$test_name" "$duration_ms" "$status" "$response_size"
}

# Show top slowest tests
show_slowest_tests() {
    local limit="${1:-5}"
    
    echo ""
    echo "🐌 Top $limit Slowest Tests:"
    
    # Get all test results and sort by duration
    local all_results
    readarray -t all_results < <(test_state_get_all_results)
    
    # Create associative array for sorting
    declare -A test_durations
    for result in "${all_results[@]}"; do
        IFS='|' read -r name status duration error_msg exec_time <<< "$result"
        test_durations["$duration"]="$name"
    done
    
    # Sort and display top N
    local count=0
    for duration in $(printf '%s\n' "${!test_durations[@]}" | sort -nr); do
        if [[ $count -ge $limit ]]; then
            break
        fi
        echo "   $((count + 1)). ${test_durations[$duration]}: ${duration}ms"
        ((count++))
    done
}

# Plugin help
performance_plugin_help() {
    cat << EOF
Performance Tracker Plugin

Automatically tracks test execution performance and stores metrics in 
centralized state. Provides detailed performance analytics including:

- Min/Max/Average execution times
- Response size tracking  
- Per-test performance metadata
- Slowest tests identification

Usage:
  Automatically enabled when plugin is loaded.
  Access data via test_state_get_plugin_metadata API.

Functions:
  - performance_track_test: Record performance for a test
  - generate_performance_report: Generate performance summary
  - show_slowest_tests: Display slowest tests

State API Usage Examples:
  # Get average duration
  avg=\$(test_state_get_plugin_metadata "grpc_performance_tracker" "avg_duration")
  
  # Get test-specific duration
  duration=\$(test_state_get_test_metadata "test_name" "grpc_performance_tracker" "duration_ms")
EOF
}

# Export functions
export -f performance_track_test
export -f update_performance_stats
export -f generate_performance_report
export -f performance_post_test_hook
export -f show_slowest_tests
export -f performance_plugin_help
