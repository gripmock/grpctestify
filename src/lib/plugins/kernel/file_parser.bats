#!/usr/bin/env bats

# file_parser.bats - Comprehensive tests for .gctf file parsing
# Tests the core file parsing functionality - CRITICAL component

# Load basic testing utilities

setup() {
    # Source the file parser
    source "$BATS_TEST_DIRNAME/file_parser.sh"
    
    # Mock tlog function
    tlog() {
        echo "TEST LOG [$1]: $2" >&2
    }
    
    # Create temp directory for test files
    TEST_DIR=$(mktemp -d)
    
    # Mock plugin functions for isolated testing
    plugin_register() { return 0; }
    pool_create() { return 0; }
    event_subscribe() { return 0; }
    event_publish() { return 0; }
}

teardown() {
    # Clean up test files
    [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# ===== BASIC PARSING TESTS =====

@test "parse_test_file: valid basic .gctf file" {
    local test_file="$TEST_DIR/basic.gctf"
    cat > "$test_file" << 'EOF'
--- ADDRESS ---
localhost:4770

--- ENDPOINT ---
user.UserService/GetUser

--- REQUEST ---
{
  "user_id": "123"
}

--- RESPONSE ---
{
  "user_id": "123",
  "name": "John Doe"
}
EOF

    run parse_test_file "$test_file"
    [ "$status" -eq 0 ]
    
    # Validate JSON output structure
    echo "$output" | jq . >/dev/null
    
    # Check extracted fields from sections
    local address=$(echo "$output" | jq -r '.sections.address')
    local endpoint=$(echo "$output" | jq -r '.sections.endpoint')
    local request=$(echo "$output" | jq -r '.sections.request')
    local response=$(echo "$output" | jq -r '.sections.response')
    

    [ "$address" = "localhost:4770" ]
    [ "$endpoint" = "user.UserService/GetUser" ]
    # JSON formatting may include newlines, just check key content
    [[ "$request" =~ "user_id" ]]
    [[ "$request" =~ "123" ]]
    [[ "$response" =~ "John Doe" ]]
}

@test "extract_section: ADDRESS section" {
    local test_file="$TEST_DIR/address.gctf"
    cat > "$test_file" << 'EOF'
--- ADDRESS ---
localhost:9090

--- ENDPOINT ---
test.Service/Method
EOF

    run extract_section "$test_file" "ADDRESS"
    [ "$status" -eq 0 ]
    [ "$output" = "localhost:9090" ]
}

@test "extract_section: ENDPOINT section" {
    local test_file="$TEST_DIR/endpoint.gctf"
    cat > "$test_file" << 'EOF'
--- ENDPOINT ---
package.service/TestMethod

--- REQUEST ---
{}
EOF

    run extract_section "$test_file" "ENDPOINT"
    [ "$status" -eq 0 ]
    [ "$output" = "package.service/TestMethod" ]
}

@test "extract_section: REQUEST section with JSON" {
    local test_file="$TEST_DIR/request.gctf"
    cat > "$test_file" << 'EOF'
--- REQUEST ---
{
  "id": 42,
  "name": "test",
  "active": true
}

--- RESPONSE ---
{}
EOF

    run extract_section "$test_file" "REQUEST"
    [ "$status" -eq 0 ]
    
    # Validate JSON and check content
    echo "$output" | jq . >/dev/null
    local id=$(echo "$output" | jq -r '.id')
    local name=$(echo "$output" | jq -r '.name')
    local active=$(echo "$output" | jq -r '.active')
    
    [ "$id" = "42" ]
    [ "$name" = "test" ]
    [ "$active" = "true" ]
}

@test "extract_section: RESPONSE section with nested JSON" {
    local test_file="$TEST_DIR/response.gctf"
    cat > "$test_file" << 'EOF'
--- RESPONSE ---
{
  "user": {
    "id": "123",
    "profile": {
      "name": "John",
      "age": 30
    }
  },
  "status": "success"
}
EOF

    run extract_section "$test_file" "RESPONSE"
    [ "$status" -eq 0 ]
    
    # Validate nested JSON structure
    echo "$output" | jq . >/dev/null
    local user_id=$(echo "$output" | jq -r '.user.id')
    local name=$(echo "$output" | jq -r '.user.profile.name')
    local age=$(echo "$output" | jq -r '.user.profile.age')
    
    [ "$user_id" = "123" ]
    [ "$name" = "John" ]
    [ "$age" = "30" ]
}

@test "extract_section: ERROR section" {
    local test_file="$TEST_DIR/error.gctf"
    cat > "$test_file" << 'EOF'
--- ERROR ---
{
  "code": 5,
  "message": "Not found",
  "details": []
}
EOF

    run extract_section "$test_file" "ERROR"
    [ "$status" -eq 0 ]
    
    echo "$output" | jq . >/dev/null
    local code=$(echo "$output" | jq -r '.code')
    local message=$(echo "$output" | jq -r '.message')
    
    [ "$code" = "5" ]
    [ "$message" = "Not found" ]
}

# ===== MULTIPLE SECTIONS TESTS =====

@test "extract_all_request_sections: single REQUEST" {
    local test_file="$TEST_DIR/single_request.gctf"
    cat > "$test_file" << 'EOF'
--- REQUEST ---
{"id": 1}

--- RESPONSE ---
{"result": "ok"}
EOF

    run extract_all_request_sections "$test_file"
    [ "$status" -eq 0 ]
    [ "$output" = '{"id": 1}' ]
}

@test "extract_all_request_sections: multiple REQUEST sections" {
    local test_file="$TEST_DIR/multiple_requests.gctf"
    cat > "$test_file" << 'EOF'
--- REQUEST ---
{"id": 1}

--- REQUEST ---
{"id": 2}

--- REQUEST ---
{"id": 3}

--- RESPONSE ---
{"result": "ok"}
EOF

    run extract_all_request_sections "$test_file"
    [ "$status" -eq 0 ]
    
    # Function returns multiple JSON objects, not array
    # Count lines to verify 3 separate JSON objects
    local count=$(echo "$output" | grep -c "id")
    [ "$count" = "3" ]
    
    # Verify each JSON object is valid and has correct ID
    echo "$output" | head -1 | jq . >/dev/null
    echo "$output" | sed -n '2p' | jq . >/dev/null  
    echo "$output" | tail -1 | jq . >/dev/null
    
    local first_id=$(echo "$output" | head -1 | jq -r '.id')
    local second_id=$(echo "$output" | sed -n '2p' | jq -r '.id')
    local third_id=$(echo "$output" | tail -1 | jq -r '.id')
    
    [ "$first_id" = "1" ]
    [ "$second_id" = "2" ]
    [ "$third_id" = "3" ]
}

# ===== HEADERS TESTS =====

@test "extract_section: HEADERS section" {
    local test_file="$TEST_DIR/headers.gctf"
    cat > "$test_file" << 'EOF'
--- HEADERS ---
{
  "authorization": "Bearer token123",
  "content-type": "application/json",
  "x-custom-header": "value"
}

--- ENDPOINT ---
test.Service/Method
EOF

    run extract_section "$test_file" "HEADERS"
    [ "$status" -eq 0 ]
    
    echo "$output" | jq . >/dev/null
    local auth=$(echo "$output" | jq -r '.authorization')
    local content_type=$(echo "$output" | jq -r '."content-type"')
    
    [ "$auth" = "Bearer token123" ]
    [ "$content_type" = "application/json" ]
}

# ===== ASSERTIONS TESTS =====

@test "extract_section: ASSERTS section" {
    local test_file="$TEST_DIR/asserts.gctf"
    cat > "$test_file" << 'EOF'
--- ASSERTS ---
{
  "jq": [
    ".user.id == \"123\"",
    ".status == \"active\""
  ],
  "regex": [
    "name.*John"
  ]
}

--- ENDPOINT ---
test.Service/Method
EOF

    run extract_section "$test_file" "ASSERTS"
    [ "$status" -eq 0 ]
    
    echo "$output" | jq . >/dev/null
    local jq_count=$(echo "$output" | jq '.jq | length')
    local first_jq=$(echo "$output" | jq -r '.jq[0]')
    
    [ "$jq_count" = "2" ]
    [ "$first_jq" = '.user.id == "123"' ]
}

# ===== VALIDATION TESTS =====

@test "file_parser_validate_file: valid .gctf file" {
    local test_file="$TEST_DIR/valid.gctf"
    cat > "$test_file" << 'EOF'
--- ENDPOINT ---
test.Service/Method

--- REQUEST ---
{"test": "data"}

--- RESPONSE ---
{"result": "success"}
EOF

    run file_parser_validate_file "$test_file"
    [ "$status" -eq 0 ]
}

@test "file_parser_validate_file: missing ENDPOINT" {
    local test_file="$TEST_DIR/no_endpoint.gctf"
    cat > "$test_file" << 'EOF'
--- REQUEST ---
{"test": "data"}

--- RESPONSE ---
{"result": "success"}
EOF

    run file_parser_validate_file "$test_file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Missing required ENDPOINT section" ]]
}

