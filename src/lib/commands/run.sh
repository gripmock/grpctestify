#!/bin/bash

# run.sh - Main test execution command  
# This file contains the main logic for running gRPC tests
# shellcheck disable=SC2155,SC2034,SC2207,SC2064,SC2086,SC2076,SC2183 # Variable handling and array operations

# All modules are automatically loaded by bashly

# Main test execution function
run_tests() {
    local test_path="${args[test_path]}"

    # Handle version flag
    if [[ "${args[--version]}" == "1" ]]; then
        show_version
        return 0
    fi

    # Handle help flag
    if [[ "${args[--help]}" == "1" ]]; then
        show_help
        return 0
    fi

    # Handle update flag
    if [[ "${args[--update]}" == "1" ]]; then
        update_command
        return 0
    fi

    # Handle completion flag
    if [[ -n "${args[--completion]}" ]]; then
        send_completions
        return 0
    fi

    # Handle config flag
    if [[ "${args[--config]}" == "1" ]]; then
        show_configuration
        return 0
    fi

    # Handle init-config flag
    if [[ -n "${args[--init-config]}" ]]; then
        create_default_config "${args[--init-config]}"
        return 0
    fi

    # Handle list-plugins flag
    if [[ "${args[--list-plugins]}" == "1" ]]; then
        list_plugins
        return 0
    fi

    # Handle create-plugin flag
    if [[ -n "${args[--create-plugin]}" ]]; then
        create_plugin_command "${args[--create-plugin]}"
        return 0
    fi

    # Validate test path
    if [[ -z "$test_path" ]]; then
        echo "Error: Test path is required" >&2
        show_help
        return 1
    fi

    # Check if test path exists
    if [[ ! -e "$test_path" ]]; then
        log error "Test path does not exist: $test_path"
        return 1
    fi

    # Set configuration from command line flags
    setup_configuration

    # Run the tests
    execute_tests "$test_path"
}

# Setup configuration from command line flags and environment variables
setup_configuration() {
    # Set log level based on verbose flag (no ENV needed)
    if [[ "${args[--verbose]}" == "1" ]]; then
        verbose="true"
        log debug "Verbose mode enabled - detailed test information will be shown"
    else
        verbose="false"
    fi
    


    # Set parallel execution
    if [[ -n "${args[--parallel]}" ]]; then
        if [[ "${args[--parallel]}" == "auto" ]]; then
            # Auto-detect CPU count
            local cpu_count
            cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
            PARALLEL_JOBS="$cpu_count"
            log debug "Auto-detected $cpu_count CPU cores, using $PARALLEL_JOBS parallel jobs"
        else
        if ! validate_parallel_jobs "${args[--parallel]}"; then
            exit 1
        fi
        PARALLEL_JOBS="${args[--parallel]}"
        fi
    fi

    # Set timeout (command line flag takes precedence over environment variable)
    if [[ -n "${args[--timeout]}" ]]; then
        if ! validate_positive_integer "${args[--timeout]}" "Timeout"; then
            exit 1
        fi
        RUNTIME_TIMEOUT="${args[--timeout]}"
    # Timeout set via --timeout flag only (no ENV fallback)
    fi

    # Set retry configuration
    if [[ "${args[--no-retry]}" == "1" ]]; then
        RETRY_COUNT=0
    elif [[ -n "${args[--retry]}" ]]; then
        if ! validate_positive_integer "${args[--retry]}" "Retry count"; then
            exit 1
        fi
        RETRY_COUNT="${args[--retry]}"
    fi

    if [[ -n "${args[--retry-delay]}" ]]; then
        if ! validate_positive_integer "${args[--retry-delay]}" "Retry delay"; then
            exit 1
        fi
        RETRY_DELAY="${args[--retry-delay]}"
    fi

    # Run all tests - no fail fast (as requested)
    FAIL_FAST=false

    # Set verbose mode (command line flag takes precedence over environment variable)
    if [[ "${args[--verbose]}" == "1" ]]; then
        VERBOSE=true
    elif [[ "${verbose:-false}" == "true" ]]; then
        VERBOSE=true
    fi

        # Set no color
    if [[ "${args[--no-color]}" == "1" ]]; then
        NO_COLOR=true
    fi

    # Initialize report system first
    report_manager_init
    
    # Set report logging (use flags directly)
    if [[ -n "${args[--log-format]}" ]]; then
        report_format="${args[--log-format]}"
        report_output_file="${args[--log-output]}"
        
        # Validate report format
        if ! validate_report_format "$REPORT_FORMAT"; then
            exit 1
        fi
        
        # Auto-generate output file if not specified
        if [[ -z "$REPORT_OUTPUT_FILE" ]]; then
            REPORT_OUTPUT_FILE=$(auto_generate_output_filename "$REPORT_FORMAT")
            export REPORT_OUTPUT_FILE
            log info "Auto-generated report file: $REPORT_OUTPUT_FILE"
        fi
    fi
    

}

