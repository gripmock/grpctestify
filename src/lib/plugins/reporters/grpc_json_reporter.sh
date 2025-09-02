#!/bin/bash

# grpc_json_reporter.sh - Enhanced JSON Report Plugin with microkernel integration
# Migrated from legacy grpc_json_reporter.sh with microkernel components

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
readonly PLUGIN_JSON_REPORTER_VERSION="1.0.0"
readonly PLUGIN_JSON_REPORTER_DESCRIPTION="Enhanced JSON reports with microkernel integration"
readonly PLUGIN_JSON_REPORTER_AUTHOR="grpctestify-team"
readonly PLUGIN_JSON_REPORTER_TYPE="reporter"

# Initialize JSON reporter plugin
grpc_json_reporter_init() {
    tlog debug "Initializing JSON reporter plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    tlog warning "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "json_reporter" "grpc_json_reporter_handler" "$PLUGIN_JSON_REPORTER_DESCRIPTION" "internal" ""
    
    # Create resource pool for report generation
    pool_create "json_reporting" 1
    
    # Subscribe to reporting events
    event_subscribe "json_reporter" "report.*" "grpc_json_reporter_event_handler"
    
    tlog debug "JSON reporter plugin initialized successfully"
    return 0
}

# Main JSON reporter handler
grpc_json_reporter_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "generate")
            grpc_json_reporter_generate "${args[@]}"
            ;;
        "format_results")
            grpc_json_reporter_format_results "${args[@]}"
            ;;
        "validate_output")
            grpc_json_reporter_validate_output "${args[@]}"
            ;;
        *)
    tlog error "Unknown JSON reporter command: $command"
            return 1
            ;;
    esac
}

# Generate JSON report with microkernel integration
grpc_json_reporter_generate() {
    local output_file="$1"
    local report_config="${2:-{}}"
    
    if [[ -z "$output_file" ]]; then
    tlog error "grpc_json_reporter_generate: output_file required"
        return 1
    fi
    
    tlog debug "Generating JSON report: $output_file"
    
    # Publish report generation start event
    local report_metadata
    report_metadata=$(cat << EOF
{
  "output_file": "$output_file",
  "reporter": "json_reporter",
  "start_time": $(date +%s),
  "config": $report_config
}
EOF
)
    event_publish "report.generation.start" "$report_metadata" "$EVENT_PRIORITY_NORMAL" "json_reporter"
    
    # Begin transaction for report generation
    local tx_id
    tx_id=$(state_db_begin_transaction "json_report_$(basename "$output_file")_$$")
    
    # Acquire resource for report generation
    local resource_token
    resource_token=$(pool_acquire "json_reporting" 30)
    if [[ $? -ne 0 ]]; then
    tlog error "Failed to acquire resource for JSON report generation"
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
    
    # Generate report from state database
    local generation_result=0
    local start_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
    
    if generate_json_report_from_state "$output_file" "$report_config"; then
    tlog info "📊 JSON report generated successfully: $output_file"
        local end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
        local duration=$((end_time - start_time))
        
        # Record successful generation
        state_db_atomic "record_report_generation" "$output_file" "SUCCESS" "$duration"
        
        # Publish success event
        event_publish "report.generation.success" "{\"output_file\":\"$output_file\",\"duration\":$duration}" "$EVENT_PRIORITY_NORMAL" "json_reporter"
    else
        generation_result=1
    tlog error "JSON report generation failed: $output_file"
        local end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
        local duration=$((end_time - start_time))
        
        # Record failed generation
        state_db_atomic "record_report_generation" "$output_file" "FAILED" "$duration"
        
        # Publish failure event
        event_publish "report.generation.failure" "{\"output_file\":\"$output_file\",\"duration\":$duration}" "$EVENT_PRIORITY_HIGH" "json_reporter"
    fi
    
    # Release resource
    pool_release "json_reporting" "$resource_token"
    
    # Commit transaction
    state_db_commit_transaction "$tx_id"
    
    return $generation_result
}

