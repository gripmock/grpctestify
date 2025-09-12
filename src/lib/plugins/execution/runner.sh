#!/bin/bash

# runner.sh - Test execution logic
# Core test execution functionality with custom IO and mutex system
# shellcheck disable=SC2155,SC2001,SC2076,SC2086,SC2034,SC2181,SC2317 # Variable handling, exit codes, unreachable code

# Custom IO and mutex systems are automatically loaded by bashly
# Plugin IO API provides controlled access for plugins

# Global array to store test failures for batch display
declare -g -a TEST_FAILURES=()

# Store test failure for later display (reactive UI)
store_test_failure() {
	local test_name="$1"
	local error_msg="$2"
	local detail1="$3"
	local detail2="$4"
	local detail3="${5:-}"
	local detail4="${6:-}"

	local failure_info="$error_msg"
	if [[ -n "$detail1" ]]; then
		failure_info="$failure_info:$detail1"
	fi
	if [[ -n "$detail2" ]]; then
		failure_info="$failure_info:$detail2"
	fi
	if [[ -n "$detail3" ]]; then
		failure_info="$failure_info:$detail3"
	fi
	if [[ -n "$detail4" ]]; then
		failure_info="$failure_info:$detail4"
	fi

	# Store in local array for backwards compatibility
	TEST_FAILURES+=("TEST_FAILED:$test_name:$error_msg")

	# Send to IO system via Plugin API
	if command -v plugin_io_error >/dev/null 2>&1; then
		# Use first parameter as test path (it should be full path)
		plugin_io_error "$test_name" "$failure_info"
	fi
}

# Detailed logging function for verbose mode
log_test_details() {
	local test_name="$1"
	local address="$2"
	local endpoint="$3"
	local request="$4"
	local headers="$5"
	local expected_response="$6"
	local expected_error="$7"
	local actual_response="$8"
	local grpc_status="$9"
	local execution_time="${10}"

	if [[ "${LOG_LEVEL:-info}" == "debug" ]]; then
		log_debug "════════════════════════════════════════"
		log_debug "📋 TEST DETAILS: $test_name"
		log_debug "════════════════════════════════════════"
		log_debug "🌐 Target: $address/$endpoint"

		if [[ -n "$headers" ]]; then
			log_debug "📤 Headers:"
			# Optimized: avoid while read loop for simple logging
			log_debug "    $headers"
		fi

		if [[ -n "$request" ]]; then
			log_debug "📤 Request Data:"
			# Optimized: use direct output instead of line-by-line processing
			io_printf "    %s\n" "$request"
		else
			log_debug "📤 Request: (empty)"
		fi

		log_debug "⏱️  Execution Time: ${execution_time}ms"
		log_debug "🔢 gRPC Status Code: $grpc_status"

		if [[ -n "$actual_response" ]]; then
			log_debug "📥 Actual Response:"
			# Optimized: use direct output instead of sed
			io_printf "    %s\n" "$actual_response"
		else
			log_debug "📥 Actual Response: (empty)"
		fi

		if [[ -n "$expected_response" ]]; then
			log_debug "✅ Expected Response:"
			# Optimized: use direct output instead of sed
			io_printf "    %s\n" "$expected_response"
		fi

		if [[ -n "$expected_error" ]]; then
			log_debug "⚠️  Expected Error:"
			# Optimized: use direct output instead of sed
			io_printf "    %s\n" "$expected_error"
		fi

		log_debug "════════════════════════════════════════"
	fi
}

# Source response comparison utilities

# Helper function to log_debug messages only in non-dots mode
log_test_success() {
	local message="$1"
	local progress_mode="$2"

	if [[ "$progress_mode" != "dots" ]]; then
		log_debug "$message"
	fi
}

# Beautiful dry-run formatter
format_dry_run_output() {
	local cmd=("$@")
	local request="$1"
	local headers="$2"
	shift 2
	local command_parts=("${@}")

	io_newline
	log_debug "🔍 DRY-RUN MODE: Command Preview"
	io_printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

	# Extract endpoint from command for display
	local endpoint=""
	for arg in "${command_parts[@]}"; do
		if [[ "$arg" =~ \. ]]; then
			endpoint="$arg"
			break
		fi
	done

	if [[ -n "$endpoint" ]]; then
		log_debug "🎯 Target Endpoint"
		io_printf "   %s\n" "$endpoint"
		io_newline
	fi

	# Command section
	log_debug "📡 gRPC Command"
	io_printf "   %s" "${command_parts[0]}"
	for arg in "${command_parts[@]:1}"; do
		if [[ "$arg" =~ ^- ]]; then
			io_printf " \\\\\n      %s" "$arg"
		else
			io_printf " \\\\\n      '%s'" "$arg"
		fi
	done
	io_newline
	io_newline

	# Headers section (if any)
	if [[ -n "$headers" ]]; then
		log_debug "📋 Request Headers"
		echo "$headers" | jq -C . 2>/dev/null || echo "   $headers"
		echo ""
	fi

	# Request data section
	if [[ -n "$request" ]]; then
		log_debug "📤 Request Data"

		# Check if this is streaming (multiple JSON objects separated by newlines)
		# Count actual JSON objects, not just lines
		local json_count=0
		while IFS= read -r line; do
			if [[ -n "$line" && "$line" =~ ^\{.*\}$ ]]; then
				((json_count++))
			fi
		done <<<"$request"

		if [[ $json_count -gt 1 ]]; then
			log_debug "   🔄 Streaming Request (Multiple Messages):"
			local msg_num=1
			while IFS= read -r line; do
				if [[ -n "$line" ]]; then
					echo "   ┌─ Message $msg_num ─┐"
					if command -v jq >/dev/null 2>&1; then
						echo "$line" | jq -C . 2>/dev/null | sed 's/^/   │ /' || echo "   │ $line"
					else
						echo "   │ $line"
					fi
					echo "   └──────────────────┘"
					((msg_num++))
				fi
			done <<<"$request"
		else
			# Single request
			if command -v jq >/dev/null 2>&1; then
				# Pretty print JSON with colors if jq available
				echo "$request" | jq -C . 2>/dev/null || {
					echo "   ┌─ Raw Request Data ─┐"
					while IFS= read -r line; do echo "   │ $line"; done <<<"$request"
					echo "   └────────────────────┘"
				}
			else
				echo "   ┌─ Request Data ─┐"
				while IFS= read -r line; do echo "   │ $line"; done <<<"$request"
				echo "   └────────────────┘"
			fi
		fi
		echo ""
	fi

	# Show what would be returned
	if [[ -n "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE:-}" && "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}" != "null" ]]; then
		log_debug "📥 Expected Response (Simulated)"
		echo "${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}" | jq -C . 2>/dev/null || echo "   ${GRPCTESTIFY_DRY_RUN_EXPECTED_RESPONSE}"
		echo ""
	elif [[ "${GRPCTESTIFY_DRY_RUN_EXPECT_ERROR:-false}" == "true" ]]; then
		log_debug "⚠️ Expected Error (Simulated)"
		echo '   {"code": 999, "message": "DRY-RUN: Simulated gRPC error"}'
		echo ""
	fi

	# Execution note
	log_debug "✨ This command would be executed in normal mode"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
}

