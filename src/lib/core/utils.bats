#!/usr/bin/env bats

# utils.bats - Tests for utils.sh module

# Load dependencies
load "${BATS_TEST_DIRNAME}/colors.sh"

# Load the utils module
load "${BATS_TEST_DIRNAME}/utils.sh"

# Mock log function for testing
log() {
    echo "$@" >&2
}

@test "process_line removes comments correctly" {
    run process_line "echo 'hello' # this is a comment"
    [ $status -eq 0 ]
    [[ "$output" == "echo 'hello' " ]]
}

@test "process_line preserves quotes with # inside" {
    run process_line "echo 'hello # world'"
    [ $status -eq 0 ]
    [[ "$output" == "echo 'hello # world'" ]]
}

@test "process_line handles escaped characters" {
    run process_line "echo 'hello \\' world' # comment"
    [ $status -eq 0 ]
    [[ "$output" == "echo 'hello \\' world' " ]]
}

@test "process_line handles empty line" {
    run process_line ""
    [ $status -eq 0 ]
    [[ "$output" == "" ]]
}

@test "process_line handles line with only comment" {
    run process_line "# this is only a comment"
    [ $status -eq 0 ]
    [[ "$output" == "" ]]
}

@test "trim_whitespace removes leading and trailing spaces" {
    run trim_whitespace "  hello world  "
    [ $status -eq 0 ]
    [[ "$output" == "hello world" ]]
}

@test "trim_whitespace handles empty string" {
    run trim_whitespace ""
    [ $status -eq 0 ]
    [[ "$output" == "" ]]
}

@test "trim_whitespace handles string with only whitespace" {
    run trim_whitespace "   "
    [ $status -eq 0 ]
    [[ "$output" == "" ]]
}

@test "is_empty_or_whitespace returns true for empty strings" {
    run is_empty_or_whitespace ""
    [ $status -eq 0 ]
    
    run is_empty_or_whitespace "   "
    [ $status -eq 0 ]
}

@test "is_empty_or_whitespace returns false for non-empty strings" {
    run is_empty_or_whitespace "hello"
    [ $status -eq 1 ]
    
    run is_empty_or_whitespace "  hello  "
    [ $status -eq 1 ]
}

@test "get_file_extension extracts extension correctly" {
    run get_file_extension "test.txt"
    [ $status -eq 0 ]
    [[ "$output" == "txt" ]]
    
    run get_file_extension "archive.tar.gz"
    [ $status -eq 0 ]
    [[ "$output" == "gz" ]]
}

@test "get_file_extension handles files without extension" {
    run get_file_extension "filename"
    [ $status -eq 0 ]
    [[ "$output" == "" ]]
}

@test "get_filename_without_extension works correctly" {
    run get_filename_without_extension "test.txt"
    [ $status -eq 0 ]
    [[ "$output" == "test" ]]
    
    run get_filename_without_extension "filename"
    [ $status -eq 0 ]
    [[ "$output" == "filename" ]]
}

@test "sanitize_string cleans input" {
    run sanitize_string "hello world!"
    [ $status -eq 0 ]
    # Should return some sanitized version
    [ -n "$output" ]
}

@test "command_exists detects existing commands" {
    run command_exists "echo"
    [ $status -eq 0 ]
    
    run command_exists "nonexistent_command_xyz"
    [ $status -eq 1 ]
}

@test "get_timestamp returns timestamp" {
    run get_timestamp
    [ $status -eq 0 ]
    # Should return a timestamp
    [ -n "$output" ]
}

# Removed tests for deleted functions (to_lowercase, to_uppercase, contains_string)

@test "expand_tilde handles tilde expansion" {
    run expand_tilde "~/test"
    [ $status -eq 0 ]
    # Should expand ~ to home directory
    [[ "$output" =~ ^/ ]]
}

@test "get_random_string generates string" {
    run get_random_string 10
    [ $status -eq 0 ]
    [ ${#output} -eq 10 ]
}

@test "is_readable_file checks file readability" {
    # Create temporary file
    local temp_file="${BATS_TMPDIR}/readable_test"
    echo "test" > "$temp_file"
    
    run is_readable_file "$temp_file"
    [ $status -eq 0 ]
    
    run is_readable_file "/nonexistent/file"
    [ $status -eq 1 ]
    
    # Clean up
    rm -f "$temp_file"
}

@test "is_writable_dir checks directory writability" {
    run is_writable_dir "${BATS_TMPDIR}"
    [ $status -eq 0 ]
    
    run is_writable_dir "/nonexistent/dir"
    [ $status -eq 1 ]
}

@test "ensure_directory creates directory" {
    local test_dir="${BATS_TMPDIR}/ensure_test"
    
    run ensure_directory "$test_dir"
    [ $status -eq 0 ]
    [ -d "$test_dir" ]
    
    # Clean up
    rmdir "$test_dir"
}

@test "error functions work correctly" {
    run error_required "test_field"
    [ $status -eq 1 ]
    [[ "$output" =~ "required" ]]
    
    run error_missing "test_file"
    [ $status -eq 1 ]
    [[ "$output" =~ "missing" ]]
    
    run error_invalid "test_value"
    [ $status -eq 1 ]
    [[ "$output" =~ "invalid" ]]
}