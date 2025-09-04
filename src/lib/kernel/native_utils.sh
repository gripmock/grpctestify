#!/bin/bash

# native_utils.sh - Pure shell implementations without external dependencies
# Replaces Python, Perl, and other external tool dependencies

#######################################
# Enhanced native shell-based JSON validation (Python-free)
# Arguments:
#   1: json_string
# Returns:
#   0 if valid JSON, 1 if invalid
#######################################
validate_json_native() {
	local json_string="$1"

	# Handle empty input
	[ -n "$json_string" ] || return 1

	# Remove leading/trailing whitespace but preserve internal structure
	json_string=$(echo "$json_string" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

	# Enhanced JSON structure validation
	local brace_count=0
	local bracket_count=0
	local paren_count=0
	local in_string=false
	local escape_next=false
	local char_count=0
	local i=0

	# Pre-validation: Must start with valid JSON char
	case "${json_string:0:1}" in
	'{' | '[' | '"' | [0-9] | 't' | 'f' | 'n') ;;
	*) return 1 ;;
	esac

	# Character-by-character validation with safety limit
	local max_iterations=10000
	while [ $i -lt ${#json_string} ] && [ $char_count -lt $max_iterations ]; do
		local char="${json_string:$i:1}"
		char_count=$((char_count + 1))

		# Handle escape sequences
		if [ "$escape_next" = true ]; then
			escape_next=false
			# Validate escape characters
			case "$char" in
			'"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' | 'u') ;;
			*) return 1 ;; # Invalid escape sequence
			esac
		elif [ "$char" = "\\" ]; then
			[ "$in_string" = true ] || return 1 # Backslash only valid in strings
			escape_next=true
		elif [ "$char" = '"' ]; then
			if [ "$in_string" = false ]; then
				in_string=true
			else
				in_string=false
			fi
		elif [ "$in_string" = false ]; then
			# Outside of string - validate structure characters
			case "$char" in
			'{')
				brace_count=$((brace_count + 1))
				;;
			'}')
				brace_count=$((brace_count - 1))
				[ $brace_count -ge 0 ] || return 1
				;;
			'[')
				bracket_count=$((bracket_count + 1))
				;;
			']')
				bracket_count=$((bracket_count - 1))
				[ $bracket_count -ge 0 ] || return 1
				;;
			'(' | ')')
				return 1 # Parentheses not valid in JSON
				;;
			[[:space:]] | ',' | ':')
				# Valid structural characters
				;;
			[0-9] | '.' | '+' | '-' | 'e' | 'E')
				# Valid number characters
				;;
			't' | 'r' | 'u' | 'e' | 'f' | 'a' | 'l' | 's' | 'n')
				# Valid for true, false, null
				;;
			*)
				# Check for control characters (invalid in JSON)
				case "$char" in
				[[:cntrl:]]) return 1 ;;
				esac
				;;
			esac
		fi

		i=$((i + 1))

		# Safety check for infinite loops
		[ $char_count -lt 10000 ] || return 1
	done

	# Final validation
	[ $brace_count -eq 0 ] && [ $bracket_count -eq 0 ] && [ "$in_string" = false ] && [ "$escape_next" = false ]
}

