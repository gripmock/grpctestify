#!/bin/bash

# grpc_report_manager.sh - Report Format Manager Plugin
# Manages different report formats through plugin system

# Plugin metadata
PLUGIN_NAME="report_manager"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Manage report formats via plugins"
PLUGIN_TYPE="manager"

# Available report formats registry
declare -A REPORT_FORMATS
declare -A REPORT_PLUGINS

# Register the manager plugin
register_plugin "$PLUGIN_NAME" "report_manager_init" "$PLUGIN_DESCRIPTION" "internal"

# Initialize report format system
report_manager_init() {
    log debug "Initializing report format manager..."
    
    # Register built-in formats
    register_report_format "junit" "junit_format_report" "JUnit XML format"
    register_report_format "json" "json_format_report" "JSON format"
    
    return 0
}

# Register a new report format
register_report_format() {
    local format_name="$1"
    local handler_function="$2"
    local description="$3"
    
    if [[ -z "$format_name" || -z "$handler_function" ]]; then
        log error "Report format registration requires name and handler function"
        return 1
    fi
    
    REPORT_FORMATS["$format_name"]="$handler_function"
    REPORT_PLUGINS["$format_name"]="$description"
    
    log debug "Registered report format: $format_name -> $handler_function"
}

# Generate report in specified format
generate_report() {
    local format="$1"
    local output_file="$2"
    local test_results="$3"
    local start_time="$4"
    local end_time="$5"
    
    if [[ -z "$format" || -z "$output_file" || -z "$test_results" ]]; then
        log error "Report generation requires format, output file, and test results"
        return 1
    fi
    
    # Check if format is supported
    if [[ -z "${REPORT_FORMATS[$format]}" ]]; then
        log error "Unsupported report format: $format"
        log info "Available formats: ${!REPORT_FORMATS[*]}"
        return 1
    fi
    
    local handler_function="${REPORT_FORMATS[$format]}"
    
    # Check if handler function exists
    if ! declare -f "$handler_function" >/dev/null 2>&1; then
        log error "Report handler function not found: $handler_function"
        return 1
    fi
    
    log info "📊 Generating $format report: $output_file"
    
    # Call the appropriate handler
    "$handler_function" "$output_file" "$test_results" "$start_time" "$end_time"
    local status=$?
    
    if [[ $status -eq 0 ]]; then
        log info "✅ Report generated successfully"
    else
        log error "❌ Failed to generate $format report"
    fi
    
    return $status
}

# List available report formats
list_report_formats() {
    echo "Available report formats:"
    for format in "${!REPORT_FORMATS[@]}"; do
        local description="${REPORT_PLUGINS[$format]}"
        echo "  $format - $description"
    done
}

# Validate report format
validate_report_format() {
    local format="$1"
    
    if [[ -z "$format" ]]; then
        log error "Report format not specified"
        return 1
    fi
    
    if [[ -z "${REPORT_FORMATS[$format]}" ]]; then
        log error "Unknown report format: $format"
        log info "Use --help to see available formats"
        return 1
    fi
    
    return 0
}

# Get report file extension for format
get_report_extension() {
    local format="$1"
    
    case "$format" in
        junit) echo "xml" ;;
        json) echo "json" ;;
        *) echo "txt" ;;
    esac
}

# Auto-generate output filename if not specified
auto_generate_output_filename() {
    local format="$1"
    local base_name="${2:-test-results}"
    
    local extension=$(get_report_extension "$format")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    echo "${base_name}_${timestamp}.${extension}"
}

# Plugin help
report_manager_help() {
    cat << EOF
Report Manager Plugin
====================

Description: Manages multiple report output formats through plugin system

Usage: 
  --log-format <format> --log-output <file>

Available Formats:
EOF
    list_report_formats
    cat << EOF

Examples:
  grpctestify tests/ --log-format junit --log-output results.xml
  grpctestify tests/ --log-format json --log-output results.json

Features:
- Extensible plugin-based architecture
- Multiple output formats
- Automatic file extension detection
- Timestamp-based auto-naming
EOF
}

# Export functions
export -f report_manager_init
export -f register_report_format
export -f generate_report
export -f list_report_formats
export -f validate_report_format
export -f get_report_extension
export -f auto_generate_output_filename
export -f report_manager_help
