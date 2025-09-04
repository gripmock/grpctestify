#!/bin/bash

# grpc_headers_trailers.sh - Enhanced gRPC headers and trailers validation plugin with microkernel integration
# Migrated from legacy grpc_headers_trailers.sh with microkernel components

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
readonly PLUGIN_HEADERS_TRAILERS_VERSION="1.0.0"
readonly PLUGIN_HEADERS_TRAILERS_DESCRIPTION="Enhanced gRPC headers and trailers validation with microkernel integration"
readonly PLUGIN_HEADERS_TRAILERS_AUTHOR="grpctestify-team"
readonly PLUGIN_HEADERS_TRAILERS_TYPE="validation"

# Header and trailer validation configuration
HEADER_VALIDATION_STRICT="${HEADER_VALIDATION_STRICT:-false}"
TRAILER_VALIDATION_STRICT="${TRAILER_VALIDATION_STRICT:-false}"
CASE_SENSITIVE_HEADERS="${CASE_SENSITIVE_HEADERS:-true}"

# Initialize headers and trailers validation plugin
grpc_headers_trailers_init() {
	log_debug "Initializing gRPC headers and trailers validation plugin..."

	# Ensure plugin integration is available
	if ! command -v plugin_register >/dev/null 2>&1; then
		log_warn "Plugin integration system not available, skipping plugin registration"
		return 1
	fi

	# Register plugin with microkernel
	plugin_register "headers_trailers" "grpc_headers_trailers_handler" "$PLUGIN_HEADERS_TRAILERS_DESCRIPTION" "internal" ""

	# Create resource pool for header/trailer validation
	pool_create "header_trailer_validation" 2

	# Subscribe to validation-related events
	event_subscribe "headers_trailers" "validation.*" "grpc_headers_trailers_event_handler"
	event_subscribe "headers_trailers" "grpc.call.*" "grpc_headers_trailers_call_handler"

	# Initialize validation tracking state
	if command -v state_db_set >/dev/null 2>&1; then
		state_db_set "headers_trailers.plugin_version" "$PLUGIN_HEADERS_TRAILERS_VERSION"
		state_db_set "headers_trailers.headers_validated" "0"
		state_db_set "headers_trailers.trailers_validated" "0"
		state_db_set "headers_trailers.validation_failures" "0"
	fi

	log_debug "gRPC headers and trailers validation plugin initialized successfully"
	return 0
}

# Main headers and trailers plugin handler
grpc_headers_trailers_handler() {
	local command="$1"
	shift
	local args=("$@")

	case "$command" in
	"evaluate_header")
		grpc_headers_trailers_evaluate_header "${args[@]}"
		;;
	"evaluate_trailer")
		grpc_headers_trailers_evaluate_trailer "${args[@]}"
		;;
	"validate_all_headers")
		grpc_headers_trailers_validate_all_headers "${args[@]}"
		;;
	"validate_all_trailers")
		grpc_headers_trailers_validate_all_trailers "${args[@]}"
		;;
	"get_statistics")
		grpc_headers_trailers_get_statistics "${args[@]}"
		;;
	"extract_metadata")
		grpc_headers_trailers_extract_metadata "${args[@]}"
		;;
	*)
		log_error "Unknown headers/trailers command: $command"
		return 1
		;;
	esac
}

