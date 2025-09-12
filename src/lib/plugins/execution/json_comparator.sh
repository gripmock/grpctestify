#!/bin/bash

# json_comparator.sh - JSON comparison utilities
# Extracted from runner.sh for better modularity
# Handles different types of JSON comparison operations

#######################################
# Compare JSON responses with different comparison types
# Arguments:
#   1: actual - actual JSON response
#   2: expected - expected JSON response
#   3: type - comparison type (exact|partial|contains)
# Returns:
#   0 if comparison passes, 1 if fails
#######################################
compare_json() {
	local actual="$1"
	local expected="$2"
	local type="${3:-exact}"

	# Validate JSON inputs
	if ! command -v jq >/dev/null 2>&1; then
		log_error "jq is required for JSON comparison but not installed"
		return 1
	fi

	if ! echo "$actual" | jq . >/dev/null 2>&1; then
		log_error "Invalid JSON in actual response"
		return 1
	fi

	if ! echo "$expected" | jq . >/dev/null 2>&1; then
		log_error "Invalid JSON in expected response"
		return 1
	fi

	case "$type" in
	"exact")
		# Exact JSON comparison (order-independent)
		if jq -e --argjson actual "$actual" --argjson expected "$expected" '$actual == $expected' >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
		;;
	"contains")
		# Check if actual contains expected (for arrays/objects)
		if echo "$actual" | jq -e --argjson expected "$expected" 'contains($expected)' >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
		;;
	"partial")
		# Check if all keys in expected exist in actual with same values
		if echo "$actual" | jq -e --argjson expected "$expected" 'contains($expected)' >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
		;;
	*)
		log_error "Unknown comparison type: $type"
		return 1
		;;
	esac
}

#######################################
# Compare JSON with detailed error reporting
# Arguments:
#   1: actual - actual JSON response
#   2: expected - expected JSON response
#   3: type - comparison type (exact|partial|contains)
#   4: test_name - test name for error reporting
# Returns:
#   0 if comparison passes, 1 if fails
# Outputs:
#   Detailed comparison results in verbose mode
#######################################
compare_json_detailed() {
	local actual="$1"
	local expected="$2"
	local type="${3:-exact}"
	local test_name="$4"

	# Perform comparison
	if compare_json "$actual" "$expected" "$type"; then
		if [[ "${verbose:-false}" == "true" ]]; then
			log_debug "✅ JSON comparison passed ($type)"
		fi
		return 0
	else
		# Detailed error reporting
		if [[ "${verbose:-false}" == "true" ]]; then
			log_error "❌ JSON comparison failed ($type) in $test_name"
			echo "Expected:"
			echo "$expected" | jq -C . 2>/dev/null | sed 's/^/    /' || echo "$expected" | sed 's/^/    /'
			echo "Actual:"
			echo "$actual" | jq -C . 2>/dev/null | sed 's/^/    /' || echo "$actual" | sed 's/^/    /'

			# Show differences if possible
			if command -v diff >/dev/null 2>&1; then
				echo "Differences:"
				diff <(echo "$expected" | jq -S . 2>/dev/null || echo "$expected") \
					<(echo "$actual" | jq -S . 2>/dev/null || echo "$actual") | sed 's/^/    /' || true
			fi
		fi
		return 1
	fi
}

#######################################
# Extract specific fields from JSON for comparison
# Arguments:
#   1: json_data - JSON string
#   2: field_path - JQ path expression (e.g., '.data.items[0].name')
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   Extracted field value
#######################################
extract_json_field() {
	local json_data="$1"
	local field_path="$2"

	if ! command -v jq >/dev/null 2>&1; then
		log_error "jq is required for field extraction but not installed"
		return 1
	fi

	if ! echo "$json_data" | jq . >/dev/null 2>&1; then
		log_error "Invalid JSON data for field extraction"
		return 1
	fi

	echo "$json_data" | jq -r "$field_path" 2>/dev/null || return 1
}

#######################################
# Validate JSON schema (basic validation)
# Arguments:
#   1: json_data - JSON string to validate
#   2: required_fields - comma-separated list of required fields
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_json_schema() {
	local json_data="$1"
	local required_fields="$2"

	if ! command -v jq >/dev/null 2>&1; then
		log_error "jq is required for schema validation but not installed"
		return 1
	fi

	if ! echo "$json_data" | jq . >/dev/null 2>&1; then
		log_error "Invalid JSON data for schema validation"
		return 1
	fi

	# Check required fields
	if [[ -n "$required_fields" ]]; then
		IFS=',' read -ra fields <<<"$required_fields"
		for field in "${fields[@]}"; do
			field=$(echo "$field" | xargs) # trim whitespace
			if ! echo "$json_data" | jq -e "has(\"$field\")" >/dev/null 2>&1; then
				log_error "Missing required field: $field"
				return 1
			fi
		done
	fi

	return 0
}

#######################################
# Format JSON for pretty display
# Arguments:
#   1: json_data - JSON string
#   2: compact - true for compact format, false for pretty (default: false)
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   Formatted JSON
#######################################
format_json() {
	local json_data="$1"
	local compact="${2:-false}"

	if ! command -v jq >/dev/null 2>&1; then
		# Fallback to basic formatting if jq not available
		echo "$json_data"
		return 0
	fi

	if ! echo "$json_data" | jq . >/dev/null 2>&1; then
		# Invalid JSON, return as-is
		echo "$json_data"
		return 1
	fi

	if [[ "$compact" == "true" ]]; then
		echo "$json_data" | jq -c . 2>/dev/null || echo "$json_data"
	else
		echo "$json_data" | jq . 2>/dev/null || echo "$json_data"
	fi
}

