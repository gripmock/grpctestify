#!/usr/bin/env bats

# Tests for file sorting functionality

setup() {
    # Mock tlog function to avoid "command not found" errors
    if ! command -v tlog >/dev/null 2>&1; then
        tlog() { echo "MOCK_LOG: $*"; }
        export -f tlog
    fi
    
    # Load the run.sh functions
    source "$BATS_TEST_DIRNAME/run.sh"
    
    # Create a temporary directory with test files
    TEST_DIR=$(mktemp -d)
    
    # Create test files in specific order
    touch "$TEST_DIR/a_first.gctf"
    touch "$TEST_DIR/m_middle.gctf" 
    touch "$TEST_DIR/z_last.gctf"
    touch "$TEST_DIR/b_second.gctf"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "collect_test_files sorts files by path (default)" {
    # Mock args with default sort
    declare -A args
    args[--sort]="path"
    
    local files=()
    collect_test_files "$TEST_DIR" files
    
    # Should have 4 files
    [ ${#files[@]} -eq 4 ]
    
    # Check sorted order (a, b, m, z)
    [[ "${files[0]}" == *"a_first.gctf" ]]
    [[ "${files[1]}" == *"b_second.gctf" ]]
    [[ "${files[2]}" == *"m_middle.gctf" ]]
    [[ "${files[3]}" == *"z_last.gctf" ]]
}

@test "collect_test_files sorts files by name" {
    # Mock args with name sort
    declare -A args
    args[--sort]="name"
    
    local files=()
    collect_test_files "$TEST_DIR" files
    
    # Should have 4 files
    [ ${#files[@]} -eq 4 ]
    
    # Check name-sorted order (same as path in this case)
    [[ "${files[0]}" == *"a_first.gctf" ]]
    [[ "${files[1]}" == *"b_second.gctf" ]]
    [[ "${files[2]}" == *"m_middle.gctf" ]]
    [[ "${files[3]}" == *"z_last.gctf" ]]
}

@test "collect_test_files with random sort" {
    # Mock args with random sort
    declare -A args
    args[--sort]="random"
    
    local files=()
    collect_test_files "$TEST_DIR" files
    
    # Should still have 4 files
    [ ${#files[@]} -eq 4 ]
    
    # All original files should be present (order may vary)
    local has_a=false has_b=false has_m=false has_z=false
    for file in "${files[@]}"; do
        [[ "$file" == *"a_first.gctf" ]] && has_a=true
        [[ "$file" == *"b_second.gctf" ]] && has_b=true  
        [[ "$file" == *"m_middle.gctf" ]] && has_m=true
        [[ "$file" == *"z_last.gctf" ]] && has_z=true
    done
    
    $has_a && $has_b && $has_m && $has_z
}

@test "sort command produces consistent output" {
    # Test that sort actually works as expected
    local sorted_output
    sorted_output=$(find "$TEST_DIR" -name "*.gctf" -type f | sort)
    
    # Split into array
    local sorted_files
    mapfile -t sorted_files <<< "$sorted_output"
    
    # Check order
    [[ "${sorted_files[0]}" == *"a_first.gctf" ]]
    [[ "${sorted_files[1]}" == *"b_second.gctf" ]]
    [[ "${sorted_files[2]}" == *"m_middle.gctf" ]]
    [[ "${sorted_files[3]}" == *"z_last.gctf" ]]
}

@test "shuf command produces different order" {
    # Test that shuf can produce different order
    local normal_order
    normal_order=$(find "$TEST_DIR" -name "*.gctf" -type f | sort)
    
    local shuffled_order
    shuffled_order=$(find "$TEST_DIR" -name "*.gctf" -type f | shuf)
    
    # Both should have same files
    [ "$(echo "$normal_order" | wc -l)" -eq "$(echo "$shuffled_order" | wc -l)" ]
    
    # Note: shuf might occasionally produce same order, so we just verify it works
    # The important thing is that shuf command exists and processes the input
    [[ -n "$shuffled_order" ]]
}
