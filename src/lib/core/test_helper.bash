#!/bin/bash

# test_helper.bash - Common helper for BATS tests
# This file loads individual modules directly for testing

# Load individual modules from source directory
MODULE_DIR="${BATS_TEST_DIRNAME}"

# Load core modules in dependency order
if [[ -f "${MODULE_DIR}/colors.sh" ]]; then
    source "${MODULE_DIR}/colors.sh"
fi

if [[ -f "${MODULE_DIR}/utils.sh" ]]; then
    source "${MODULE_DIR}/utils.sh"
fi

if [[ -f "${MODULE_DIR}/validation.sh" ]]; then
    source "${MODULE_DIR}/validation.sh"
fi

if [[ -f "${MODULE_DIR}/parser.sh" ]]; then
    source "${MODULE_DIR}/parser.sh"
fi

if [[ -f "${MODULE_DIR}/assertions.sh" ]]; then
    source "${MODULE_DIR}/assertions.sh"
fi

if [[ -f "${MODULE_DIR}/parallel.sh" ]]; then
    source "${MODULE_DIR}/parallel.sh"
fi

if [[ -f "${MODULE_DIR}/plugin_system_enhanced.sh" ]]; then
    source "${MODULE_DIR}/plugin_system_enhanced.sh"
fi

if [[ -f "${MODULE_DIR}/runner.sh" ]]; then
    source "${MODULE_DIR}/runner.sh"
fi

if [[ -f "${MODULE_DIR}/progress.sh" ]]; then
    source "${MODULE_DIR}/progress.sh"
fi

if [[ -f "${MODULE_DIR}/error_recovery.sh" ]]; then
    source "${MODULE_DIR}/error_recovery.sh"
fi

if [[ -f "${MODULE_DIR}/report_generator.sh" ]]; then
    source "${MODULE_DIR}/report_generator.sh"
fi

if [[ -f "${MODULE_DIR}/response_comparison.sh" ]]; then
    source "${MODULE_DIR}/response_comparison.sh"
fi

# Export common test utilities
export BATS_TEST_TIMEOUT=30
