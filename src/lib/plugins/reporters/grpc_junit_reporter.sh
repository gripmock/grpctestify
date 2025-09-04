#!/bin/bash

# grpc_junit_reporter.sh - Enhanced JUnit XML Report Plugin with microkernel integration
# Migrated from legacy grpc_junit_reporter.sh with microkernel components

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
readonly PLUGIN_JUNIT_REPORTER_VERSION="1.0.0"
readonly PLUGIN_JUNIT_REPORTER_DESCRIPTION="Enhanced JUnit XML reports with microkernel integration"
readonly PLUGIN_JUNIT_REPORTER_AUTHOR="grpctestify-team"
readonly PLUGIN_JUNIT_REPORTER_TYPE="reporter"

# Initialize JUnit reporter plugin
grpc_junit_reporter_init() {
	log_debug "Initializing JUnit reporter plugin..."

	# Ensure plugin integration is available
	if ! command -v plugin_register >/dev/null 2>&1; then
		log_warn "Plugin integration system not available, skipping plugin registration"
		return 1
	fi

	# Register plugin with microkernel
	plugin_register "junit_reporter" "grpc_junit_reporter_handler" "$PLUGIN_JUNIT_REPORTER_DESCRIPTION" "internal" ""

	# Create resource pool for report generation
	pool_create "junit_reporting" 1

	# Subscribe to reporting events
	event_subscribe "junit_reporter" "report.*" "grpc_junit_reporter_event_handler"

	log_debug "JUnit reporter plugin initialized successfully"
	return 0
}

# Main JUnit reporter handler
grpc_junit_reporter_handler() {
	local command="$1"
	shift
	local args=("$@")

	case "$command" in
	"generate")
		grpc_junit_reporter_generate "${args[@]}"
		;;
	"validate_xml")
		grpc_junit_reporter_validate_xml "${args[@]}"
		;;
	"convert_to_junit")
		grpc_junit_reporter_convert_to_junit "${args[@]}"
		;;
	*)
		log_error "Unknown JUnit reporter command: $command"
		return 1
		;;
	esac
}

# Generate JUnit XML report with microkernel integration
grpc_junit_reporter_generate() {
	local output_file="$1"
	local report_config="${2:-{}}"

	if [[ -z "$output_file" ]]; then
		log_error "grpc_junit_reporter_generate: output_file required"
		return 1
	fi

	log_debug "Generating JUnit XML report: $output_file"

	# Publish report generation start event
	local report_metadata
	report_metadata=$(
		cat <<EOF
{
  "output_file": "$output_file",
  "reporter": "junit_reporter",
  "start_time": $(date +%s),
  "config": $report_config
}
EOF
	)
	event_publish "report.generation.start" "$report_metadata" "$EVENT_PRIORITY_NORMAL" "junit_reporter"

	# Begin transaction for report generation
	local tx_id
	tx_id=$(state_db_begin_transaction "junit_report_$(basename "$output_file")_$$")

	# Acquire resource for report generation
	local resource_token
	resource_token=$(pool_acquire "junit_reporting" 30)
	if [[ $? -ne 0 ]]; then
		log_error "Failed to acquire resource for JUnit report generation"
		state_db_rollback_transaction "$tx_id"
		return 1
	fi

	# Generate report from state database
	local generation_result=0
	local start_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))

	if generate_junit_report_from_state "$output_file" "$report_config"; then
		log_info "📊 JUnit XML report generated successfully: $output_file"
		local end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
		local duration=$((end_time - start_time))

		# Record successful generation
		state_db_atomic "record_junit_generation" "$output_file" "SUCCESS" "$duration"

		# Publish success event
		event_publish "report.generation.success" "{\"output_file\":\"$output_file\",\"duration\":$duration}" "$EVENT_PRIORITY_NORMAL" "junit_reporter"
	else
		generation_result=1
		log_error "JUnit XML report generation failed: $output_file"
		local end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
		local duration=$((end_time - start_time))

		# Record failed generation
		state_db_atomic "record_junit_generation" "$output_file" "FAILED" "$duration"

		# Publish failure event
		event_publish "report.generation.failure" "{\"output_file\":\"$output_file\",\"duration\":$duration}" "$EVENT_PRIORITY_HIGH" "junit_reporter"
	fi

	# Release resource
	pool_release "junit_reporting" "$resource_token"

	# Commit transaction
	state_db_commit_transaction "$tx_id"

	return $generation_result
}

