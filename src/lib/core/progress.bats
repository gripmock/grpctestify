#!/usr/bin/env bats

# progress.bats - Tests for progress.sh module

# Load the progress module
load "${BATS_TEST_DIRNAME}/progress.sh"

@test "print_progress function works with different modes" {
    # Test dots mode
    run print_progress "." "dots"
    [ $status -eq 0 ]
    
    # Test different character in dots mode
    run print_progress "F" "dots"
    [ $status -eq 0 ]
    
    # Test none mode
    run print_progress "." "none"
    [ $status -eq 0 ]
}

@test "print_progress_summary function works correctly" {
    # Test progress summary
    run print_progress_summary 10 8 2
    [ $status -eq 0 ]
    [[ "$output" =~ "10" ]]
    [[ "$output" =~ "8" ]]
    [[ "$output" =~ "2" ]]
}
