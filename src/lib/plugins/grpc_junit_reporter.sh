#!/bin/bash

# grpc_junit_reporter.sh - JUnit XML Report Plugin
# Generates JUnit XML reports for gRPC test results

# Plugin metadata
PLUGIN_NAME="junit_reporter"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Generate JUnit XML reports"
PLUGIN_TYPE="reporter"

# Register the plugin
register_plugin "$PLUGIN_NAME" "junit_format_report" "$PLUGIN_DESCRIPTION" "internal"

# Main function to generate JUnit XML report
junit_format_report() {
    local output_file="$1"
    local test_results="$2"  # JSON with test results
    local start_time="$3"
    local end_time="$4"
    
    if [[ -z "$output_file" || -z "$test_results" ]]; then
        log error "JUnit reporter: Missing required parameters"
        return 1
    fi
    
    # Parse test results from JSON
    local total_tests passed_tests failed_tests skipped_tests
    total_tests=$(echo "$test_results" | jq -r '.total // 0')
    passed_tests=$(echo "$test_results" | jq -r '.passed // 0')
    failed_tests=$(echo "$test_results" | jq -r '.failed // 0') 
    skipped_tests=$(echo "$test_results" | jq -r '.skipped // 0')
    
    local duration=$((end_time - start_time))
    local timestamp=$(date -Iseconds)
    
    log info "📊 Generating JUnit XML report: $output_file"
    
    # Create output directory if needed
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # Generate JUnit XML
    _junit_generate_xml "$output_file" "$total_tests" "$passed_tests" "$failed_tests" \
                       "$skipped_tests" "$duration" "$timestamp" "$test_results"
}

# Internal function to generate XML structure
_junit_generate_xml() {
    local output_file="$1"
    local total="$2"
    local passed="$3"
    local failed="$4"
    local skipped="$5"
    local duration="$6"
    local timestamp="$7"
    local test_results="$8"
    
    cat > "$output_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="grpctestify" 
           tests="$total" 
           failures="$failed" 
           errors="0" 
           skipped="$skipped" 
           time="$duration"
           timestamp="$timestamp">
  
  <properties>
    <property name="grpctestify.version" value="${APP_VERSION:-1.0.0}"/>
    <property name="hostname" value="$(hostname)"/>
    <property name="username" value="$(whoami)"/>
    <property name="plugin.name" value="$PLUGIN_NAME"/>
    <property name="plugin.version" value="$PLUGIN_VERSION"/>
  </properties>
  
  <testsuite name="grpc-tests" 
             tests="$total" 
             failures="$failed" 
             errors="0" 
             skipped="$skipped" 
             time="$duration">
EOF

    # Add individual test cases
    echo "$test_results" | jq -r '.tests[]?' | while IFS= read -r test_entry; do
        if [[ -n "$test_entry" ]]; then
            _junit_add_testcase "$test_entry" >> "$output_file"
        fi
    done
    
    # Close XML structure
    cat >> "$output_file" << EOF
  </testsuite>
</testsuites>
EOF

    log info "✅ JUnit XML report generated successfully"
}

# Add individual test case to XML
_junit_add_testcase() {
    local test_entry="$1"
    
    local test_name test_status test_duration test_error
    test_name=$(echo "$test_entry" | jq -r '.name // "unknown"')
    test_status=$(echo "$test_entry" | jq -r '.status // "unknown"')
    test_duration=$(echo "$test_entry" | jq -r '.duration // 0')
    test_error=$(echo "$test_entry" | jq -r '.error // ""')
    
    echo "    <testcase name=\"$test_name\" classname=\"grpctestify\" time=\"$test_duration\">"
    
    case "$test_status" in
        "failed")
            echo "      <failure message=\"Test failed\">"
            echo "        <![CDATA[$test_error]]>"
            echo "      </failure>"
            ;;
        "skipped")
            echo "      <skipped/>"
            ;;
        "error")
            echo "      <error message=\"Test error\">"
            echo "        <![CDATA[$test_error]]>"
            echo "      </error>"
            ;;
        # "passed" cases don't need additional elements
    esac
    
    echo "    </testcase>"
}

# Plugin configuration validation
junit_validate_config() {
    # Ensure jq is available for JSON processing
    if ! command -v jq >/dev/null 2>&1; then
        log error "JUnit reporter requires 'jq' command"
        return 1
    fi
    
    # Ensure hostname and whoami commands are available
    if ! command -v hostname >/dev/null 2>&1; then
        log warning "hostname command not available, using 'localhost'"
    fi
    
    return 0
}

# Plugin help information
junit_plugin_help() {
    cat << EOF
JUnit Reporter Plugin
=====================

Description: Generates JUnit XML reports compatible with CI/CD systems

Usage: --log-junit <output_file>

Features:
- Standard JUnit XML format
- Compatible with Jenkins, GitHub Actions, GitLab CI
- Includes test timing and metadata
- Proper XML escaping for error messages

Examples:
  grpctestify tests/ --log-junit results.xml
  grpctestify test.gctf --log-junit reports/junit.xml

Requirements:
- jq command for JSON processing
EOF
}

# Export plugin functions
export -f junit_format_report
export -f junit_validate_config
export -f junit_plugin_help