@test "file_parser_validate_file: invalid JSON in REQUEST" {
    local test_file="$TEST_DIR/invalid_json.gctf"
    cat > "$test_file" << 'EOF'
--- ENDPOINT ---
test.Service/Method

--- REQUEST ---
{invalid json}

--- RESPONSE ---
{"result": "success"}
EOF

    run file_parser_validate_file "$test_file" "strict"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid JSON in REQUEST section" ]]
}

@test "file_parser_validate_file: empty file" {
    local test_file="$TEST_DIR/empty.gctf"
    touch "$test_file"

    run file_parser_validate_file "$test_file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Test file is empty" ]]
}

# ===== INLINE OPTIONS TESTS =====

@test "parse_inline_options: response options" {
    local options_header="--- RESPONSE partial=true tolerance=0.1 ---"
    
    run parse_inline_options "$options_header"
    [ "$status" -eq 0 ]
    
    echo "$output" | jq . >/dev/null
    local partial=$(echo "$output" | jq -r '.partial')
    local tolerance=$(echo "$output" | jq -r '.tolerance')
    
    [ "$partial" = "true" ]
    [ "$tolerance" = "0.1" ]
}

@test "parse_inline_options: no options" {
    local options_header="--- RESPONSE ---"
    
    run parse_inline_options "$options_header"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

# ===== ERROR HANDLING TESTS =====

@test "extract_section: non-existent section" {
    local test_file="$TEST_DIR/basic.gctf"
    cat > "$test_file" << 'EOF'
--- ENDPOINT ---
test.Service/Method
EOF

    run extract_section "$test_file" "NONEXISTENT"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "extract_section: file does not exist" {
    run extract_section "/nonexistent/file.gctf" "ENDPOINT"
    # Function returns 0 due to pipe with sed, but awk outputs error to stderr
    [ "$status" -eq 0 ]
    # Error message appears in stderr/stdout
    [[ "$output" =~ "can't open file" ]]
}

@test "parse_test_file: file does not exist" {
    run parse_test_file "/nonexistent/file.gctf"
    [ "$status" -eq 1 ]
}

# ===== INTEGRATION TESTS =====

@test "complete .gctf parsing with all sections" {
    local test_file="$TEST_DIR/complete.gctf"
    cat > "$test_file" << 'EOF'
--- ADDRESS ---
localhost:9090

--- ENDPOINT ---
user.UserService/CreateUser

--- HEADERS ---
{
  "authorization": "Bearer token123"
}

--- REQUEST ---
{
  "name": "Alice",
  "email": "alice@example.com",
  "age": 25
}

--- RESPONSE ---
{
  "id": "user_456",
  "name": "Alice",
  "email": "alice@example.com",
  "created_at": "2024-01-01T00:00:00Z"
}

--- ASSERTS ---
{
  "jq": [
    ".id != null",
    ".name == \"Alice\"",
    ".email == \"alice@example.com\""
  ]
}
EOF

    run parse_test_file "$test_file"
    [ "$status" -eq 0 ]
    
    # Validate complete JSON structure
    echo "$output" | jq . >/dev/null
    
    # Check all major components from sections
    local address=$(echo "$output" | jq -r '.sections.address')
    local endpoint=$(echo "$output" | jq -r '.sections.endpoint')
    
    [ "$address" = "localhost:9090" ]
    [ "$endpoint" = "user.UserService/CreateUser" ]
    
    # Check that sections contain expected content
    [[ "$(echo "$output" | jq -r '.sections.headers')" =~ "Bearer token123" ]]
    [[ "$(echo "$output" | jq -r '.sections.request')" =~ "Alice" ]]
    [[ "$(echo "$output" | jq -r '.sections.response')" =~ "user_456" ]]
    [[ "$(echo "$output" | jq -r '.sections.asserts')" =~ "jq" ]]
}
