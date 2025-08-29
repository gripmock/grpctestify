#!/bin/bash

# report_generator.sh - Generate test reports
# Supports console output format

# Global report data structure  
# Note: Using separate variables instead of associative arrays for broader compatibility
REPORT_DATA_start_time=""
REPORT_DATA_end_time=""
REPORT_DATA_total_tests=0
REPORT_DATA_passed_count=0
REPORT_DATA_failed_count=0
REPORT_DATA_timeout_count=0
REPORT_DATA_skipped_count=0
REPORT_DATA_total_duration=0
REPORT_DATA_hostname=""
REPORT_DATA_username=""
REPORT_DATA_grpctestify_version=""
REPORT_DATA_success_rate=0

# Arrays to store test results by category for detailed reporting
PASSED_TESTS=()
FAILED_TESTS=()
TIMEOUT_TESTS=()
SKIPPED_TESTS=()

# Initialize report data
init_report_data() {
    # shellcheck disable=SC2034  # Used in future versions
    REPORT_DATA_start_time=$(date -Iseconds)
    REPORT_DATA_total_tests=0
    REPORT_DATA_passed_count=0
    REPORT_DATA_failed_count=0
    REPORT_DATA_timeout_count=0
    REPORT_DATA_skipped_count=0
    REPORT_DATA_total_duration=0
    # shellcheck disable=SC2034  # Used in future versions
    REPORT_DATA_hostname=$(hostname)
    # shellcheck disable=SC2034  # Used in future versions
    REPORT_DATA_username=$(whoami)
    # shellcheck disable=SC2034  # Used in future versions
    REPORT_DATA_grpctestify_version="$APP_VERSION"
    
    # Reset all counters and arrays to initial state
    PASSED_TESTS=()
    FAILED_TESTS=()
    TIMEOUT_TESTS=()
    SKIPPED_TESTS=()
}

# Add test result to report data
add_test_result() {
    local test_file="$1"
    local status="$2"  # Test outcome: PASS/FAIL/TIMEOUT/SKIP
    local duration="${3:-0}"
    # shellcheck disable=SC2034  # Used in future versions
    local error_message="${4:-}"
    # shellcheck disable=SC2034  # Used in future versions
    local start_time="${5:-$(date -Iseconds)}"
    # shellcheck disable=SC2034  # Used in future versions
    local end_time="${6:-$(date -Iseconds)}"
    
    # shellcheck disable=SC2034  # Used in future versions
    # shellcheck disable=SC2155
    local test_name=$(basename "$test_file" .gctf)
    # shellcheck disable=SC2034  # Used in future versions
    local test_key="${test_file//\//_}"
    
    # Store individual test result (simplified - no detailed storage for now)
    
    # Update counters and arrays
    REPORT_DATA_total_tests=$((REPORT_DATA_total_tests + 1))
    REPORT_DATA_total_duration=$((REPORT_DATA_total_duration + duration))
    
    case "$status" in
        "PASS")
            REPORT_DATA_passed_count=$((REPORT_DATA_passed_count + 1))
            PASSED_TESTS+=("$test_file")
            ;;
        "FAIL")
            REPORT_DATA_failed_count=$((REPORT_DATA_failed_count + 1))
            FAILED_TESTS+=("$test_file")
            ;;
        "TIMEOUT")
            REPORT_DATA_timeout_count=$((REPORT_DATA_timeout_count + 1))
            TIMEOUT_TESTS+=("$test_file")
            ;;
        "SKIP")
            REPORT_DATA_skipped_count=$((REPORT_DATA_skipped_count + 1))
            SKIPPED_TESTS+=("$test_file")
            ;;
    esac
}

# Finalize report data
finalize_report_data() {
    # shellcheck disable=SC2034  # Used in future versions
    REPORT_DATA_end_time=$(date -Iseconds)
    
    # Calculate success rate
    local total=$REPORT_DATA_total_tests
    local passed=$REPORT_DATA_passed_count
    local success_rate=0
    
    if [[ $total -gt 0 ]]; then
        success_rate=$((passed * 100 / total))
    fi
    
    REPORT_DATA_success_rate=$success_rate
}

# Generate console report (default/existing format)
generate_console_report() {
    local output_file="${1:-}"
    
    # Skip console summary if already shown by show_summary function
    # Only show detailed sections (failed tests, etc.)
    
    # Show failed tests details
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        log section "Failed Tests"
        for test_file in "${FAILED_TESTS[@]}"; do
            log error "  ❌ $test_file"
        done
    fi
    
    # Show timeout tests details
    if [[ ${#TIMEOUT_TESTS[@]} -gt 0 ]]; then
        log section "Timeout Tests"
        for test_file in "${TIMEOUT_TESTS[@]}"; do
            log error "  ⏰ $test_file"
        done
    fi
    
    # If output file specified, also write to file
    if [[ -n "$output_file" ]]; then
        {
            echo "=== gRPC Testify Report ==="
            echo "Generated: $(date)"
            echo "Total tests: $REPORT_DATA_total_tests"
            echo "Passed: $REPORT_DATA_passed_count"
            echo "Failed: $REPORT_DATA_failed_count"
            echo "Timeout: $REPORT_DATA_timeout_count"
            echo "Skipped: $REPORT_DATA_skipped_count"
            echo "Success rate: $REPORT_DATA_success_rate%"
            echo "Duration: ${REPORT_DATA_total_duration}ms"
            echo
            
            if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
                echo "Failed Tests:"
                for test_file in "${FAILED_TESTS[@]}"; do
                    echo "  - $test_file"
                done
                echo
            fi
            
            if [[ ${#TIMEOUT_TESTS[@]} -gt 0 ]]; then
                echo "Timeout Tests:"
                for test_file in "${TIMEOUT_TESTS[@]}"; do
                    echo "  - $test_file"
                done
            fi
        } > "$output_file"
        
        log info "Console report written to: $output_file"
    fi
}


# Main report generation function
generate_report() {
    local format="${1:-console}"
    local output_file="${2:-}"
    
    # Finalize report data before generation
    finalize_report_data
    
    case "$format" in
        "console")
            generate_console_report "$output_file"
            ;;
        *)
            log error "Unknown report format: $format"
            log error "Supported formats: console"
            return 1
            ;;
    esac
}

# Export functions for use in other modules
export -f init_report_data
export -f add_test_result
export -f finalize_report_data
export -f generate_report
export -f generate_console_report

