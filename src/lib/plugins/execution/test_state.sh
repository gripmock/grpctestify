#!/bin/bash

# test_state.sh - Centralized test results state management
# Provides unified API for storing and retrieving test results

# Global test state
declare -g -A GRPCTESTIFY_STATE=(
    [total_tests]=0
    [executed_tests]=0
    [passed_tests]=0
    [failed_tests]=0
    [skipped_tests]=0
    [start_time]=0
    [end_time]=0
    [execution_mode]=""
    [dry_run]=false
    [parallel_jobs]=1
)

# Test results arrays
declare -g -a GRPCTESTIFY_TEST_RESULTS=()
declare -g -a GRPCTESTIFY_FAILED_DETAILS=()

# Individual test result structure
# Each element: "test_name|status|duration|error_message|execution_time"

# Plugin metadata storage
declare -g -A GRPCTESTIFY_PLUGIN_METADATA=()
declare -g -A GRPCTESTIFY_TEST_METADATA=()

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE INITIALIZATION API
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Initialize test state
test_state_init() {
    local total_tests="$1"
    local execution_mode="$2"
    local dry_run="${3:-false}"
    local parallel_jobs="${4:-1}"
    
    GRPCTESTIFY_STATE[total_tests]="$total_tests"
    GRPCTESTIFY_STATE[executed_tests]=0
    GRPCTESTIFY_STATE[passed_tests]=0
    GRPCTESTIFY_STATE[failed_tests]=0
    GRPCTESTIFY_STATE[skipped_tests]=0
    GRPCTESTIFY_STATE[execution_mode]="$execution_mode"
    GRPCTESTIFY_STATE[dry_run]="$dry_run"
    GRPCTESTIFY_STATE[parallel_jobs]="$parallel_jobs"
    GRPCTESTIFY_STATE[start_time]=$(get_current_time_ms)
    GRPCTESTIFY_STATE[end_time]=0
    
    # Clear previous results
    GRPCTESTIFY_TEST_RESULTS=()
    GRPCTESTIFY_FAILED_DETAILS=()
    
    tlog debug "Test state initialized: $total_tests tests, $execution_mode mode"
}

# Finalize test execution
test_state_finalize() {
    GRPCTESTIFY_STATE[end_time]=$(get_current_time_ms)
    
    # Calculate skipped tests
    local executed=$((GRPCTESTIFY_STATE[passed_tests] + GRPCTESTIFY_STATE[failed_tests]))
    GRPCTESTIFY_STATE[executed_tests]="$executed"
    GRPCTESTIFY_STATE[skipped_tests]=$((GRPCTESTIFY_STATE[total_tests] - executed))
    
    tlog debug "Test state finalized: ${GRPCTESTIFY_STATE[executed_tests]}/${GRPCTESTIFY_STATE[total_tests]} executed"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RESULT RECORDING API
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Record test result
test_state_record_result() {
    local test_name="$1"
    local status="$2"           # PASS, FAIL, SKIP
    local duration_ms="$3"      # Duration in milliseconds
    local error_message="$4"    # Optional error message
    local execution_time="$5"   # Optional execution timestamp
    
    # Validate parameters
    if [[ -z "$test_name" || -z "$status" ]]; then
    tlog error "test_state_record_result: test_name and status are required"
        return 1
    fi
    
    # Normalize test name (ensure full path)
    local normalized_name
    normalized_name=$(normalize_test_name "$test_name")
    
    # Set defaults
    duration_ms="${duration_ms:-0}"
    error_message="${error_message:-}"
    execution_time="${execution_time:-$(get_current_time_ms)}"
    
    # Create result entry with full path
    local result_entry="${normalized_name}|${status}|${duration_ms}|${error_message}|${execution_time}"
    GRPCTESTIFY_TEST_RESULTS+=("$result_entry")
    
    # Update counters
    case "$status" in
        "PASS")
            ((GRPCTESTIFY_STATE[passed_tests]++))
            ;;
        "FAIL")
            ((GRPCTESTIFY_STATE[failed_tests]++))
            # Store detailed failure information
            test_state_record_failure "$normalized_name" "$error_message" "$duration_ms"
            ;;
        "SKIP")
            ((GRPCTESTIFY_STATE[skipped_tests]++))
            ;;
        *)
    tlog warning "Unknown test status: $status for test $normalized_name"
            ;;
    esac
    
    tlog debug "Recorded result: $normalized_name = $status (${duration_ms}ms)"
}

