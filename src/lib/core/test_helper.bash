#!/bin/bash

# test_helper.bash - Common helper for BATS tests
# Minimal helper to avoid system conflicts

# Set up basic variables for testing
export BATS_TEST_TIMEOUT=30

# Mock functions to avoid dependencies
log() {
    echo "$@" >&2
}

# Load only essential modules for unit testing
MODULE_DIR="${BATS_TEST_DIRNAME}"

# Conditionally load modules based on test needs
# Colors module is generally safe
if [[ -f "${MODULE_DIR}/colors.sh" ]] && [[ ! "$BATS_TEST_FILENAME" =~ runner|parallel|plugin ]]; then
    source "${MODULE_DIR}/colors.sh"
fi

# Utils is needed by many tests but may cause issues
if [[ -f "${MODULE_DIR}/utils.sh" ]] && [[ ! "$BATS_TEST_FILENAME" =~ runner|parallel|plugin ]]; then
    source "${MODULE_DIR}/utils.sh"
fi

# Only load specific modules for specific tests
case "$BATS_TEST_FILENAME" in
    *parser*)
        [[ -f "${MODULE_DIR}/parser.sh" ]] && source "${MODULE_DIR}/parser.sh"
        ;;
    *validation*)
        [[ -f "${MODULE_DIR}/validation.sh" ]] && source "${MODULE_DIR}/validation.sh"
        ;;
    *assertions*)
        [[ -f "${MODULE_DIR}/assertions.sh" ]] && source "${MODULE_DIR}/assertions.sh"
        ;;
    *response_comparison*)
        [[ -f "${MODULE_DIR}/response_comparison.sh" ]] && source "${MODULE_DIR}/response_comparison.sh"
        ;;
    *expected_error*)
        [[ -f "${MODULE_DIR}/runner.sh" ]] && source "${MODULE_DIR}/runner.sh"
        ;;
esac