# Determine optimal progress mode based on context
determine_progress_mode() {
    local test_count="$1"
    
    # Smart defaults based on industry best practices:
    # - Single test: detailed output (like pytest -v for one test)
    # - Multiple tests: dots mode (like pytest default)
    # - Verbose mode: always detailed regardless of count
    
    if [[ "${verbose:-false}" == "true" ]]; then
        echo "verbose"
    elif [[ "$test_count" -eq 1 ]]; then
        echo "detailed"
    else
        echo "dots"
    fi
}

# Buffered output system for race condition protection
declare -g TEST_OUTPUT_BUFFERS=()
declare -g TEST_OUTPUT_LOCK=""

# Initialize output buffering system
init_output_buffering() {
    TEST_OUTPUT_LOCK=$(mktemp)
    TEST_OUTPUT_BUFFERS=()
}

# Add output to buffer for a specific test
buffer_test_output() {
    local test_name="$1"
    local output="$2"
    local buffer_file
    
    # Create unique buffer file for this test
    buffer_file=$(mktemp -t "grpctestify_buffer_${test_name//\//_}_XXXXXX")
    echo "$output" > "$buffer_file"
    TEST_OUTPUT_BUFFERS+=("$test_name:$buffer_file")
}

# Flush all buffered output in correct order
flush_buffered_output() {
    local test_files=("$@")
    
    # Output in the same order as tests were started
    for test_file in "${test_files[@]}"; do
        local test_name=$(basename "$test_file" .gctf)
        
        # Find buffer for this test
        for buffer_entry in "${TEST_OUTPUT_BUFFERS[@]}"; do
            if [[ "$buffer_entry" =~ ^${test_name}: ]]; then
                local buffer_file="${buffer_entry#*:}"
                if [[ -f "$buffer_file" ]]; then
                    cat "$buffer_file"
                    rm -f "$buffer_file"
                fi
                break
            fi
        done
    done
}

# Clean up buffering system
cleanup_output_buffering() {
    # Clean up any remaining buffer files
    for buffer_entry in "${TEST_OUTPUT_BUFFERS[@]}"; do
        local buffer_file="${buffer_entry#*:}"
        rm -f "$buffer_file"
    done
    
    rm -f "$TEST_OUTPUT_LOCK"
    TEST_OUTPUT_BUFFERS=()
}

