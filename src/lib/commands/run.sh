#!/bin/bash
# shellcheck shell=bash

# Single-pass extractor for all sections in a .gctf file
parse_gctf_sections() {
	local file="$1"
	awk '
        BEGIN{sec=""}
        /^--- [A-Z_]+ ---$/ {
            sec=$0; gsub(/^--- /, "", sec); gsub(/ ---$/, "", sec); next
        }
        /^---/ { sec=""; next }
        { if (sec!="") print sec "\t" $0 }
    ' "$file"
}

# run.sh - Simplified test execution command based on simple_grpc_test_runner.sh
# This file contains the main logic for running gRPC tests
# Refactored to remove microkernel dependencies and use proven stable architecture

set -euo pipefail

# Basic logging (standard levels: error, warn, info, debug)
# Note: Using plugin-based logging functions instead

# Timeout function for preventing hanging tests
kernel_timeout() {
	local timeout_seconds="$1"
	shift

	if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -eq 0 ]]; then
		log_error "kernel_timeout: invalid timeout value: $timeout_seconds"
		return 1
	fi

	cached_timeout_exec "$timeout_seconds" "$@"
}

# Smart comment removal (from v0.0.13)
process_line() {
	local line="$1"
	local in_str=0
	local escaped=0
	local res=""
	local i c

	for ((i = 0; i < ${#line}; i++)); do
		c="${line:$i:1}"
		if [[ $escaped -eq 1 ]]; then
			res="$res$c"
			escaped=0
		elif [[ "$c" == "\\" ]]; then
			res="$res$c"
			escaped=1
		elif [[ "$c" == "\"" ]]; then
			res="$res$c"
			in_str=$((1 - in_str))
		elif [[ "$c" == "#" && $in_str -eq 0 ]]; then
			break
		else
			res="$res$c"
		fi
	done
	# Trim trailing spaces and tabs (no external sed)
	local end_index=$((${#res} - 1))
	while ((end_index >= 0)); do
		c="${res:end_index:1}"
		if [[ "$c" == $'\t' || "$c" == ' ' ]]; then
			res="${res:0:end_index}"
			((end_index--))
			continue
		fi
		break
	done
	echo "$res"
}

# Helper function to calculate test duration (reduces redundant date calls)
calculate_test_duration() {
	local start_time="$1"
	echo "$(($(date +%s%N) / 1000000 - start_time))"
}

# Auto-detect optimal number of parallel jobs based on CPU cores
auto_detect_parallel_jobs() {
	local cpu_count

	# Method 1: nproc (Linux, modern systems)
	if command -v nproc >/dev/null 2>&1; then
		cpu_count=$(nproc 2>/dev/null)
		if [[ -n "$cpu_count" && "$cpu_count" -gt 0 ]]; then
			echo "$cpu_count"
			return 0
		fi
	fi

	# Method 2: sysctl (macOS, BSD)
	if command -v sysctl >/dev/null 2>&1; then
		cpu_count=$(sysctl -n hw.ncpu 2>/dev/null)
		if [[ -n "$cpu_count" && "$cpu_count" -gt 0 ]]; then
			echo "$cpu_count"
			return 0
		fi
	fi

	# Fallback: reasonable default
	echo "4"
}

# Run single test file
run_single_test() {
	local test_file="$1"
	local dry_run="${2:-false}"

	if [[ ! -f "$test_file" ]]; then
		log_error "Test file not found: $test_file"
		return 1
	fi

	# Parse test file (trace timing via gperf)
	gperf "parse"
	local address=""
	local endpoint=""
	local request=""
	local expected_response=""
	local expected_error=""
	local headers=""
	local request_headers=""
	local options_section=""
	local asserts_section=""
	local tls_section=""
	local proto_section=""
	while IFS=$'\t' read -r sec line; do
		case "$sec" in
		ADDRESS)
			if [[ -z "$address" ]]; then
				address="${line#"${line%%[![:space:]]*}"}"       # ltrim
				address="${address%"${address##*[![:space:]]}"}" # rtrim
			fi
			;;
		ENDPOINT)
			if [[ -z "$endpoint" ]]; then
				endpoint="${line#"${line%%[![:space:]]*}"}"         # ltrim
				endpoint="${endpoint%"${endpoint##*[![:space:]]}"}" # rtrim
			fi
			;;
		REQUEST)
			if [[ ! "$line" =~ ^[[:space:]]*# ]]; then
				processed_line=$(process_line "$line")
				[[ -n "$processed_line" ]] && request+="$processed_line"
			fi
			;;
		RESPONSE)
			if [[ ! "$line" =~ ^[[:space:]]*# ]]; then
				processed_line=$(process_line "$line")
				[[ -n "$processed_line" ]] && expected_response+="$processed_line"
			fi
			;;
		ERROR)
			expected_error+="$line"$'\n'
			;;
		HEADERS)
			headers+="$line"$'\n'
			;;
		REQUEST_HEADERS)
			request_headers+="$line"$'\n'
			;;
		OPTIONS)
			options_section+="$line"$'\n'
			;;
		ASSERTS)
			asserts_section+="$line"$'\n'
			;;
		TLS)
			tls_section+="$line"$'\n'
			;;
		PROTO)
			proto_section+="$line"$'\n'
			;;
		esac
	done < <(parse_gctf_sections "$test_file")
	gperf "parse"
	# parse span ends via gperf below

	# Parse inline options from OPTIONS section
	local partial_option="false"
	local tolerance_option=""
	local redact_option=""
	local timeout_option=""

	if [[ -n "$options_section" ]]; then
		while IFS= read -r option_line; do
			if [[ "$option_line" =~ ^partial:[[:space:]]*(.+)$ ]]; then
				partial_option="${BASH_REMATCH[1]// /}"
			elif [[ "$option_line" =~ ^tolerance:[[:space:]]*(.+)$ ]]; then
				tolerance_option="${BASH_REMATCH[1]// /}"
			elif [[ "$option_line" =~ ^redact:[[:space:]]*(.+)$ ]]; then
				redact_option="${BASH_REMATCH[1]}"
			elif [[ "$option_line" =~ ^timeout:[[:space:]]*(.+)$ ]]; then
				timeout_option="${BASH_REMATCH[1]// /}"
			fi
		done <<<"$options_section"
	fi

	# Use GRPCTESTIFY_ADDRESS if no address in file
	if [[ -z "$address" ]]; then
		address="${GRPCTESTIFY_ADDRESS:-localhost:4770}"
	fi

	# Warn about deprecated HEADERS section and collect for summary
	if [[ -n "$headers" ]]; then
		log_warn "HEADERS section is deprecated. Use REQUEST_HEADERS instead."
		# Increment global counter for summary (if it exists)
		if [[ -n "${headers_warnings:-}" ]]; then
			headers_warnings=$((headers_warnings + 1))
		fi
	fi

	if [[ -z "$endpoint" ]]; then
		log_error "No endpoint specified in $test_file"
		return 1
	fi

	# Prepare headers arguments
	local header_args=()
	if [[ -n "$headers" ]]; then
		while IFS= read -r header; do
			if [[ -n "$header" && ! "$header" =~ ^[[:space:]]*$ ]]; then
				header_args+=("-H" "$header")
			fi
		done <<<"$headers"
	fi
	if [[ -n "$request_headers" ]]; then
		while IFS= read -r header; do
			if [[ -n "$header" && ! "$header" =~ ^[[:space:]]*$ ]]; then
				header_args+=("-H" "$header")
			fi
		done <<<"$request_headers"
	fi

	# Build argv with shared helper
	local has_request="0"
	[[ -n "$request" ]] && has_request="1"
	# Call the plugin's build_grpcurl_args
	gperf "grpc.args_build"
	build_grpcurl_args "$address" "$endpoint" "$tls_section" "$proto_section" header_args "$has_request"
	gperf "grpc.args_build"

	# Dry-run mode check (rich diagnostic output)
	if [[ "$dry_run" == "true" ]]; then
		echo "DRY-RUN ▶ File: $test_file"
		echo "DRY-RUN ▶ Reproducible command:"
		render_grpcurl_preview "$request" "${GRPCURL_ARGS[@]}" | indent_only 2

		if [[ -n "$request" ]]; then
			print_section "Request:" "$request"
		fi

		print_section "Effective OPTIONS:" "timeout: ${timeout_option:-30}
partial: ${partial_option}
redact: ${redact_option}
tolerance: ${tolerance_option}"

		if [[ -n "$expected_response" ]]; then
			print_section "Expected RESPONSE:" "$expected_response"
		fi
		if [[ -n "$expected_error" ]]; then
			print_section "Expected ERROR:" "$expected_error"
		fi
		if [[ -n "$asserts_section" ]]; then
			print_section "Expected ASSERTS:" "$asserts_section"
		fi

		# Streaming hint removed per project requirements

		return 3 # SKIPPED for dry-run
	fi

	# Execute real grpc call using shared helper
	local timeout_seconds="${timeout_option:-${args[--timeout]:-30}}" # per-file OPTIONS override, fallback to CLI --timeout, then 30
	if [[ -n "$request" ]]; then
		local grpc_start_ms=$(($(date +%s%N) / 1000000))
		grpc_output=$(execute_grpcurl_argv "$timeout_seconds" "$request" "${GRPCURL_ARGS[@]}")
		local grpc_status=$?
		local grpc_end_ms=$(($(date +%s%N) / 1000000))
		local grpc_duration_ms=$((grpc_end_ms - grpc_start_ms))
		perf_add "grpc.exec" "$grpc_duration_ms"
		if [[ $grpc_status -eq 124 ]]; then
			log_error "gRPC call timed out after ${timeout_seconds}s in $test_file"
			return 1
		fi
	else
		local grpc_start_ms=$(($(date +%s%N) / 1000000))
		grpc_output=$(execute_grpcurl_argv "$timeout_seconds" "" "${GRPCURL_ARGS[@]}")
		local grpc_status=$?
		local grpc_end_ms=$(($(date +%s%N) / 1000000))
		local grpc_duration_ms=$((grpc_end_ms - grpc_start_ms))
		perf_add "grpc.exec" "$grpc_duration_ms"
		if [[ $grpc_status -eq 124 ]]; then
			log_error "gRPC call timed out after ${timeout_seconds}s in $test_file"
			return 1
		fi
	fi
	local grpc_exit_code=$?
	# Note: gRPC durations tracked via perf aggregates; no legacy accumulation

	# Handle timeout specifically
	if [[ $grpc_exit_code -eq 124 ]]; then
		log_error "gRPC call timed out after ${timeout_seconds}s in $test_file"
		return 1 # FAIL
	fi

	# Detect error even if grpcurl exits 0 but returns JSON with code/message
	local detected_error_code
	detected_error_code=$(echo "$grpc_output" | jq -r '.code // empty' 2>/dev/null || true)
	if [[ -z "$detected_error_code" ]]; then
		detected_error_code=$(echo "$grpc_output" | sed -n 's/.*code = \([0-9][0-9]*\).*/\1/p' | head -n1)
	fi
	local is_error=0
	if [[ $grpc_exit_code -ne 0 || -n "$detected_error_code" ]]; then
		is_error=1
	fi

	# Check result
	if [[ $is_error -eq 0 ]]; then
		# Success case - check response
		if [[ -n "$expected_error" ]]; then
			log_error "Expected error but got success in $test_file"
			return 1 # FAIL
		fi

		if [[ -n "$expected_response" ]]; then
			gperf "compare"
			# Apply inline options for JSON comparison
			local actual_for_comparison="$grpc_output"
			local expected_for_comparison="$expected_response"

			# Apply redact option (remove specified fields)
			if [[ -n "$redact_option" ]]; then
				# Convert comma-separated list to jq array format using pure Bash (strip brackets/quotes, then join)
				local redact_fields_raw="$redact_option"
				redact_fields_raw=${redact_fields_raw//[/}
				redact_fields_raw=${redact_fields_raw//]/}
				redact_fields_raw=${redact_fields_raw/\"/}
				redact_fields_raw=${redact_fields_raw//\"/}
				local redact_fields
				redact_fields=${redact_fields_raw//,/","}
				redact_fields="\"$redact_fields\""
				actual_for_comparison=$(echo "$actual_for_comparison" | jq -c "delpaths([[$redact_fields] | map([.])])" 2>/dev/null || echo "$actual_for_comparison")
				expected_for_comparison=$(echo "$expected_for_comparison" | jq -c "delpaths([[$redact_fields] | map([.])])" 2>/dev/null || echo "$expected_for_comparison")
			fi

			# Apply partial matching if enabled
			if [[ "$partial_option" == "true" ]]; then
				# For partial matching, check if all expected fields exist in actual
				local expected_keys=$(echo "$expected_for_comparison" | jq -c 'paths(scalars) as $p | {"path": $p, "value": getpath($p)}' 2>/dev/null || echo "")
				if [[ -n "$expected_keys" ]]; then
					local partial_match_failed=false
					while IFS= read -r key_value; do
						if [[ -n "$key_value" ]]; then
							local path=$(echo "$key_value" | jq -r '.path | join(".")' 2>/dev/null)
							local expected_val=$(echo "$key_value" | jq -r '.value' 2>/dev/null)
							local actual_val=$(echo "$actual_for_comparison" | jq -r ".$path" 2>/dev/null || echo "null")

							if [[ "$expected_val" != "$actual_val" ]]; then
								partial_match_failed=true
								break
							fi
						fi
					done <<<"$expected_keys"

					if [[ "$partial_match_failed" == "false" ]]; then
						gperf "compare"
						return 0 # PASS - partial match succeeded
					fi
				fi
			fi

			# Standard exact comparison
			local clean_expected=$(echo "$expected_for_comparison" | jq -S -c . 2>/dev/null || echo "$expected_for_comparison")
			local clean_actual=$(echo "$actual_for_comparison" | jq -S -c . 2>/dev/null || echo "$actual_for_comparison")

			if [[ "$clean_actual" == "$clean_expected" ]]; then
				gperf "compare"
				return 0 # PASS
			else
				log_error "Response mismatch in $test_file"
				log_error "Expected: $clean_expected"
				log_error "Actual: $clean_actual"
				gperf "compare"
				return 1 # FAIL
			fi
		else
			return 0 # PASS (no response validation)
		fi
	else
		# Error case - check if error was expected
		if [[ -n "$expected_error" ]]; then
			# Fast path: if both expected and actual are valid JSON and equal -> PASS
			local __exp_json_eq __act_json_eq
			__exp_json_eq=$(echo "$expected_error" | jq -S -c . 2>/dev/null || true)
			__act_json_eq=$(echo "$grpc_output" | jq -S -c . 2>/dev/null || true)
			if [[ -n "$__exp_json_eq" && -n "$__act_json_eq" && "$__exp_json_eq" == "$__act_json_eq" ]]; then
				return 0
			fi
			# Expected error fields (JSON format from grpcurl)
			local expected_code expected_message
			# Extract structured fields using jq (grpcurl always returns JSON)
			expected_code=$(echo "$expected_error" | jq -r '.code // empty' 2>/dev/null || true)
			expected_message=$(echo "$expected_error" | jq -r '.message // empty' 2>/dev/null || true)

			# Actual error fields (grpcurl always returns JSON)
			local actual_code actual_message
			actual_code=$(echo "$grpc_output" | jq -r '.code // empty' 2>/dev/null || true)
			actual_message=$(echo "$grpc_output" | jq -r '.message // empty' 2>/dev/null || true)

			# Normalize nulls
			[[ "$expected_code" == "null" ]] && expected_code=""
			[[ "$expected_message" == "null" ]] && expected_message=""
			[[ "$actual_code" == "null" ]] && actual_code=""
			[[ "$actual_message" == "null" ]] && actual_message=""

			# If both expected and actual are valid JSON objects and equal, accept
			local expected_json_norm actual_json_norm
			expected_json_norm=$(echo "$expected_error" | jq -S -c . 2>/dev/null || true)
			actual_json_norm=$(echo "$grpc_output" | jq -S -c . 2>/dev/null || true)
			if [[ -n "$expected_json_norm" && -n "$actual_json_norm" && "$expected_json_norm" == "$actual_json_norm" ]]; then
				return 0
			fi

			local mismatch=false

			# Compare code if provided
			if [[ -n "$expected_code" ]]; then
				if [[ -z "$actual_code" || "$actual_code" != "$expected_code" ]]; then
					mismatch=true
				fi
			fi

			# Normalize messages (JSON strings don't have newlines, just trim whitespace)
			local norm_expected_message norm_actual_message
			norm_expected_message="${expected_message#"${expected_message%%[![:space:]]*}"}"           # ltrim
			norm_expected_message="${norm_expected_message%"${norm_expected_message##*[![:space:]]}"}" # rtrim
			norm_actual_message="${actual_message#"${actual_message%%[![:space:]]*}"}"                 # ltrim
			norm_actual_message="${norm_actual_message%"${norm_actual_message##*[![:space:]]}"}"       # rtrim

			# Compare message (substring match on normalized text) if provided
			if [[ -n "$expected_message" ]]; then
				if [[ -n "$norm_actual_message" ]]; then
					if [[ "$norm_actual_message" != *"$norm_expected_message"* ]]; then
						mismatch=true
					fi
				else
					# Fallback: search in full output text (JSON doesn't have newlines)
					if [[ "$grpc_output" != *"$norm_expected_message"* ]]; then
						mismatch=true
					fi
				fi
			fi

			# If no structured fields provided in expected_error, fallback to raw contains
			if [[ -z "$expected_code" && -z "$expected_message" ]]; then
				# Simple contains check (JSON doesn't have newlines)
				if [[ "$grpc_output" == *"$expected_error"* ]]; then
					mismatch=false
				else
					mismatch=true
				fi
			fi

			if [[ "$mismatch" == false ]]; then
				return 0
			fi

			log_error "Error mismatch in $test_file"
			if [[ -n "$expected_code" || -n "$expected_message" ]]; then
				log_error "Expected (code/message): ${expected_code:-""} / ${norm_expected_message:-""}"
				log_error "Actual   (code/message): ${actual_code:-""} / ${norm_actual_message:-""}"
			else
				log_error "Expected to contain: $expected_error_norm"
			fi
			log_error "Actual error output: $grpc_output"
			return 1
		else
			log_error "gRPC call failed for $test_file: $grpc_output"
			return 1 # FAIL
		fi
	fi
}

# CPU detection - using plugin-based implementation

# File collection with sorting support
collect_test_files() {
	local test_path="$1"
	local sort_mode="${2:-path}"
	local files=()

	if [[ -f "$test_path" ]]; then
		files=("$test_path")
	elif [[ -d "$test_path" ]]; then
		while IFS= read -r -d '' file; do
			files+=("$file")
		done < <(find "$test_path" -name "*.gctf" -print0)

		# Sort files according to mode (simplified for now)
		case "$sort_mode" in
		"random")
			IFS=$'\n' files=($(printf '%s\n' "${files[@]}" | shuf))
			;;
		*)
			IFS=$'\n' files=($(sort <<<"${files[*]}"))
			;;
		esac
	fi

	printf '%s\n' "${files[@]}"
}

# Report generation - using plugin-based implementations

# Perform the complete update process (based on v0.0.13 implementation)
perform_update() {
	local latest_version="$1"
	local current_script="$2"

	echo "🔄 Downloading grpctestify.sh $latest_version..."

	local download_url="https://github.com/gripmock/grpctestify/releases/download/${latest_version}/grpctestify.sh"
	local temp_file="/tmp/grpctestify_update_$$.sh"

	# Download latest version
	if ! curl -L --connect-timeout 10 --max-time 300 -o "$temp_file" "$download_url" 2>&1; then
		log_error "Failed to download update"
		rm -f "$temp_file"
		return 1
	fi

	# Verify file was downloaded
	if [[ ! -f "$temp_file" || ! -s "$temp_file" ]]; then
		log_error "Downloaded file is empty or missing"
		rm -f "$temp_file"
		return 1
	fi

	echo "📋 Verifying checksum..."

	# Verify checksum using checksums.txt file (like in v0.0.13)
	local checksum_url="https://github.com/gripmock/grpctestify/releases/download/${latest_version}/checksums.txt"
	local expected_checksum
	if expected_checksum=$(curl -s --connect-timeout 10 --max-time 30 "$checksum_url" 2>/dev/null | grep "grpctestify.sh" | awk '{print $1}'); then
		if [[ -n "$expected_checksum" ]]; then
			# Calculate checksum
			local actual_checksum
			if command -v sha256sum >/dev/null 2>&1; then
				actual_checksum=$(sha256sum "$temp_file" | cut -d' ' -f1)
			elif command -v shasum >/dev/null 2>&1; then
				actual_checksum=$(shasum -a 256 "$temp_file" | cut -d' ' -f1)
			else
				log_warn "No SHA-256 tool available, skipping checksum verification"
				actual_checksum="$expected_checksum" # Skip verification
			fi

			if [[ "$actual_checksum" != "$expected_checksum" ]]; then
				log_error "Checksum verification failed"
				log_error "Expected: $expected_checksum"
				log_error "Actual: $actual_checksum"
				rm -f "$temp_file"
				return 1
			fi
			echo "✅ Checksum verification passed"
		else
			log_warn "Could not find grpctestify.sh checksum in checksums.txt"
		fi
	else
		log_warn "Could not fetch checksums.txt, proceeding without verification"
	fi

	echo "💾 Creating backup..."

	# Create backup
	local backup_file="${current_script}.backup.$(date +%Y%m%d_%H%M%S)"
	if ! cp "$current_script" "$backup_file"; then
		log_error "Failed to create backup"
		rm -f "$temp_file"
		return 1
	fi

	echo "🔧 Installing update..."

	# Replace with new version
	if ! cp "$temp_file" "$current_script"; then
		log_error "Failed to install update"
		# Restore backup
		cp "$backup_file" "$current_script"
		rm -f "$temp_file"
		return 1
	fi

	# Set executable permissions
	if ! chmod +x "$current_script"; then
		log_error "Failed to set executable permissions"
		rm -f "$temp_file"
		return 1
	fi

	# Clean up
	rm -f "$temp_file"

	echo ""
	echo "✅ Update completed successfully!"
	echo "📦 Updated to version: $latest_version"
	echo "💾 Backup available at: $backup_file"
	echo ""
	echo "🔄 Please restart grpctestify.sh to use the new version"

	return 0
}

# Shared grpcurl helpers moved to src/lib/plugins/grpc/helpers.sh
# build_grpcurl_args
# render_grpcurl_preview
# execute_grpcurl_argv

# Main test execution function (renamed for bashly)
run_tests() {
	# Accept multiple test paths as arguments
	local test_paths=("$@")

	# Handle version flag
	if [[ "${args[--version]:-0}" == "1" ]]; then
		echo "grpctestify v1.0.0"
		return 0
	fi

	# Handle list-plugins flag
	if [[ "${args[--list - plugins]:-0}" == "1" ]]; then
		echo "Available plugins:"
		echo ""
		echo "📁 Built-in plugins (integrated into grpctestify.sh):"

		# List of built-in plugin categories
		local builtin_plugins=(
			"🔧 Core plugins:"
			"  • grpc_client - gRPC call execution"
			"  • json_comparator - JSON response validation"
			"  • test_orchestrator - Test execution management"
			"  • failure_reporter - Error reporting and logging"
			""
			"🎯 Assertion plugins:"
			"  • grpc_asserts - gRPC-specific assertions"
			"  • json_assertions - JSON content validation"
			"  • numeric_assertions - Numeric value checks"
			"  • regex_assertions - Regular expression matching"
			""
			"🛠️ System plugins:"
			"  • grpc_tls - TLS/SSL support"
			"  • grpc_headers_trailers - Headers and trailers handling"
			"  • grpc_response_time - Performance measurement"
			"  • grpc_type_validation - Protocol buffer validation"
			""
			"🎨 Output plugins:"
			"  • colors - Terminal color support"
			"  • progress - Progress indicators"
			"  • logging_io - Enhanced logging"
			"  • grpc_json_reporter - JSON format reports"
		)

		printf '%s\n' "${builtin_plugins[@]}"

		echo ""
		echo "📁 External plugins directory: ${GRPCTESTIFY_PLUGIN_DIR:-~/.grpctestify/plugins}"
		if [[ -d "${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}" ]]; then
			local external_count=0
			while IFS= read -r -d '' plugin; do
				if [[ -f "$plugin" ]]; then
					plugin_name="${plugin##*/}"      # Remove path, keep filename
					plugin_name="${plugin_name%.sh}" # Remove .sh extension
					echo "  • $plugin_name (external)"
					((external_count++))
				fi
			done < <(find "${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}" -name "*.sh" -type f -print0 2>/dev/null)

			if [[ $external_count -eq 0 ]]; then
				echo "  (No external plugins found)"
			fi
		else
			echo "  (Directory not found - create it to add external plugins)"
		fi
		return 0
	fi

	# Handle config flag
	if [[ "${args[--config]:-0}" == "1" ]]; then
		echo "Current grpctestify.sh configuration:"
		echo ""
		echo "🔧 Environment variables:"
		echo "  GRPCTESTIFY_ADDRESS: ${GRPCTESTIFY_ADDRESS:-localhost:4770}"
		echo "  GRPCTESTIFY_PLUGIN_DIR: ${GRPCTESTIFY_PLUGIN_DIR:-~/.grpctestify/plugins}"
		echo "  Note: Use CLI flags for timeout, verbose, parallel, and sort options"
		echo ""
		echo "⚙️ Default settings:"
		echo "  Parallel jobs: ${args[--parallel]:-auto}"
		echo "  Sort mode: ${args[--sort]:-path}"
		echo "  Retry count: ${args[--retry]:-3}"
		echo "  Retry delay: ${args[--retry - delay]:-1}s"
		echo "  Test timeout: ${args[--timeout]:-30}s"
		echo ""
		echo "📁 Plugin directory:"
		if [[ -d "${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}" ]]; then
			echo "  Status: ✅ Exists"
			echo "  Location: ${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}"
		else
			echo "  Status: ❌ Not found"
			echo "  Run 'mkdir -p ~/.grpctestify/plugins' to create"
		fi
		return 0
	fi

	# Handle update flag
	if [[ "${args[--update]:-0}" == "1" ]]; then
		# Use the proper update implementation from update.sh
		echo "🔄 grpctestify.sh v1.0.0 - Update"
		echo ""
		echo "📡 Checking for updates..."

		# Get latest version from GitHub API
		local api_url="https://api.github.com/repos/gripmock/grpctestify/releases/latest"
		local latest_version=""
		local current_version="v1.0.0"

		# Check dependencies
		# curl/jq are expected; if missing, update will fail gracefully during execution

		# Query GitHub API with timeout
		local response
		if ! response=$(curl -s --connect-timeout 10 --max-time 30 "$api_url" 2>&1); then
			log_error "Failed to check for updates (network error)"
			return 1
		fi

		# Extract version from response
		if ! latest_version=$(echo "$response" | jq -r '.tag_name // empty' 2>/dev/null); then
			log_error "Failed to parse GitHub API response"
			return 1
		fi

		if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
			log_error "No version information found in API response"
			return 1
		fi

		echo "Current version: $current_version"
		echo "Latest version: $latest_version"
		echo ""

		# Compare versions
		if [[ "$latest_version" != "$current_version" ]]; then
			echo "🆕 Update available: $current_version -> $latest_version"
			echo ""
			echo -n "Do you want to update? [y/N]: "
			read -r response

			case "$response" in
			[yY] | [yY][eE][sS])
				perform_update "$latest_version" "$0"
				;;
			*)
				echo "❌ Update cancelled by user"
				;;
			esac
		else
			echo "✅ Already up to date"
		fi

		return 0
	fi

	# Handle create-plugin flag
	if [[ -n "${args[--create - plugin]:-}" ]]; then
		local plugin_name="${args[--create - plugin]}"

		echo "🔌 Creating new plugin: $plugin_name"
		echo ""

		# Load plugins module if not already loaded
		if ! command -v create_plugin_command >/dev/null 2>&1; then
			source "${BASH_SOURCE[0]%/*}/plugins.sh"
		fi

		# Use the new plugin creation logic from plugins.sh
		create_plugin_command "$plugin_name"

		return 0
	fi

	# Handle init-config flag
	if [[ -n "${args[--init - config]:-}" ]]; then
		local config_file="${args[--init - config]}"

		echo "⚙️ Creating configuration file: $config_file"

		if [[ -f "$config_file" ]]; then
			log_error "Configuration file already exists: $config_file"
			return 1
		fi

		cat >"$config_file" <<'EOF'
# grpctestify.sh configuration file
# This file can be sourced before running grpctestify.sh

# Default gRPC server address
export GRPCTESTIFY_ADDRESS="localhost:4770"

# Plugin directory for external plugins
export GRPCTESTIFY_PLUGIN_DIR="$HOME/.grpctestify/plugins"

# Note: CLI flags take precedence over environment variables
# Use --timeout, --verbose, --parallel, --sort flags instead of ENV variables
EOF

		echo "✅ Configuration file created!"
		echo "📁 Location: $config_file"
		echo ""
		echo "🔧 Usage:"
		echo "  source $config_file"
		echo "  ./grpctestify.sh your_tests/"

		return 0
	fi

	# Handle completion flag
	if [[ -n "${args[--completion]:-}" ]]; then
		local shell_type="${args[--completion]}"

		echo "🚀 Installing shell completion for: $shell_type"
		echo ""
		echo "ℹ️ Shell completion functionality:"
		echo "  • Bash completion: Add to ~/.bashrc"
		echo "  • Zsh completion: Add to ~/.zshrc"
		echo "  • Complete grpctestify.sh flags and options"
		echo ""
		echo "📝 Implementation:"
		echo "  This feature is planned for future releases"
		echo "  Current version: v1.0.0 (basic completion available)"

		return 0
	fi

	# If no test paths provided, show help (unless flags handled above)
	if [[ ${#test_paths[@]} -eq 0 ]]; then
		grpctestify.sh_usage
		return 0
	fi

	# Validate all test paths
	for test_path in "${test_paths[@]}"; do
		if [[ ! -e "$test_path" ]]; then
			log_error "Test path does not exist: $test_path"
			return 1
		fi
	done

	# Get options from bashly args
	local parallel_jobs="${args[--parallel]:-}"
	local dry_run="${args[--dry - run]:-0}"
	local verbose="${args[--verbose]:-0}"
	local sort_mode="${args[--sort]:-path}"
	local log_format="${args[--log - format]:-}"
	local log_output="${args[--log - output]:-}"

	# Validate log format if specified
	if [[ -n "$log_format" ]]; then
		case "$log_format" in
		"junit" | "json")
			if [[ -z "$log_output" ]]; then
				log_error "Error: --log-output is required when using --log-format"
				return 1
			fi
			;;
		*)
			log_error "Error: Unsupported log format '$log_format'. Supported: junit, json"
			return 1
			;;
		esac
	fi

	# Auto-detect parallel jobs if not specified or set to "auto"
	if [[ -z "$parallel_jobs" || "$parallel_jobs" == "auto" ]]; then
		parallel_jobs=$(auto_detect_parallel_jobs)
		[[ "$verbose" == "1" ]] && log_info "Auto-detected $parallel_jobs CPU cores, using $parallel_jobs parallel jobs"
	fi

	# Collect test files from all provided paths
	gperf "collect"
	local test_files=()
	for test_path in "${test_paths[@]}"; do
		while IFS= read -r file; do
			test_files+=("$file")
		done < <(collect_test_files "$test_path" "$sort_mode")
	done
	gperf "collect"

	local total=${#test_files[@]}

	if [[ "$total" -eq 0 ]]; then
		log_error "No test files found in any of the specified paths"
		return 1
	fi

	[[ "$verbose" == "1" ]] && log_info "Auto-selected progress mode: $([ "$verbose" == "1" ] && echo "verbose" || echo "dots") ($total tests, verbose=$verbose)"

	# Start timing for detailed statistics (millisecond precision)
	local start_time
	start_time=$(($(date +%s%N) / 1000000))

	# Global run timeout budget: total_tests * (CLI --timeout or 30)s * 1.2 safety
	local cli_timeout_sec="${args[--timeout]:-30}"
	[[ -z "$cli_timeout_sec" ]] && cli_timeout_sec=30
	local budget_ms=$((total * cli_timeout_sec * 1200)) # 1.2x safety factor

	local passed=0
	local failed=0
	local skipped=0
	# Global counter for warnings (accessible by run_single_test)
	headers_warnings=0

	# Arrays to store test details for JUnit report
	local passed_tests=()
	local failed_tests=()
	local skipped_tests=()

	# Progress dots counter for line wrapping (80 chars max per line)
	local dots_count=0
	# Global abort flag
	local aborted=false
	# Safety cap to ensure we never exceed number of files
	local max_iterations=$total
	local processed=0
	# Debug accumulators (only meaningful when GRPCTESTIFY_LOG_LEVEL=debug)

	if [[ "$total" -eq 1 ]]; then
		log_info "Running 1 test sequentially..."
		[[ "$verbose" == "1" ]] && log_info "Verbose mode enabled - detailed test information will be shown"
	else
		if [[ "$parallel_jobs" -eq 1 ]]; then
			log_info "Running $total test(s) sequentially..."
		else
			log_info "Running $total test(s) in parallel (jobs: $parallel_jobs)..."
		fi
	fi

	# Execute tests with pytest-style UI
	gperf "loop"

	# Use indexed loop instead of array expansion (more reliable in generated scripts)
	for ((i = 0; i < ${#test_files[@]}; i++)); do
		if [[ $processed -ge $max_iterations ]]; then
			break
		fi
		# Check global budget before starting next test
		local now_ms
		now_ms=$(($(date +%s%N) / 1000000))
		local elapsed_ms=$((now_ms - start_time))
		if [[ $elapsed_ms -gt $budget_ms ]]; then
			aborted=true
			local remaining=$((total - i))
			# Record synthetic failures for remaining tests with reason
			for ((j = i; j < total; j++)); do
				local rem_file="${test_files[$j]}"
				failed_tests+=("$rem_file|0|Aborted by global timeout")
			done
			failed=$((failed + remaining))
			# Keep UI consistent: print 'E' for each remaining in dots mode
			if [[ "$verbose" != "1" ]]; then
				for ((r = 0; r < remaining; r++)); do
					echo -n "E"
					dots_count=$((dots_count + 1))
					if [[ $((dots_count % 80)) -eq 0 ]]; then
						echo "" # Force flush and newline
					fi
				done
			fi
			log_error "Global run timeout exceeded: ${elapsed_ms}ms > budget ${budget_ms}ms. Aborting remaining tests."
			break
		fi

		local test_file="${test_files[$i]}"
		local test_name="${test_file##*/}" # Remove path, keep filename
		test_name="${test_name%.gctf}"     # Remove .gctf extension

		# Start timing for this test (reuse now_ms for efficiency)
		local test_start_time="$now_ms"

		# Pytest-style UI: verbose vs dots mode
		if [[ "$verbose" == "1" ]]; then
			if [[ "$dry_run" == "1" ]]; then
				# Dry-run: let run_single_test print the formatted preview, then separate
				run_single_test "$test_file" "true"
				# Duration for stats
				local test_duration
				test_duration=$(calculate_test_duration "$test_start_time")
				skipped=$((skipped + 1))
				skipped_tests+=("$test_file|$test_duration")
				printf "\n----\n\n"
			else
				printf "Testing %s ... " "$test_name"
				if run_single_test "$test_file" "false"; then
					echo "✅ PASS"
					passed=$((passed + 1))

					# Calculate test duration
					local test_duration
					test_duration=$(calculate_test_duration "$test_start_time")
					passed_tests+=("$test_file|$test_duration")
				else
					local exit_code=$?

					# Calculate test duration
					local test_duration
					test_duration=$(calculate_test_duration "$test_start_time")

					if [[ "$exit_code" -eq 3 ]]; then
						echo "🔍 SKIP (dry-run)"
						skipped=$((skipped + 1))
						skipped_tests+=("$test_file|$test_duration")
					else
						echo "❌ FAIL"
						failed=$((failed + 1))
						failed_tests+=("$test_file|$test_duration|Test execution failed")
					fi
				fi
			fi
		else
			# Dots mode (pytest-style)
			if [[ "$dry_run" == "1" ]]; then
				run_single_test "$test_file" "true"
				# For dry-run, show a simple separator between requests and skip progress symbols
				printf "\n----\n\n"
			else
				if run_single_test "$test_file" "false" >/dev/null 2>&1; then
					local exit_code=$?
				else
					local exit_code=$?
				fi
			fi

			# Calculate test duration
			local test_duration
			test_duration=$(calculate_test_duration "$test_start_time")

			case $exit_code in
			0)
				if [[ "$dry_run" != "1" ]]; then echo -n "."; fi
				passed=$((passed + 1))
				passed_tests+=("$test_file|$test_duration")
				;;
			3)
				if [[ "$dry_run" != "1" ]]; then
					echo -n "S"
				fi
				skipped=$((skipped + 1))
				skipped_tests+=("$test_file|$test_duration")
				;;
			*)
				if [[ "$dry_run" != "1" ]]; then echo -n "E"; fi
				failed=$((failed + 1))
				failed_tests+=("$test_file|$test_duration|Test execution failed")
				;;
			esac

			# Line wrapping for progress dots (80 chars per line like other test tools)
			if [[ "$dry_run" != "1" ]]; then
				dots_count=$((dots_count + 1))
				if [[ $((dots_count % 80)) -eq 0 ]]; then
					echo "" # Force flush and newline
				fi
			fi
		fi

		processed=$((processed + 1))
	done

	# Post-loop guard: if processed exceeded planned total, treat as error
	if [[ $processed -gt $total ]]; then
		log_error "Internal error: processed $processed tests > collected $total"
		aborted=true
	fi

	# Add newline after dots mode
	[[ "$verbose" != "1" ]] && echo
	# Stop loop perf span after ensuring newline to avoid mixing with progress dots
	gperf "loop"

	# Calculate execution time and advanced statistics (millisecond precision)
	local end_time
	end_time=$(($(date +%s%N) / 1000000))
	local duration_ms=$((end_time - start_time))

	# Calculate average time per test
	local avg_per_test_ms=0
	if [[ $total -gt 0 ]]; then
		avg_per_test_ms=$((duration_ms / total))
	fi

	# Professional summary like pytest/jest
	echo
	echo "════════════════════════════════════════════════════════════════════════════════"

	# Test results line with professional formatting
	if [[ $failed -gt 0 ]]; then
		echo "❌ FAILED ($failed failed, $passed passed$([ "$skipped" -gt 0 ] && echo ", $skipped skipped" || echo "") in ${duration_ms}ms)"
	elif [[ $skipped -gt 0 ]]; then
		echo "🔍 PASSED ($passed passed, $skipped skipped in ${duration_ms}ms)"
	else
		echo "✅ PASSED ($passed passed in ${duration_ms}ms)"
	fi

	echo "────────────────────────────────────────────────────────────────────────────────"
	# Print perf summary (trace-only)
	perf_summary

	# Detailed statistics section
	echo "📊 Execution Statistics:"
	echo "   • Total tests: $total"
	echo "   • Passed: $passed"
	echo "   • Failed: $failed"
	echo "   • Skipped: $skipped"
	echo "   • Duration: ${duration_ms}ms"
	echo "   • Average per test: ${avg_per_test_ms}ms"

	# gRPC timing and overhead statistics (from perf aggregates)
	local total_grpc_ms="${PERF_SUM["$$|grpc.exec"]:-0}"
	local grpc_calls="${PERF_COUNT["$$|grpc.exec"]:-0}"
	if [[ "$grpc_calls" -gt 0 ]]; then
		local avg_grpc_ms=$((total_grpc_ms / grpc_calls))
		local overhead_ms=$((duration_ms - total_grpc_ms))
		local avg_overhead_per_test_ms=0
		if [[ $total -gt 0 ]]; then
			avg_overhead_per_test_ms=$((overhead_ms / total))
		fi
		echo "   • gRPC: total ${total_grpc_ms}ms, avg ${avg_grpc_ms}ms per call"
		echo "   • Overhead: ${overhead_ms}ms total, avg ${avg_overhead_per_test_ms}ms per test"
	else
		echo "   • gRPC: no calls measured"
	fi

	# Execution mode information
	if [[ "$parallel_jobs" -eq 1 ]]; then
		echo "   • Mode: Sequential (1 thread)"
	else
		echo "   • Mode: Parallel ($parallel_jobs threads)"
	fi

	# Success rate calculation (only for executed tests)
	local executed=$((passed + failed))
	if [[ "$dry_run" == "1" ]]; then
		echo "   • Success rate: N/A (dry-run mode)"
	elif [[ $executed -gt 0 ]]; then
		local success_rate_num=$(((passed * 100) / executed))
		echo "   • Success rate: ${success_rate_num}% ($passed/$executed executed)"
	else
		echo "   • Success rate: N/A (no tests executed)"
	fi

	# Performance analysis with emojis
	if [[ $total -gt 0 && "$dry_run" != "1" ]]; then
		if [[ $avg_per_test_ms -lt 100 ]]; then
			echo "   • Performance: ⚡ Excellent (${avg_per_test_ms}ms/test)"
		elif [[ $avg_per_test_ms -lt 500 ]]; then
			echo "   • Performance: ✅ Good (${avg_per_test_ms}ms/test)"
		elif [[ $avg_per_test_ms -lt 1000 ]]; then
			echo "   • Performance: ⚠️  Moderate (${avg_per_test_ms}ms/test)"
		else
			echo "   • Performance: 🐌 Slow (${avg_per_test_ms}ms/test)"
		fi
	fi

	echo "────────────────────────────────────────────────────────────────────────────────"

	# Warnings section (collected during execution)
	local has_warnings=false
	if [[ $headers_warnings -gt 0 ]]; then
		if [[ "$has_warnings" == "false" ]]; then
			echo "⚠️  Warnings:"
			has_warnings=true
		fi
		echo "   • Found $headers_warnings HEADERS sections - use REQUEST_HEADERS instead"
	fi

	# Failed tests section (full file paths)
	if [[ $failed -gt 0 && ${#failed_tests[@]} -gt 0 ]]; then
		echo "❌ Failed Tests:"
		for test_info in "${failed_tests[@]}"; do
			local fpath="${test_info%%|*}"
			local remaining="${test_info#*|}"
			local fdur="${remaining%%|*}"
			echo "   • $fpath (${fdur}ms)"
		done
	fi

	# Environment info
	echo "🔧 Environment:"
	echo "   • gRPC Address: ${GRPCTESTIFY_ADDRESS:-localhost:4770}"
	echo "   • Sort Mode: $sort_mode"
	if [[ "$dry_run" == "1" ]]; then
		echo "   • Dry Run: Enabled (no actual gRPC calls)"
	else
		echo "   • Dry Run: Disabled (real gRPC calls)"
	fi

	if [[ "$has_warnings" == "false" ]]; then
		echo "✨ No warnings detected"
	fi

	echo "════════════════════════════════════════════════════════════════════════════════"

	# Generate reports if requested
	if [[ -n "$log_format" && -n "$log_output" ]]; then
		echo
		echo "📋 Generating $log_format report..."

		# Ensure reporting plugin is available (bashly will inline src/lib/**/*.sh)
		type reporting_generate_junit_report >/dev/null 2>&1 || true
		type reporting_generate_json_report >/dev/null 2>&1 || true

		case "$log_format" in
		"junit")
			reporting_generate_junit_report "$log_output" "$total" "$passed" "$failed" "$skipped" "$duration_ms" "$start_time" "passed_tests" "failed_tests" "skipped_tests"
			;;
		"json")
			reporting_generate_json_report "$log_output" "$total" "$passed" "$failed" "$skipped" "$duration_ms" "$start_time" "passed_tests" "failed_tests" "skipped_tests"
			;;
		esac

		if [[ $? -eq 0 ]]; then
			echo "✅ Report saved: $log_output"
		else
			echo "❌ Failed to generate report: $log_output"
		fi
	fi

	# Return appropriate exit code (0 only for 100% success in non-dry-run)
	if [[ "$dry_run" == "1" ]]; then
		return 0 # Dry-run always succeeds
	else
		if [[ "$aborted" == "true" ]]; then
			return 1
		fi
		return $([[ $failed -eq 0 ]] && echo 0 || echo 1)
	fi
}

# Required by bashly framework - this function will be called by the generated script
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
	# Being sourced by bashly generated script
	true
fi
