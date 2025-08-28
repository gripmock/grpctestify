#!/usr/bin/env bats

# assertions.bats - Tests for assertions.sh module

# Load the assertions module
load "/load "${BATS_TEST_DIRNAME}/assertions.sh'"

@test "extract_asserts function extracts assertions correctly" {
    # Create test file
    local test_file=$(mktemp)
    cat > "$test_file" << 'EOF'
--- ASSERTS ---
.message == "Hello, World!"
.status == 0
EOF
    
    # Test assertion extraction
    run extract_asserts "$test_file"
    [ $status -eq 0 ]
    [[ "$output" =~ "Hello, World!" ]]
    
    # Cleanup
    rm -f "$test_file"
}

@test "evaluate_asserts function evaluates assertions correctly" {
    # Test assertion evaluation
    local response='{"message": "Hello, World!", "status": 0}'
    local asserts='.message == "Hello, World!"
.status == 0'
    
    run evaluate_asserts "$asserts" "$response"
    [ $status -eq 0 ]
}

@test "evaluate_asserts_indexed function evaluates indexed assertions" {
    # Test indexed assertion evaluation
    local responses='[{"message": "First"}, {"message": "Second"}]'
    local asserts='[1] .message == "First"
[2] .message == "Second"'
    
    run evaluate_asserts_indexed "$asserts" "$responses"
    [ $status -eq 0 ]
}

@test "evaluate_all_asserts function evaluates all assertion types" {
    # Test all assertion types
    local response='{"message": "Hello, World!", "status": 0}'
    local asserts='.message == "Hello, World!"
.status == 0'
    
    run evaluate_all_asserts "$asserts" "$response"
    [ $status -eq 0 ]
}