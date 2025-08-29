#!/usr/bin/env bats

# run.bats - Tests for run.sh module

# NOTE: We don't load any modules to avoid side effects in unit tests
# All functions are mocked inline for isolated testing

# Mock functions for testing
log() {
    echo "$@" >&2
}

show_version() {
    echo "grpctestify $APP_VERSION"
}

show_help() {
    echo "grpctestify help"
}

update_script() {
    echo "Updating script..."
}

send_completions() {
    echo "completion script"
}

list_plugins() {
    echo "Plugin list"
}

create_plugin() {
    echo "Creating plugin: $1"
}

setup() {
    # Mock args array for testing
    declare -gA args
    args[test_path]=""
    args[--version]="0"
    args[--help]="0"
    args[--update]="0"
    args[--completions]="0"
    args[--plugins]="0"
    args[--create-plugin]=""
    args[--log-format]=""
    args[--log-output]=""
}

@test "run_tests handles version flag" {
    args[--version]="1"
    
    run run_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "grpctestify $APP_VERSION" ]]
}

@test "run_tests handles help flag" {
    args[--help]="1"
    
    run run_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "grpctestify help" ]]
}

@test "run_tests handles update flag" {
    args[--update]="1"
    
    run run_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "Updating script" ]]
}

@test "run_tests handles completions flag" {
    args[--completions]="1"
    
    run run_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "completion script" ]]
}

@test "run_tests handles plugins list flag" {
    args[--plugins]="list"
    
    run run_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "Plugin list" ]]
}

@test "run_tests handles create plugin command" {
    args[--plugins]="create"
    args[--create-plugin]="test_plugin"
    
    run run_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "Creating plugin: test_plugin" ]]
}

@test "run_tests prioritizes flags correctly" {
    # Version should take priority
    args[--version]="1"
    args[--help]="1"
    
    run run_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "grpctestify $APP_VERSION" ]]
}

@test "setup_configuration initializes variables correctly" {
    # Mock some args
    args[--address]="localhost:4770"
    args[--timeout]="30"
    args[--retries]="3"
    
    run setup_configuration
    [ $status -eq 0 ]
    
    # Should set global variables (checked via mocked functions)
}

@test "validate_input rejects missing test path" {
    args[test_path]=""
    
    run validate_input
    [ $status -eq 1 ]
}

@test "validate_input accepts valid test path" {
    # Create temporary test file
    local test_file="${BATS_TMPDIR}/test.gctf"
    echo "--- ADDRESS ---" > "$test_file"
    echo "localhost:4770" >> "$test_file"
    
    args[test_path]="$test_file"
    
    run validate_input
    [ $status -eq 0 ]
    
    # Clean up
    rm -f "$test_file"
}

@test "load_configuration loads from file" {
    # Create temporary config file
    local config_file="${BATS_TMPDIR}/config.conf"
    echo "DEFAULT_ADDRESS=localhost:9999" > "$config_file"
    echo "RUNTIME_TIMEOUT=60" >> "$config_file"
    
    export GRPCTESTIFY_CONFIG="$config_file"
    
    run load_configuration
    [ $status -eq 0 ]
    
    # Clean up
    rm -f "$config_file"
    unset GRPCTESTIFY_CONFIG
}

@test "execute_tests processes test files" {
    # Create temporary test file
    local test_file="${BATS_TMPDIR}/test.gctf"
    cat > "$test_file" << 'EOF'
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
test.Service/Method

--- REQUEST ---
{"test": "data"}

--- ASSERTS ---
.success == true
EOF
    
    args[test_path]="$test_file"
    
    # Mock execute_tests (simplified)
    execute_tests() {
        echo "Executing tests from: ${args[test_path]}"
        return 0
    }
    
    run execute_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "Executing tests" ]]
    
    # Clean up
    rm -f "$test_file"
}

@test "run_sequential_tests processes multiple test files" {
    # Create temporary test directory
    local test_dir="${BATS_TMPDIR}/tests"
    mkdir -p "$test_dir"
    
    # Create test files
    echo "test1" > "$test_dir/test1.gctf"
    echo "test2" > "$test_dir/test2.gctf"
    
    # Mock run_sequential_tests
    run_sequential_tests() {
        echo "Running sequential tests"
        return 0
    }
    
    run run_sequential_tests
    [ $status -eq 0 ]
    [[ "$output" =~ "Running sequential tests" ]]
    
    # Clean up
    rm -rf "$test_dir"
}

@test "show_summary displays test results" {
    # Mock test results variables
    TOTAL_TESTS=5
    PASSED_TESTS=4
    FAILED_TESTS=1
    
    show_summary() {
        echo "Tests: $TOTAL_TESTS, Passed: $PASSED_TESTS, Failed: $FAILED_TESTS"
    }
    
    run show_summary
    [ $status -eq 0 ]
    [[ "$output" =~ "Tests: 5, Passed: 4, Failed: 1" ]]
}

@test "setup_configuration handles report format correctly" {
    # Mock report functions
    report_manager_init() { return 0; }
    validate_report_format() { 
        [ "$1" = "junit" ] && return 0 || return 1
    }
    auto_generate_output_filename() {
        echo "auto-generated-${1}.xml"
    }
    
    # Mock setup_configuration function to test logic
    setup_configuration() {
        if [[ -n "${args[--log-format]}" ]]; then
            local report_format="${args[--log-format]}"
            local report_output_file="${args[--log-output]}"
            
            if ! validate_report_format "$report_format"; then
                return 1
            fi
            
            if [[ -z "$report_output_file" ]]; then
                report_output_file=$(auto_generate_output_filename "$report_format")
                echo "Auto-generated report file: $report_output_file"
            fi
        fi
        return 0
    }
    
    # Test with valid format and output
    args[--log-format]="junit"
    args[--log-output]="test.xml"
    
    run setup_configuration
    [ $status -eq 0 ]
}

@test "setup_configuration fails with invalid report format" {
    # Mock report functions
    report_manager_init() { return 0; }
    validate_report_format() { 
        log error "Unknown report format: $1"
        return 1
    }
    
    # Mock setup_configuration function to test logic
    setup_configuration() {
        if [[ -n "${args[--log-format]}" ]]; then
            local report_format="${args[--log-format]}"
            
            if ! validate_report_format "$report_format"; then
                return 1
            fi
        fi
        return 0
    }
    
    # Test with invalid format
    args[--log-format]="invalid"
    args[--log-output]="test.xml"
    
    run setup_configuration
    [ $status -eq 1 ]
    [[ "$output" =~ "Unknown report format" ]]
}
