#!/bin/bash

# grpc_json_reporter.sh - JSON Report Plugin
# Generates JSON reports for gRPC test results

# Plugin metadata
PLUGIN_NAME="json_reporter"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Generate JSON reports"
PLUGIN_TYPE="reporter"

# Register the plugin
register_plugin "$PLUGIN_NAME" "json_format_report" "$PLUGIN_DESCRIPTION" "internal"

# Main function to generate JSON report
json_format_report() {
    local output_file="$1"
    local test_results="$2"  # JSON with test results
    local start_time="$3"
    local end_time="$4"
    
    if [[ -z "$output_file" || -z "$test_results" ]]; then
        log error "JSON reporter: Missing required parameters"
        return 1
    fi
    
    local duration=$((end_time - start_time))
    local timestamp=$(date -Iseconds)
    
    log info "📊 Generating JSON report: $output_file"
    
    # Create output directory if needed
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # Enhance test results with metadata
    local enhanced_results=$(echo "$test_results" | jq --arg duration "$duration" \
                           --arg timestamp "$timestamp" \
                           --arg hostname "$(hostname)" \
                           --arg username "$(whoami)" \
                           --arg version "${APP_VERSION:-1.0.0}" \
                           '. + {
                               "duration": ($duration | tonumber),
                               "timestamp": $timestamp,
                               "hostname": $hostname, 
                               "username": $username,
                               "grpctestify_version": $version,
                               "report_format": "json",
                               "plugin": {
                                   "name": "json_reporter",
                                   "version": "1.0.0"
                               }
                           }')
    
    # Write formatted JSON to file
    echo "$enhanced_results" | jq '.' > "$output_file"
    
    if [[ $? -eq 0 ]]; then
        log info "✅ JSON report generated successfully"
        return 0
    else
        log error "❌ Failed to generate JSON report"
        return 1
    fi
}

# Plugin validation
json_validate_config() {
    if ! command -v jq >/dev/null 2>&1; then
        log error "JSON reporter requires 'jq' command"
        return 1
    fi
    return 0
}

# Plugin help
json_plugin_help() {
    cat << EOF
JSON Reporter Plugin
===================

Description: Generates JSON reports with detailed test information

Usage: --log-format json --log-output <output_file>

Features:
- Machine-readable JSON format
- Complete test metadata
- Easy integration with other tools
- Structured error information

Examples:
  grpctestify tests/ --log-format json --log-output results.json
  grpctestify test.gctf --log-format json --log-output report.json

Requirements:
- jq command for JSON processing
EOF
}

# Export plugin functions
export -f json_format_report
export -f json_validate_config 
export -f json_plugin_help
