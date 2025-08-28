#!/usr/bin/env bats

# help.bats - Tests for help.sh module

# Load the help module
load "/load "${BATS_TEST_DIRNAME}/help.sh'"

@test "show_help function shows help information" {
    # Test help display
    run show_help
    [ $status -eq 0 ]
    [[ "$output" =~ "grpctestify" ]]
}

@test "show_version function shows version information" {
    # Test version display
    run show_version
    [ $status -eq 0 ]
    [[ "$output" =~ "version" ]]
}

@test "show_update_help function shows update help" {
    # Test update help display
    run show_update_help
    [ $status -eq 0 ]
    [[ "$output" =~ "update" ]]
}

@test "show_completion_help function shows completion help" {
    # Test completion help display
    run show_completion_help
    [ $status -eq 0 ]
    [[ "$output" =~ "completion" ]]
}