# Execute tests based on the provided path
execute_tests() {
    local test_path="$1"
    local test_files=()
    
    # Initialize global test result arrays for JUnit XML
    declare -g -a PASSED_TESTS=()
    declare -g -a FAILED_TESTS=()

    # Initialize report data
    init_report_data

    # Determine if it's a file or directory
    if [[ -f "$test_path" ]]; then
        # Single file
        if [[ "$test_path" == *.gctf ]]; then
            test_files=("$test_path")
        else
    log error "File must have .gctf extension: $test_path"
            return 1
        fi
    elif [[ -d "$test_path" ]]; then
        # Directory - find all .gctf files
        while IFS= read -r -d '' file; do
            test_files+=("$file")
        done < <(find "$test_path" -name "*.gctf" -type f -print0)
        
        if [[ ${#test_files[@]} -eq 0 ]]; then
    log error "No .gctf files found in directory: $test_path"
            return 1
        fi
    else
    log error "Invalid test path: $test_path"
        return 1
    fi

    # Determine optimal progress mode based on test count and context
    local progress_mode
    progress_mode=$(determine_progress_mode ${#test_files[@]})
    # Progress mode set via local variable (no ENV needed)
    
    log debug "Auto-selected progress mode: $progress_mode (${#test_files[@]} tests, verbose=${verbose:-false})"

    # Initialize output buffering for verbose parallel mode
    if [[ "$PARALLEL_JOBS" -gt 1 && "$progress_mode" == "verbose" ]]; then
        init_output_buffering
    fi

    # Run tests
    local test_exit_code=0
    if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
        run_parallel_tests "${test_files[@]}"
        test_exit_code=$?
        
        # Flush buffered output in verbose mode
        if [[ "$progress_mode" == "verbose" ]]; then
            flush_buffered_output "${test_files[@]}"
            cleanup_output_buffering
        fi
    else
        run_sequential_tests "${test_files[@]}"
        test_exit_code=$?
    fi

    return $test_exit_code
}

# Run tests sequentially
run_sequential_tests() {
    local test_files=("$@")
    local total_tests=${#test_files[@]}
    local passed=0
    local failed=0
    local start_time=$(date +%s)

    log info "Running $total_tests test(s) sequentially..."

    for test_file in "${test_files[@]}"; do
        local test_start_time=$(date +%s)
        local test_start_iso=$(date -Iseconds)
        

        if run_single_test "$test_file"; then
            passed=$((passed + 1))
            PASSED_TESTS+=("$test_file")
            local test_end_time=$(date +%s)
            local test_end_iso=$(date -Iseconds)
            local duration=$((test_end_time - test_start_time))
            add_test_result "$test_file" "PASS" "$duration" "" "$test_start_iso" "$test_end_iso"
        else
            failed=$((failed + 1))
            FAILED_TESTS+=("$test_file")
            local test_end_time=$(date +%s)
            local test_end_iso=$(date -Iseconds)
            local duration=$((test_end_time - test_start_time))
            add_test_result "$test_file" "FAIL" "$duration" "Test execution failed" "$test_start_iso" "$test_end_iso"
            
            # Check fail-fast setting (user requested to disable fail-fast)
            if [[ "${FAIL_FAST:-false}" == "true" ]]; then
            log error "Test failed, stopping execution"
            break
            fi
        fi
    done
    


    # Show summary (pass test files array for potential JUnit generation)
    declare -g -a ALL_TEST_FILES=("${test_files[@]}")
    show_summary $passed $failed $total_tests $start_time
    
    # Return exit code based on test results (like v0.0.13)
    if [[ $failed -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Run tests in parallel
run_parallel_tests() {
    local test_files=("$@")
    local total_tests=${#test_files[@]}
    local start_time=$(date +%s)

    log info "Running $total_tests test(s) in parallel (jobs: $PARALLEL_JOBS)..."

    # Parallel execution framework is ready and stable
    # Use background process approach for reliable parallel execution
    run_parallel_with_background "${test_files[@]}"
}

# Run tests using GNU parallel
run_parallel_with_gnu_parallel() {
    local test_files=("$@")
    local passed=0
    local failed=0
    
    # Export necessary functions and variables for parallel
    export -f run_single_test run_test log setup_colors
    export -f extract_section parse_test_file compare_responses
    export -f run_grpc_call run_grpc_call_with_retry
    export -f evaluate_asserts_with_plugins validate_expected_error
    export -f apply_tolerance_comparison apply_percentage_tolerance_comparison
    export -f format_dry_run_output log_test_details log_test_success
    export PROGRESS_MODE LOG_LEVEL verbose DRY_RUN
    
    # Run tests in parallel and collect results
    printf '%s\n' "${test_files[@]}" | \
        parallel -j "$PARALLEL_JOBS" --group run_single_test
    
    # Note: This approach loses individual test result tracking
    # but provides true parallel execution
}

# Run tests using background processes (simple and reliable)
run_parallel_with_background() {
    local test_files=("$@")
    local temp_dir
    temp_dir=$(mktemp -d)
    local pids=()
    local job_count=0
    
    log info "Starting parallel execution with background processes..."
    
    # Run tests in batches to respect PARALLEL_JOBS limit
    for test_file in "${test_files[@]}"; do
        # Wait if we've reached the parallel job limit
        if [[ ${#pids[@]} -ge $PARALLEL_JOBS ]]; then
            # Wait for the oldest job to complete
            local oldest_pid="${pids[0]}"
            wait "$oldest_pid"
            # Remove the completed PID from array
            pids=("${pids[@]:1}")
        fi
        
        # Start test in background
        (
            local result_file="$temp_dir/result_$$_$RANDOM"
            local test_name=$(basename "$test_file" .gctf)
            
            # Capture output for verbose mode buffering
            if [[ "${PROGRESS_MODE:-none}" == "verbose" ]]; then
                local output
                if output=$(run_single_test "$test_file" 2>&1); then
                    echo "PASS:$test_file" > "$result_file"
                    # Buffer the output for ordered display later (in verbose mode show ALL tests)
                    buffer_test_output "$test_name" "✅ PASSED: $test_name\n$output"
                else
                    echo "FAIL:$test_file" > "$result_file"
                    # Buffer the output for ordered display later (in verbose mode show ALL tests)
                    buffer_test_output "$test_name" "❌ FAILED: $test_name\n$output"
                fi
            else
                # Normal mode - direct output to log file
                if run_single_test "$test_file" >"$result_file.log" 2>&1; then
                    echo "PASS:$test_file" > "$result_file"
                else
                    echo "FAIL:$test_file" > "$result_file"
                fi
            fi
        ) &
        
        pids+=($!)
        ((job_count++))
        
        # Show progress for dots mode
        if [[ "${PROGRESS_MODE:-none}" == "dots" ]]; then
            printf "."
            # Force flush output
            exec 2>&2
        fi
    done
    
    # Wait for all remaining jobs to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    if [[ "${PROGRESS_MODE:-none}" == "dots" ]]; then
        echo  # New line after dots
    fi
    
    # Collect and process results
    local passed=0
    local failed=0
    local failed_tests=()
    
    for result_file in "$temp_dir"/result_*; do
        if [[ -f "$result_file" ]]; then
            local result
            result=$(cat "$result_file")
            if [[ "$result" =~ ^PASS: ]]; then
                ((passed++))
            elif [[ "$result" =~ ^FAIL: ]]; then
                ((failed++))
                local test_name="${result#FAIL:}"
                failed_tests+=("$test_name")
                
                # Store failed test details for smart summary
                local log_file="${result_file}.log"
                if [[ -f "$log_file" ]]; then
                    # In dots mode, we'll show details later in summary
                    # In other modes, show immediately
                    if [[ "${PROGRESS_MODE:-none}" != "dots" ]]; then
                        cat "$log_file"
                    fi
                fi
            fi
        fi
    done
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Update global test result arrays for consistency
    declare -g -a PASSED_TESTS=()
    declare -g -a FAILED_TESTS=("${failed_tests[@]}")
    
    # Add passed tests (extract from total minus failed)
    local test_files=("$@")
    for test_file in "${test_files[@]}"; do
        local found_failed=false
        for failed_test in "${failed_tests[@]}"; do
            if [[ "$test_file" == "$failed_test" ]]; then
                found_failed=true
                break
            fi
        done
        if [[ "$found_failed" == "false" ]]; then
            PASSED_TESTS+=("$test_file")
        fi
    done
    
    # Show standard summary using the same function as sequential
    declare -g -a ALL_TEST_FILES=("${test_files[@]}")
    show_summary $passed $failed ${#test_files[@]} $start_time
    
    # Return appropriate exit code
    if [[ $failed -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Run a single test file
run_single_test() {
    local test_file="$1"
    
    # Execute the test - run_test function handles all timing and logging
    run_test "$test_file" "${PROGRESS_MODE:-none}"
    return $?
}

# Execute a single test
execute_test() {
    local address="$1"
    local endpoint="$2"
    local requests="$3"
    local responses="$4"
    local asserts="$5"
    local options="$6"

    # Parse options
    local timeout="${RUNTIME_TIMEOUT:-$DEFAULT_TIMEOUT}"
    local tolerance="0.01"
    local partial=false
    local redact_fields=()

    if [[ -n "$options" ]]; then
        timeout=$(echo "$options" | grep "timeout:" | cut -d: -f2 | tr -d ' ' || echo "$timeout")
        tolerance=$(echo "$options" | grep "tolerance:" | cut -d: -f2 | tr -d ' ' || echo "$tolerance")
        partial=$(echo "$options" | grep "partial:" | grep -q "true" && echo "true" || echo "false")
        redact_fields=($(echo "$options" | grep "redact:" | sed 's/redact: \[\(.*\)\]/\1/' | tr -d '"' | tr ',' ' '))
    fi

    # Execute gRPC call

    local response
    if ! response=$(execute_grpc_call "$address" "$endpoint" "$requests" "$timeout"); then

        return 1
    fi


    # Validate response

    if ! validate_response "$response" "$responses" "$asserts" "$tolerance" "$partial" "${redact_fields[@]}"; then

        return 1
    fi



    return 0
}

# Execute gRPC call using grpcurl
execute_grpc_call() {
    local address="$1"
    local endpoint="$2"
    local requests="$3"
    local timeout="$4"

    # Build grpcurl command
    local cmd="grpcurl -plaintext -d @ $address $endpoint"
    
    # Execute with timeout
    local grpc_stderr
    local grpc_status
    
    # Capture both stdout and stderr
    grpc_stderr=$(timeout "$timeout" bash -c "echo '$requests' | $cmd" 2>&1)
    grpc_status=$?
    
    if [[ $grpc_status -ne 0 ]]; then
        log error "gRPC call failed or timed out"
        echo "Error details: $grpc_stderr" >&2
        return 1
    fi

    echo "$grpc_stderr"
    return 0
}

# Validate response against expected response and assertions
validate_response() {
    local actual_response="$1"
    local expected_response="$2"
    local asserts="$3"
    local tolerance="$4"
    local partial="$5"
    shift 5
    local redact_fields=("$@")

    # Apply redaction if specified
    if [[ ${#redact_fields[@]} -gt 0 ]]; then
        for field in "${redact_fields[@]}"; do
            actual_response=$(echo "$actual_response" | jq "del(.$field)" 2>/dev/null || echo "$actual_response")
        done
    fi

    # Run assertions
    if [[ -n "$asserts" ]]; then
        if ! run_assertions "$actual_response" "$asserts"; then
            return 1
        fi
    fi

    # Compare with expected response if not partial
    if [[ "$partial" != "true" && -n "$expected_response" ]]; then

        if ! compare_responses "$actual_response" "$expected_response" "$tolerance"; then

            return 1
        fi

    fi

    return 0
}

# Run assertions using jq
run_assertions() {
    local response="$1"
    local asserts="$2"

    while IFS= read -r assertion; do
        if [[ -n "$assertion" && ! "$assertion" =~ ^[[:space:]]*# ]]; then
            if ! echo "$response" | jq -e "$assertion" >/dev/null 2>&1; then
    log error "Assertion failed: $assertion"
                return 1
            fi
        fi
    done <<< "$asserts"

    return 0
}

# Compare responses (overridden by runner.sh)

# Show test summary
show_summary() {
    local passed="$1"
    local failed="$2"
    local total="$3"
    local start_time="$4"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local executed=$((passed + failed))
    local skipped=$((total - executed))
    local success_rate=0
    
    if [[ $total -gt 0 ]]; then
        success_rate=$((passed * 100 / total))
    fi

    echo
    log section "Test Execution Summary"
    echo "  📊 Total tests planned: $total"
    echo "  🏃 Tests executed: $executed"
    echo "  ✅ Passed: $passed"
    if [[ $failed -gt 0 ]]; then
        echo "  ❌ Failed: $failed"
    fi
    if [[ $skipped -gt 0 ]]; then
        echo "  ⏭️  Skipped (due to early stop): $skipped"
    fi
    echo "  📈 Success rate: $success_rate%"
    echo "  ⏱️  Duration: ${duration}s"
    echo
    
    if [[ $failed -eq 0 ]]; then
        log success "🎉 All tests passed!"
        return 0
    else
        if [[ $skipped -gt 0 ]]; then
            log error "💥 $failed test(s) failed, $skipped test(s) not executed"
        else
            log error "💥 $failed test(s) failed"
        fi
        
        # Smart summary: Show test details based on mode
        # - dots mode: only failed tests
        # - verbose mode: all tests (passed and failed)
        # - other modes: nothing (already shown during execution)
        if [[ "${PROGRESS_MODE:-none}" == "dots" && ${#FAILED_TESTS[@]} -gt 0 ]] || [[ "${PROGRESS_MODE:-none}" == "verbose" ]]; then
            echo
            
            if [[ "${PROGRESS_MODE:-none}" == "verbose" ]]; then
                # Verbose mode: show ALL tests (passed and failed)
                log section "All Tests Details"
                
                # Show passed tests first
                if [[ ${#PASSED_TESTS[@]} -gt 0 ]]; then
                    for passed_test in "${PASSED_TESTS[@]}"; do
                        echo
                        log success "═══ ✅ $(basename "$passed_test" .gctf) ═══"
                        # Try to find and show log for passed test too
                        local test_name=$(basename "$passed_test" .gctf)
                        echo "  Test passed successfully"
                    done
                fi
                
                # Then show failed tests
                if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
                    for failed_test in "${FAILED_TESTS[@]}"; do
                        echo
                        log error "═══ ❌ $(basename "$failed_test" .gctf) ═══"
                        # Find and display log for this failed test
                        if [[ -f "${failed_test}.log" ]]; then
                            cat "${failed_test}.log"
                        elif [[ -f "${failed_test%.*}.log" ]]; then
                            cat "${failed_test%.*}.log"
                        else
                            echo "  No detailed log available for this test"
                        fi
                    done
                fi
            else
                # Dots mode: show only failed tests
                log section "Failed Tests Details"
                for failed_test in "${FAILED_TESTS[@]}"; do
                    echo
                    log error "═══ $(basename "$failed_test" .gctf) ═══"
                    
                    # Find and display log for this failed test
                    if [[ -f "${failed_test}.log" ]]; then
                        cat "${failed_test}.log"
                    elif [[ -f "${failed_test%.*}.log" ]]; then
                        cat "${failed_test%.*}.log"
                    else
                        # Try to find log file in temp directories or similar pattern
                        local test_name=$(basename "$failed_test" .gctf)
                        local log_pattern="/tmp/*${test_name}*.log"
                        local found_log=""
                        for log_file in $log_pattern; do
                            if [[ -f "$log_file" ]]; then
                                found_log="$log_file"
                                break
                            fi
                        done
                        
                        if [[ -n "$found_log" ]]; then
                            cat "$found_log"
                        else
                            echo "  No detailed log available for this test"
                        fi
                    fi
                done
            fi
        fi
        
        # Generate report if requested
        if [[ -n "$REPORT_FORMAT" && -n "$REPORT_OUTPUT_FILE" ]]; then
            local test_results_json=$(build_test_results_json "$passed" "$failed" "$total" "$4" "${ALL_TEST_FILES[@]}")
            generate_report "$REPORT_FORMAT" "$REPORT_OUTPUT_FILE" "$test_results_json" "$4" "$(date +%s)"
        fi
        return 1
    fi
}

# Build test results JSON for reporting
build_test_results_json() {
    local passed="$1"
    local failed="$2"
    local total="$3"
    local start_time="$4"
    shift 4
    local all_test_files=("$@")
    
    local skipped=$((total - passed - failed))
    
    # Start building JSON
    local json='{
        "total": '$total',
        "passed": '$passed',
        "failed": '$failed',
        "skipped": '$skipped',
        "tests": ['
    
    # Add individual test results
    local first=true
    for test_file in "${all_test_files[@]}"; do
        if [[ ! "$first" == "true" ]]; then
            json+=','
        fi
        first=false
        
        local test_name=$(basename "$test_file" .gctf)
        local test_status="unknown"
        local test_duration=0
        local test_error=""
        
        # Determine test status from arrays (simplified)
        if [[ " ${PASSED_TESTS[*]} " =~ " $test_file " ]]; then
            test_status="passed"
        elif [[ " ${FAILED_TESTS[*]} " =~ " $test_file " ]]; then
            test_status="failed"
            # Try to get error from logs if available
            test_error="Test failed"
        elif [[ " ${TIMEOUT_TESTS[*]} " =~ " $test_file " ]]; then
            test_status="error"
            test_error="Timeout"
        else
            test_status="skipped"
        fi
        
        json+='{
            "name": "'$test_name'",
            "file": "'$test_file'",
            "status": "'$test_status'",
            "duration": '$test_duration
        
        if [[ -n "$test_error" ]]; then
            json+=', "error": "'$test_error'"'
        fi
        
        json+='}'
    done
    
    json+=']}'
    
    echo "$json"
}

# Generate JUnit XML report
generate_junit_xml() {
    local output_file="$1"
    local passed="$2"
    local failed="$3"
    local total="$4"
    local start_time="$5"
    shift 5
    local all_test_files=("$@")

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local timestamp=$(date -Iseconds)
    local skipped=$((total - passed - failed))

    echo "ℹ️ Creating JUnit XML: $output_file" >&2

    # Create output directory if it doesn't exist
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"

    cat > "$output_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="grpctestify" 
           tests="$total" 
           failures="$failed" 
           errors="0" 
           skipped="$skipped" 
           time="$duration"
           timestamp="$timestamp">
  
  <properties>
    <property name="grpctestify.version" value="$APP_VERSION"/>
    <property name="hostname" value="$(hostname)"/>
    <property name="username" value="$(whoami)"/>
  </properties>
  
  <testsuite name="grpc-tests" 
             tests="$total" 
             failures="$failed" 
             errors="0" 
             skipped="$skipped" 
             time="$duration">
EOF

    # Create associative arrays to track test status
    local -A test_status
    
    # Mark passed tests
    if [[ -n "${PASSED_TESTS[*]}" ]]; then
        for test_file in "${PASSED_TESTS[@]}"; do
            test_status["$test_file"]="passed"
        done
    fi
    
    # Mark failed tests
    if [[ -n "${FAILED_TESTS[*]}" ]]; then
        for test_file in "${FAILED_TESTS[@]}"; do
            test_status["$test_file"]="failed"
        done
    fi
    
    # Generate test cases for all tests
    for test_file in "${all_test_files[@]}"; do
        local test_name=$(basename "$test_file" .gctf)
        local status="${test_status[$test_file]:-skipped}"
        
        case "$status" in
            "passed")
                echo "    <testcase classname=\"grpctestify\" name=\"$test_name\" file=\"$test_file\" time=\"0\">" >> "$output_file"
                echo "    </testcase>" >> "$output_file"
                ;;
            "failed")
                echo "    <testcase classname=\"grpctestify\" name=\"$test_name\" file=\"$test_file\" time=\"0\">" >> "$output_file"
                echo "      <failure message=\"Test failed\" type=\"AssertionError\">" >> "$output_file"
                echo "        Test execution failed" >> "$output_file"
                echo "      </failure>" >> "$output_file"
                echo "    </testcase>" >> "$output_file"
                ;;
            "skipped")
                echo "    <testcase classname=\"grpctestify\" name=\"$test_name\" file=\"$test_file\" time=\"0\">" >> "$output_file"
                echo "      <skipped message=\"Test skipped due to early termination (fail-fast mode)\" type=\"Skipped\">" >> "$output_file"
                echo "        Test was not executed because a previous test failed and fail-fast mode is enabled" >> "$output_file"
                echo "      </skipped>" >> "$output_file"
                echo "    </testcase>" >> "$output_file"
                ;;
        esac
    done
    
    cat >> "$output_file" << EOF
    
  </testsuite>
</testsuites>
EOF

    echo "✅ JUnit XML generated: $output_file" >&2
}

# Parallel execution with synchronized logging to prevent race conditions
run_parallel_execution_synchronized() {
    local test_files=("$@")
    local total_tests=${#test_files[@]}
    local results_dir=$(mktemp -d)
    local passed=0
    local failed=0
    local failed_tests=()
    local start_time=$(date +%s)
    
    # Create a wrapper script that uses functions directly
    local grpctestify_path="$(readlink -f "$0")"
    local wrapper_script="$results_dir/test_wrapper.sh"
    
cat > "$wrapper_script" << EOF
#!/bin/bash
test_file="\$1"
results_dir="$results_dir"
test_name="\$(basename "\$test_file" .gctf)"
log_file="\$results_dir/\${test_name}.log"
result_file="\$results_dir/\${test_name}.result"

# Change to grpctestify directory
cd "\$(dirname "$grpctestify_path")"

# Simply call grpctestify for single file (avoid recursion by using --parallel=1)
if timeout 30 "$grpctestify_path" "\$test_file" --parallel=1 > "\$log_file" 2>&1; then
    echo "PASS:\$test_name" > "\$result_file"
else
    echo "FAIL:\$test_name" > "\$result_file"
fi
EOF
    
    chmod +x "$wrapper_script"
    
    # Run tests in parallel using xargs
    printf '%s\n' "${test_files[@]}" | xargs -n 1 -P "$PARALLEL_JOBS" "$wrapper_script"
    
    # Collect and display results in order
    for test_file in "${test_files[@]}"; do
        local test_name="$(basename "$test_file" .gctf)"
        local log_file="$results_dir/${test_name}.log"
        local result_file="$results_dir/${test_name}.result"
        
        if [[ -f "$result_file" ]]; then
            local result=$(cat "$result_file")
            if [[ "$result" == PASS:* ]]; then
                ((passed++))
                if [[ "${PROGRESS_MODE:-none}" != "dots" ]]; then
                    # Show full log for non-dots mode
                    cat "$log_file"
                fi
                printf "."
            else
                ((failed++))
                failed_tests+=("$test_name")
                if [[ "${PROGRESS_MODE:-none}" == "dots" ]]; then
                    # In dots mode, only show errors at the end
                    printf "F"
                else
                    # Show full log immediately
                    cat "$log_file"
                fi
            fi
        else
            # Missing result file - treat as failure
            ((failed++))
            failed_tests+=("$test_name")
            printf "F"
        fi
    done
    
    echo ""  # New line after dots
    
    # Show failed test details in dots mode
    if [[ "${PROGRESS_MODE:-none}" == "dots" && ${#failed_tests[@]} -gt 0 ]]; then
        echo ""
        log error "Failed Tests Details:"
        for test_name in "${failed_tests[@]}"; do
            local log_file="$results_dir/${test_name}.log"
            if [[ -f "$log_file" ]]; then
                echo ""
                log error "═══ $test_name ═══"
                cat "$log_file"
            fi
        done
    fi
    
    # Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log section "Test Execution Summary"
    log info "📊 Total tests planned: $total_tests"
    log info "🏃 Tests executed: $((passed + failed))"
    if [[ $passed -gt 0 ]]; then
        log info "✅ Passed: $passed"
    fi
    if [[ $failed -gt 0 ]]; then
        log info "❌ Failed: $failed"
    fi
    local success_rate=$((passed * 100 / total_tests))
    log info "📈 Success rate: ${success_rate}%"
    log info "⏱️  Duration: ${duration}s"
    
    # Cleanup
    rm -rf "$results_dir"
    
    if [[ $failed -gt 0 ]]; then
        echo ""
        log error "💥 $failed test(s) failed"
        return 1
    else
        echo ""
        log success "🎉 All tests passed!"
        return 0
    fi
}
