#!/bin/bash

# parallel.sh - Advanced parallel execution utilities

# Default timeout for individual tests (in seconds)
DEFAULT_TEST_TIMEOUT=30

# Run a single test with timeout
run_test_with_timeout() {
    local test_file="$1"
    local timeout_seconds="${2:-$DEFAULT_TEST_TIMEOUT}"
    local result_file="$3"
    
    # Create a temporary script for timeout execution
    local timeout_script
    timeout_script=$(mktemp)
    
    cat > "$timeout_script" << EOF
#!/bin/bash
set -e

# All modules are automatically loaded by bashly

# Run the test
if run_single_test "$test_file"; then
    echo "PASS:$test_file" > "$result_file"
    exit 0
else
    echo "FAIL:$test_file" > "$result_file"
    exit 1
fi
EOF
    
    chmod +x "$timeout_script"
    
    # Run with timeout
    if timeout "$timeout_seconds" "$timeout_script"; then
        local exit_code=$?
        rm -f "$timeout_script"
        return $exit_code
    else
        local exit_code=$?
        echo "TIMEOUT:$test_file" > "$result_file"
        rm -f "$timeout_script"
        return 124  # Timeout exit code
    fi
}

# Enhanced parallel test execution with job management
run_enhanced_parallel_tests() {
    local test_files="$1"
    local parallel_jobs="$2"
    local timeout_seconds="${3:-$DEFAULT_TEST_TIMEOUT}"
    
    log info "Running enhanced parallel tests with $parallel_jobs jobs (timeout: ${timeout_seconds}s)"
    
    # Setup progress indicator
    local progress_mode
    progress_mode=$(get_config "progress_mode" "none")
    local test_count
    test_count=$(echo "$test_files" | wc -l)
    
    if [[ "$progress_mode" != "none" ]]; then
        setup_progress "$progress_mode" "$test_count"
    fi
    
    # Create temporary directory for results
    local results_dir
    results_dir=$(mktemp -d)
    local failed_tests=0
    local passed_tests=0
    local timeout_tests=0
    local failed_test_files=()
    local timeout_test_files=()
    
    # Function to run a single test with timeout
    run_single_test_with_timeout() {
        local test_file="$1"
        local result_file="$results_dir/$(basename "$test_file" | tr '/' '_').result"
        
        # Run the test with timeout
        if run_test_with_timeout "$test_file" "$timeout_seconds" "$result_file"; then
            return 0
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                echo "TIMEOUT:$test_file" > "$result_file"
            else
                echo "FAIL:$test_file" > "$result_file"
            fi
            return $exit_code
        fi
    }
    
    # Export function for parallel execution
    export -f run_single_test_with_timeout
    export -f run_test_with_timeout
    export -f run_single_test
    export -f run_grpc_call
    export -f compare_responses
    export -f extract_section
    export -f parse_test_file
    export -f evaluate_asserts_with_plugins
    export -f apply_tolerance_comparison
    export -f apply_percentage_tolerance_comparison
    export -f log
    export -f print_progress
    export -f setup_colors

    export -f validate_address
    export -f validate_json
    # Dependencies are handled by bashly
    
    # Run tests in parallel using xargs with timeout
    echo "$test_files" | xargs -n 1 -P "$parallel_jobs" -I {} bash -c 'run_single_test_with_timeout "{}"'
    
    # Collect results
    for result_file in "$results_dir"/*.result; do
        if [[ -f "$result_file" ]]; then
            local result
            result=$(cat "$result_file")
            local test_file
            test_file=$(echo "$result" | cut -d: -f2-)
            
            if [[ "$result" == PASS:* ]]; then
                ((passed_tests++))
                if [[ "$progress_mode" != "none" ]]; then
                    print_progress "." "$progress_mode"
                fi
            elif [[ "$result" == TIMEOUT:* ]]; then
                ((timeout_tests++))
                timeout_test_files+=("$test_file")
                if [[ "$progress_mode" != "none" ]]; then
                    print_progress "T" "$progress_mode"
                fi
                log error "Test timed out: $test_file"
            else
                ((failed_tests++))
                failed_test_files+=("$test_file")
                if [[ "$progress_mode" != "none" ]]; then
                    print_progress "F" "$progress_mode"
                fi
                log error "Test failed: $test_file"
            fi
        fi
    done
    
    # Cleanup results directory
    rm -rf "$results_dir"
    
    # Finish progress
    if [[ "$progress_mode" != "none" ]]; then
        finish_progress
    fi
    
    # Show detailed summary
    log section "Enhanced Parallel Test Summary"
    log info "Total tests: $test_count"
    log info "Passed tests: $passed_tests"
    log info "Failed tests: $failed_tests"
    log info "Timeout tests: $timeout_tests"
    
    if [[ ${#failed_test_files[@]} -gt 0 ]]; then
        log error "Failed test files:"
        for failed_file in "${failed_test_files[@]}"; do
            log error "  - $failed_file"
        done
    fi
    
    if [[ ${#timeout_test_files[@]} -gt 0 ]]; then
        log error "Timeout test files:"
        for timeout_file in "${timeout_test_files[@]}"; do
            log error "  - $timeout_file"
        done
    fi
    
    # Return appropriate exit code
    if [[ $failed_tests -gt 0 ]] || [[ $timeout_tests -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Wait for parallel jobs with timeout
wait_for_parallel_jobs() {
    local pids=("$@")
    local timeout_seconds="${PARALLEL_TIMEOUT:-300}"
    local start_time
    start_time=$(date +%s)
    
    while [[ ${#pids[@]} -gt 0 ]]; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout_seconds ]]; then
            log error "Parallel execution timeout after ${timeout_seconds}s"
            # Kill remaining processes
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    kill -TERM "$pid" 2>/dev/null || true
                fi
            done
            return 124
        fi
        
        # Check which processes are still running
        local remaining_pids=()
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                remaining_pids+=("$pid")
            fi
        done
        pids=("${remaining_pids[@]}")
        
        if [[ ${#pids[@]} -gt 0 ]]; then
            sleep 1
        fi
    done
    
    return 0
}

# Print failed tests summary
print_failed_tests() {
    local failed_tests=("$@")
    
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        return 0
    fi
    
    log section "Failed Tests Summary"
    for test_file in "${failed_tests[@]}"; do
        log error "❌ $test_file"
    done
    
    log info "Total failed tests: ${#failed_tests[@]}"
}

# Get optimal number of parallel jobs based on system resources
get_optimal_parallel_jobs() {
    local requested_jobs="$1"
    local cpu_count
    cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
    
    # Use minimum of requested jobs and CPU count * 2
    local optimal_jobs
    optimal_jobs=$((cpu_count * 2))
    
    if [[ "$requested_jobs" -gt "$optimal_jobs" ]]; then
        log warning "Requested $requested_jobs jobs, but optimal is $optimal_jobs (CPU count: $cpu_count)"
        echo "$optimal_jobs"
    else
        echo "$requested_jobs"
    fi
}

# Main parallel test execution function (from original version)
run_test_parallel() {
    local test_files=("$@")
    local parallel_jobs=$(get_flag "parallel" "1")
    local timeout_seconds=$(get_flag "timeout" "$DEFAULT_TEST_TIMEOUT")
    local fail_fast="true"  # Always fail fast
    
    # Validate parallel jobs - must be positive integer (regex: start-of-line + digits + end-of-line)
    if ! [[ "$parallel_jobs" =~ ^[0-9]+$ ]] || [[ "$parallel_jobs" -lt 1 ]]; then
        log error "Invalid parallel jobs: $parallel_jobs"
        return 1
    fi
    
    # Get optimal parallel jobs if auto is requested
    if [[ "$parallel_jobs" == "auto" ]]; then
        parallel_jobs=$(get_optimal_parallel_jobs "$parallel_jobs")
    fi
    
    log info "Starting parallel test execution with $parallel_jobs jobs"
    log debug "Test files: ${test_files[*]}"
    log debug "Timeout: ${timeout_seconds}s"
    log debug "Fail fast: $fail_fast"
    
    # Create results directory
    local results_dir
    results_dir=$(mktemp -d)
    local pids=()
    local test_results=()
    local failed_tests=()
    local passed_tests=()
    local timeout_tests=()
    
    # Function to run a single test in parallel
    run_single_test_parallel() {
        local test_file="$1"
        local result_file="$results_dir/$(basename "$test_file" | tr '/' '_').result"
        local pid_file="$results_dir/$(basename "$test_file" | tr '/' '_').pid"
        
        # Store PID
        echo $$ > "$pid_file"
        
        # Run the test with timeout and error recovery
        if timeout "$timeout_seconds" bash -c "
            # All modules are automatically loaded by bashly
            if run_single_test '$test_file'; then
                echo 'PASS:$test_file' > '$result_file'
                exit 0
            else
                local exit_code=\$?
                # Try to recover from test failure if retry is enabled
                if ! is_no_retry; then
                    if recover_from_test_failure '$test_file' 'Test failed' 1; then
                        echo 'PASS:$test_file' > '$result_file'
                        exit 0
                    fi
                fi
                echo 'FAIL:$test_file' > '$result_file'
                exit \$exit_code
            fi
        "; then
            echo "PASS:$test_file" > "$result_file"
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                echo "TIMEOUT:$test_file" > "$result_file"
            else
                echo "FAIL:$test_file" > "$result_file"
            fi
        fi
    }
    
    # Export function for parallel execution
    export -f run_single_test_parallel
    export -f run_single_test
    export -f run_grpc_call
    export -f run_grpc_call_with_retry
    export -f compare_responses
    export -f extract_section
    export -f parse_test_file
    export -f evaluate_asserts_with_plugins
    export -f apply_tolerance_comparison
    export -f apply_percentage_tolerance_comparison
    export -f log
    export -f print_progress
    export -f setup_colors

    export -f validate_address
    export -f validate_json
    # Dependencies are handled by bashly
    export -f is_no_retry
    export -f recover_from_test_failure
    export -f handle_network_failure
    export -f check_service_health
    export -f wait_for_service
    
    # Start tests in parallel
    for test_file in "${test_files[@]}"; do
        # Run test in background
        run_single_test_parallel "$test_file" &
        local pid=$!
        pids+=("$pid")
        
        # Limit number of parallel jobs
        if [[ ${#pids[@]} -ge $parallel_jobs ]]; then
            # Wait for one job to complete
            wait_for_parallel_tests "${pids[@]}"
            # Remove completed PIDs
            local remaining_pids=()
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    remaining_pids+=("$pid")
                fi
            done
            pids=("${remaining_pids[@]}")
        fi
        
        # Check fail-fast condition
        if [[ "$fail_fast" == "true" ]]; then
            # Check if any test has failed
            for result_file in "$results_dir"/*.result; do
                if [[ -f "$result_file" ]]; then
                    local result
                    result=$(cat "$result_file")
                    if [[ "$result" == FAIL:* ]]; then
                        log error "Fail-fast enabled: stopping execution due to test failure"
                        # Kill remaining processes
                        for pid in "${pids[@]}"; do
                            if kill -0 "$pid" 2>/dev/null; then
                                kill -TERM "$pid" 2>/dev/null || true
                            fi
                        done
                        # Collect results and return
                        collect_parallel_results "$results_dir" passed_tests failed_tests timeout_tests
                        print_failed_tests "${failed_tests[@]}"
                        rm -rf "$results_dir"
                        return 1
                    fi
                fi
            done
        fi
    done
    
    # Wait for remaining jobs
    wait_for_parallel_tests "${pids[@]}"
    
    # Collect results
    collect_parallel_results "$results_dir" passed_tests failed_tests timeout_tests
    
    # Cleanup
    rm -rf "$results_dir"
    
    # Print summary
    print_parallel_summary "${#test_files[@]}" "${#passed_tests[@]}" "${#failed_tests[@]}" "${#timeout_tests[@]}"
    
    # Print failed tests if any
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        print_failed_tests "${failed_tests[@]}"
    fi
    
    # Return appropriate exit code
    if [[ ${#failed_tests[@]} -gt 0 ]] || [[ ${#timeout_tests[@]} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Wait for parallel tests to complete (from original version)
wait_for_parallel_tests() {
    local pids=("$@")
    local timeout_seconds="${PARALLEL_TIMEOUT:-300}"
    local start_time
    start_time=$(date +%s)
    
    log debug "Waiting for ${#pids[@]} parallel tests to complete"
    
    while [[ ${#pids[@]} -gt 0 ]]; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout_seconds ]]; then
            log error "Parallel execution timeout after ${timeout_seconds}s"
            # Kill remaining processes
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    kill -TERM "$pid" 2>/dev/null || true
                fi
            done
            return 124
        fi
        
        # Check which processes are still running
        local remaining_pids=()
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                remaining_pids+=("$pid")
            fi
        done
        pids=("${remaining_pids[@]}")
        
        if [[ ${#pids[@]} -gt 0 ]]; then
            sleep 0.1  # Shorter sleep for better responsiveness
        fi
    done
    
    log debug "All parallel tests completed"
    return 0
}

# Collect results from parallel execution
collect_parallel_results() {
    local results_dir="$1"
    local -n passed_tests_ref="$2"
    local -n failed_tests_ref="$3"
    local -n timeout_tests_ref="$4"
    
    passed_tests_ref=()
    failed_tests_ref=()
    timeout_tests_ref=()
    
    for result_file in "$results_dir"/*.result; do
        if [[ -f "$result_file" ]]; then
            local result
            result=$(cat "$result_file")
            local test_file
            test_file=$(echo "$result" | cut -d: -f2-)
            
            if [[ "$result" == PASS:* ]]; then
                passed_tests_ref+=("$test_file")
            elif [[ "$result" == TIMEOUT:* ]]; then
                timeout_tests_ref+=("$test_file")
            else
                failed_tests_ref+=("$test_file")
            fi
        fi
    done
}

# Print parallel execution summary
print_parallel_summary() {
    local total_tests="$1"
    local passed_count="$2"
    local failed_count="$3"
    local timeout_count="$4"
    
    log section "Parallel Test Execution Summary"
    log info "Total tests: $total_tests"
    log success "Passed tests: $passed_count"
    
    if [[ $failed_count -gt 0 ]]; then
        log error "Failed tests: $failed_count"
    fi
    
    if [[ $timeout_count -gt 0 ]]; then
        log error "Timeout tests: $timeout_count"
    fi
    
    # Calculate success rate
    local success_rate=0
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$((passed_count * 100 / total_tests))
    fi
    
    log info "Success rate: ${success_rate}%"
}

# Parallel test discovery functions
discover_test_files() {
    local search_paths=("$@")
    local discovered_files=()
    
    # If no paths provided, use current directory
    if [[ ${#search_paths[@]} -eq 0 ]]; then
        search_paths=(".")
    fi
    
    log debug "Discovering test files in paths: ${search_paths[*]}"
    
    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            # Single file
            if [[ "$path" == *.gctf ]]; then
                discovered_files+=("$path")
            fi
        elif [[ -d "$path" ]]; then
            # Directory - find all .gctf files recursively
            while IFS= read -r -d '' file; do
                discovered_files+=("$file")
            done < <(find "$path" -name "*.gctf" -type f -print0 2>/dev/null)
        fi
    done
    
    # Remove duplicates and sort
    if [[ ${#discovered_files[@]} -gt 0 ]]; then
        printf '%s\n' "${discovered_files[@]}" | sort -u
    fi
}

# Parallel test discovery with categorization
discover_and_categorize_tests() {
    local search_paths=("$@")
    local discovered_files
    discovered_files=$(discover_test_files "${search_paths[@]}")
    
    if [[ -z "$discovered_files" ]]; then
        log warning "No test files found in specified paths"
        return 1
    fi
    
    local total_count
    total_count=$(echo "$discovered_files" | wc -l)
    log info "Discovered $total_count test files"
    
    # Categorize tests by directory structure
    local categorized_tests=()
    local categories=()
    
    while IFS= read -r test_file; do
        if [[ -n "$test_file" ]]; then
            local dir_name
            dir_name=$(dirname "$test_file")
            local category
            category=$(basename "$dir_name")
            
            # Add to category if not already present
            if [[ ! " ${categories[*]} " =~ " $category " ]]; then
                categories+=("$category")
            fi
            
            categorized_tests+=("$category:$test_file")
        fi
    done <<< "$discovered_files"
    
    # Print categorization summary
    log section "Test Discovery Summary"
    for category in "${categories[@]}"; do
        local count=0
        for test in "${categorized_tests[@]}"; do
            if [[ "$test" == "$category:"* ]]; then
                ((count++))
            fi
        done
        log info "Category '$category': $count tests"
    done
    
    # Return discovered files
    echo "$discovered_files"
}

# Parallel test discovery with filtering
discover_tests_with_filters() {
    local search_paths=("$@")
    local filter_pattern="${TEST_FILTER:-}"
    local exclude_pattern="${TEST_EXCLUDE:-}"
    local max_depth="${TEST_MAX_DEPTH:-}"
    
    local discovered_files
    discovered_files=$(discover_test_files "${search_paths[@]}")
    
    if [[ -z "$discovered_files" ]]; then
        return 1
    fi
    
    local filtered_files=()
    
    while IFS= read -r test_file; do
        if [[ -n "$test_file" ]]; then
            local include_file=true
            
            # Apply include filter
            if [[ -n "$filter_pattern" ]]; then
                if [[ ! "$test_file" =~ $filter_pattern ]]; then
                    include_file=false
                fi
            fi
            
            # Apply exclude filter
            if [[ -n "$exclude_pattern" ]] && [[ "$include_file" == true ]]; then
                if [[ "$test_file" =~ $exclude_pattern ]]; then
                    include_file=false
                fi
            fi
            
            # Apply depth filter
            if [[ -n "$max_depth" ]] && [[ "$include_file" == true ]]; then
                local depth
                depth=$(echo "$test_file" | tr -cd '/' | wc -c)
                if [[ $depth -gt $max_depth ]]; then
                    include_file=false
                fi
            fi
            
            if [[ "$include_file" == true ]]; then
                filtered_files+=("$test_file")
            fi
        fi
    done <<< "$discovered_files"
    
    if [[ ${#filtered_files[@]} -gt 0 ]]; then
        printf '%s\n' "${filtered_files[@]}"
    fi
}

# Parallel test discovery with dependency analysis
discover_tests_with_dependencies() {
    local search_paths=("$@")
    local discovered_files
    discovered_files=$(discover_test_files "${search_paths[@]}")
    
    if [[ -z "$discovered_files" ]]; then
        return 1
    fi
    
    local dependency_map=()
    local independent_tests=()
    local dependent_tests=()
    
    while IFS= read -r test_file; do
        if [[ -n "$test_file" ]]; then
            # DEPENDS section removed - all tests are now independent
            independent_tests+=("$test_file")
        fi
    done <<< "$discovered_files"
    
    # Print dependency analysis
    log section "Test Dependency Analysis"
    log info "Independent tests: ${#independent_tests[@]}"
    log info "Dependent tests: ${#dependent_tests[@]}"
    
    if [[ ${#dependent_tests[@]} -gt 0 ]]; then
        log info "Dependency relationships:"
        for dep_info in "${dependency_map[@]}"; do
            local test_file
            test_file=$(echo "$dep_info" | cut -d: -f1)
            local dependencies
            dependencies=$(echo "$dep_info" | cut -d: -f2-)
            log info "  $test_file depends on: $dependencies"
        done
    fi
    
    # Return all discovered files
    echo "$discovered_files"
}

# Optimize test execution order based on dependencies and test characteristics
optimize_test_execution_order() {
    local test_files=("$@")
    local optimized_order=()
    local independent_tests=()
    local dependent_tests=()
    
    # DEPENDS section removed - all tests are independent
    independent_tests=("${test_files[@]}")
    dependent_tests=()
    
    # Add independent tests first (can run in parallel)
    optimized_order+=("${independent_tests[@]}")
    
    # Add dependent tests (need to be run after dependencies)
    optimized_order+=("${dependent_tests[@]}")
    
    # Return optimized order
    printf '%s\n' "${optimized_order[@]}"
}

# Export new functions
export -f discover_test_files
export -f discover_and_categorize_tests
export -f discover_tests_with_filters
export -f discover_tests_with_dependencies
export -f optimize_test_execution_order