# Record detailed failure information
test_state_record_failure() {
    local test_name="$1"
    local error_message="$2"
    local duration_ms="$3"
    local expected="${4:-}"
    local actual="${5:-}"
    
    # Create failure detail entry
    local failure_entry="${test_name}|${error_message}|${duration_ms}|${expected}|${actual}"
    GRPCTESTIFY_FAILED_DETAILS+=("$failure_entry")
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# QUERY API FOR PLUGINS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Get overall statistics
test_state_get_stats() {
    local format="${1:-human}"  # human, json, kvp
    
    case "$format" in
        "json")
            cat << EOF
{
    "total": ${GRPCTESTIFY_STATE[total_tests]},
    "executed": ${GRPCTESTIFY_STATE[executed_tests]},
    "passed": ${GRPCTESTIFY_STATE[passed_tests]},
    "failed": ${GRPCTESTIFY_STATE[failed_tests]},
    "skipped": ${GRPCTESTIFY_STATE[skipped_tests]},
    "duration_ms": $((GRPCTESTIFY_STATE[end_time] - GRPCTESTIFY_STATE[start_time])),
    "success_rate": $(test_state_get_success_rate),
    "execution_mode": "${GRPCTESTIFY_STATE[execution_mode]}",
    "dry_run": ${GRPCTESTIFY_STATE[dry_run]},
    "parallel_jobs": ${GRPCTESTIFY_STATE[parallel_jobs]}
}
EOF
            ;;
        "kvp")
            echo "total=${GRPCTESTIFY_STATE[total_tests]}"
            echo "executed=${GRPCTESTIFY_STATE[executed_tests]}"
            echo "passed=${GRPCTESTIFY_STATE[passed_tests]}"
            echo "failed=${GRPCTESTIFY_STATE[failed_tests]}"
            echo "skipped=${GRPCTESTIFY_STATE[skipped_tests]}"
            echo "duration_ms=$((GRPCTESTIFY_STATE[end_time] - GRPCTESTIFY_STATE[start_time]))"
            echo "success_rate=$(test_state_get_success_rate)"
            echo "execution_mode=${GRPCTESTIFY_STATE[execution_mode]}"
            echo "dry_run=${GRPCTESTIFY_STATE[dry_run]}"
            echo "parallel_jobs=${GRPCTESTIFY_STATE[parallel_jobs]}"
            ;;
        *)
            echo "Total: ${GRPCTESTIFY_STATE[total_tests]}"
            echo "Executed: ${GRPCTESTIFY_STATE[executed_tests]}"
            echo "Passed: ${GRPCTESTIFY_STATE[passed_tests]}"
            echo "Failed: ${GRPCTESTIFY_STATE[failed_tests]}"
            echo "Skipped: ${GRPCTESTIFY_STATE[skipped_tests]}"
            echo "Duration: $((GRPCTESTIFY_STATE[end_time] - GRPCTESTIFY_STATE[start_time]))ms"
            echo "Success Rate: $(test_state_get_success_rate)%"
            echo "Mode: ${GRPCTESTIFY_STATE[execution_mode]}"
            echo "Dry Run: ${GRPCTESTIFY_STATE[dry_run]}"
            echo "Parallel Jobs: ${GRPCTESTIFY_STATE[parallel_jobs]}"
            ;;
    esac
}

# Get specific metric
test_state_get() {
    local metric="$1"
    echo "${GRPCTESTIFY_STATE[$metric]:-}"
}

# Get success rate percentage
test_state_get_success_rate() {
    local total="${GRPCTESTIFY_STATE[total_tests]}"
    local passed="${GRPCTESTIFY_STATE[passed_tests]}"
    
    if [[ "$total" -eq 0 ]]; then
        echo "0"
    else
        echo $(( (passed * 100) / total ))
    fi
}

# Get execution duration in milliseconds
test_state_get_duration() {
    if [[ "${GRPCTESTIFY_STATE[end_time]}" -eq 0 ]]; then
        # Test still running
        echo $(($(get_current_time_ms) - GRPCTESTIFY_STATE[start_time]))
    else
        echo $((GRPCTESTIFY_STATE[end_time] - GRPCTESTIFY_STATE[start_time]))
    fi
}

# Get all test results
test_state_get_all_results() {
    local format="${1:-array}"  # array, json, csv
    
    case "$format" in
        "json")
            echo "["
            local first=true
            for result in "${GRPCTESTIFY_TEST_RESULTS[@]}"; do
                IFS='|' read -r name status duration error_msg exec_time <<< "$result"
                
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                
                cat << EOF
    {
        "name": "$name",
        "status": "$status",
        "duration_ms": $duration,
        "error_message": "$error_msg",
        "execution_time": $exec_time
    }