run_grpc_call() {
	local address="$1"
	local endpoint="$2"
	local request="$3"
	local headers="$4"
	local proto_file="$5"
	local dry_run="${6:-false}"

	# Build command array
	local cmd=("grpcurl" "-plaintext" "-format-error")

	if [[ -n "$proto_file" ]]; then
		cmd+=("-proto" "$proto_file")
	fi

	if [[ -n "$headers" ]]; then
		while IFS= read -r header; do
			if [[ -n "$header" ]]; then
				cmd+=("-H" "$header")
			fi
		done <<<"$headers"
	fi

	if [[ -n "$request" ]]; then
		# Critical fix: Use stdin (-d @) for multiple REQUEST sections to preserve JSON properly
		cmd+=("-d" "@")
	fi

	cmd+=("$address" "$endpoint")

	# Dry-run mode: delegate preview to shared helper
	if [[ "$dry_run" == "true" ]]; then
		render_grpcurl_preview "$request" "${cmd[@]}"
		return 0
	fi

	# Only show debug info in verbose mode or non-dots progress mode
	if [[ "${verbose:-false}" == "true" || "${LOG_LEVEL:-info}" == "debug" ]]; then
		log_debug "📡 gRPC Command:"
		# Format command nicely with line breaks for readability
		local formatted_cmd="grpcurl"
		for arg in "${cmd[@]:1}"; do
			if [[ "$arg" =~ ^- ]]; then
				formatted_cmd="$formatted_cmd \\\\\n      $arg"
			elif [[ "$arg" == "localhost:"* || "$arg" =~ \. ]]; then
				formatted_cmd="$formatted_cmd \\\\\n      '$arg'"
			else
				formatted_cmd="$formatted_cmd '$arg'"
			fi
		done
		echo -e "🔍    $formatted_cmd" >&2

		if [[ -n "$request" ]]; then
			log_debug "📤 Request Payload:"
			# Pretty print JSON if possible, otherwise show as-is
			if command -v jq >/dev/null 2>&1 && echo "$request" | jq . >/dev/null 2>&1; then
				echo "$request" | jq -C . 2>/dev/null | sed 's/^/🔍    /' >&2
			else
				echo "$request" | sed 's/^/🔍    /' >&2
			fi
		else
			log_debug "📤 Request Payload: (empty)"
		fi
	fi

	# Execute with request data using stdin piping (no temp files)
	if [[ -n "$request" ]]; then
		# Use jq -c to compact JSON and pipe directly to grpcurl
		printf '%s' "$request" | jq -c . | "${cmd[@]}" 2>&1
		return $?
	else
		"${cmd[@]}" 2>&1
	fi
}

# Enhanced gRPC call with retry mechanism
run_grpc_call_with_retry() {
	local address="$1"
	local endpoint="$2"
	local request="$3"
	local headers="$4"
	local proto_file="$5"
	local dry_run="${6:-false}"

	# Check if retry is disabled
	if is_no_retry; then
		log_debug "Retry mechanism disabled, using direct gRPC call"
		run_grpc_call "$address" "$endpoint" "$request" "$headers" "$proto_file" "$dry_run"
		return $?
	fi

	# Get retry configuration
	local max_retries="$(get_retry_count)"
	local retry_delay="$(get_retry_delay)"

	log_debug "🔄 Using retry mechanism: max_retries=$max_retries, delay=${retry_delay}s"

	# Use the retry mechanism from error_recovery.sh
	retry_grpc_call "$address" "$endpoint" "$request" "$headers" "$max_retries" "$dry_run"
}

## validate_expected_error moved to validation/error_validator.sh

## compare_responses moved to json_comparator.sh

### run_test duplicated implementation removed.

## apply_tolerance_comparison moved to json_comparator.sh

## apply_percentage_tolerance_comparison moved to json_comparator.sh
