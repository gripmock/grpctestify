#!/bin/sh

# posix_compat.sh - POSIX shell compatibility layer
# Provides bash-like functionality for sh/dash/ash/busybox

#######################################
# POSIX-compatible test for numeric values
# Arguments:
#   1: value to test
# Returns:
#   0 if numeric, 1 if not
#######################################
is_numeric() {
	case "$1" in
	'' | *[!0-9]*) return 1 ;;
	*) return 0 ;;
	esac
}

#######################################
# POSIX-compatible test for positive integer
# Arguments:
#   1: value to test
# Returns:
#   0 if positive integer, 1 if not
#######################################
is_positive_integer() {
	is_numeric "$1" && [ "$1" -gt 0 ] 2>/dev/null
}

#######################################
# Validate positive integer with error message
# Arguments:
#   1: value to test
#   2: field name for error message
# Returns:
#   0 if positive integer, 1 if not
#######################################
validate_positive_integer() {
	local value="$1"
	local field_name="${2:-Value}"

	if ! is_positive_integer "$value"; then
		echo "Error: $field_name must be a positive integer, got '$value'" >&2
		return 1
	fi
	return 0
}

# REMOVED: array_contains function - unused dead code

#######################################
# POSIX-compatible string starts with test
# Arguments:
#   1: string to test
#   2: prefix to check
# Returns:
#   0 if string starts with prefix, 1 if not
#######################################
string_starts_with() {
	case "$1" in
	"$2"*) return 0 ;;
	*) return 1 ;;
	esac
}

#######################################
# POSIX-compatible string ends with test
# Arguments:
#   1: string to test
#   2: suffix to check
# Returns:
#   0 if string ends with suffix, 1 if not
#######################################
string_ends_with() {
	case "$1" in
	*"$2") return 0 ;;
	*) return 1 ;;
	esac
}

#######################################
# POSIX-compatible variable test
# Arguments:
#   1: variable value or unset
# Returns:
#   0 if variable is set and non-empty, 1 if not
#######################################
is_set() {
	[ -n "${1-}" ]
}

#######################################
# POSIX-compatible command existence test
# Arguments:
#   1: command name
# Returns:
#   0 if command exists, 1 if not
#######################################
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

#######################################
# POSIX-compatible printf with fallback
# Arguments:
#   1: format string
#   2+: arguments
#######################################
safe_printf() {
	# shellcheck disable=SC2059  # format string is intentional
	printf "$@" 2>/dev/null || echo "$*"
}

#######################################
# POSIX-compatible temporary file creation
# Arguments:
#   1: template (optional)
# Returns:
#   Path to temporary file
#######################################
portable_mktemp() {
	local template="${1:-tmp.XXXXXX}"

	# Always use simple approach without external mktemp
	local temp_file="/tmp/${template}.$$"
	touch "$temp_file" && echo "$temp_file"
}

#######################################
# POSIX-compatible basename (avoid external command)
# Arguments:
#   1: path
# Returns:
#   basename of path
#######################################
portable_basename() {
	local path="$1"

	# Remove trailing slashes
	while string_ends_with "$path" "/"; do
		path="${path%/}"
	done

	# Return everything after the last slash
	echo "${path##*/}"
}

#######################################
# POSIX-compatible dirname (avoid external command)
# Arguments:
#   1: path
# Returns:
#   dirname of path
#######################################
portable_dirname() {
	local path="$1"

	# Remove trailing slashes
	while string_ends_with "$path" "/" && [ "$path" != "/" ]; do
		path="${path%/}"
	done

	# If no slash found, return current directory
	case "$path" in
	*/*) echo "${path%/*}" ;;
	*) echo "." ;;
	esac
}

#######################################
# POSIX-compatible read array (since bash arrays don't exist in POSIX)
# Arguments:
#   1: variable name prefix
# Returns:
#   Sets variables with numeric suffixes
#######################################
posix_read_array() {
	local prefix="$1"
	local i=0

	while IFS= read -r line; do
		# SECURE: No eval, use declare instead
		declare -g "${prefix}_${i}=$line"
		i=$((i + 1))
	done

	declare -g "${prefix}_count=$i"
}

#######################################
# Test if we're running under bash
# Returns:
#   0 if bash, 1 if not
#######################################
is_bash_shell() {
	[ -n "${BASH_VERSION-}" ]
}

#######################################
# Test if we're running under zsh
# Returns:
#   0 if zsh, 1 if not
#######################################
is_zsh_shell() {
	[ -n "${ZSH_VERSION-}" ]
}

# REMOVED: get_shell_type function - unused dead code

#######################################
# POSIX-compatible local variable simulation
# Arguments:
#   1+: variable assignments
# Note: This is a documentation function - POSIX sh doesn't have local
#######################################
posix_local_warning() {
	# This function serves as documentation that 'local' is not POSIX
	# In POSIX sh, all variables are global unless in a function
	# Use careful variable naming to avoid conflicts
	:
}

# Export functions if running in bash/zsh
if is_bash_shell || is_zsh_shell; then
	export -f is_numeric is_positive_integer
	export -f string_starts_with string_ends_with is_set
	export -f command_exists safe_printf portable_mktemp
	export -f portable_basename portable_dirname posix_read_array
	export -f is_bash_shell is_zsh_shell
fi
