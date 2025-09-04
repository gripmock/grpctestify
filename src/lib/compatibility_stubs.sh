#!/bin/bash

# compatibility_stubs.sh - Temporary compatibility stubs for missing functions
# These functions provide minimal compatibility for the current run.sh

# Validate parallel jobs count
validate_parallel_jobs() {
    local jobs="$1"
    if [[ ! "$jobs" =~ ^[0-9]+$ ]] || [[ "$jobs" -lt 1 ]] || [[ "$jobs" -gt 100 ]]; then
        echo "Error: Invalid parallel jobs count: $jobs (must be 1-100)" >&2
        return 1
    fi
    return 0
}

# Report manager stubs
report_manager_init() {
    # Stub: do nothing
    return 0
}

init_report_data() {
    # Stub: do nothing
    return 0
}

add_test_result() {
    # Stub: do nothing
    return 0
}

# log() function is provided by run.sh

show_summary() {
    # Stub: do nothing
    return 0
}

# run_single_test() - removed stub, using real implementation from run.sh

# Additional missing functions from microkernel
# Microkernel functions removed

# health_monitor and event_system removed

# Unused functions removed

# Export functions
export -f validate_parallel_jobs report_manager_init init_report_data add_test_result show_summary
# Microkernel exports removed
# Unused exports removed
