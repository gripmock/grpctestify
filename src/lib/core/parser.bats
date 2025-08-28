#!/usr/bin/env bats

# parser.bats - Tests for parser.sh module

# Load the parser module
load "${BATS_TEST_DIRNAME}/parser.sh"

@test "extract_section function extracts sections correctly" {
    # Create test file
    local test_file=$(mktemp)
    cat > "$test_file" << 'EOF'
--- ENDPOINT ---
localhost:4770

--- REQUEST ---
{"name": "test"}

--- RESPONSE ---
{"message": "Hello, test!"}
EOF
    
    # Test endpoint extraction
    run extract_section "$test_file" "ENDPOINT"
    [ $status -eq 0 ]
    [[ "$output" =~ "localhost:4770" ]]
    
    # Test request extraction
    run extract_section "$test_file" "REQUEST"
    [ $status -eq 0 ]
    [[ "$output" =~ "test" ]]
    
    # Test response extraction
    run extract_section "$test_file" "RESPONSE"
    [ $status -eq 0 ]
    [[ "$output" =~ "Hello, test!" ]]
    
    # Cleanup
    rm -f "$test_file"
}

@test "parse_test_file function parses test files correctly" {
    # Create test file
    local test_file=$(mktemp)
    cat > "$test_file" << 'EOF'
--- ENDPOINT ---
localhost:4770

--- REQUEST ---
{"name": "test"}

--- RESPONSE ---
{"message": "Hello, test!"}
EOF
    
    # Test file parsing
    run parse_test_file "$test_file"
    [ $status -eq 0 ]
    
    # Cleanup
    rm -f "$test_file"
}

@test "parse_inline_options function parses inline options" {
    # Test inline options parsing
    run parse_inline_options "tolerance=0.1,redact=password"
    [ $status -eq 0 ]
}