# Generate JUnit XML report from state database
generate_junit_report_from_state() {
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

	# Get execution timeline from state
	local start_time="${GRPCTESTIFY_STATE[execution_start_time]:-$(date +%s)}"
	local end_time="${GRPCTESTIFY_STATE[execution_end_time]:-$(date +%s)}"
	local duration_ms=$((end_time - start_time))
	local duration_seconds=$(echo "scale=3; $duration_ms / 1000" | bc 2>/dev/null || echo "0")

	# Parse report configuration
	local include_system_properties
	include_system_properties=$(echo "$report_config" | jq -r '.include_system_properties // true')
	local test_suite_name
	test_suite_name=$(echo "$report_config" | jq -r '.test_suite_name // "grpctestify"')

	# Generate JUnit XML header
	cat >"$output_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="$test_suite_name" tests="$total_tests" failures="$failed_tests" skipped="$skipped_tests" time="$duration_seconds">
EOF

	# Add system properties if requested
	if [[ "$include_system_properties" == "true" ]]; then
		cat >>"$output_file" <<EOF
  <properties>
    <property name="grpctestify.version" value="${APP_VERSION:-v1.0.0}"/>
    <property name="grpctestify.microkernel" value="true"/>
    <property name="grpctestify.timestamp" value="$(date -Iseconds)"/>
    <property name="system.hostname" value="$(hostname 2>/dev/null || echo 'unknown')"/>
    <property name="system.username" value="$(whoami 2>/dev/null || echo 'unknown')"/>
    <property name="system.os" value="${OSTYPE:-unknown}"/>
    <property name="system.shell" value="${SHELL:-unknown}"/>
  </properties>
EOF
	fi

	# Generate test suite
	cat >>"$output_file" <<EOF
  <testsuite name="$test_suite_name" tests="$total_tests" failures="$failed_tests" skipped="$skipped_tests" time="$duration_seconds" timestamp="$(date -Iseconds)">
EOF

	# Add individual test cases from state
	if [[ ${#GRPCTESTIFY_TEST_RESULTS[@]} -gt 0 ]]; then
		for result in "${GRPCTESTIFY_TEST_RESULTS[@]}"; do
			generate_junit_testcase "$result" >>"$output_file"
		done
	fi

	# Add failed test details if available
	if [[ ${#GRPCTESTIFY_FAILED_DETAILS[@]} -gt 0 ]]; then
		for failure in "${GRPCTESTIFY_FAILED_DETAILS[@]}"; do
			generate_junit_failure_case "$failure" >>"$output_file"
		done
	fi

	# Close test suite and test suites
	cat >>"$output_file" <<EOF
  </testsuite>
</testsuites>
EOF

	if [[ $? -eq 0 ]]; then
		log_debug "JUnit XML report written to: $output_file"
		return 0
	else
		log_error "Failed to write JUnit XML report to: $output_file"
		return 1
	fi
}

# Generate individual JUnit test case XML
generate_junit_testcase() {
	local result_json="$1"

	# Parse test result
	local test_name
	test_name=$(echo "$result_json" | jq -r '.test_file // .name // "unknown"')
	local test_status
	test_status=$(echo "$result_json" | jq -r '.result // .status // "unknown"')
	local test_duration
	test_duration=$(echo "$result_json" | jq -r '.duration // 0')
	local test_classname
	test_classname=$(echo "$result_json" | jq -r '.classname // "grpctestify"')
	local test_message
	test_message=$(echo "$result_json" | jq -r '.message // ""')

	# Convert duration from milliseconds to seconds
	local duration_seconds
	duration_seconds=$(echo "scale=3; $test_duration / 1000" | bc 2>/dev/null || echo "0")

	# Sanitize test name for XML
	test_name=$(echo "$test_name" | sed 's/[<>&"]//g')
	test_classname=$(echo "$test_classname" | sed 's/[<>&"]//g')

	case "$test_status" in
	"PASS" | "passed" | "success")
		echo "    <testcase name=\"$test_name\" classname=\"$test_classname\" time=\"$duration_seconds\"/>"
		;;
	"FAIL" | "failed" | "error")
		echo "    <testcase name=\"$test_name\" classname=\"$test_classname\" time=\"$duration_seconds\">"
		echo "      <failure message=\"Test failed\">"
		if [[ -n "$test_message" ]]; then
			echo "        <![CDATA[$test_message]]>"
		else
			echo "        Test execution failed"
		fi
		echo "      </failure>"
		echo "    </testcase>"
		;;
	"SKIP" | "skipped")
		echo "    <testcase name=\"$test_name\" classname=\"$test_classname\" time=\"$duration_seconds\">"
		echo "      <skipped message=\"Test skipped\"/>"
		echo "    </testcase>"
		;;
	*)
		echo "    <testcase name=\"$test_name\" classname=\"$test_classname\" time=\"$duration_seconds\">"
		echo "      <error message=\"Unknown test status: $test_status\"/>"
		echo "    </testcase>"
		;;
	esac
}

# Generate JUnit failure case from failure details
generate_junit_failure_case() {
	local failure_json="$1"

	# Parse failure details
	local test_name
	test_name=$(echo "$failure_json" | jq -r '.test_file // .name // "unknown"')
	local error_message
	error_message=$(echo "$failure_json" | jq -r '.error_message // .message // "Test failed"')
	local error_details
	error_details=$(echo "$failure_json" | jq -r '.error_details // .details // ""')

	# Sanitize for XML
	test_name=$(echo "$test_name" | sed 's/[<>&"]//g')
	error_message=$(echo "$error_message" | sed 's/[<>&"]//g')

	echo "    <testcase name=\"$test_name\" classname=\"grpctestify\">"
	echo "      <failure message=\"$error_message\">"
	if [[ -n "$error_details" ]]; then
		echo "        <![CDATA[$error_details]]>"
	fi
	echo "      </failure>"
	echo "    </testcase>"
}

# Validate JUnit XML output
grpc_junit_reporter_validate_xml() {
	local output_file="$1"

	if [[ ! -f "$output_file" ]]; then
		log_error "Report file does not exist: $output_file"
		return 1
	fi

	# Basic XML validation
	if ! xmllint --noout "$output_file" 2>/dev/null; then
		# Fallback validation if xmllint is not available
		if ! grep -q "<?xml" "$output_file" || ! grep -q "<testsuites" "$output_file"; then
			log_error "Invalid XML structure in report file: $output_file"
			return 1
		fi
	fi

	# Validate required JUnit elements
	local required_elements=("testsuites" "testsuite")
	for element in "${required_elements[@]}"; do
		if ! grep -q "<$element" "$output_file"; then
			log_error "Missing required element '<$element>' in report: $output_file"
			return 1
		fi
	done

	log_debug "JUnit XML report validation passed: $output_file"
	return 0
}

# Convert test results to JUnit format
grpc_junit_reporter_convert_to_junit() {
	local test_results="$1"
	local output_format="${2:-xml}"

	if [[ -z "$test_results" ]]; then
		echo ""
		return 0
	fi

	case "$output_format" in
	"xml")
		# Convert JSON results to JUnit XML format
		echo "$test_results" | jq -r '.[] | @base64' | while IFS= read -r encoded_result; do
			local result
			result=$(echo "$encoded_result" | base64 -d 2>/dev/null || echo "$encoded_result")
			generate_junit_testcase "$result"
		done
		;;
	"json")
		# Return as structured JSON
		echo "$test_results"
		;;
	*)
		log_error "Unsupported output format: $output_format"
		return 1
		;;
	esac
}

# JUnit reporter event handler
grpc_junit_reporter_event_handler() {
	local event_message="$1"

	log_debug "JUnit reporter received event: $event_message"

	# Handle reporting events
	# This could be used for:
	# - Report generation performance monitoring
	# - XML validation and formatting
	# - CI/CD integration optimizations
	# - Test result aggregation strategies

	return 0
}

# State database helper functions
record_junit_generation() {
	local output_file="$1"
	local status="$2"
	local duration="$3"

	local report_key="junit_generation_$(basename "$output_file")"
	GRPCTESTIFY_STATE["${report_key}_status"]="$status"
	GRPCTESTIFY_STATE["${report_key}_duration"]="$duration"
	GRPCTESTIFY_STATE["${report_key}_timestamp"]="$(date +%s)"

	return 0
}

# Export functions
export -f grpc_junit_reporter_init grpc_junit_reporter_handler grpc_junit_reporter_generate
export -f generate_junit_report_from_state generate_junit_testcase generate_junit_failure_case
export -f grpc_junit_reporter_validate_xml grpc_junit_reporter_convert_to_junit grpc_junit_reporter_event_handler
export -f record_junit_generation