# Enhanced header assertion with microkernel integration
grpc_headers_trailers_evaluate_header() {
	local response="$1"
	local header_name="$2"
	local expected_value="$3"
	local validation_options="${4:-{}}"

	if [[ -z "$response" || -z "$header_name" ]]; then
		log_error "grpc_headers_trailers_evaluate_header: response and header_name required"
		return 1
	fi

	log_debug "Evaluating header assertion: $header_name"

	# Publish header validation start event
	local validation_metadata
	validation_metadata=$(
		cat <<EOF
{
  "header_name": "$header_name",
  "expected_value": "$expected_value",
  "plugin": "headers_trailers",
  "start_time": $(date +%s),
  "options": $validation_options
}
EOF
	)
	event_publish "validation.header.start" "$validation_metadata" "$EVENT_PRIORITY_NORMAL" "headers_trailers"

	# Begin transaction for header validation
	local tx_id
	tx_id=$(state_db_begin_transaction "header_validation_${header_name}_$$")

	# Acquire resource for header validation
	local resource_token
	resource_token=$(pool_acquire "header_trailer_validation" 30)
	if [[ $? -ne 0 ]]; then
		log_error "Failed to acquire resource for header validation"
		state_db_rollback_transaction "$tx_id"
		return 1
	fi

	# Extract actual header value with enhanced methods
	local actual_value
	if ! actual_value=$(extract_header_value "$response" "$header_name" "$validation_options"); then
		log_error "Failed to extract header '$header_name' from response"
		pool_release "header_trailer_validation" "$resource_token"
		state_db_rollback_transaction "$tx_id"
		return 1
	fi

	# Perform enhanced header validation
	local validation_result=0
	if validate_header_value "$actual_value" "$expected_value" "$validation_options"; then
		log_debug "Header assertion passed: $header_name = '$actual_value'"

		# Record successful validation
		state_db_atomic "record_header_validation" "$header_name" "$actual_value" "$expected_value" "PASS"

		# Publish success event
		event_publish "validation.header.success" "{\"header_name\":\"$header_name\",\"actual_value\":\"$actual_value\"}" "$EVENT_PRIORITY_NORMAL" "headers_trailers"
	else
		validation_result=1
		log_error "Header assertion failed: $header_name expected '$expected_value', got '$actual_value'"

		# Record failed validation
		state_db_atomic "record_header_validation" "$header_name" "$actual_value" "$expected_value" "FAIL"

		# Publish failure event
		event_publish "validation.header.failure" "{\"header_name\":\"$header_name\",\"expected\":\"$expected_value\",\"actual\":\"$actual_value\"}" "$EVENT_PRIORITY_HIGH" "headers_trailers"
	fi

	# Update validation statistics
	increment_validation_counter "headers_validated"
	if [[ $validation_result -ne 0 ]]; then
		increment_validation_counter "validation_failures"
	fi

	# Release resource
	pool_release "header_trailer_validation" "$resource_token"

	# Commit transaction
	state_db_commit_transaction "$tx_id"

	return $validation_result
}

# Enhanced trailer assertion with microkernel integration
grpc_headers_trailers_evaluate_trailer() {
	local response="$1"
	local trailer_name="$2"
	local expected_value="$3"
	local validation_options="${4:-{}}"

	if [[ -z "$response" || -z "$trailer_name" ]]; then
		log_error "grpc_headers_trailers_evaluate_trailer: response and trailer_name required"
		return 1
	fi

	log_debug "Evaluating trailer assertion: $trailer_name"

	# Publish trailer validation start event
	local validation_metadata
	validation_metadata=$(
		cat <<EOF
{
  "trailer_name": "$trailer_name",
  "expected_value": "$expected_value",
  "plugin": "headers_trailers",
  "start_time": $(date +%s),
  "options": $validation_options
}
EOF
	)
	event_publish "validation.trailer.start" "$validation_metadata" "$EVENT_PRIORITY_NORMAL" "headers_trailers"

	# Begin transaction for trailer validation
	local tx_id
	tx_id=$(state_db_begin_transaction "trailer_validation_${trailer_name}_$$")

	# Acquire resource for trailer validation
	local resource_token
	resource_token=$(pool_acquire "header_trailer_validation" 30)
	if [[ $? -ne 0 ]]; then
		log_error "Failed to acquire resource for trailer validation"
		state_db_rollback_transaction "$tx_id"
		return 1
	fi

	# Extract actual trailer value with enhanced methods
	local actual_value
	if ! actual_value=$(extract_trailer_value "$response" "$trailer_name" "$validation_options"); then
		log_error "Failed to extract trailer '$trailer_name' from response"
		pool_release "header_trailer_validation" "$resource_token"
		state_db_rollback_transaction "$tx_id"
		return 1
	fi

	# Perform enhanced trailer validation
	local validation_result=0
	if validate_trailer_value "$actual_value" "$expected_value" "$validation_options"; then
		log_debug "Trailer assertion passed: $trailer_name = '$actual_value'"

		# Record successful validation
		state_db_atomic "record_trailer_validation" "$trailer_name" "$actual_value" "$expected_value" "PASS"

		# Publish success event
		event_publish "validation.trailer.success" "{\"trailer_name\":\"$trailer_name\",\"actual_value\":\"$actual_value\"}" "$EVENT_PRIORITY_NORMAL" "headers_trailers"
	else
		validation_result=1
		log_error "Trailer assertion failed: $trailer_name expected '$expected_value', got '$actual_value'"

		# Record failed validation
		state_db_atomic "record_trailer_validation" "$trailer_name" "$actual_value" "$expected_value" "FAIL"

		# Publish failure event
		event_publish "validation.trailer.failure" "{\"trailer_name\":\"$trailer_name\",\"expected\":\"$expected_value\",\"actual\":\"$actual_value\"}" "$EVENT_PRIORITY_HIGH" "headers_trailers"
	fi

	# Update validation statistics
	increment_validation_counter "trailers_validated"
	if [[ $validation_result -ne 0 ]]; then
		increment_validation_counter "validation_failures"
	fi

	# Release resource
	pool_release "header_trailer_validation" "$resource_token"

	# Commit transaction
	state_db_commit_transaction "$tx_id"

	return $validation_result
}

