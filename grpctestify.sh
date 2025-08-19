#!/bin/bash

VERSION="v0.0.14"

# Color configuration
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"
CHECK="✅"
CROSS="❌"
INFO="ℹ️"
ALERT="⚠️"
DIVIDER="─"

# Parse arguments
NO_COLOR=0
VERBOSE=0
UPDATE=0
BASH_COMPLETION=0
ZSH_COMPLETION=0
while [[ $# -gt 0 ]]; do
	case "$1" in
	--no-color)
		NO_COLOR=1
		shift
		;;
	--verbose)
		VERBOSE=1
		shift
		;;
	--version)
		printf "%s\n" "$VERSION"
		exit 0
		;;
	--update)
		UPDATE=1
		shift
		;;
    --bash-completion)
        BASH_COMPLETION=1
        shift
        ;;
    --zsh-completion)
        ZSH_COMPLETION=1
        shift
        ;;
	-h | --help)
		HELP=1
		shift
		;;
	*) break ;;
	esac
done

# Disable colors if requested
if [[ "$NO_COLOR" -eq 1 ]]; then
	RED=""
	GREEN=""
	YELLOW=""
	BLUE=""
	NC=""
	CHECK="OK"
	CROSS="ERR"
	INFO="INF"
	ALERT="WARN"
fi

log() {
	local level="$1"
	local message="$2"

	# Skip debug messages if not in verbose mode
	if [[ "$level" == "debug" && "$VERBOSE" -eq 0 ]]; then
		return 0
	fi

	case "$level" in
	debug)
		[[ "$NO_COLOR" -eq 1 ]] && printf "[DBG] %s\n" "$message" || printf "${YELLOW}🔍${NC} %s\n" "$message"
		;;
	info)
		[[ "$NO_COLOR" -eq 1 ]] && printf "[%s] %s\n" "$INFO" "$message" || printf "${BLUE}%s${NC} %s\n" "$INFO" "$message"
		;;
	success)
		[[ "$NO_COLOR" -eq 1 ]] && printf " %s  %s\n" "$CHECK" "$message" || printf "${GREEN}%s${NC} %s\n" "$CHECK" "$message"
		;;
	warn)
		[[ "$NO_COLOR" -eq 1 ]] && printf "[%s] %s\n" "$ALERT" "$message" || printf "${YELLOW}%s${NC} %s\n" "$ALERT" "$message"
		;;
	error)
		[[ "$NO_COLOR" -eq 1 ]] && printf " %s  %s\n" "$CROSS" "$message" >&2 || printf "${RED}%s${NC} %s\n" "$CROSS" "$message" >&2
		;;
	section)
		[[ "$NO_COLOR" -eq 1 ]] && printf "\n---[ %s ]---\n" "$message" || printf "\n${YELLOW} %s%s%s[ %s ]%s%s%s${NC}\n" "$DIVIDER" "$DIVIDER" "$DIVIDER" "$message" "$DIVIDER" "$DIVIDER" "$DIVIDER"
		;;
	*)
		# Fallback for unknown log levels
		printf "${RED}???${NC} [%s] %s\n" "$level" "$message" >&2
		return 1
		;;
	esac
}

check_dependencies() {
	for cmd in grpcurl jq grep awk date basename find mktemp rm; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			log error "Missing dependency: $cmd"
			exit 1
		fi
	done
}

