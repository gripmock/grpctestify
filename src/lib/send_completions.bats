#!/usr/bin/env bats

# send_completions.bats - Tests for send_completions.sh module

# Load the send_completions module
load "${BATS_TEST_DIRNAME}/send_completions.sh"

@test "send_completions generates bash completion script" {
    run send_completions
    [ $status -eq 0 ]
    
    # Check for bash completion header
    [[ "$output" =~ "# grpctestify completion" ]]
    [[ "$output" =~ "shell-script" ]]
}

@test "send_completions includes completion functions" {
    run send_completions
    [ $status -eq 0 ]
    
    # Check for required completion functions
    [[ "$output" =~ "_grpctestify_completions_filter" ]]
    [[ "$output" =~ "_grpctestify_completions" ]]
    [[ "$output" =~ "complete -F _grpctestify_completions grpctestify" ]]
}

@test "send_completions includes standard completion logic" {
    run send_completions
    [ $status -eq 0 ]
    
    # Check for completion variables and logic
    [[ "$output" =~ "COMP_WORDS" ]]
    [[ "$output" =~ "COMP_CWORD" ]]
    [[ "$output" =~ "compgen" ]]
}

@test "send_completions includes flag filtering" {
    run send_completions
    [ $status -eq 0 ]
    
    # Check for completion filtering logic (more generic check)
    [[ "$output" =~ "_grpctestify_completions_filter" ]]
}

@test "send_completions includes completion cases" {
    run send_completions
    [ $status -eq 0 ]
    
    # Check for case statements handling different commands
    [[ "$output" =~ "case" ]]
    [[ "$output" =~ "esac" ]]
}

@test "send_completions output is valid bash syntax" {
    # Generate completions and try to parse as bash
    local completion_script
    completion_script=$(send_completions)
    
    # Write to temporary file and check syntax
    local temp_file="${BATS_TMPDIR}/completion_test.sh"
    echo "$completion_script" > "$temp_file"
    
    # Check bash syntax
    run bash -n "$temp_file"
    [ $status -eq 0 ]
    
    # Clean up
    rm -f "$temp_file"
}

@test "send_completions includes help text references" {
    run send_completions
    [ $status -eq 0 ]
    
    # Check for references to bashly/completely
    [[ "$output" =~ "completely" ]]
    [[ "$output" =~ "bashly-framework" ]]
}

@test "send_completions generates non-empty output" {
    run send_completions
    [ $status -eq 0 ]
    [ -n "$output" ]
    
    # Should be substantial completion script
    [ ${#output} -gt 1000 ]
}

@test "send_completions includes proper completion registration" {
    run send_completions
    [ $status -eq 0 ]
    
    # Should register completion for grpctestify command
    [[ "$output" =~ "complete -F _grpctestify_completions grpctestify" ]]
}

@test "send_completions output format is consistent" {
    # Run multiple times to ensure consistent output
    local output1 output2
    output1=$(send_completions)
    output2=$(send_completions)
    
    [ "$output1" = "$output2" ]
}