# Enhanced header value extraction
extract_header_value() {
	local response="$1"
	local header_name="$2"
	local validation_options="$3"

	# Parse validation options
	local case_sensitive
	case_sensitive=$(echo "$validation_options" | jq -r '.case_sensitive // true' 2>/dev/null)

	# Normalize header name for case-insensitive search
	local search_header="$header_name"
	if [[ "$case_sensitive" == "false" ]]; then
		search_header=$(echo "$header_name" | tr '[:upper:]' '[:lower:]')
	fi

	# Try multiple header field locations with priority order
	local header_fields=("_headers" "headers" "metadata" "grpc_headers" "response_headers")

	for field in "${header_fields[@]}"; do
		local actual_value
		if [[ "$case_sensitive" == "false" ]]; then
			# Case-insensitive search
			actual_value=$(echo "$response" | jq -r ".$field | to_entries | map(select(.key | ascii_downcase == \"$search_header\")) | .[0].value // empty" 2>/dev/null)
		else
			# Case-sensitive search
			actual_value=$(echo "$response" | jq -r ".$field.\"$header_name\" // empty" 2>/dev/null)
		fi

		if [[ "$actual_value" != "null" && -n "$actual_value" ]]; then
			echo "$actual_value"
			return 0
		fi
	done

	# Try to extract from error response metadata
	local error_value
	error_value=$(echo "$response" | jq -r ".error.headers.\"$header_name\" // empty" 2>/dev/null)
	if [[ "$error_value" != "null" && -n "$error_value" ]]; then
		echo "$error_value"
		return 0
	fi

	log_error "Header '$header_name' not found in gRPC response"
	return 1
}

# Enhanced trailer value extraction
extract_trailer_value() {
	local response="$1"
	local trailer_name="$2"
	local validation_options="$3"

	# Parse validation options
	local case_sensitive
	case_sensitive=$(echo "$validation_options" | jq -r '.case_sensitive // true' 2>/dev/null)

	# Normalize trailer name for case-insensitive search
	local search_trailer="$trailer_name"
	if [[ "$case_sensitive" == "false" ]]; then
		search_trailer=$(echo "$trailer_name" | tr '[:upper:]' '[:lower:]')
	fi

	# Try multiple trailer field locations with priority order
	local trailer_fields=("_trailers" "trailers" "metadata" "grpc_trailers" "response_trailers")

	for field in "${trailer_fields[@]}"; do
		local actual_value
		if [[ "$case_sensitive" == "false" ]]; then
			# Case-insensitive search
			actual_value=$(echo "$response" | jq -r ".$field | to_entries | map(select(.key | ascii_downcase == \"$search_trailer\")) | .[0].value // empty" 2>/dev/null)
		else
			# Case-sensitive search
			actual_value=$(echo "$response" | jq -r ".$field.\"$trailer_name\" // empty" 2>/dev/null)
		fi

		if [[ "$actual_value" != "null" && -n "$actual_value" ]]; then
			echo "$actual_value"
			return 0
		fi
	done

	# Try to extract from error response metadata
	local error_value
	error_value=$(echo "$response" | jq -r ".error.trailers.\"$trailer_name\" // empty" 2>/dev/null)
	if [[ "$error_value" != "null" && -n "$error_value" ]]; then
		echo "$error_value"
		return 0
	fi

	log_error "Trailer '$trailer_name' not found in gRPC response"
	return 1
}

