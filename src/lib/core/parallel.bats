#!/usr/bin/env bats

# parallel.bats - Tests for parallel.sh module

# Load test helper which loads grpctestify.sh functions
source "${BATS_TEST_DIRNAME}/test_helper.bash"

@test "run_test_with_timeout function runs tests with timeout" {
    # Test timeout functionality
    local temp_file=$(mktemp)
    echo 'echo "test"' > "$temp_file"
    
    run run_test_with_timeout "$temp_file" 5 "$temp_file.result"
    [ $status -eq 0 ]
    
    # Cleanup
    rm -f "$temp_file" "$temp_file.result"
}

@test "get_optimal_parallel_jobs function gets optimal parallel jobs" {
    # Test optimal parallel jobs calculation
    run get_optimal_parallel_jobs
    [ $status -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "run_test_parallel function runs tests in parallel" {
    # Test parallel test execution
    local temp_file=$(mktemp)
    echo 'echo "test"' > "$temp_file"
    
    run run_test_parallel "$temp_file" 2
    [ $status -eq 0 ]
    
    # Cleanup
    rm -f "$temp_file"
}

@test "discover_test_files finds test files in directory" {
    # Create temporary test directory structure
    local temp_dir=$(mktemp -d)
    local subdir="$temp_dir/subdir"
    mkdir -p "$subdir"
    
    # Create test files
    touch "$temp_dir/test1.gctf"
    touch "$temp_dir/test2.gctf"
    touch "$subdir/test3.gctf"
    touch "$temp_dir/notest.txt"  # Non-test file
    
    # Test discovery
    run discover_test_files "$temp_dir"
    [ $status -eq 0 ]
    
    # Should find 3 test files
    local count=$(echo "$output" | wc -l)
    [ $count -eq 3 ]
    
    # Should contain all test files
    [[ "$output" =~ "test1.gctf" ]]
    [[ "$output" =~ "test2.gctf" ]]
    [[ "$output" =~ "subdir/test3.gctf" ]]
    
    # Cleanup
    rm -rf "$temp_dir"
}

@test "discover_test_files handles single file" {
    # Create temporary test file
    local temp_file=$(mktemp --suffix=.gctf)
    
    # Test discovery
    run discover_test_files "$temp_file"
    [ $status -eq 0 ]
    [ "$output" = "$temp_file" ]
    
    # Cleanup
    rm -f "$temp_file"
}

@test "discover_test_files handles non-test file" {
    # Create temporary non-test file
    local temp_file=$(mktemp --suffix=.txt)
    
    # Test discovery
    run discover_test_files "$temp_file"
    [ $status -eq 0 ]
    [ -z "$output" ]
    
    # Cleanup
    rm -f "$temp_file"
}

@test "discover_and_categorize_tests categorizes tests by directory" {
    # Create temporary test directory structure
    local temp_dir=$(mktemp -d)
    local basic_dir="$temp_dir/basic"
    local advanced_dir="$temp_dir/advanced"
    mkdir -p "$basic_dir" "$advanced_dir"
    
    # Create test files in different categories
    touch "$basic_dir/test1.gctf"
    touch "$basic_dir/test2.gctf"
    touch "$advanced_dir/test3.gctf"
    
    # Test categorization
    run discover_and_categorize_tests "$temp_dir"
    [ $status -eq 0 ]
    
    # Should find 3 test files
    local count=$(echo "$output" | wc -l)
    [ $count -eq 3 ]
    
    # Should show categorization in output
    [[ "$output" =~ "Category 'basic': 2 tests" ]]
    [[ "$output" =~ "Category 'advanced': 1 tests" ]]
    
    # Cleanup
    rm -rf "$temp_dir"
}

@test "discover_tests_with_filters applies include filter" {
    # Create temporary test directory structure
    local temp_dir=$(mktemp -d)
    touch "$temp_dir/auth_test.gctf"
    touch "$temp_dir/user_test.gctf"
    touch "$temp_dir/other_test.gctf"
    
    # Set filter to only include auth tests
    export TEST_FILTER="auth"
    
    # Test filtering
    run discover_tests_with_filters "$temp_dir"
    [ $status -eq 0 ]
    
    # Should only find auth test
    local count=$(echo "$output" | wc -l)
    [ $count -eq 1 ]
    [[ "$output" =~ "auth_test.gctf" ]]
    
    # Cleanup
    unset TEST_FILTER
    rm -rf "$temp_dir"
}

@test "discover_tests_with_filters applies exclude filter" {
    # Create temporary test directory structure
    local temp_dir=$(mktemp -d)
    touch "$temp_dir/auth_test.gctf"
    touch "$temp_dir/user_test.gctf"
    touch "$temp_dir/other_test.gctf"
    
    # Set exclude filter to exclude auth tests
    export TEST_EXCLUDE="auth"
    
    # Test filtering
    run discover_tests_with_filters "$temp_dir"
    [ $status -eq 0 ]
    
    # Should find 2 tests (excluding auth)
    local count=$(echo "$output" | wc -l)
    [ $count -eq 2 ]
    [[ ! "$output" =~ "auth_test.gctf" ]]
    
    # Cleanup
    unset TEST_EXCLUDE
    rm -rf "$temp_dir"
}

@test "discover_tests_with_filters applies depth filter" {
    # Create temporary test directory structure
    local temp_dir=$(mktemp -d)
    local subdir="$temp_dir/subdir"
    local deepdir="$subdir/deep"
    mkdir -p "$deepdir"
    
    # Create test files at different depths
    touch "$temp_dir/test1.gctf"  # depth 0
    touch "$subdir/test2.gctf"    # depth 1
    touch "$deepdir/test3.gctf"   # depth 2
    
    # Set max depth to 1
    export TEST_MAX_DEPTH="1"
    
    # Test filtering
    run discover_tests_with_filters "$temp_dir"
    [ $status -eq 0 ]
    
    # Should find 2 tests (depth 0 and 1)
    local count=$(echo "$output" | wc -l)
    [ $count -eq 2 ]
    [[ "$output" =~ "test1.gctf" ]]
    [[ "$output" =~ "subdir/test2.gctf" ]]
    [[ ! "$output" =~ "deep/test3.gctf" ]]
    
    # Cleanup
    unset TEST_MAX_DEPTH
    rm -rf "$temp_dir"
}

@test "discover_tests_with_dependencies analyzes test dependencies" {
    # Create temporary test directory structure
    local temp_dir=$(mktemp -d)
    
    # Create independent test
    cat > "$temp_dir/independent.gctf" << 'EOF'
--- ENDPOINT ---
test
--- REQUEST ---
{}
EOF
    
    # Create dependent test
    cat > "$temp_dir/dependent.gctf" << 'EOF'
--- DEPENDS ---
independent.gctf
--- ENDPOINT ---
test
--- REQUEST ---
{}
EOF
    
    # Test dependency analysis
    run discover_tests_with_dependencies "$temp_dir"
    [ $status -eq 0 ]
    
    # Should find 2 test files
    local count=$(echo "$output" | wc -l)
    [ $count -eq 2 ]
    
    # Should show dependency analysis in output
    [[ "$output" =~ "Independent tests: 1" ]]
    [[ "$output" =~ "Dependent tests: 1" ]]
    [[ "$output" =~ "dependent.gctf depends on: independent.gctf" ]]
    
    # Cleanup
    rm -rf "$temp_dir"
}

@test "optimize_test_execution_order optimizes test order" {
    # Create temporary test directory structure
    local temp_dir=$(mktemp -d)
    
    # Create independent test
    cat > "$temp_dir/independent.gctf" << 'EOF'
--- ENDPOINT ---
test
--- REQUEST ---
{}
EOF
    
    # Create dependent test
    cat > "$temp_dir/dependent.gctf" << 'EOF'
--- DEPENDS ---
independent.gctf
--- ENDPOINT ---
test
--- REQUEST ---
{}
EOF
    
    # Test optimization
    local test_files=("$temp_dir/dependent.gctf" "$temp_dir/independent.gctf")
    run optimize_test_execution_order "${test_files[@]}"
    [ $status -eq 0 ]
    
    # Should return 2 test files
    local count=$(echo "$output" | wc -l)
    [ $count -eq 2 ]
    
    # Independent test should come first
    local first_test=$(echo "$output" | head -n1)
    [[ "$first_test" =~ "independent.gctf" ]]
    
    # Cleanup
    rm -rf "$temp_dir"
}
