#!/usr/bin/env bats

# Tests for bi-directional streaming with jq-based JSON parsing

setup() {
    # Mock tlog function to avoid "command not found" errors
    if ! command -v tlog >/dev/null 2>&1; then
        tlog() { echo "MOCK_LOG: $*"; }
        export -f tlog
    fi
    
    # Load the run.sh functions
    source "$BATS_TEST_DIRNAME/run.sh"
    
    # Create a temporary test file
    TEST_FILE=$(mktemp)
    MULTI_RESPONSE_FILE=$(mktemp)
    
    # Single response test file
    cat > "$TEST_FILE" << 'EOF'
--- ENDPOINT ---
test.Service/Method

--- REQUEST ---
{"test": "value"}

--- RESPONSE ---
{"result": "success"}
EOF

    # Multiple response test file for bi-directional streaming
    cat > "$MULTI_RESPONSE_FILE" << 'EOF'
--- ENDPOINT ---
chat.Service/Chat

--- REQUEST ---
{"user": "alice", "message": "hello"}

--- RESPONSE ---
{"user": "bob", "message": "hi alice"}

--- REQUEST ---
{"user": "alice", "message": "how are you?"}

--- RESPONSE ---
{"user": "bob", "message": "great!"}

--- REQUEST ---
{"user": "alice", "message": "bye"}

--- RESPONSE ---
{"user": "bob", "message": "goodbye!"}
EOF
}

teardown() {
    rm -f "$TEST_FILE" "$MULTI_RESPONSE_FILE"
}

@test "response_count calculation works correctly" {
    local count=$(grep -c "^--- RESPONSE ---" "$TEST_FILE")
    [ "$count" -eq "1" ]
    
    local multi_count=$(grep -c "^--- RESPONSE ---" "$MULTI_RESPONSE_FILE")
    [ "$multi_count" -eq "3" ]
}

@test "single RESPONSE parsing uses traditional awk" {
    local response=$(awk '/--- RESPONSE ---/{flag=1; next} /^---/{flag=0} flag' "$TEST_FILE")
    [[ "$response" == '{"result": "success"}' ]]
}

@test "multiple RESPONSE parsing extracts all RESPONSE sections" {
    local response=$(awk '/--- RESPONSE ---/{flag=1; next} /^---/{flag=0} flag' "$MULTI_RESPONSE_FILE")
    # Should contain both responses
    [[ "$response" == *'"hi alice"'* ]]
    [[ "$response" == *'"great!"'* ]]
}

@test "jq can parse and normalize JSON arrays from multi-line input" {
    local test_input='{"a": 2, "b": 1}
{"c": 4, "d": 3}
{"e": 6, "f": 5}'
    
    local result=$(echo "$test_input" | jq -s -S -c 'map(select(. != null and . != ""))')
    local expected='[{"a":2,"b":1},{"c":4,"d":3},{"e":6,"f":5}]'
    
    [[ "$result" == "$expected" ]]
}

@test "jq-based comparison handles identical JSON arrays" {
    local json1='{"user":"bob","msg":"hi"}
{"user":"alice","msg":"hello"}'
    
    local json2='{"user": "bob", "msg": "hi"}
{"user": "alice", "msg": "hello"}'
    
    local array1=$(echo "$json1" | jq -s -S -c 'map(select(. != null and . != ""))')
    local array2=$(echo "$json2" | jq -s -S -c 'map(select(. != null and . != ""))')
    
    [[ "$array1" == "$array2" ]]
}

@test "jq-based comparison detects different JSON arrays" {
    local json1='{"user":"bob","msg":"hi"}
{"user":"alice","msg":"hello"}'
    
    local json2='{"user":"bob","msg":"hi"}
{"user":"alice","msg":"goodbye"}'
    
    local array1=$(echo "$json1" | jq -s -S -c 'map(select(. != null and . != ""))')
    local array2=$(echo "$json2" | jq -s -S -c 'map(select(. != null and . != ""))')
    
    [[ "$array1" != "$array2" ]]
}
