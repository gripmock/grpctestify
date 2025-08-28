#!/bin/bash

# run.sh - Main test execution command
# This file contains the main logic for running gRPC tests

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
    # Set progress mode
    if [[ -n "${args[--progress]}" ]]; then
        PROGRESS_MODE="${args[--progress]}"
    fi

    # Set parallel execution
    if [[ -n "${args[--parallel]}" ]]; then
        if ! validate_parallel_jobs "${args[--parallel]}"; then
            exit 1
        fi
        PARALLEL_JOBS="${args[--parallel]}"
    fi

    # Set timeout (command line flag takes precedence over environment variable)
    if [[ -n "${args[--timeout]}" ]]; then
        if ! validate_positive_integer "${args[--timeout]}" "Timeout"; then
            exit 1
        fi
        RUNTIME_TIMEOUT="${args[--timeout]}"
    elif [[ -n "${GRPCTESTIFY_TIMEOUT}" ]]; then
        RUNTIME_TIMEOUT="${GRPCTESTIFY_TIMEOUT}"
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

    # Always fail fast - stop on first error (like v0.0.13)
    FAIL_FAST=true

    # Set verbose mode (command line flag takes precedence over environment variable)
    if [[ "${args[--verbose]}" == "1" ]]; then
        VERBOSE=true
    elif [[ "${GRPCTESTIFY_VERBOSE}" == "true" ]]; then
        VERBOSE=true
    fi

        # Set no color
    if [[ "${args[--no-color]}" == "1" ]]; then
        NO_COLOR=true
    fi

    # Set junit logging
    if [[ -n "${args[--log-junit]}" ]]; then
        export JUNIT_OUTPUT_FILE="${args[--log-junit]}"
    fi
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

    # Run tests
    local test_exit_code=0
    if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
        run_parallel_tests "${test_files[@]}"
        test_exit_code=$?
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
            
            # Always stop on first failure (v0.0.13 behavior)
            log error "Test failed, stopping execution"
            break
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

    # Use parallel execution
    run_parallel_execution "${test_files[@]}"
}

# Run a single test file
run_single_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .gctf)
    
    # Show test header like v0.0.13 (only in progress=none mode)
    if [[ "${PROGRESS_MODE:-none}" == "none" ]]; then
        echo ""
        echo " ───[ Test: $test_name ]───"
    fi
    
    log info "Running test: $test_name"
    
    # Parse test file
    local test_data
    test_data=$(parse_test_file "$test_file")
    
    local address endpoint requests responses options
    address=$(echo "$test_data" | jq -r '.address')
    endpoint=$(echo "$test_data" | jq -r '.endpoint')
    requests=$(echo "$test_data" | jq -r '.request')
    responses=$(echo "$test_data" | jq -r '.response')
    # ASSERT section removed - use ASSERTS instead
    options=$(extract_section "$test_file" "OPTIONS")
    
    if [[ -z "$address" || -z "$endpoint" ]]; then
        log error "Invalid test file: missing address or endpoint"
        return 1
    fi

    # Show configuration like v0.0.13 (only in progress=none mode)
    if [[ "${PROGRESS_MODE:-none}" == "none" ]]; then
        echo "ℹ️ Configuration:"
        echo "ℹ️   ADDRESS: $address"
        echo "ℹ️   ENDPOINT: $endpoint"
        if [[ "$requests" != "null" && -n "$requests" ]]; then
            echo "ℹ️   REQUEST: $(echo "$requests" | jq -c .)"
        fi
        if [[ "$responses" != "null" && -n "$responses" ]]; then
            echo "ℹ️   RESPONSE: $(echo "$responses" | jq -c .)"
        fi
        echo "ℹ️ Executing gRPC request to $address..."
    fi

    # Execute the test with timing
    local start_time=$(date +%s)
    if execute_test "$address" "$endpoint" "$requests" "$responses" "" "$options"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ "${PROGRESS_MODE:-none}" == "none" ]]; then
            log success "TEST PASSED: $test_name (${duration}s)"
            echo "ℹ️ Completed: $test_name"
        elif [[ "${PROGRESS_MODE}" == "dots" ]]; then
            echo -n "."
        fi
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ "${PROGRESS_MODE:-none}" == "none" ]]; then
            log error "TEST FAILED: $test_name (${duration}s)"
        elif [[ "${PROGRESS_MODE}" == "dots" ]]; then
            echo -n "F"
            echo ""
            echo " ───[ Test: $test_name ]───"
            echo "ℹ️ Configuration:"
            echo "ℹ️   ADDRESS: $address"
            echo "ℹ️   ENDPOINT: $endpoint"
            # Show detailed error info in dots mode too
        fi
        return 1
    fi
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
        
        # Generate JUnit XML if requested (workaround for execution flow issue)
        if [[ -n "$JUNIT_OUTPUT_FILE" ]]; then
            echo "ℹ️ Generating JUnit XML report: $JUNIT_OUTPUT_FILE" >&2
            local actual_passed="$passed"
            local actual_failed="$failed"
            generate_junit_xml "$JUNIT_OUTPUT_FILE" "$actual_passed" "$actual_failed" "$total" "$4" "${ALL_TEST_FILES[@]}"
        fi
        return 1
    fi
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