EOF
            done
            echo "]"
            ;;
        "csv")
            echo "name,status,duration_ms,error_message,execution_time"
            for result in "${GRPCTESTIFY_TEST_RESULTS[@]}"; do
                echo "${result//|/,}"
            done
            ;;
        *)
            # Return array (for bash consumption)
            printf '%s\n' "${GRPCTESTIFY_TEST_RESULTS[@]}"
            ;;
    esac
}

# Get failed test results only
test_state_get_failed_results() {
    local format="${1:-array}"
    
    case "$format" in
        "json")
            echo "["
            local first=true
            for failure in "${GRPCTESTIFY_FAILED_DETAILS[@]}"; do
                IFS='|' read -r name error_msg duration expected actual <<< "$failure"
                
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                
                cat << EOF
    {
        "name": "$name",
        "error_message": "$error_msg",
        "duration_ms": $duration,
        "expected": "$expected",
        "actual": "$actual"
    }
EOF
            done
            echo "]"
            ;;
        *)
            printf '%s\n' "${GRPCTESTIFY_FAILED_DETAILS[@]}"
            ;;
    esac
}

# Get test results by status
test_state_get_by_status() {
    local status="$1"
    local format="${2:-array}"
    
    local filtered_results=()
    for result in "${GRPCTESTIFY_TEST_RESULTS[@]}"; do
        IFS='|' read -r name result_status duration error_msg exec_time <<< "$result"
        if [[ "$result_status" == "$status" ]]; then
            filtered_results+=("$result")
        fi
    done
    
    case "$format" in
        "json")
            echo "["
            local first=true
            for result in "${filtered_results[@]}"; do
                IFS='|' read -r name result_status duration error_msg exec_time <<< "$result"
                
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                
                cat << EOF
    {
        "name": "$name",
        "status": "$result_status",
        "duration_ms": $duration,
        "error_message": "$error_msg",
        "execution_time": $exec_time
    }
EOF
            done
            echo "]"
            ;;
        "count")
            echo "${#filtered_results[@]}"
            ;;
        *)
            printf '%s\n' "${filtered_results[@]}"
            ;;
    esac
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Get current time in milliseconds (Python-free)
get_current_time_ms() {
    if command -v native_timestamp_ms >/dev/null 2>&1; then
        native_timestamp_ms
    else
        echo $(($(date +%s) * 1000))
    fi
}

# Check if test execution is complete
test_state_is_complete() {
    [[ "${GRPCTESTIFY_STATE[end_time]}" -ne 0 ]]
}

# Reset state (for testing)
test_state_reset() {
    for key in "${!GRPCTESTIFY_STATE[@]}"; do
        case "$key" in
            "dry_run")
                GRPCTESTIFY_STATE[$key]=false
                ;;
            *)
                GRPCTESTIFY_STATE[$key]=0
                ;;
        esac
    done
    GRPCTESTIFY_TEST_RESULTS=()
    GRPCTESTIFY_FAILED_DETAILS=()
    GRPCTESTIFY_PLUGIN_METADATA=()
    GRPCTESTIFY_TEST_METADATA=()
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PLUGIN WRITE API
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Allow plugins to store global metadata
test_state_set_plugin_metadata() {
    local plugin_name="$1"
    local key="$2"
    local value="$3"
    
    if [[ -z "$plugin_name" || -z "$key" ]]; then
    tlog error "test_state_set_plugin_metadata: plugin_name and key are required"
        return 1
    fi
    
    local metadata_key="${plugin_name}:${key}"
    GRPCTESTIFY_PLUGIN_METADATA["$metadata_key"]="$value"
    
    tlog debug "Plugin metadata stored: $metadata_key = $value"
}

# Allow plugins to retrieve global metadata
test_state_get_plugin_metadata() {
    local plugin_name="$1"
    local key="$2"
    
    if [[ -z "$plugin_name" || -z "$key" ]]; then
    tlog error "test_state_get_plugin_metadata: plugin_name and key are required"
        return 1
    fi
    
    local metadata_key="${plugin_name}:${key}"
    echo "${GRPCTESTIFY_PLUGIN_METADATA[$metadata_key]:-}"
}

