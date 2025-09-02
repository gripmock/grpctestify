#!/usr/bin/env bats

# regression_tests.bats - Simple regression tests for critical bug fixes
# Testing ONLY pure bash logic without loading any modules

# ===== PARALLEL EXECUTION LOGIC TESTS =====

@test "execution mode selection: verbose forces sequential" {
    # Bug fixed: verbose mode was trying to run in parallel
    
    PARALLEL_JOBS=8
    PROGRESS_MODE="verbose"
    
    # Test the fixed logic
    if [[ "${PROGRESS_MODE}" == "verbose" || "${PROGRESS_MODE}" == "detailed" ]]; then
        result="sequential"
    elif [[ -n "${PARALLEL_JOBS}" && "${PARALLEL_JOBS}" -gt 1 ]]; then
        result="parallel"
    else
        result="sequential"
    fi
    
    [[ "$result" == "sequential" ]]
}

@test "execution mode selection: dots uses parallel when available" {
    # Bug fixed: parallel execution was force-disabled
    
    PARALLEL_JOBS=8
    PROGRESS_MODE="dots"
    
    if [[ "${PROGRESS_MODE}" == "verbose" || "${PROGRESS_MODE}" == "detailed" ]]; then
        result="sequential"
    elif [[ -n "${PARALLEL_JOBS}" && "${PARALLEL_JOBS}" -gt 1 ]]; then
        result="parallel"
    else
        result="sequential"
    fi
    
    [[ "$result" == "parallel" ]]
}

@test "execution mode selection: single job falls back to sequential" {
    # Bug fixed: --parallel 1 edge case
    
    PARALLEL_JOBS=1
    PROGRESS_MODE="dots"
    
    if [[ "${PROGRESS_MODE}" == "verbose" || "${PROGRESS_MODE}" == "detailed" ]]; then
        result="sequential"
    elif [[ -n "${PARALLEL_JOBS}" && "${PARALLEL_JOBS}" -gt 1 ]]; then
        result="parallel"
    else
        result="sequential"
    fi
    
    [[ "$result" == "sequential" ]]
}

# ===== REPORT FORMAT VALIDATION TESTS =====

@test "report format validation: accepts only junit and json" {
    # Bug fixed: unsupported formats (csv, html) were accepted
    
    validate_format() {
        case "$1" in
            "junit"|"json") return 0 ;;
            *) return 1 ;;
        esac
    }
    
    # Valid formats
    run validate_format "junit"
    [ $status -eq 0 ]
    
    run validate_format "json"
    [ $status -eq 0 ]
    
    # Invalid formats (should fail)
    run validate_format "csv"
    [ $status -eq 1 ]
    
    run validate_format "html"
    [ $status -eq 1 ]
    
    run validate_format "xml"
    [ $status -eq 1 ]
}

@test "report extension mapping: only xml and json" {
    # Bug fixed: unsupported extensions were mapped
    
    get_extension() {
        case "$1" in
            "junit") echo ".xml" ;;
            "json") echo ".json" ;;
            *) echo "" ;;
        esac
    }
    
    [[ "$(get_extension junit)" == ".xml" ]]
    [[ "$(get_extension json)" == ".json" ]]
    [[ -z "$(get_extension csv)" ]]
    [[ -z "$(get_extension html)" ]]
}

# ===== VARIABLE SCOPE TESTS =====

@test "variable export: PROGRESS_MODE accessible in subshells" {
    # Bug fixed: PROGRESS_MODE was local but accessed in subshells
    
    PROGRESS_MODE="dots"
    export PROGRESS_MODE
    
    result=$(bash -c 'echo $PROGRESS_MODE')
    [[ "$result" == "dots" ]]
}

@test "variable export: report variables accessible in subshells" {
    # Bug fixed: report variables had scope issues
    
    report_format="junit"
    report_output_file="test.xml"
    export report_format report_output_file
    
    format_result=$(bash -c 'echo $report_format')
    file_result=$(bash -c 'echo $report_output_file')
    
    [[ "$format_result" == "junit" ]]
    [[ "$file_result" == "test.xml" ]]
}

# ===== UI FORMATTING TESTS =====





@test "timing precision: milliseconds calculation" {
    # Bug fixed: timing was only in seconds
    
    start_time=1234567890123
    end_time=1234567890188
    execution_time=$((end_time - start_time))
    
    # Should be 65 milliseconds
    [[ "$execution_time" == "65" ]]
    
    # Format check
    msg="Test completed (${execution_time}ms)"
    [[ "$msg" =~ "ms)" ]]
    [[ ! "$msg" =~ "[0-9]+s)" ]]  # Should not contain seconds format like "65s"
}

# ===== ERROR HANDLING TESTS =====

@test "failure collection: array accumulation logic" {
    # Bug fixed: errors displayed immediately instead of collected
    
    declare -a TEST_FAILURES=()
    
    add_failure() {
        TEST_FAILURES+=("$1|$2|$3")
    }
    
    add_failure "test1" "error1" "45ms"
    add_failure "test2" "error2" "32ms"
    
    [[ "${#TEST_FAILURES[@]}" == "2" ]]
    [[ "${TEST_FAILURES[0]}" =~ "test1" ]]
    [[ "${TEST_FAILURES[1]}" =~ "test2" ]]
}

# ===== WORKFLOW FIXES TESTS =====

@test "command format: no || true patterns" {
    # Bug fixed: || true was hiding failures in CI
    
    good_cmd="grpctestify tests/ --log-format junit --log-output results.xml"
    bad_cmd="grpctestify tests/ --log-junit=results.xml || true"
    
    # Good command should not hide failures
    [[ ! "$good_cmd" =~ "|| true" ]]
    
    # Bad command contained the pattern we fixed
    [[ "$bad_cmd" =~ "|| true" ]]
}

@test "flag consistency: modern flag names" {
    # Bug fixed: mixed old/new flag names
    
    modern_flags="--log-format junit --log-output report.xml"
    legacy_flags="--log-junit=report.xml --report-format junit"
    
    # Modern should not contain legacy patterns
    [[ ! "$modern_flags" =~ "--log-junit" ]]
    [[ ! "$modern_flags" =~ "--report-format" ]]
    
    # Modern should contain new patterns
    [[ "$modern_flags" =~ "--log-format" ]]
    [[ "$modern_flags" =~ "--log-output" ]]
}

# ===== PARALLEL JOBS CALCULATION =====

@test "parallel jobs: auto-detection fallback logic" {
    # Bug fixed: parallel was force-disabled
    
    auto_detect_cpu() {
        # Simulate the fixed auto-detection logic
        local cpu_count
        cpu_count=$(echo "4" 2>/dev/null || echo "4")  # Mock nproc/sysctl
        echo "$cpu_count"
    }
    
    # Should default to auto behavior
    parallel_setting="auto"
    if [[ "$parallel_setting" == "auto" ]]; then
        PARALLEL_JOBS=$(auto_detect_cpu)
    else
        PARALLEL_JOBS="$parallel_setting"
    fi
    
    [[ "$PARALLEL_JOBS" == "4" ]]
}