# Enhanced header value validation with pattern support
validate_header_value() {
	local actual_value="$1"
	local expected_value="$2"
	local validation_options="$3"

	# Parse validation options
	local validation_type
	validation_type=$(echo "$validation_options" | jq -r '.type // "exact"' 2>/dev/null)
	local case_sensitive
	case_sensitive=$(echo "$validation_options" | jq -r '.case_sensitive // true' 2>/dev/null)

	case "$validation_type" in
	"exact")
		if [[ "$case_sensitive" == "false" ]]; then
			[[ "${actual_value,,}" == "${expected_value,,}" ]]
		else
			[[ "$actual_value" == "$expected_value" ]]
		fi
		;;
	"contains")
		if [[ "$case_sensitive" == "false" ]]; then
			[[ "${actual_value,,}" == *"${expected_value,,}"* ]]
		else
			[[ "$actual_value" == *"$expected_value"* ]]
		fi
		;;
	"regex")
		[[ "$actual_value" =~ $expected_value ]]
		;;
	"starts_with")
		if [[ "$case_sensitive" == "false" ]]; then
			[[ "${actual_value,,}" == "${expected_value,,}"* ]]
		else
			[[ "$actual_value" == "$expected_value"* ]]
		fi
		;;
	"ends_with")
		if [[ "$case_sensitive" == "false" ]]; then
			[[ "${actual_value,,}" == *"${expected_value,,}" ]]
		else
			[[ "$actual_value" == *"$expected_value" ]]
		fi
		;;
	*)
		log_error "Unknown validation type: $validation_type"
		return 1
		;;
	esac
}

# Enhanced trailer value validation (same logic as headers)
validate_trailer_value() {
	validate_header_value "$@"
}

# Validate all headers in response
grpc_headers_trailers_validate_all_headers() {
	local response="$1"
	local expected_headers="$2" # JSON object with header expectations
	local validation_options="${3:-{}}"

	local validation_failures=0
	local total_validations=0

	# Parse expected headers and validate each
	echo "$expected_headers" | jq -r 'to_entries[] | "\(.key)=\(.value)"' | while IFS='=' read -r header_name expected_value; do
		((total_validations++))
		if ! grpc_headers_trailers_evaluate_header "$response" "$header_name" "$expected_value" "$validation_options"; then
			((validation_failures++))
		fi
	done

	if [[ $validation_failures -eq 0 ]]; then
		log_debug "All headers validated successfully ($total_validations headers)"
		return 0
	else
		log_error "$validation_failures out of $total_validations header validations failed"
		return 1
	fi
}

# Validate all trailers in response
grpc_headers_trailers_validate_all_trailers() {
	local response="$1"
	local expected_trailers="$2" # JSON object with trailer expectations
	local validation_options="${3:-{}}"

	local validation_failures=0
	local total_validations=0

	# Parse expected trailers and validate each
	echo "$expected_trailers" | jq -r 'to_entries[] | "\(.key)=\(.value)"' | while IFS='=' read -r trailer_name expected_value; do
		((total_validations++))
		if ! grpc_headers_trailers_evaluate_trailer "$response" "$trailer_name" "$expected_value" "$validation_options"; then
			((validation_failures++))
		fi
	done

	if [[ $validation_failures -eq 0 ]]; then
		log_debug "All trailers validated successfully ($total_validations trailers)"
		return 0
	else
		log_error "$validation_failures out of $total_validations trailer validations failed"
		return 1
	fi
}

# Extract all metadata from response
grpc_headers_trailers_extract_metadata() {
	local response="$1"
	local metadata_type="${2:-all}" # all, headers, trailers

	case "$metadata_type" in
	"headers")
		echo "$response" | jq '{headers: (._headers // .headers // .metadata // {})}' 2>/dev/null
		;;
	"trailers")
		echo "$response" | jq '{trailers: (._trailers // .trailers // {})}' 2>/dev/null
		;;
	"all")
		echo "$response" | jq '{
                headers: (._headers // .headers // .metadata // {}),
                trailers: (._trailers // .trailers // {})
            }' 2>/dev/null
		;;
	*)
		log_error "Unknown metadata type: $metadata_type"
		return 1
		;;
	esac
}

