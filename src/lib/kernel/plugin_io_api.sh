#!/bin/bash

# Plugin IO API for gRPC Testify
# Provides controlled interface for plugins to interact with the IO system
# All plugin IO operations must go through this API

#######################################
# Ensure mutex system is initialized
# Returns:
#   0 if mutex available, 1 if not
#######################################
_plugin_io_ensure_mutex() {
	if command -v mutex_is_available >/dev/null 2>&1 && mutex_is_available; then
		return 0
	elif command -v mutex_init >/dev/null 2>&1; then
		mutex_init >/dev/null 2>&1
		return $?
	else
		return 1
	fi
}

#######################################
# Plugin IO API - Progress Reporting
#######################################

# Send progress update for a test
# Arguments:
#   1: Test name
#   2: Status (running, passed, failed, skipped)
#   3: Display symbol (., F, S, E, etc.)
# Returns:
#   0 on success
#######################################
plugin_io_progress() {
	local test_name="$1"
	local status="$2"
	local symbol="$3"

	# Validate parameters
	if [[ -z "$test_name" || -z "$status" || -z "$symbol" ]]; then
		log_error "plugin_io_progress: Missing required parameters"
		return 1
	fi

	# Validate status
	case "$status" in
	running | passed | failed | skipped | error) ;;
	*)
		log_error "plugin_io_progress: Invalid status '$status'"
		return 1
		;;
	esac

	# Send through IO system if available, otherwise use fallback
	if command -v io_send_progress >/dev/null 2>&1; then
		io_send_progress "$test_name" "$status" "$symbol"
	else
		# Fallback to direct output with mutex protection if available
		if _plugin_io_ensure_mutex; then
			mutex_printf "%s" "$symbol"
		else
			printf "%s" "$symbol"
		fi
	fi
}

#######################################
# Plugin IO API - Result Reporting
#######################################

# Send test result
# Arguments:
#   1: Test name
#   2: Status (PASSED, FAILED, ERROR, SKIPPED)
#   3: Duration in milliseconds
#   4: Additional details (optional)
# Returns:
#   0 on success
#######################################
plugin_io_result() {
	local test_name="$1"
	local status="$2"
	local duration="$3"
	local details="${4:-}"

	# Validate parameters
	if [[ -z "$test_name" || -z "$status" || -z "$duration" ]]; then
		log_error "plugin_io_result: Missing required parameters"
		return 1
	fi

	# Validate status
	case "$status" in
	PASSED | FAILED | ERROR | SKIPPED) ;;
	*)
		log_error "plugin_io_result: Invalid status '$status'"
		return 1
		;;
	esac

	# Validate duration is numeric
	if ! [[ "$duration" =~ ^[0-9]+$ ]]; then
		log_error "plugin_io_result: Duration must be numeric (milliseconds)"
		return 1
	fi

	# Send through IO system if available, otherwise use state system
	if command -v io_send_result >/dev/null 2>&1; then
		io_send_result "$test_name" "$status" "$duration" "$details"
	elif command -v test_state_record_result >/dev/null 2>&1; then
		test_state_record_result "$test_name" "$status" "$duration" "$details"
	fi
}

#######################################
# Plugin IO API - Error Reporting
#######################################

# Send error message
# Arguments:
#   1: Test name
#   2: Error details
# Returns:
#   0 on success
#######################################
plugin_io_error() {
	local test_name="$1"
	local error_details="$2"

	# Validate parameters
	if [[ -z "$test_name" || -z "$error_details" ]]; then
		log_error "plugin_io_error: Missing required parameters"
		return 1
	fi

	# Send through IO system if available, otherwise use fallback
	if command -v io_send_error >/dev/null 2>&1; then
		io_send_error "$test_name" "$error_details"
	elif command -v store_test_failure >/dev/null 2>&1; then
		store_test_failure "$test_name" "$error_details"
	fi
}

#######################################
# Plugin IO API - Output Functions
#######################################

# Safe output with mutex protection
# Arguments:
#   1: Format string
#   2+: Format arguments
# Returns:
#   0 on success
#######################################
plugin_io_print() {
	local format="$1"
	shift

	if command -v io_printf >/dev/null 2>&1; then
		io_printf "$format" "$@"
	elif _plugin_io_ensure_mutex; then
		mutex_printf "$format" "$@"
	else
		printf "$format" "$@"
	fi
}

# Safe error output with mutex protection
# Arguments:
#   1+: Error message parts
# Returns:
#   0 on success
#######################################
plugin_io_error_print() {
	if command -v io_error >/dev/null 2>&1; then
		io_error "$*"
	elif _plugin_io_ensure_mutex; then
		mutex_eprint "$*"
	else
		printf "%s\n" "$*" >&2
	fi
}

# Output newline safely
# Returns:
#   0 on success
#######################################
plugin_io_newline() {
	if command -v io_newline >/dev/null 2>&1; then
		io_newline
	elif _plugin_io_ensure_mutex; then
		mutex_printf "\n"
	else
		printf "\n"
	fi
}

#######################################
# Plugin IO API - Information Functions
#######################################

# Check if IO system is available
# Returns:
#   0 if available, 1 if not
#######################################
plugin_io_available() {
	command -v io_init >/dev/null 2>&1
}

