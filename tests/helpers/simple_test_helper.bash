#!/bin/bash

# simple_test_helper.bash - Minimal test helper for unit testing
# Only essential functions, no complex module loading

# Set up basic test timeout
export BATS_TEST_TIMEOUT=30

# Safe mock functions to avoid system command conflicts
tlog() {
    local level="$1"
    shift
    case "$level" in
        error) printf "ERROR: %s\n" "$*" >&2 ;;
        warn)  printf "WARN: %s\n" "$*" >&2 ;;
        info)  printf "INFO: %s\n" "$*" ;;
        debug) [[ "${DEBUG:-}" == "true" ]] && printf "DEBUG: %s\n" "$*" ;;
        *)     printf "%s: %s\n" "$level" "$*" ;;
    esac
}

# Basic logging aliases
glog() { tlog "$@"; }
log() { tlog "$@"; }
io_glog() { tlog "$@"; }

# Mock jq function if not available
if ! command -v jq >/dev/null 2>&1; then
    jq() {
        echo "mock-jq-output"
    }
fi

# Mock grpcurl function if not available  
if ! command -v grpcurl >/dev/null 2>&1; then
    grpcurl() {
        echo "mock-grpcurl-output"
    }
fi

# Mock date function for predictable timestamps
mock_date() {
    echo "2024-01-01 12:00:00"
}