# Get validation statistics
grpc_headers_trailers_get_statistics() {
	local format="${1:-json}"

	if command -v state_db_get >/dev/null 2>&1; then
		local headers_validated
		headers_validated=$(state_db_get "headers_trailers.headers_validated" || echo "0")
		local trailers_validated
		trailers_validated=$(state_db_get "headers_trailers.trailers_validated" || echo "0")
		local validation_failures
		validation_failures=$(state_db_get "headers_trailers.validation_failures" || echo "0")

		local total_validations=$((headers_validated + trailers_validated))
		local success_rate=0
		if [[ $total_validations -gt 0 ]]; then
			success_rate=$(echo "scale=2; ($total_validations - $validation_failures) * 100 / $total_validations" | bc 2>/dev/null || echo "0")
		fi

		case "$format" in
		"json")
			jq -n \
				--argjson headers "$headers_validated" \
				--argjson trailers "$trailers_validated" \
				--argjson total "$total_validations" \
				--argjson failures "$validation_failures" \
				--argjson success_rate "$success_rate" \
				'{
                        headers_validated: $headers,
                        trailers_validated: $trailers,
                        total_validations: $total,
                        validation_failures: $failures,
                        success_rate: $success_rate,
                        plugin_version: "1.0.0"
                    }'
			;;
		"summary")
			echo "Headers/Trailers Validation Statistics:"
			echo "  Headers validated: $headers_validated"
			echo "  Trailers validated: $trailers_validated"
			echo "  Total validations: $total_validations"
			echo "  Failures: $validation_failures"
			echo "  Success rate: ${success_rate}%"
			;;
		esac
	else
		echo '{"error": "State database not available"}'
	fi
}

# Increment validation counter
increment_validation_counter() {
	local counter_name="$1"

	if command -v state_db_get >/dev/null 2>&1; then
		local current_value
		current_value=$(state_db_get "headers_trailers.$counter_name" || echo "0")
		state_db_set "headers_trailers.$counter_name" "$((current_value + 1))"
	fi
}

# Headers and trailers event handler
grpc_headers_trailers_event_handler() {
	local event_message="$1"

	log_debug "Headers/trailers plugin received event: $event_message"

	# Handle validation-related events
	# This could be used for:
	# - Validation performance monitoring
	# - Header/trailer pattern analysis
	# - Security header compliance checking
	# - Metadata enrichment strategies

	return 0
}

# gRPC call event handler for automatic metadata extraction
grpc_headers_trailers_call_handler() {
	local event_message="$1"

	# Extract and log metadata from gRPC call events for analysis
	local endpoint
	endpoint=$(echo "$event_message" | jq -r '.endpoint // empty' 2>/dev/null)

	if [[ -n "$endpoint" && "$endpoint" != "null" ]]; then
		log_debug "Received gRPC call event for endpoint: $endpoint"
		# Could implement automatic header/trailer tracking here
	fi

	return 0
}

# State database helper functions
record_header_validation() {
	local header_name="$1"
	local actual_value="$2"
	local expected_value="$3"
	local result="$4"

	local validation_key="header_validation_$(echo "$header_name" | tr '[:upper:]' '[:lower:]' | tr -d ' ')_$(date +%s)"
	GRPCTESTIFY_STATE["${validation_key}_name"]="$header_name"
	GRPCTESTIFY_STATE["${validation_key}_actual"]="$actual_value"
	GRPCTESTIFY_STATE["${validation_key}_expected"]="$expected_value"
	GRPCTESTIFY_STATE["${validation_key}_result"]="$result"
	GRPCTESTIFY_STATE["${validation_key}_timestamp"]="$(date +%s)"

	return 0
}

record_trailer_validation() {
	local trailer_name="$1"
	local actual_value="$2"
	local expected_value="$3"
	local result="$4"

	local validation_key="trailer_validation_$(echo "$trailer_name" | tr '[:upper:]' '[:lower:]' | tr -d ' ')_$(date +%s)"
	GRPCTESTIFY_STATE["${validation_key}_name"]="$trailer_name"
	GRPCTESTIFY_STATE["${validation_key}_actual"]="$actual_value"
	GRPCTESTIFY_STATE["${validation_key}_expected"]="$expected_value"
	GRPCTESTIFY_STATE["${validation_key}_result"]="$result"
	GRPCTESTIFY_STATE["${validation_key}_timestamp"]="$(date +%s)"

	return 0
}

# Legacy compatibility functions
assert_grpc_header() {
	grpc_headers_trailers_evaluate_header "$@"
}

assert_grpc_trailer() {
	grpc_headers_trailers_evaluate_trailer "$@"
}

# Export functions
export -f grpc_headers_trailers_init grpc_headers_trailers_handler grpc_headers_trailers_evaluate_header
export -f grpc_headers_trailers_evaluate_trailer extract_header_value extract_trailer_value
export -f validate_header_value validate_trailer_value grpc_headers_trailers_validate_all_headers
export -f grpc_headers_trailers_validate_all_trailers grpc_headers_trailers_extract_metadata grpc_headers_trailers_get_statistics
export -f increment_validation_counter grpc_headers_trailers_event_handler grpc_headers_trailers_call_handler
export -f record_header_validation record_trailer_validation assert_grpc_header assert_grpc_trailer
