#!/usr/bin/env bats

# utils.bats - Tests for utils.sh module

setup() {
    # Load the module under test
    source "${BATS_TEST_DIRNAME}/utils.sh"
    
    # Mock log function for testing
    log() {
        echo "$@" >&2
    }
    export -f log
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

@test "expand_tilde handles tilde expansion" {
    run expand_tilde "~/test"
    [ $status -eq 0 ]
    # Should expand tilde to home directory
    [[ "$output" =~ "$HOME" ]]
}

@test "expand_tilde handles path without tilde" {
    run expand_tilde "/absolute/path"
    [ $status -eq 0 ]
    [[ "$output" == "/absolute/path" ]]
}

@test "ensure_directory creates directory if needed" {
    local test_dir="${BATS_TMPDIR}/test_utils_dir"
    
    run ensure_directory "$test_dir"
    [ $status -eq 0 ]
    [ -d "$test_dir" ]
    
    # Cleanup
    rmdir "$test_dir"
}

@test "ensure_directory handles existing directory" {
    local test_dir="${BATS_TMPDIR}/existing_dir"
    mkdir -p "$test_dir"
    
    run ensure_directory "$test_dir"
    [ $status -eq 0 ]
    [ -d "$test_dir" ]
    
    # Cleanup
    rmdir "$test_dir"
}