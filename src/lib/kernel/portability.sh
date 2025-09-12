#!/bin/bash

# portability.sh - Cross-platform compatibility layer
# Provides unified interface for platform-specific operations

#######################################
# Detect current operating system
# Returns:
#   0 on success
# Globals:
#   OS_TYPE - linux, darwin, freebsd, openbsd, solaris, windows
#   OS_DISTRO - ubuntu, centos, alpine, etc. (Linux only)
#######################################
detect_os() {
	if [[ -n "${OS_TYPE:-}" ]]; then
		return 0 # Already detected
	fi

	case "$(uname -s 2>/dev/null)" in
	Linux*)
		export OS_TYPE="linux"
		# Detect Linux distro
		if [[ -f /etc/os-release ]]; then
			export OS_DISTRO=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
		elif [[ -f /etc/redhat-release ]]; then
			export OS_DISTRO="centos"
		elif [[ -f /etc/debian_version ]]; then
			export OS_DISTRO="debian"
		else
			export OS_DISTRO="unknown"
		fi
		;;
	Darwin*)
		export OS_TYPE="darwin"
		export OS_DISTRO="macos"
		;;
	FreeBSD*)
		export OS_TYPE="freebsd"
		export OS_DISTRO="freebsd"
		;;
	OpenBSD*)
		export OS_TYPE="openbsd"
		export OS_DISTRO="openbsd"
		;;
	SunOS*)
		export OS_TYPE="solaris"
		export OS_DISTRO="solaris"
		;;
	CYGWIN* | MINGW* | MSYS*)
		export OS_TYPE="windows"
		export OS_DISTRO="cygwin"
		;;
	*)
		export OS_TYPE="unknown"
		export OS_DISTRO="unknown"
		;;
	esac
}

#######################################
# Cross-platform timeout function
# Arguments:
#   1: timeout_seconds - timeout in seconds
#   2+: command and arguments
# Returns: Exit code of the command or 124 for timeout
#######################################
portable_timeout() {
	local timeout_seconds="$1"
	shift

	if [[ ! "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -le 0 ]]; then
		log_error "portable_timeout: invalid timeout value: $timeout_seconds"
		return 1
	fi

	# Use cached timeout utility if available
	if is_timeout_available; then
		local timeout_cmd
		timeout_cmd=$(get_timeout_command)
		"$timeout_cmd" "$timeout_seconds" "$@"
		return $?
	fi

	# Fallback to pure shell implementation
	local cmd_pid timeout_pid

	# Start command in background
	"$@" &
	cmd_pid=$!

	# Start timeout killer in background
	(
		sleep "$timeout_seconds"
		if kill -0 "$cmd_pid" 2>/dev/null; then
			kill -TERM "$cmd_pid" 2>/dev/null
			sleep 1
			kill -KILL "$cmd_pid" 2>/dev/null
		fi
	) &
	timeout_pid=$!

	# Wait for command to complete
	local exit_code
	if wait "$cmd_pid" 2>/dev/null; then
		exit_code=$?
		kill "$timeout_pid" 2>/dev/null
		return $exit_code
	else
		kill "$timeout_pid" 2>/dev/null
		return 124 # Timeout exit code
	fi
}

#######################################
# Cross-platform CPU count detection
# Returns:
#   Number of CPU cores available
#######################################
portable_cpu_count() {
	local cpu_count

	# Method 1: Native shell detection (preferred - Python-free)
	if is_utility_available "native_cpu_count"; then
		cpu_count=$(native_cpu_count)
		if [[ -n "$cpu_count" && "$cpu_count" -gt 0 ]]; then
			echo "$cpu_count"
			return 0
		fi
	fi

	# Detect OS for system-specific methods
	detect_os

	case "$OS_TYPE" in
	linux)
		# Method 2: nproc (modern Linux)
		if is_utility_available "nproc"; then
			cpu_count=$(nproc 2>/dev/null)
			if [[ -n "$cpu_count" && "$cpu_count" -gt 0 ]]; then
				echo "$cpu_count"
				return 0
			fi
		fi
		;;

	darwin | freebsd | openbsd)
		# Method 3: sysctl (BSD systems including macOS)
		if is_utility_available "sysctl"; then
			cpu_count=$(sysctl -n hw.ncpu 2>/dev/null)
			if [[ -n "$cpu_count" && "$cpu_count" -gt 0 ]]; then
				echo "$cpu_count"
				return 0
			fi
		fi
		;;

	solaris)
		# Solaris psrinfo
		if is_utility_available "psrinfo"; then
			cpu_count=$(psrinfo | wc -l 2>/dev/null)
			if [[ -n "$cpu_count" && "$cpu_count" -gt 0 ]]; then
				echo "$cpu_count"
				return 0
			fi
		fi
		;;

	windows)
		# Windows CYGWIN/MINGW
		if [[ -n "${NUMBER_OF_PROCESSORS:-}" ]]; then
			echo "${NUMBER_OF_PROCESSORS}"
			return 0
		fi
		;;
	esac

	# Final fallback: reasonable default
	echo "4"
}

#######################################
# Cross-platform millisecond timestamp
# Returns:
#   Current timestamp in milliseconds
#######################################
portable_timestamp_ms() {
	# Method 1: Native shell implementation (preferred - Python-free)
	if is_utility_available "native_timestamp_ms"; then
		native_timestamp_ms
		return 0
	fi

	# Method 2: GNU date with nanoseconds (Linux)
	if date +%s%3N >/dev/null 2>&1; then
		date +%s%3N
		return 0
	fi

	# Method 3: Enhanced fallback with pseudo-milliseconds (fully native)
	local seconds subseconds
	seconds=$(date +%s)
	# Generate deterministic pseudo-random subseconds based on PID and current time
	subseconds=$(((RANDOM + $$ + seconds) % 1000))
	printf "%d%03d" "$seconds" "$subseconds"
}

#######################################
# POSIX-compatible test for bash features
# Returns:
#   0 if running in bash, 1 if in sh/dash/etc
#######################################
is_bash() {
	[[ -n "${BASH_VERSION:-}" ]]
}

#######################################
# POSIX-compatible variable assignment
# Arguments:
#   1: variable_name
#   2: value
#######################################
portable_assign() {
	local var_name="$1"
	local value="$2"

	if is_bash; then
		# Use bash dynamic variable assignment
		printf -v "$var_name" '%s' "$value"
	else
		# SECURE: Use declare instead of eval
		declare -g "$var_name=$value"
	fi
}

#######################################
# Cross-platform sed in-place editing
# Arguments:
#   1: sed_expression
#   2: file_path
#######################################
portable_sed_inplace() {
	local sed_expr="$1"
	local file_path="$2"

	detect_os

	case "$OS_TYPE" in
	darwin)
		# macOS sed requires -i with backup suffix
		sed -i '' "$sed_expr" "$file_path"
		;;
	*)
		# GNU sed (Linux) and most others
		sed -i "$sed_expr" "$file_path"
		;;
	esac
}

#######################################
# Export all functions for use by other modules
#######################################
export -f detect_os portable_timeout portable_cpu_count portable_timestamp_ms
export -f is_bash portable_assign portable_sed_inplace
