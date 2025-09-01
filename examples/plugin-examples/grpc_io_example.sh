#!/bin/bash

# grpc_io_example.sh - Example plugin demonstrating Plugin IO API
# Shows how plugins should interact with the IO system

PLUGIN_NAME="grpc_io_example"
PLUGIN_DESCRIPTION="Example plugin using Plugin IO API"
PLUGIN_TYPE="example"

# Register the plugin
register_plugin "$PLUGIN_NAME" "io_example_test" "$PLUGIN_DESCRIPTION" "internal"

# Example function that uses Plugin IO API
io_example_test() {
    local test_name="$1"
    local duration_ms="$2"
    local status="$3"
    
    # Check if Plugin IO API is available
    if ! command -v plugin_io_available >/dev/null 2>&1; then
        log warn "Plugin IO API not available, skipping example"
        return 0
    fi
    
    # Example of using Plugin IO API functions
    case "$status" in
        "PASSED")
            # Report successful test
            plugin_io_test_success "$test_name" "$duration_ms" "Example plugin validation"
            
            # Custom output using safe IO
            plugin_io_print "🎉 Test %s completed successfully in %sms\n" "$test_name" "$duration_ms"
            ;;
            
        "FAILED")
            # Report failed test
            plugin_io_test_failure "$test_name" "$duration_ms" "Example plugin detected failure"
            
            # Custom error output
            plugin_io_error_print "❌ Test $test_name failed validation"
            ;;
            
        "ERROR")
            # Report error
            plugin_io_test_error "$test_name" "$duration_ms" "Example plugin error"
            ;;
            
        "SKIPPED")
            # Report skipped test
            plugin_io_test_skip "$test_name" "Skipped by example plugin"
            ;;
    esac
    
    # Example batch operations
    if [[ "$test_name" == "batch_example" ]]; then
        # Batch progress updates
        plugin_io_batch_progress \
            "test1:running:." \
            "test2:running:." \
            "test3:failed:F"
            
        # Batch results
        plugin_io_batch_results \
            "test1:PASSED:100:details1" \
            "test2:PASSED:150:details2" \
            "test3:FAILED:200:validation failed"
    fi
    
    # Example validation
    if plugin_io_validate_test_name "$test_name"; then
        log debug "Test name '$test_name' is valid"
    else
        log warn "Test name '$test_name' is invalid"
    fi
    
    # Check API availability
    if plugin_io_available; then
        log debug "Plugin IO API is available"
    else
        log debug "Plugin IO API is not available"
    fi
    
    # Output status for debugging
    if [[ "${DEBUG:-}" == "true" ]]; then
        plugin_io_status
    fi
}

# Demonstrate custom progress reporting
io_example_custom_progress() {
    local test_name="$1"
    local percentage="$2"
    
    # Custom progress symbols
    local symbol
    case "$percentage" in
        [0-2][0-9]) symbol="░" ;;      # 0-29%
        [3-6][0-9]) symbol="▒" ;;      # 30-69%
        [7-8][0-9]) symbol="▓" ;;      # 70-89%
        9[0-9]|100) symbol="█" ;;      # 90-100%
    esac
    
    # Send custom progress
    plugin_io_progress "$test_name" "running" "$symbol"
}

# Demonstrate safe output with formatting
io_example_safe_output() {
    local message="$1"
    local level="${2:-info}"
    
    case "$level" in
        "error")
            plugin_io_error_print "🚨 ERROR: $message"
            ;;
        "warn")
            plugin_io_error_print "⚠️  WARN: $message"
            ;;
        "info")
            plugin_io_print "ℹ️  INFO: %s\n" "$message"
            ;;
        "success")
            plugin_io_print "✅ SUCCESS: %s\n" "$message"
            ;;
    esac
}

# Demonstrate test lifecycle management
io_example_test_lifecycle() {
    local test_name="$1"
    
    # Start test
    plugin_io_test_start "$test_name"
    plugin_io_print "🏁 Starting test: %s\n" "$test_name"
    
    # Simulate test execution
    sleep 0.1
    
    # Report progress
    plugin_io_progress "$test_name" "running" "⚙"
    plugin_io_print "⚙️  Processing test: %s\n" "$test_name"
    
    # Simulate completion
    local success=$((RANDOM % 2))
    if [[ $success -eq 1 ]]; then
        plugin_io_test_success "$test_name" "100" "Lifecycle example completed"
        plugin_io_print "🎯 Test completed: %s\n" "$test_name"
    else
        plugin_io_test_failure "$test_name" "100" "Lifecycle example failed"
        plugin_io_print "💥 Test failed: %s\n" "$test_name"
    fi
}

# Export plugin functions
export -f io_example_test io_example_custom_progress
export -f io_example_safe_output io_example_test_lifecycle

# Example usage (for manual testing only)
# Uncomment to test manually: ./grpc_io_example.sh
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     echo "Testing Plugin IO API Example..."
#     io_example_test "example_test" "250" "PASSED"
#     io_example_custom_progress "progress_test" "75"
#     io_example_safe_output "This is a test message" "info"
#     io_example_test_lifecycle "lifecycle_test"
# fi