display_help() {
	printf "${BLUE}▶${NC} ${YELLOW}gRPC Testify $VERSION${NC} - gRPC Server Testing Tool\n\n"
	printf "${INFO} Usage: $0 [options] <test_file_or_directory>\n\n"
	printf "${INFO} Options:\n"
	printf "   --no-color   Disable colored output\n"
	printf "   --verbose    Enable verbose debug output\n"
	printf "   --version    Show version information\n"
	printf "   --update     Check for updates and update the script\n"
	printf "   -h, --help   Show this help message\n\n"
	printf "${INFO} Requirements:\n"
	printf "   ${CHECK} grpcurl (https://github.com/fullstorydev/grpcurl)\n"
	printf "   ${CHECK} jq (https://stedolan.github.io/jq/)\n\n"
	printf "${INFO} Test File Format:\n"
	printf "   --- ADDRESS ---\n"
	printf "   localhost:4770\n\n"
	printf "   --- ENDPOINT ---\n"
	printf "   helloworld.Greeter/SayHello\n\n"
	printf "   --- REQUEST_HEADERS --- (optional)\n"
	printf "   x-user: test\n"
	printf "   x-token: 123\n\n"
	printf "   # Note: 'HEADERS' is deprecated; use 'REQUEST_HEADERS' instead.\n\n"
	printf "   --- RESPONSE_HEADERS --- (optional)\n"
	printf "   content-type: application/grpc\n"
	printf "   x-response-id: abc123\n\n"
	printf "   --- RESPONSE_TRAILERS --- (optional)\n"
	printf "   grpc-status: 0\n"
	printf "   x-trailer-id: def456\n\n"
	printf "   --- REQUEST --- (optional)\n"
	printf "   {\"name\": \"test\"}\n\n"
	printf "   --- RESPONSE --- (optional)\n"
	printf "   {\"message\": \"Hello test\"}\n\n"
	printf "   --- ERROR --- (optional)\n"
	printf "   {\"code\": 16, \"message\": \"user not found\"}\n\n"
	printf "${INFO} Examples:\n"
	printf "   $0 my_test.gctf\n"
	printf "   $0 --verbose tests/\n"
}

validate_address() {
	if ! echo "$1" | grep -qE '^[a-zA-Z0-9.-]+:[0-9]+$'; then
		log error "Invalid ADDRESS format: $1"
		return 1
	fi
}

validate_json() {
	if ! echo "$1" | jq empty 2>/dev/null; then
		log error "Invalid JSON in $2 section"
		return 1
	fi
}