# Allow plugins to store per-test metadata
test_state_set_test_metadata() {
    local test_name="$1"
    local plugin_name="$2"
    local key="$3"
    local value="$4"
    
    if [[ -z "$test_name" || -z "$plugin_name" || -z "$key" ]]; then
    tlog error "test_state_set_test_metadata: test_name, plugin_name and key are required"
        return 1
    fi
    
    local metadata_key="${test_name}:${plugin_name}:${key}"
    GRPCTESTIFY_TEST_METADATA["$metadata_key"]="$value"
    
    tlog debug "Test metadata stored: $metadata_key = $value"
}

# Allow plugins to retrieve per-test metadata
test_state_get_test_metadata() {
    local test_name="$1"
    local plugin_name="$2"
    local key="$3"
    
    if [[ -z "$test_name" || -z "$plugin_name" || -z "$key" ]]; then
    tlog error "test_state_get_test_metadata: test_name, plugin_name and key are required"
        return 1
    fi
    
    local metadata_key="${test_name}:${plugin_name}:${key}"
    echo "${GRPCTESTIFY_TEST_METADATA[$metadata_key]:-}"
}

# Allow plugins to modify core state (with validation)
test_state_update() {
    local key="$1"
    local value="$2"
    local plugin_name="${3:-unknown}"
    
    if [[ -z "$key" ]]; then
    tlog error "test_state_update: key is required"
        return 1
    fi
    
    # Validate that key exists and is modifiable
    case "$key" in
        "total_tests"|"start_time"|"execution_mode")
    tlog warning "Plugin $plugin_name attempted to modify read-only state: $key"
            return 1
            ;;
        "passed_tests"|"failed_tests"|"skipped_tests"|"executed_tests"|"end_time"|"parallel_jobs"|"dry_run")
            GRPCTESTIFY_STATE["$key"]="$value"
    tlog debug "Plugin $plugin_name updated state: $key = $value"
            ;;
        *)
    tlog warning "Plugin $plugin_name attempted to set unknown state: $key"
            return 1
            ;;
    esac
}

# Allow plugins to increment counters safely
test_state_increment() {
    local counter="$1"
    local amount="${2:-1}"
    local plugin_name="${3:-unknown}"
    
    case "$counter" in
        "passed_tests"|"failed_tests"|"skipped_tests"|"executed_tests")
            local current="${GRPCTESTIFY_STATE[$counter]}"
            GRPCTESTIFY_STATE["$counter"]=$((current + amount))
    tlog debug "Plugin $plugin_name incremented $counter by $amount (now: ${GRPCTESTIFY_STATE[$counter]})"
            ;;
        *)
    tlog error "test_state_increment: invalid counter $counter"
            return 1
            ;;
    esac
}

# Allow plugins to add custom test results
test_state_add_test_result() {
    local test_name="$1"
    local status="$2"
    local duration_ms="$3"
    local error_message="$4"
    local plugin_name="${5:-unknown}"
    
    # Use the standard record function but with plugin attribution
    local attribution=""
    if [[ "$plugin_name" != "unknown" ]]; then
        attribution=" (via $plugin_name)"
    fi
    
    test_state_record_result "$test_name" "$status" "$duration_ms" "${error_message}${attribution}" "$(get_current_time_ms)"
    
    tlog debug "Plugin $plugin_name added test result: $test_name = $status"
}

# Get all plugin metadata as JSON
test_state_get_all_plugin_metadata() {
    local format="${1:-json}"
    
    case "$format" in
        "json")
            echo "{"
            local first=true
            for key in "${!GRPCTESTIFY_PLUGIN_METADATA[@]}"; do
                IFS=':' read -r plugin_name metadata_key <<< "$key"
                
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                
                echo "    \"$key\": \"${GRPCTESTIFY_PLUGIN_METADATA[$key]}\""
            done
            echo "}"
            ;;
        "kvp")
            for key in "${!GRPCTESTIFY_PLUGIN_METADATA[@]}"; do
                echo "$key=${GRPCTESTIFY_PLUGIN_METADATA[$key]}"
            done
            ;;
        *)
            for key in "${!GRPCTESTIFY_PLUGIN_METADATA[@]}"; do
                echo "$key: ${GRPCTESTIFY_PLUGIN_METADATA[$key]}"
            done
            ;;
    esac
}