# Generate JSON report from state database
generate_json_report_from_state() {
    local output_file="$1"
    local report_config="$2"
    
    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" || return 1
    
    # Get test statistics from state database
    local test_stats
    test_stats=$(state_db_get_stats)
    
    local total_tests
    total_tests=$(echo "$test_stats" | jq -r '.total_tests // 0')
    local passed_tests
    passed_tests=$(echo "$test_stats" | jq -r '.passed_tests // 0')
    local failed_tests
    failed_tests=$(echo "$test_stats" | jq -r '.failed_tests // 0')
    local skipped_tests
    skipped_tests=$(echo "$test_stats" | jq -r '.skipped_tests // 0')
    
    # Get test results from state database
    local test_results_json="[]"
    if [[ ${#GRPCTESTIFY_TEST_RESULTS[@]} -gt 0 ]]; then
        test_results_json=$(printf '%s\n' "${GRPCTESTIFY_TEST_RESULTS[@]}" | jq -s '.')
    fi
    
    # Get plugin metadata
    local plugin_metadata_json="{}"
    if command -v test_state_get_all_plugin_metadata >/dev/null 2>&1; then
        plugin_metadata_json=$(test_state_get_all_plugin_metadata)
    fi
    
    # Get execution timeline from state
    local start_time="${GRPCTESTIFY_STATE[execution_start_time]:-$(date +%s)}"
    local end_time="${GRPCTESTIFY_STATE[execution_end_time]:-$(date +%s)}"
    local duration=$((end_time - start_time))
    
    # Parse report configuration
    local include_plugin_metadata
    include_plugin_metadata=$(echo "$report_config" | jq -r '.include_plugin_metadata // true')
    local include_system_info
    include_system_info=$(echo "$report_config" | jq -r '.include_system_info // true')
    local pretty_print
    pretty_print=$(echo "$report_config" | jq -r '.pretty_print // true')
    
    # Build comprehensive JSON report
    local report_json
    report_json=$(jq -n \
        --argjson total_tests "$total_tests" \
        --argjson passed_tests "$passed_tests" \
        --argjson failed_tests "$failed_tests" \
        --argjson skipped_tests "$skipped_tests" \
        --argjson duration "$duration" \
        --arg start_time "$start_time" \
        --arg end_time "$end_time" \
        --arg timestamp "$(date -Iseconds)" \
        --arg hostname "$(hostname 2>/dev/null || echo 'unknown')" \
        --arg username "$(whoami 2>/dev/null || echo 'unknown')" \
        --arg version "${APP_VERSION:-v1.0.0}" \
        --argjson test_results "$test_results_json" \
        --argjson plugin_metadata "$plugin_metadata_json" \
        --argjson include_plugin_metadata "$include_plugin_metadata" \
        --argjson include_system_info "$include_system_info" \
        '{
            "report": {
                "format": "json",
                "version": "2.0",
                "generator": {
                    "name": "grpctestify",
                    "version": $version,
                    "plugin": "json_reporter"
                },
                "timestamp": $timestamp
            },
            "summary": {
                "total_tests": $total_tests,
                "passed": $passed_tests,
                "failed": $failed_tests,
                "skipped": $skipped_tests,
                "success_rate": (if $total_tests > 0 then ($passed_tests * 100 / $total_tests) else 0 end),
                "duration_ms": $duration,
                "start_time": $start_time,
                "end_time": $end_time
            },
            "test_results": $test_results,
            "plugin_metadata": (if $include_plugin_metadata then $plugin_metadata else null end),
            "system_info": (if $include_system_info then {
                "hostname": $hostname,
                "username": $username,
                "timestamp": $timestamp,
                "os": $ENV.OSTYPE,
                "shell": $ENV.SHELL
            } else null end),
            "grpctestify": {
                "version": $version,
                "microkernel": true,
                "plugins_count": ($plugin_metadata | if type == "object" then keys | length else 0 end)
            }
        }')
    
    # Write report to file
    if [[ "$pretty_print" == "true" ]]; then
        echo "$report_json" | jq . > "$output_file"
    else
        echo "$report_json" | jq -c . > "$output_file"
    fi
    
    if [[ $? -eq 0 ]]; then
    tlog debug "JSON report written to: $output_file"
        return 0
    else
    tlog error "Failed to write JSON report to: $output_file"
        return 1
    fi
}

# Format test results for JSON output
grpc_json_reporter_format_results() {
    local raw_results="$1"
    local format_options="${2:-{}}"
    
    if [[ -z "$raw_results" ]]; then
        echo "[]"
        return 0
    fi
    
    # Parse format options
    local include_timings
    include_timings=$(echo "$format_options" | jq -r '.include_timings // true')
    local include_details
    include_details=$(echo "$format_options" | jq -r '.include_details // true')
    
    # Process raw results into structured format
    echo "$raw_results" | jq \
        --argjson include_timings "$include_timings" \
        --argjson include_details "$include_details" \
        'map(
            if $include_timings and $include_details then
                .
            elif $include_timings then
                del(.details)
            elif $include_details then
                del(.duration, .start_time, .end_time)
            else
                {name: .name, status: .status, result: .result}
            end
        )'
}

# Validate JSON report output
grpc_json_reporter_validate_output() {
    local output_file="$1"
    
    if [[ ! -f "$output_file" ]]; then
    tlog error "Report file does not exist: $output_file"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq . "$output_file" >/dev/null 2>&1; then
    tlog error "Invalid JSON in report file: $output_file"
        return 1
    fi
    
    # Validate required fields
    local required_fields=("report" "summary" "test_results")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$output_file" >/dev/null 2>&1; then
    tlog error "Missing required field '$field' in report: $output_file"
            return 1
        fi
    done
    
    tlog debug "JSON report validation passed: $output_file"
    return 0
}

# JSON reporter event handler
grpc_json_reporter_event_handler() {
    local event_message="$1"
    
    tlog debug "JSON reporter received event: $event_message"
    
    # Handle reporting events
    # This could be used for:
    # - Report generation performance monitoring
    # - Output format optimization
    # - Report delivery mechanisms
    # - Report archival strategies
    
    return 0
}

# State database helper functions
record_report_generation() {
    local output_file="$1"
    local status="$2"
    local duration="$3"
    
    local report_key="report_generation_$(basename "$output_file")"
    GRPCTESTIFY_STATE["${report_key}_status"]="$status"
    GRPCTESTIFY_STATE["${report_key}_duration"]="$duration"
    GRPCTESTIFY_STATE["${report_key}_timestamp"]="$(date +%s)"
    
    return 0
}

# Legacy functions removed - use grpc_json_reporter_generate directly

# Export functions
export -f grpc_json_reporter_init grpc_json_reporter_handler grpc_json_reporter_generate
export -f generate_json_report_from_state grpc_json_reporter_format_results grpc_json_reporter_validate_output
export -f grpc_json_reporter_event_handler record_report_generation
# Legacy function exports removed