# Export functions for use by other plugins
export -f compare_json
export -f compare_json_detailed
export -f extract_json_field
export -f validate_json_schema
export -f format_json

# Apply tolerance comparison for numeric values
apply_tolerance_comparison() {
	local expected="$1"
	local actual="$2"
	local tolerance_spec="$3"

	if [[ "$tolerance_spec" =~ ^tolerance\[(.+)\]=(.+)$ ]]; then
		local path="${BASH_REMATCH[1]}"
		local tolerance_value="${BASH_REMATCH[2]}"
		local expected_val
		expected_val=$(echo "$expected" | jq -r "$path // empty" 2>/dev/null)
		local actual_val
		actual_val=$(echo "$actual" | jq -r "$path // empty" 2>/dev/null)
		if [[ "$expected_val" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$actual_val" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
			local diff
			diff=$(echo "$expected_val - $actual_val" | bc -l 2>/dev/null || echo "0")
			local abs_diff
			abs_diff=$(echo "if ($diff < 0) -1*$diff else $diff" | bc -l 2>/dev/null || echo "0")
			if (($(echo "$abs_diff <= $tolerance_value" | bc -l))); then
				return 0
			else
				return 1
			fi
		else
			return 0
		fi
	else
		return 1
	fi
}

# Apply percentage tolerance comparison for numeric values
apply_percentage_tolerance_comparison() {
	local expected="$1"
	local actual="$2"
	local tol_percent_spec="$3"

	if [[ "$tol_percent_spec" =~ ^tol_percent\[(.+)\]=(.+)$ ]]; then
		local path="${BASH_REMATCH[1]}"
		local tolerance_percent="${BASH_REMATCH[2]}"
		local expected_val
		expected_val=$(echo "$expected" | jq -r "$path // empty" 2>/dev/null)
		local actual_val
		actual_val=$(echo "$actual" | jq -r "$path // empty" 2>/dev/null)
		if [[ "$expected_val" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$actual_val" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
			local diff
			diff=$(echo "$expected_val - $actual_val" | bc -l 2>/dev/null || echo "0")
			local abs_diff
			abs_diff=$(echo "if ($diff < 0) -1*$diff else $diff" | bc -l 2>/dev/null || echo "0")
			local percent_diff
			percent_diff=$(echo "scale=6; $abs_diff * 100 / $expected_val" | bc -l 2>/dev/null || echo "0")
			if (($(echo "$percent_diff <= $tolerance_percent" | bc -l))); then
				return 0
			else
				return 1
			fi
		else
			return 0
		fi
	else
		return 1
	fi
}

# Compare responses with options (type, tolerance, redact, unordered arrays)
compare_responses() {
	local expected="$1"
	local actual="$2"
	local options="$3"
	local type="exact"
	local count="==1"
	local tolerance=""
	local tol_percent=""
	local redact=""
	local unordered_arrays="false"
	local unordered_arrays_paths=""
	local with_asserts="false"
	if [[ -n "$options" ]]; then
		while IFS='=' read -r key value; do
			case "$key" in
			"type") type="$value" ;;
			"count") count="$value" ;;
			"tolerance"*) tolerance="$key=$value" ;;
			"tol_percent"*) tol_percent="$key=$value" ;;
			"redact") redact="$value" ;;
			"unordered_arrays") unordered_arrays="$value" ;;
			"unordered_arrays_paths") unordered_arrays_paths="$value" ;;
			"with_asserts") with_asserts="$value" ;;
			esac
		done <<<"$options"
	fi
	if [[ -n "$redact" ]]; then
		local redact_paths
		redact_paths="$(echo "$redact" | tr ',' ' ')"
		for path in $redact_paths; do
			expected="$(echo "$expected" | jq "del($path)")"
			actual="$(echo "$actual" | jq "del($path)")"
		done
	fi
	if [[ -n "$tolerance" ]]; then
		if ! apply_tolerance_comparison "$expected" "$actual" "$tolerance"; then
			return 1
		fi
	fi
	if [[ -n "$tol_percent" ]]; then
		if ! apply_percentage_tolerance_comparison "$expected" "$actual" "$tol_percent"; then
			return 1
		fi
	fi
	if [[ "$unordered_arrays" == "true" ]]; then
		expected="$(echo "$expected" | jq -S .)"
		actual="$(echo "$actual" | jq -S .)"
	fi
	if [[ -n "$unordered_arrays_paths" ]]; then
		local paths
		paths="$(echo "$unordered_arrays_paths" | tr ',' ' ')"
		for path in $paths; do
			expected="$(echo "$expected" | jq "$path |= sort")"
			actual="$(echo "$actual" | jq "$path |= sort")"
		done
	fi
	case "$type" in
	"exact")
		if command -v jq >/dev/null 2>&1; then
			if echo "$actual" | jq . >/dev/null 2>&1 && echo "$expected" | jq . >/dev/null 2>&1; then
				local normalized_actual normalized_expected
				normalized_actual="$(echo "$actual" | jq -S -c .)"
				normalized_expected="$(echo "$expected" | jq -S -c .)"
				[[ "$normalized_actual" == "$normalized_expected" ]]
				return $?
			fi
		fi
		[[ "$expected" == "$actual" ]]
		return $?
		;;
	"partial")
		if echo "$actual" | jq -e --argjson expected "$expected" 'contains($expected)' >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
		;;
	*)
		log_error "Unknown comparison type: $type"
		return 1
		;;
	esac
}

export -f compare_responses
export -f apply_tolerance_comparison
export -f apply_percentage_tolerance_comparison
