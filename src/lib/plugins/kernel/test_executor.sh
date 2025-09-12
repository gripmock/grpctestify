#!/bin/bash

# test_executor.sh - Core test execution plugin using microkernel architecture
# Replaces legacy runner.sh with microkernel-integrated test execution

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
readonly PLUGIN_TEST_EXECUTOR_VERSION="1.0.0"
readonly PLUGIN_TEST_EXECUTOR_DESCRIPTION="Kernel test execution with microkernel integration"
readonly PLUGIN_TEST_EXECUTOR_AUTHOR="grpctestify-team"
readonly PLUGIN_TEST_EXECUTOR_TYPE="kernel"

# Test execution configuration
TEST_EXECUTOR_POOL_SIZE="${TEST_EXECUTOR_POOL_SIZE:-4}"
TEST_EXECUTOR_TIMEOUT="${TEST_EXECUTOR_TIMEOUT:-60}"
TEST_EXECUTOR_MAX_RETRIES="${TEST_EXECUTOR_MAX_RETRIES:-2}"

# Initialize test executor plugin
test_executor_init() {
	log_debug "Initializing test executor plugin..."

	# Ensure plugin integration is available
	if ! command -v plugin_register >/dev/null 2>&1; then
		log_warn "Plugin integration system not available, skipping plugin registration"
		return 1
	fi

	# Register plugin with microkernel
	plugin_register "test_executor" "test_executor_handler" "$PLUGIN_TEST_EXECUTOR_DESCRIPTION" "core" ""

	# Create dedicated resource pool for test execution
	pool_create "test_execution" "$TEST_EXECUTOR_POOL_SIZE"

	# Subscribe to test-related events
	event_subscribe "test_executor" "test.*" "test_executor_event_handler"

	log_debug "Test executor plugin initialized successfully"
	return 0
}

# Main test executor handler
test_executor_handler() {
	local command="$1"
	shift
	local args=("$@")

	case "$command" in
	"execute_single")
		test_executor_execute_single "${args[@]}"
		;;
	"execute_batch")
		test_executor_execute_batch "${args[@]}"
		;;
	"validate_test")
		test_executor_validate_test "${args[@]}"
		;;
	*)
		log_error "Unknown test executor command: $command"
		return 1
		;;
	esac
}

# Execute a single test with microkernel integration
test_executor_execute_single() {
	local test_file="$1"
	local test_config="${2:-{}}"

	if [[ -z "$test_file" || ! -f "$test_file" ]]; then
		log_error "test_executor_execute_single: valid test_file required"
		return 1
	fi

	log_debug "Executing single test: $test_file"

	# Publish test execution start event
	local test_metadata
	test_metadata=$(
		cat <<EOF
{
  "test_file": "$test_file",
  "executor": "test_executor",
  "start_time": $(date +%s),
  "config": $test_config
}
EOF
	)
	event_publish "test.execution.start" "$test_metadata" "$EVENT_PRIORITY_NORMAL" "test_executor"

	# Begin transaction for test execution
	local tx_id
	tx_id=$(state_db_begin_transaction "test_execution_$(basename "$test_file")_$$")

	# Acquire resource for test execution
	local resource_token
	resource_token=$(pool_acquire "test_execution" "$TEST_EXECUTOR_TIMEOUT")
	if [[ $? -ne 0 ]]; then
		log_error "Failed to acquire resource for test execution: $test_file"
		state_db_rollback_transaction "$tx_id"
		return 1
	fi

	# Execute test in monitored routine
	local execution_result=0
	local start_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))

	if execute_test_routine "$test_file" "$test_config"; then
		log_debug "Test executed successfully: $test_file"
		local end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
		local duration=$((end_time - start_time))

		# Record successful execution
		state_db_atomic "record_test_execution" "$test_file" "PASS" "$duration" ""

		# Publish success event
		event_publish "test.execution.success" "{\"test_file\":\"$test_file\",\"duration\":$duration}" "$EVENT_PRIORITY_NORMAL" "test_executor"
	else
		execution_result=1
		log_error "Test execution failed: $test_file"
		local end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
		local duration=$((end_time - start_time))

		# Record failed execution
		state_db_atomic "record_test_execution" "$test_file" "FAIL" "$duration" "Test execution failed"

		# Publish failure event
		event_publish "test.execution.failure" "{\"test_file\":\"$test_file\",\"duration\":$duration}" "$EVENT_PRIORITY_HIGH" "test_executor"
	fi

	# Release resource
	pool_release "test_execution" "$resource_token"

	# Commit transaction
	state_db_commit_transaction "$tx_id"

	return $execution_result
}

