#!/bin/bash

VERSION="v0.0.1"

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
	ALERT="!"
fi

log() {
	if [[ "$VERBOSE" -eq 0 && "$1" == "debug" ]]; then
		return 0
	fi
	case "$1" in
	debug) [[ "$NO_COLOR" -eq 1 ]] && printf "[DBG] %s\n" "$2" || printf "${YELLOW}🔍${NC} %s\n" "$2" ;;
	info) [[ "$NO_COLOR" -eq 1 ]] && printf "[%s] %s\n" "$INFO" "$2" || printf "${BLUE}%s${NC} %s\n" "$INFO" "$2" ;;
	success) [[ "$NO_COLOR" -eq 1 ]] && printf " %s  %s\n" "$CHECK" "$2" || printf "${GREEN}%s${NC} %s\n" "$CHECK" "$2" ;;
	error) [[ "$NO_COLOR" -eq 1 ]] && printf " %s  %s\n" "$CROSS" "$2" >&2 || printf "${RED}%s${NC} %s\n" "$CROSS" "$2" >&2 ;;
	section) [[ "$NO_COLOR" -eq 1 ]] && printf "\n---[ %s ]---\n" "$2" || printf "\n${YELLOW} %s%s%s[ %s ]%s%s%s${NC}\n" "$DIVIDER" "$DIVIDER" "$DIVIDER" "$2" "$DIVIDER" "$DIVIDER" "$DIVIDER" ;;
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
	printf "   -h, --help   Show this help message\n\n"
	printf "${INFO} Requirements:\n"
	printf "   ${CHECK} grpcurl (https://github.com/fullstorydev/grpcurl)\n"
	printf "   ${CHECK} jq (https://stedolan.github.io/jq/)\n\n"
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
    $0 ~ "^[[:space:]]*---[[:space:]]*" sec "[[:space:]]*---" { 
        found=1; 
        next 
    } 
    /^[[:space:]]*---/ { 
        found=0 
    } 
    found' "$TEST_FILE" | tr -d '\r' | tr '\n' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
	}

	ENDPOINT=$(extract_section "ENDPOINT")
	RESPONSE=$(extract_section "RESPONSE")

	for section in ENDPOINT RESPONSE; do
		if [[ -z "$(extract_section "$section")" ]]; then
			log error "Missing $section section in $TEST_FILE"
			return 1
		fi
	done

	ADDRESS=$(extract_section "ADDRESS" || echo "localhost:4770")
	REQUEST=$(extract_section "REQUEST")

	log info "Configuration:"
	log info "  ADDRESS: $ADDRESS"
	log info "  ENDPOINT: $ENDPOINT"
	[[ -n "$REQUEST" ]] && log info "  REQUEST: $REQUEST" || log info "  REQUEST: EMPTY"

	[[ -n "$REQUEST" ]] && validate_json "$REQUEST" "REQUEST"
	validate_address "$ADDRESS"
	validate_json "$RESPONSE" "RESPONSE"

	REQUEST_TMP=""
	if [[ -n "$REQUEST" ]]; then
		REQUEST_TMP=$(mktemp)
		echo "$REQUEST" | jq -c . >"$REQUEST_TMP"
		log debug "Request file: $REQUEST_TMP"
		if [[ "$VERBOSE" -eq 1 ]]; then
			log debug "Request content: $(cat "$REQUEST_TMP")"
		fi
	fi

	log info "Executing gRPC request to $ADDRESS..."

	if [[ -n "$REQUEST_TMP" ]]; then
		log debug "$ grpcurl -plaintext -d @ \"$ADDRESS\" \"$ENDPOINT\" < $REQUEST_TMP"
		# shellcheck disable=SC2086
		RESPONSE_OUTPUT=$(grpcurl -plaintext -d @ "$ADDRESS" "$ENDPOINT" <$REQUEST_TMP 2>&1)
	else
		log debug "$ grpcurl -plaintext \"$ADDRESS\" \"$ENDPOINT\""
		# shellcheck disable=SC2086
		RESPONSE_OUTPUT=$(grpcurl -plaintext "$ADDRESS" "$ENDPOINT" 2>&1)
	fi

	GRPC_STATUS=$?
	[[ -n "$REQUEST_TMP" ]] && rm -f "$REQUEST_TMP"

	if [[ $GRPC_STATUS -ne 0 ]]; then
		log error "gRPC request failed with status $GRPC_STATUS"
		log error "Response: $RESPONSE_OUTPUT"
		return 1
	fi

	EXPECTED=$(echo "$RESPONSE" | jq --sort-keys .)
	ACTUAL=$(echo "$RESPONSE_OUTPUT" | jq --sort-keys . 2>/dev/null || echo "$RESPONSE_OUTPUT")

	log debug "Expected response: $EXPECTED"
	log debug "Actual response: $ACTUAL"

	if [[ "$EXPECTED" == "$ACTUAL" ]]; then
		log success "TEST PASSED: $TEST_NAME"
		return 0
	else
		log error "TEST FAILED: $TEST_NAME"
		log error "--- Expected ---"
		printf "%s\n" "$EXPECTED"
		log error "+++ Actual +++"
		printf "%s\n" "$ACTUAL"
		return 1
	fi
}

# Main execution
check_dependencies

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
