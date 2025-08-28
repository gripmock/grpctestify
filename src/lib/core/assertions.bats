#!/usr/bin/env bats

# assertions.bats - Tests for assertions.sh module

# Load test helper which loads grpctestify.sh functions
source "${BATS_TEST_DIRNAME}/test_helper.bash"

@test "extract_asserts function extracts assertions correctly" {
    # Create test file
    local test_file=$(mktemp)
    cat > "$test_file" << 'EOF'
--- ASSERTS ---
.message == "Hello, World!"
.status == 0
--- OTHER ---
some other content
EOF

    run extract_asserts "$test_file"
    [ $status -eq 0 ]
    [[ "$output" =~ ".message == \"Hello, World!\"" ]]
    [[ "$output" =~ ".status == 0" ]]
    
    # Clean up
    rm -f "$test_file"
}

@test "evaluate_asserts function evaluates assertions correctly" {
    # Test with valid JSON and assertions
    local assertions=".message == \"Hello\" && .status == 200"
    local response='{"message": "Hello", "status": 200}'
    
    run evaluate_asserts "$assertions" "$response"
    [ $status -eq 0 ]
}