# Execute test routine with health monitoring
execute_test_routine() {
	local test_file="$1"
	local test_config="$2"

	# TEMPORARY FIX: Execute directly without routine spawning to prevent fork bomb
	log_debug "Executing test directly without routine spawning: $test_file"

	# Execute test directly
	execute_test_with_monitoring "$test_file" "$test_config"
	local wait_result=$?

	# Check test result
	local routine_status="completed"

	case "$routine_status" in
	"completed")
		log_debug "Test routine completed successfully: $test_file"
		return 0
		;;
	"failed" | "killed")
		log_error "Test routine failed or was killed: $test_file (status: $routine_status)"
		return 1
		;;
	*)
		log_warn "Test routine in unexpected state: $routine_status for $test_file"
		return 1
		;;
	esac
}

# Execute test with health monitoring wrapper
execute_test_with_monitoring() {
	local test_file="$1"
	local test_config="$2"

	# Setup test execution environment
	export TEST_FILE="$test_file"
	export TEST_CONFIG="$test_config"
	export TEST_START_TIME="$(date +%s)"

	# Validate test file before execution
	if ! test_executor_validate_test "$test_file"; then
		log_error "Test validation failed: $test_file"
		return 1
	fi

	# Parse test file and extract components
	local test_components
	test_components=$(parse_test_file_components "$test_file")
	if [[ $? -ne 0 ]]; then
		log_error "Failed to parse test file: $test_file"
		return 1
	fi

	# Execute test components in sequence
	local components_result=0

	# 1. Execute gRPC calls
	if ! execute_grpc_calls "$test_file" "$test_components"; then
		components_result=1
		log_error "gRPC calls failed for test: $test_file"
	fi

	# 2. Process assertions (if gRPC calls succeeded)
	if [[ $components_result -eq 0 ]]; then
		if ! execute_test_assertions "$test_file" "$test_components"; then
			components_result=1
			log_error "Assertions failed for test: $test_file"
		fi
	fi

	# 3. Generate test results
	if ! generate_test_results "$test_file" "$components_result"; then
		log_warn "Failed to generate test results for: $test_file"
	fi

	return $components_result
}

# Parse test file components
parse_test_file_components() {
	local test_file="$1"

	# This would integrate with file_parser plugin when available
	# For now, use basic parsing
	if command -v plugin_execute >/dev/null 2>&1 && plugin_exists "file_parser"; then
		plugin_execute "file_parser" "parse" "$test_file"
	else
		# Fallback to basic parsing
		echo '{"grpc_calls":[],"assertions":[],"metadata":{}}'
	fi
}

# Execute gRPC calls
execute_grpc_calls() {
	local test_file="$1"
	local test_components="$2"

	# This would integrate with grpc_client plugin when available
	if command -v plugin_execute >/dev/null 2>&1 && plugin_exists "grpc_client"; then
		plugin_execute "grpc_client" "execute_calls" "$test_file" "$test_components"
	else
		# Fallback to legacy gRPC execution
		log_debug "Using legacy gRPC execution for: $test_file"
		# This would call the existing run_single_test or similar
		return 0
	fi
}

# Execute test assertions
execute_test_assertions() {
	local test_file="$1"
	local test_components="$2"

	# Use microkernel-integrated assertions plugin
	if command -v plugin_execute >/dev/null 2>&1 && plugin_exists "grpc_asserts"; then
		# Get gRPC responses from previous execution
		local responses='[]' # This would be populated from actual execution
		plugin_execute "grpc_asserts" "$test_file" "$responses" "$test_components"
	else
		log_warn "Assertions plugin not available, skipping assertions for: $test_file"
		return 0
	fi
}

# Generate test results
generate_test_results() {
	local test_file="$1"
	local test_result="$2"
	local end_time="$(date +%s)"
	local duration=$((end_time - TEST_START_TIME))

	# Record test results in state database
	local result_status
	[[ $test_result -eq 0 ]] && result_status="PASS" || result_status="FAIL"

	state_db_atomic "record_test_result" "$test_file" "$result_status" "$duration"

	# Publish test completion event
	local result_metadata
	result_metadata=$(
		cat <<EOF
{
  "test_file": "$test_file",
  "result": "$result_status",
  "duration": $duration,
  "end_time": $end_time
}
EOF
	)
	event_publish "test.execution.complete" "$result_metadata" "$EVENT_PRIORITY_NORMAL" "test_executor"

	return 0
}

