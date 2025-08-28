#!/usr/bin/env bats

# with_asserts.bats - Tests for with_asserts functionality

# Load modules
load "${BATS_TEST_DIRNAME}/parser.sh"
load "${BATS_TEST_DIRNAME}/utils.sh"

@test "parse_inline_options handles with_asserts flag correctly" {
    # Test standalone flag
    run parse_inline_options "--- RESPONSE with_asserts ---"
    [ $status -eq 0 ]
    [[ "$output" =~ "with_asserts=true" ]]
    
    # Test explicit true value
    run parse_inline_options "--- RESPONSE with_asserts=true ---"
    [ $status -eq 0 ]
    [[ "$output" =~ "with_asserts=true" ]]
    
    # Test explicit false value
    run parse_inline_options "--- RESPONSE with_asserts=false ---"
    [ $status -eq 0 ]
    [[ "$output" =~ "with_asserts=false" ]]
}

@test "parse_inline_options handles multiple options with with_asserts" {
    run parse_inline_options "--- RESPONSE with_asserts type=exact ---"
    [ $status -eq 0 ]
    [[ "$output" =~ "with_asserts=true" ]]
    [[ "$output" =~ "type=exact" ]]
}

@test "extract_section_header extracts RESPONSE header correctly" {
    # Create test file
    local test_file=$(mktemp)
    cat > "$test_file" << 'EOF'
--- ENDPOINT ---
test.Service/Method

--- RESPONSE with_asserts ---
{"message": "test"}

--- ASSERTS ---
.message == "test"
EOF
    
    run extract_section_header "$test_file" "RESPONSE"
    [ $status -eq 0 ]
    [[ "$output" =~ "--- RESPONSE with_asserts ---" ]]
    
    # Cleanup
    rm -f "$test_file"
}

@test "parse_inline_options handles complex combinations" {
    run parse_inline_options "--- RESPONSE with_asserts type=partial tolerance[.value]=0.1 ---"
    [ $status -eq 0 ]
    [[ "$output" =~ "with_asserts=true" ]]
    [[ "$output" =~ "type=partial" ]]
    [[ "$output" =~ "tolerance[.value]=0.1" ]]
}