# Get all test metadata for a specific test
test_state_get_test_all_metadata() {
    local test_name="$1"
    local format="${2:-json}"
    
    case "$format" in
        "json")
            echo "{"
            local first=true
            for key in "${!GRPCTESTIFY_TEST_METADATA[@]}"; do
                if [[ "$key" =~ ^${test_name}: ]]; then
                    IFS=':' read -r test plugin_name metadata_key <<< "$key"
                    
                    if [[ "$first" == "true" ]]; then
                        first=false
                    else
                        echo ","
                    fi
                    
                    echo "    \"${plugin_name}:${metadata_key}\": \"${GRPCTESTIFY_TEST_METADATA[$key]}\""
                fi
            done
            echo "}"
            ;;
        *)
            for key in "${!GRPCTESTIFY_TEST_METADATA[@]}"; do
                if [[ "$key" =~ ^${test_name}: ]]; then
                    echo "$key: ${GRPCTESTIFY_TEST_METADATA[$key]}"
                fi
            done
            ;;
    esac
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXPORT FUNCTIONS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export -f test_state_init
export -f test_state_finalize
export -f test_state_record_result
export -f test_state_record_failure
export -f test_state_get_stats
export -f test_state_get
export -f test_state_get_success_rate
export -f test_state_get_duration
export -f test_state_get_all_results
export -f test_state_get_failed_results
export -f test_state_get_by_status
export -f get_current_time_ms
export -f test_state_is_complete
export -f test_state_reset

# Plugin Write API
export -f test_state_set_plugin_metadata
export -f test_state_get_plugin_metadata
export -f test_state_set_test_metadata
export -f test_state_get_test_metadata
export -f test_state_update
export -f test_state_increment
export -f test_state_add_test_result
export -f test_state_get_all_plugin_metadata
export -f test_state_get_test_all_metadata

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST NAME NORMALIZATION AND ANALYSIS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Normalize test name to use full path for uniqueness
normalize_test_name() {
    local test_name="$1"
    
    # If already absolute path, return as-is
    if [[ "$test_name" =~ ^/ ]]; then
        echo "$test_name"
        return 0
    fi
    
    # If contains directory separators, make relative to current directory
    if [[ "$test_name" =~ / ]]; then
        echo "$(pwd)/$test_name"
        return 0
    fi
    
    # If just filename, try to find it in current directory structure
    local full_path
    if [[ -f "$test_name" ]]; then
        full_path="$(pwd)/$test_name"
    elif [[ -f "./$test_name" ]]; then
        full_path="$(pwd)/$test_name"
    else
        # Try to find in subdirectories (common case)
        full_path=$(find . -name "$test_name" -type f 2>/dev/null | head -1)
        if [[ -n "$full_path" ]]; then
            full_path="$(pwd)/${full_path#./}"
        else
            # Default to current directory + filename
            full_path="$(pwd)/$test_name"
        fi
    fi
    
    echo "$full_path"
}

# Get short name from full path (for display)
get_test_short_name() {
    local full_path="$1"
    basename "$full_path" .gctf
}

# Get test directory from full path
get_test_directory() {
    local full_path="$1"
    dirname "$full_path"
}

# Get test relative path from project root
get_test_relative_path() {
    local full_path="$1"
    local project_root="${PROJECT_ROOT:-$(pwd)}"
    
    # Remove project root prefix
    echo "${full_path#$project_root/}"
}

# Get detailed information for a specific test
test_state_get_test_info() {
    local test_pattern="$1"
    local format="${2:-human}"  # human, json
    
    for result in "${GRPCTESTIFY_TEST_RESULTS[@]}"; do
        IFS='|' read -r name status duration error_msg exec_time <<< "$result"
        
        # Check if this is the test we're looking for
        if [[ "$name" =~ $test_pattern || "$(get_test_short_name "$name")" == "$test_pattern" ]]; then
            case "$format" in
                "json")
                    cat << EOF
{
    "full_path": "$name",
    "short_name": "$(get_test_short_name "$name")",
    "relative_path": "$(get_test_relative_path "$name")",
    "directory": "$(get_test_directory "$name")",
    "status": "$status",
    "duration_ms": $duration,
    "error_message": "$error_msg",
    "execution_time": $exec_time
}
EOF
                    ;;
                *)
                    echo "Test Information:"
                    echo "  Full Path: $name"
                    echo "  Short Name: $(get_test_short_name "$name")"
                    echo "  Relative Path: $(get_test_relative_path "$name")"
                    echo "  Directory: $(get_test_directory "$name")"
                    echo "  Status: $status"
                    echo "  Duration: ${duration}ms"
                    echo "  Execution Time: $exec_time"
                    if [[ -n "$error_msg" ]]; then
                        echo "  Error: $error_msg"
                    fi
                    ;;
            esac
            return 0
        fi
    done
    
    echo "Test not found: $test_pattern" >&2
    return 1
}

# Export new functions
export -f normalize_test_name get_test_short_name get_test_directory get_test_relative_path
export -f test_state_get_test_info