# Check if mutex system is available
# Returns:
#   0 if available, 1 if not
#######################################
plugin_mutex_available() {
	command -v mutex_init >/dev/null 2>&1
}

# Get IO system status for debugging
# Returns:
#   Prints status information
#######################################
plugin_io_status() {
	echo "Plugin IO API Status:"
	echo "  IO System: $(plugin_io_available && echo "Available" || echo "Not Available")"
	echo "  Mutex System: $(plugin_mutex_available && echo "Available" || echo "Not Available")"

	if command -v io_status >/dev/null 2>&1; then
		echo ""
		io_status
	fi

	if command -v mutex_status >/dev/null 2>&1; then
		echo ""
		mutex_status
	fi
}

#######################################
# Plugin IO API - Batch Operations
#######################################

# Send multiple progress updates atomically
# Arguments:
#   1+: Multiple "test_name:status:symbol" entries
# Returns:
#   0 on success
#######################################
plugin_io_batch_progress() {
	local entry
	for entry in "$@"; do
		local test_name status symbol
		IFS=':' read -r test_name status symbol <<<"$entry"
		plugin_io_progress "$test_name" "$status" "$symbol"
	done
}

# Send multiple results atomically
# Arguments:
#   1+: Multiple "test_name:status:duration:details" entries
# Returns:
#   0 on success
#######################################
plugin_io_batch_results() {
	local entry
	for entry in "$@"; do
		local test_name status duration details
		IFS=':' read -r test_name status duration details <<<"$entry"
		plugin_io_result "$test_name" "$status" "$duration" "$details"
	done
}

#######################################
# Plugin IO API - Validation Helpers
#######################################

# Validate test name format
# Arguments:
#   1: Test name
# Returns:
#   0 if valid, 1 if invalid
#######################################
plugin_io_validate_test_name() {
	local test_name="$1"

	# Must not be empty
	[[ -n "$test_name" ]] || return 1

	# Must not contain control characters
	[[ ! "$test_name" =~ [[:cntrl:]] ]] || return 1

	# Must not contain colon (used as delimiter)
	[[ ! "$test_name" =~ : ]] || return 1

	return 0
}

# Validate status value
# Arguments:
#   1: Status value
#   2: Type (progress|result)
# Returns:
#   0 if valid, 1 if invalid
#######################################
plugin_io_validate_status() {
	local status="$1"
	local type="$2"

	case "$type" in
	progress)
		case "$status" in
		running | passed | failed | skipped | error) return 0 ;;
		*) return 1 ;;
		esac
		;;
	result)
		case "$status" in
		PASSED | FAILED | ERROR | SKIPPED) return 0 ;;
		*) return 1 ;;
		esac
		;;
	*)
		return 1
		;;
	esac
}

#######################################
# Plugin IO API - Convenience Functions
#######################################

# Report test start
# Arguments:
#   1: Test name
# Returns:
#   0 on success
#######################################
plugin_io_test_start() {
	local test_name="$1"
	plugin_io_progress "$test_name" "running" "."
}

# Report test success
# Arguments:
#   1: Test name
#   2: Duration in milliseconds
#   3: Details (optional)
# Returns:
#   0 on success
#######################################
plugin_io_test_success() {
	local test_name="$1"
	local duration="$2"
	local details="${3:-}"

	plugin_io_progress "$test_name" "passed" "."
	plugin_io_result "$test_name" "PASSED" "$duration" "$details"
}

# Report test failure
# Arguments:
#   1: Test name
#   2: Duration in milliseconds
#   3: Error details
# Returns:
#   0 on success
#######################################
plugin_io_test_failure() {
	local test_name="$1"
	local duration="$2"
	local error_details="$3"

	plugin_io_progress "$test_name" "failed" "F"
	plugin_io_result "$test_name" "FAILED" "$duration" "$error_details"
	plugin_io_error "$test_name" "$error_details"
}

# Report test error
# Arguments:
#   1: Test name
#   2: Duration in milliseconds (optional, defaults to 0)
#   3: Error details
# Returns:
#   0 on success
#######################################
plugin_io_test_error() {
	local test_name="$1"
	local duration="${2:-0}"
	local error_details="$3"

	plugin_io_progress "$test_name" "error" "E"
	plugin_io_result "$test_name" "ERROR" "$duration" "$error_details"
	plugin_io_error "$test_name" "$error_details"
}

# Report test skip
# Arguments:
#   1: Test name
#   2: Reason for skipping
# Returns:
#   0 on success
#######################################
plugin_io_test_skip() {
	local test_name="$1"
	local reason="${2:-Skipped}"

	plugin_io_progress "$test_name" "skipped" "S"
	plugin_io_result "$test_name" "SKIPPED" "0" "$reason"
}

# Export all plugin IO API functions
export -f plugin_io_progress plugin_io_result plugin_io_error
export -f plugin_io_print plugin_io_error_print plugin_io_newline
export -f plugin_io_available plugin_mutex_available plugin_io_status
export -f plugin_io_batch_progress plugin_io_batch_results
export -f plugin_io_validate_test_name plugin_io_validate_status
export -f plugin_io_test_start plugin_io_test_success plugin_io_test_failure
export -f plugin_io_test_error plugin_io_test_skip