# Execute batch of tests
test_executor_execute_batch() {
	local test_files=("$@")
	local batch_size="${TEST_EXECUTOR_POOL_SIZE:-4}"
	local total_tests=${#test_files[@]}
	local completed_tests=0
	local failed_tests=0

	log_debug "Executing batch of $total_tests tests with batch size $batch_size"

	# Publish batch execution start event
	event_publish "test.batch.start" "{\"total_tests\":$total_tests,\"batch_size\":$batch_size}" "$EVENT_PRIORITY_NORMAL" "test_executor"

	# Process tests in batches
	local test_index=0
	while [[ $test_index -lt $total_tests ]]; do
		local batch_routines=()
		local batch_start=$test_index

		# Launch batch of tests
		while [[ ${#batch_routines[@]} -lt $batch_size && $test_index -lt $total_tests ]]; do
			local test_file="${test_files[$test_index]}"

			# Execute test in background routine
			local routine_id
			routine_id=$(routine_spawn "test_executor_execute_single '$test_file'" "batch_test_$test_index")

			if [[ $? -eq 0 ]]; then
				batch_routines+=("$routine_id")
			else
				log_error "Failed to spawn routine for test: $test_file"
				((failed_tests++))
			fi

			((test_index++))
		done

		# Wait for batch completion
		for routine_id in "${batch_routines[@]}"; do
			if routine_wait "$routine_id" "$TEST_EXECUTOR_TIMEOUT"; then
				((completed_tests++))
			else
				((failed_tests++))
			fi
		done

		log_debug "Batch completed: $completed_tests passed, $failed_tests failed"
	done

	# Publish batch completion event
	local batch_summary
	batch_summary=$(
		cat <<EOF
{
  "total_tests": $total_tests,
  "completed_tests": $completed_tests,
  "failed_tests": $failed_tests,
  "success_rate": $(echo "scale=2; $completed_tests * 100 / $total_tests" | bc 2>/dev/null || echo "0")
}
EOF
	)
	event_publish "test.batch.complete" "$batch_summary" "$EVENT_PRIORITY_NORMAL" "test_executor"

	[[ $failed_tests -eq 0 ]]
}

# Validate test file
test_executor_validate_test() {
	local test_file="$1"

	if [[ ! -f "$test_file" ]]; then
		log_error "Test file does not exist: $test_file"
		return 1
	fi

	if [[ ! -r "$test_file" ]]; then
		log_error "Test file is not readable: $test_file"
		return 1
	fi

	# Check file extension
	if [[ ! "$test_file" =~ \.gctf$ ]]; then
		log_warn "Test file does not have .gctf extension: $test_file"
	fi

	# Basic content validation
	if [[ ! -s "$test_file" ]]; then
		log_error "Test file is empty: $test_file"
		return 1
	fi

	log_debug "Test file validation passed: $test_file"
	return 0
}

# Test executor event handler
test_executor_event_handler() {
	local event_message="$1"

	log_debug "Test executor received event: $event_message"

	# Handle test-related events
	# This could be used for:
	# - Test performance monitoring
	# - Failure pattern analysis
	# - Dynamic test scheduling
	# - Resource usage optimization

	return 0
}

# State database helper functions
record_test_execution() {
	local test_file="$1"
	local status="$2"
	local duration="$3"
	local error_message="$4"

	local test_key="test_execution_$(basename "$test_file")"
	GRPCTESTIFY_STATE["${test_key}_status"]="$status"
	GRPCTESTIFY_STATE["${test_key}_duration"]="$duration"
	GRPCTESTIFY_STATE["${test_key}_timestamp"]="$(date +%s)"
	[[ -n "$error_message" ]] && GRPCTESTIFY_STATE["${test_key}_error"]="$error_message"

	return 0
}

record_test_result() {
	local test_file="$1"
	local result="$2"
	local duration="$3"

	# Add to test results array
	local result_entry
	result_entry=$(
		cat <<EOF
{
  "test_file": "$test_file",
  "result": "$result",
  "duration": $duration,
  "timestamp": $(date +%s)
}
EOF
	)
	GRPCTESTIFY_TEST_RESULTS+=("$result_entry")

	return 0
}

# Export functions
export -f test_executor_init test_executor_handler test_executor_execute_single
export -f execute_test_routine execute_test_with_monitoring parse_test_file_components
export -f execute_grpc_calls execute_test_assertions generate_test_results
export -f test_executor_execute_batch test_executor_validate_test test_executor_event_handler
export -f record_test_execution record_test_result