#######################################
# Enhanced native millisecond timestamp (Python-free)
# Returns:
#   Current timestamp in milliseconds with best available precision
#######################################
native_timestamp_ms() {
	local timestamp_base timestamp_ms

	# Method 1: Use date with nanoseconds (GNU date - Linux)
	if timestamp_base=$(date +%s%N 2>/dev/null) && [ ${#timestamp_base} -eq 19 ]; then
		# Convert nanoseconds to milliseconds (remove last 6 digits)
		echo "${timestamp_base%??????}"
		return 0
	fi

	# Method 2: Enhanced precision using multiple entropy sources
	if timestamp_base=$(date +%s 2>/dev/null); then
		local subsec_component=0

		# Try to get subsecond precision from various sources
		if [ -r /proc/uptime ]; then
			# Use system uptime fractional part
			local uptime_frac
			uptime_frac=$(cut -d. -f2 /proc/uptime 2>/dev/null | head -c 3)
			[ -n "$uptime_frac" ] && subsec_component="$uptime_frac"
		elif [ -r /proc/timer_list ]; then
			# Extract timing info from kernel timer list
			local timer_frac
			timer_frac=$(head -20 /proc/timer_list 2>/dev/null | grep -o '[0-9]\{3\}' | head -1)
			[ -n "$timer_frac" ] && subsec_component="$timer_frac"
		elif [ -r /proc/loadavg ]; then
			# Use load average fractional part
			local load_frac
			load_frac=$(cut -d. -f2 /proc/loadavg 2>/dev/null | head -c 3)
			[ -n "$load_frac" ] && subsec_component="$load_frac"
		fi

		# Fallback: Generate deterministic pseudo-milliseconds
		if [ "$subsec_component" = "0" ] || [ -z "$subsec_component" ]; then
			# Use PID, current second, and RANDOM for deterministic but varied subseconds
			subsec_component=$(((RANDOM + $$ + timestamp_base) % 1000))
			subsec_component=$(printf "%03d" "$subsec_component")
		fi

		# Ensure subsec_component is exactly 3 digits
		subsec_component=$(printf "%03d" "${subsec_component:-0}")

		echo "${timestamp_base}${subsec_component}"
		return 0
	fi

	# Method 3: Ultimate fallback
	echo "$(($(date +%s 2>/dev/null || echo $(($(printf "%d" "'$(date)") * 60))) * 1000))"
}

#######################################
# Native CPU count detection without external tools
# Returns:
#   Number of CPU cores
#######################################
native_cpu_count() {
	local cpu_count=0

	# Method 1: /proc/cpuinfo (Linux)
	if [ -f /proc/cpuinfo ]; then
		cpu_count=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null)
		if [ -n "$cpu_count" ] && [ "$cpu_count" -gt 0 ] 2>/dev/null; then
			echo "$cpu_count"
			return 0
		fi
	fi

	# Method 2: /proc/stat (Linux alternative)
	if [ -f /proc/stat ]; then
		cpu_count=$(grep "^cpu[0-9]" /proc/stat 2>/dev/null | wc -l)
		if [ -n "$cpu_count" ] && [ "$cpu_count" -gt 0 ] 2>/dev/null; then
			echo "$cpu_count"
			return 0
		fi
	fi

	# Method 3: /sys/devices/system/cpu (Linux)
	if [ -d /sys/devices/system/cpu ]; then
		cpu_count=$(ls /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null | wc -l)
		if [ -n "$cpu_count" ] && [ "$cpu_count" -gt 0 ] 2>/dev/null; then
			echo "$cpu_count"
			return 0
		fi
	fi

	# Method 4: macOS/BSD sysctl
	if command -v sysctl >/dev/null 2>&1; then
		cpu_count=$(sysctl -n hw.ncpu 2>/dev/null)
		if [ -n "$cpu_count" ] && [ "$cpu_count" -gt 0 ] 2>/dev/null; then
			echo "$cpu_count"
			return 0
		fi
	fi

	# Method 5: Environment variables (Windows/Cygwin)
	if [ -n "${NUMBER_OF_PROCESSORS:-}" ]; then
		echo "${NUMBER_OF_PROCESSORS}"
		return 0
	fi

	# Method 5: Hardware detection via /proc/hardware (some embedded systems)
	if [ -f /proc/hardware ]; then
		cpu_count=$(grep -i "cpu" /proc/hardware 2>/dev/null | wc -l)
		if [ -n "$cpu_count" ] && [ "$cpu_count" -gt 0 ] 2>/dev/null; then
			echo "$cpu_count"
			return 0
		fi
	fi

	# Fallback: reasonable default
	echo "4"
}

#######################################
# Native string manipulation - JSON key extraction
# Arguments:
#   1: json_string
#   2: key_name
# Returns:
#   Value of the key (simplified extraction)
#######################################
extract_json_key_native() {
	local json_string="$1"
	local key_name="$2"

	# Use a more robust approach with grep and sed
	# Look for "key": and extract the value - handle strings with quotes specially
	local value

	# Try to match quoted string values first
	value=$(echo "$json_string" | sed -n "s/.*\"${key_name}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")

	if [ -n "$value" ]; then
		# Found a quoted string value
		echo "$value"
	else
		# Try to match non-quoted values (numbers, booleans, null)
		value=$(echo "$json_string" | sed -n "s/.*\"${key_name}\"[[:space:]]*:[[:space:]]*\([^,}[:space:]]*\).*/\1/p")
		[ -n "$value" ] && echo "$value"
	fi
}

#######################################
# Native alternative to grep -c
# Arguments:
#   1: pattern
#   2: input (via stdin if not provided)
# Returns:
#   Count of matches
#######################################
count_matches_native() {
	local pattern="$1"
	local input="$2"
	local count=0
	local line

	# If no second argument provided, read from stdin with timeout
	if [ $# -eq 1 ]; then
		input=$(timeout 1 cat 2>/dev/null || echo "")
	fi

	# Handle empty input
	[ -z "$input" ] && {
		echo "0"
		return
	}

	# Convert input to lines and count matches
	while IFS= read -r line; do
		case "$line" in
		*"$pattern"*) count=$((count + 1)) ;;
		esac
	done <<<"$input"

	echo "$count"
}

#######################################
# Native alternative to wc -l
# Arguments:
#   1: input (via stdin if not provided)
# Returns:
#   Line count
#######################################
count_lines_native() {
	local input="$1"
	local count=0
	local line

	# If no argument provided, read from stdin with timeout
	if [ $# -eq 0 ]; then
		input=$(timeout 1 cat 2>/dev/null || echo "")
	fi

	# Handle empty input
	[ -z "$input" ] && {
		echo "0"
		return
	}

	# Simple line counting with while loop
	while IFS= read -r line || [ -n "$line" ]; do
		count=$((count + 1))
	done <<<"$input"

	echo "$count"
}

#######################################
# Native UUID generation (simplified)
# Returns:
#   UUID-like string
#######################################
generate_uuid_native() {
	# Generate a UUID-like string using available entropy
	local hex_chars="0123456789abcdef"
	local uuid=""
	local i

	# Use /dev/urandom if available
	if [ -r /dev/urandom ]; then
		# Read 16 bytes and convert to hex
		uuid=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n' | head -c 32)
		if [ ${#uuid} -eq 32 ]; then
			# Format as UUID: 8-4-4-4-12
			echo "${uuid:0:8}-${uuid:8:4}-${uuid:12:4}-${uuid:16:4}-${uuid:20:12}"
			return 0
		fi
	fi

	# Fallback: use RANDOM and current time
	local timestamp=$(date +%s 2>/dev/null || echo $RANDOM)
	local random1=${RANDOM:-123}
	local random2=${RANDOM:-456}
	local random3=${RANDOM:-789}

	printf "%08x-%04x-%04x-%04x-%08x%04x" \
		$timestamp \
		$((random1 % 65536)) \
		$((random2 % 65536)) \
		$((random3 % 65536)) \
		$timestamp \
		$((random1 % 65536))
}

#######################################
# Native check if command exists (alternative to which/command -v)
# Arguments:
#   1: command_name
# Returns:
#   0 if exists, 1 if not
#######################################
command_exists_native() {
	local cmd="$1"

	# Try to find in PATH manually
	local IFS=:
	for dir in $PATH; do
		if [ -x "$dir/$cmd" ]; then
			return 0
		fi
	done

	# Check if it's a builtin
	case "$cmd" in
	echo | printf | test | [ | cd | pwd | exit | return | source | . | :) return 0 ;;
	esac

	return 1
}

# Export functions for use by other modules
export -f validate_json_native native_timestamp_ms native_cpu_count
export -f extract_json_key_native count_matches_native count_lines_native
export -f generate_uuid_native command_exists_native
