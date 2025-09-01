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

log() {
    # Stub: simple logging
    local level="$1"
    local message="$2"
    echo "[$level] $message" >&2
}

show_summary() {
    # Stub: do nothing
    return 0
}

# run_single_test() - removed stub, using real implementation from run.sh

# Additional missing functions from microkernel
plugin_manager_init() {
    return 0
}

state_db_init() {
    return 0
}

state_db_set() {
    return 0
}

state_db_get() {
    echo ""
}

resource_pool_init() {
    return 0
}

routine_manager_init() {
    return 0
}

health_monitor_init() {
    return 0
}

event_system_init() {
    return 0
}

# Progress and UI functions
show_progress() {
    return 0
}

update_progress() {
    return 0
}

# Validation functions
validate_test_file() {
    return 0
}

validate_grpc_endpoint() {
    return 0
}

# Export functions
export -f validate_parallel_jobs report_manager_init init_report_data add_test_result log show_summary
export -f plugin_manager_init state_db_init state_db_set state_db_get resource_pool_init routine_manager_init
export -f health_monitor_init event_system_init show_progress update_progress validate_test_file validate_grpc_endpoint