run_test() {
	local TEST_FILE=$1
	local TEST_NAME=$(basename "$TEST_FILE" .gctf)

	log section "Test: $TEST_NAME"

	if [[ ! -f "$TEST_FILE" ]]; then
		log error "File not found: $TEST_FILE"
		return 1
	fi

	extract_section() {
		awk -v sec="$1" '
		function process_line(line) {
			in_str = 0
			escaped = 0
			res = ""
			for (i = 1; i <= length(line); i++) {
				c = substr(line, i, 1)
				if (escaped) {
					res = res c
					escaped = 0
				} else if (c == "\\") {
					res = res c
					escaped = 1
				} else if (c == "\"") {
					res = res c
					in_str = !in_str
				} else if (c == "#" && !in_str) {
					break
				} else {
					res = res c
				}
			}
			return res
		}
		$0 ~ /^[[:space:]]*#/ { next } # skip comment lines
		$0 ~ "^[[:space:]]*---[[:space:]]*" sec "[[:space:]]*---" { 
			found=1 
			next 
		} 
		/^[[:space:]]*---/ { 
			found=0 
		} 
		found {
            # Process comments inside JSON strings
			processed = process_line($0)
			gsub(/[[:space:]]+$/, "", processed)
			printf "%s\n", processed
		}' "$TEST_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
	}

	ENDPOINT=$(extract_section "ENDPOINT")
	RESPONSE=$(extract_section "RESPONSE")
	ERROR=$(extract_section "ERROR")
	HEADERS=$(extract_section "HEADERS")
	REQUEST_HEADERS=$(extract_section "REQUEST_HEADERS")
	RESPONSE_HEADERS=$(extract_section "RESPONSE_HEADERS")
	RESPONSE_TRAILERS=$(extract_section "RESPONSE_TRAILERS")

	if [[ -z "$RESPONSE" && -z "$ERROR" ]]; then
		log error "At least one of RESPONSE or ERROR sections must be present in $TEST_FILE"
		return 1
	fi

	for section in ENDPOINT; do
		if [[ -z "$(extract_section "$section")" ]]; then
			log error "Missing $section section in $TEST_FILE"
			return 1
		fi
	done

	ADDRESS=$(extract_section "ADDRESS" | xargs)
	ADDRESS=${ADDRESS:-${DEFAULT_ADDRESS:-localhost:4770}}
	REQUEST=$(extract_section "REQUEST")

	log info "Configuration:"
	log info "  ADDRESS: $ADDRESS"
	log info "  ENDPOINT: $ENDPOINT"

	# Map deprecated HEADERS to REQUEST_HEADERS if needed
	if [[ -n "$HEADERS" && -z "$REQUEST_HEADERS" ]]; then
		log warn "HEADERS is deprecated; use REQUEST_HEADERS instead"
		REQUEST_HEADERS="$HEADERS"
	elif [[ -n "$HEADERS" && -n "$REQUEST_HEADERS" ]]; then
		log warn "HEADERS is deprecated and ignored because REQUEST_HEADERS is present"
	fi

	[[ -n "$REQUEST_HEADERS" ]] && log info "  REQUEST_HEADERS: $REQUEST_HEADERS"
	[[ -n "$RESPONSE_HEADERS" ]] && log info "  RESPONSE_HEADERS: $RESPONSE_HEADERS"
	[[ -n "$RESPONSE_TRAILERS" ]] && log info "  RESPONSE_TRAILERS: $RESPONSE_TRAILERS"
	[[ -n "$REQUEST" ]] && log info "  REQUEST: $(echo $REQUEST | jq -c .)" || log info "  REQUEST: EMPTY"
	[[ -n "$RESPONSE" ]] && log info "  RESPONSE: $(echo $RESPONSE | jq -c .)"
	[[ -n "$ERROR" ]] && log info "  ERROR: $(echo $ERROR | jq -c .)"

	if [[ -n "$REQUEST" ]]; then
		validate_json "$REQUEST" "REQUEST" || return 1
	fi

	if [[ -n "$RESPONSE" ]]; then
		validate_json "$RESPONSE" "RESPONSE" || return 1
	fi

	if [[ -n "$ERROR" ]]; then
		validate_json "$ERROR" "ERROR" || return 1
	fi

	validate_address "$ADDRESS" || return 1

	REQUEST_TMP=""
	if [[ -n "$REQUEST" ]]; then
		REQUEST_TMP=$(mktemp)
		echo "$REQUEST" | jq -c . >"$REQUEST_TMP"
		log debug "Request file: $REQUEST_TMP"
		[[ "$VERBOSE" -eq 1 ]] && log debug "Request content: $(cat "$REQUEST_TMP")"
	fi

	log info "Executing gRPC request to $ADDRESS..."

	# Initialize grpcurl_flags as an array
	grpcurl_flags=(-plaintext)
	
	# Add verbose flag only if we need to capture response headers or trailers
	[[ -n "$RESPONSE_HEADERS" || -n "$RESPONSE_TRAILERS" ]] && grpcurl_flags+=(-v)

	# Add request headers if present
	if [[ -n "$REQUEST_HEADERS" ]]; then
		while IFS= read -r header; do
			header=$(echo "$header" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
			if [[ -n "$header" ]]; then
				grpcurl_flags+=(-H "$header")
			fi
		done <<<"$REQUEST_HEADERS"
	fi

	# Add format-error flag if ERROR section exists
	[[ -n "$ERROR" ]] && grpcurl_flags+=(-format-error)

	# Execute gRPC request
	temp_grpc_output=$(mktemp)
	temp_time=$(mktemp)

	if [[ -n "$REQUEST_TMP" ]]; then
		flags_str=$(printf "%s " "${grpcurl_flags[@]}")
		log debug "$ grpcurl ${flags_str}-d @ \"$ADDRESS\" \"$ENDPOINT\" < $REQUEST_TMP"
		# shellcheck disable=SC2086
		(
			TIMEFORMAT='%R'
			{ time grpcurl "${grpcurl_flags[@]}" -d @ "$ADDRESS" "$ENDPOINT" <"$REQUEST_TMP" >"$temp_grpc_output" 2>&1; } 2>"$temp_time"
		)
	else
		flags_str=$(printf "%s " "${grpcurl_flags[@]}")
		log debug "$ grpcurl ${flags_str}\"$ADDRESS\" \"$ENDPOINT\""
		# shellcheck disable=SC2086
		(
			TIMEFORMAT='%R'
			{ time grpcurl "${grpcurl_flags[@]}" "$ADDRESS" "$ENDPOINT" >"$temp_grpc_output" 2>&1; } 2>"$temp_time"
		)
	fi

	GRPC_STATUS=$?

	RESPONSE_OUTPUT=$(cat "$temp_grpc_output")
	execution_time=$(awk '{printf "%.0f", $1 * 1000}' "$temp_time")

	# Extract response headers and trailers from verbose output
	ACTUAL_RESPONSE_HEADERS=""
	ACTUAL_RESPONSE_TRAILERS=""
	# Always extract headers and trailers if verbose output is available (when -v flag was used)
	if [[ -n "$RESPONSE_HEADERS" || -n "$RESPONSE_TRAILERS" ]]; then
		# Extract headers section from verbose output
		if [[ -n "$RESPONSE_HEADERS" ]]; then
			ACTUAL_RESPONSE_HEADERS=$(echo "$RESPONSE_OUTPUT" | awk '
			/^Response headers received:/ {
				in_headers = 1
				next
			}
			/^Response contents:/ {
				in_headers = 0
				next
			}
			/^Response trailers received:/ {
				in_headers = 0
				next
			}
			/^Sent [0-9]+ request/ {
				in_headers = 0
				next
			}
			in_headers && /^[[:space:]]*[a-zA-Z0-9_-]+:/ {
				gsub(/^[[:space:]]+/, "")
				gsub(/[[:space:]]+$/, "")
				if (length($0) > 0) {
					print $0
				}
			}
			' | sort)
		fi
		
		# Extract trailers section from verbose output
		if [[ -n "$RESPONSE_TRAILERS" ]]; then
			ACTUAL_RESPONSE_TRAILERS=$(echo "$RESPONSE_OUTPUT" | awk '
			/^Response trailers received:/ {
				in_trailers = 1
				next
			}
			/^Sent [0-9]+ request/ {
				in_trailers = 0
				next
			}
			/^[[:space:]]*---/ {
				in_trailers = 0
				next
			}
			in_trailers && /^[[:space:]]*[a-zA-Z0-9_-]+:/ {
				gsub(/^[[:space:]]+/, "")
				gsub(/[[:space:]]+$/, "")
				if (length($0) > 0) {
					print $0
				}
			}
			' | sort)
		fi
	fi

	[[ -n "$temp_grpc_output" ]] && rm -f "$temp_grpc_output"
	[[ -n "$temp_time" ]] && rm -f "$temp_time"
	[[ -n "$REQUEST_TMP" ]] && rm -f "$REQUEST_TMP"

	# Handle response expectations
	if [[ -n "$ERROR" ]]; then
		EXPECTED=$(echo "$ERROR" | jq --sort-keys .)
		if [[ $GRPC_STATUS -eq 0 ]]; then
			log error "Expected gRPC error but request succeeded"
			return 1
		fi
	else
		# Check if RESPONSE contains multiple JSON objects (not in array format)
		response_json_count=$(echo "$RESPONSE" | jq -s 'length' 2>/dev/null || echo "1")
		
		if [[ "$response_json_count" -gt 1 ]]; then
			# Multiple JSON objects expected, convert to array for comparison
			EXPECTED=$(echo "$RESPONSE" | jq -s --sort-keys .)
		else
			EXPECTED=$(echo "$RESPONSE" | jq --sort-keys .)
		fi
		
		if [[ $GRPC_STATUS -ne 0 ]]; then
			log error "gRPC request failed with status $GRPC_STATUS"
			log error "Response: $RESPONSE_OUTPUT"
			return 1
		fi
	fi

	# Build ACTUAL response, considering verbose output when RESPONSE_HEADERS or RESPONSE_TRAILERS are requested
	if [[ -n "$RESPONSE_HEADERS" || -n "$RESPONSE_TRAILERS" ]]; then
		# Extract all JSON response blocks from verbose output
		response_blocks=$(echo "$RESPONSE_OUTPUT" | awk '
		/^Response contents:/ {
			in_resp = 1
			next
		}
		/^Response (headers|trailers) received:/ {
			in_resp = 0
			next
		}
		/^Sent [0-9]+ request/ {
			in_resp = 0
			next
		}
		in_resp { print }
		')
		
		# If expected is an array, assemble all blocks into array; else take first
		if echo "$RESPONSE" | jq -e 'type=="array"' >/dev/null 2>&1; then
			ACTUAL=$(echo "$response_blocks" | jq -s --sort-keys . 2>/dev/null || echo "$RESPONSE_OUTPUT")
		else
			ACTUAL=$(echo "$response_blocks" | jq -s '.[0]' 2>/dev/null | jq --sort-keys . 2>/dev/null || echo "$RESPONSE_OUTPUT")
		fi
	else
		# For non-verbose output, handle stream responses properly
		# Check if RESPONSE contains multiple JSON objects (not in array format)
		response_json_count=$(echo "$RESPONSE" | jq -s 'length' 2>/dev/null || echo "1")
		actual_json_count=$(echo "$RESPONSE_OUTPUT" | jq -s 'length' 2>/dev/null || echo "1")
		
		if [[ "$response_json_count" -gt 1 ]] || [[ "$actual_json_count" -gt 1 ]]; then
			# Multiple JSON objects expected or received, collect all
			ACTUAL=$(echo "$RESPONSE_OUTPUT" | jq -s --sort-keys . 2>/dev/null || echo "$RESPONSE_OUTPUT")
		else
			# Single JSON object expected
			ACTUAL=$(echo "$RESPONSE_OUTPUT" | jq --sort-keys . 2>/dev/null || echo "$RESPONSE_OUTPUT")
		fi
	fi

	log debug "Expected response: $EXPECTED"
	log debug "Actual response: $ACTUAL"

	# Validate response headers if specified
	if [[ -n "$RESPONSE_HEADERS" ]]; then
		log debug "Expected headers: $RESPONSE_HEADERS"
		log debug "Actual headers: $ACTUAL_RESPONSE_HEADERS"
		
		# Convert expected headers to sorted format for comparison
		EXPECTED_HEADERS=$(echo "$RESPONSE_HEADERS" | sort)
		
		if [[ "$EXPECTED_HEADERS" == "$ACTUAL_RESPONSE_HEADERS" ]]; then
			log success "Headers validation passed"
		else
			log error "Headers validation failed"
			log error "--- Expected Headers ---"
			printf "%s\n" "$EXPECTED_HEADERS"
			log error "+++ Actual Headers +++"
			printf "%s\n" "$ACTUAL_RESPONSE_HEADERS"
			return 1
		fi
	fi

	# Validate response trailers if specified
	if [[ -n "$RESPONSE_TRAILERS" ]]; then
		log debug "Expected trailers: $RESPONSE_TRAILERS"
		log debug "Actual trailers: $ACTUAL_RESPONSE_TRAILERS"
		
		# Convert expected trailers to sorted format for comparison
		EXPECTED_TRAILERS=$(echo "$RESPONSE_TRAILERS" | sort)
		
		if [[ "$EXPECTED_TRAILERS" == "$ACTUAL_RESPONSE_TRAILERS" ]]; then
			log success "Trailers validation passed"
		else
			log error "Trailers validation failed"
			log error "--- Expected Trailers ---"
			printf "%s\n" "$EXPECTED_TRAILERS"
			log error "+++ Actual Trailers +++"
			printf "%s\n" "$ACTUAL_RESPONSE_TRAILERS"
			return 1
		fi
	fi

	if [[ "$EXPECTED" == "$ACTUAL" ]]; then
		log success "TEST PASSED: $TEST_NAME ($execution_time ms)"
		return 0
	else
		log error "TEST FAILED: $TEST_NAME ($execution_time ms)"
		log error "--- Expected ---"
		printf "%s\n" "$EXPECTED"
		log error "+++ Actual +++"
		printf "%s\n" "$ACTUAL"
		return 1
	fi
}

update_script() {
	log section "Update Check"
	check_dependencies

	current_version=${VERSION#v}
	current_version_parts=(${current_version//./ })

	log info "Checking for updates..."
	latest_release=$(curl -s https://api.github.com/repos/gripmock/grpctestify/releases/latest)
	latest_version=$(echo "$latest_release" | jq -r '.tag_name' | sed 's/^v//')
	latest_version_parts=(${latest_version//./ })

	log info "Current version: $VERSION"
	log info "Latest version: v$latest_version"

	compare_versions() {
		local current=("${!1}")
		local latest=("${!2}")
		for ((i = 0; i < ${#current[@]}; i++)); do
			if [[ ${current[i]} -lt ${latest[i]} ]]; then
				return 1
			elif [[ ${current[i]} -gt ${latest[i]} ]]; then
				return 2
			fi
		done
		return 0
	}

	compare_versions current_version_parts[@] latest_version_parts[@]
	result=$?

	case $result in
	1)
		log info "New version available. Updating..."
		script_url=$(echo "$latest_release" | jq -r '.assets[] | select(.name == "grpctestify.sh").browser_download_url')
		script_url=${script_url:-"https://raw.githubusercontent.com/gripmock/grpctestify/v${latest_version}/grpctestify.sh"}
		checksum_url=$(echo "$latest_release" | jq -r '.assets[] | select(.name == "checksums.txt").browser_download_url')

		temp_file=$(mktemp)
		checksum_file=$(mktemp)

		# Download script and checksum
		if ! curl -sSL --output "$temp_file" "$script_url"; then
			log error "Failed to download script"
			rm -f "$temp_file" "$checksum_file"
			exit 1
		fi

		if [[ -n "$checksum_url" ]]; then
			if ! curl -sSL --output "$checksum_file" "$checksum_url"; then
				log warn "Failed to download checksum file. Proceeding without verification..."
				rm -f "$checksum_file"
			else
				expected_hash=$(grep "grpctestify.sh" "$checksum_file" | awk '{print $1}')
				actual_hash=$(sha256sum "$temp_file" | awk '{print $1}')

				if [[ "$expected_hash" != "$actual_hash" ]]; then
					log error "Checksum verification failed! Aborting update."
					rm -f "$temp_file" "$checksum_file"
					exit 1
				fi
				log success "Checksum verification passed"
			fi
		else
			log warn "No checksum file found. Proceeding without verification..."
		fi

		chmod +x "$temp_file"
		script_path=$(readlink -f "$0")
		if [[ -w "$script_path" ]]; then
			mv "$temp_file" "$script_path"
			log success "Update successful. Restart the script to use the new version."
		else
			sudo mv "$temp_file" "$script_path"
			log success "Update successful with sudo. Restart the script."
		fi
		rm -f "$checksum_file"
		;;
	0)
		log success "Already up to date."
		;;
	2)
		log info "Current version is newer than the latest release. You might be using a development version."
		;;
	esac
}

# Function to generate bash completion
generate_bash_completion() {
    cat <<EOF
_grpctestify() {
    local cur prev opts
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    opts="--help --version --update --no-color --verbose"

    if [[ \${cur} == -* ]]; then
        COMPREPLY=( \$(compgen -W "\${opts}" -- \${cur}) )
        return 0
    fi
}
complete -F _grpctestify grpctestify
EOF
}

# Function to generate zsh completion
generate_zsh_completion() {
    cat <<EOF
#compdef grpctestify

_grpctestify() {
    local state line
    typeset -A opt_args

    _arguments \\
        '--help[Show help message]' \\
        '--version[Show version information]' \\
        '--update[Check for updates and update the script]' \\
        '--no-color[Disable colored output]' \\
        '--verbose[Enable verbose debug output]' \\
        ':test_file:_files'
}

_grpctestify "\$@"
EOF
}

# Main execution
if [[ "$BASH_COMPLETION" -eq 1 ]]; then
    generate_bash_completion
    exit 0
elif [[ "$ZSH_COMPLETION" -eq 1 ]]; then
    generate_zsh_completion
    exit 0
fi

# Main execution
check_dependencies

if [[ "$UPDATE" -eq 1 ]]; then
	update_script
	exit 0
fi

if [[ -n "$HELP" || $# -eq 0 ]]; then
	display_help
	exit 0
fi

TEST_PATH=$1

log section "gRPC Testify $VERSION"
log info "Processing: $TEST_PATH"

if [[ -d "$TEST_PATH" ]]; then
	log info "Running in directory mode"
	find "$TEST_PATH" -type f -name "*.gctf" | while read -r file; do
		run_test "$file" || exit 1
		log info "Completed: $(basename "$file" .gctf)"
	done
else
	run_test "$TEST_PATH"
	exit $?
fi
