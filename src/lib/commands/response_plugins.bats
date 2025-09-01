#!/usr/bin/env bats

# Test suite for RESPONSE inline plugins API

setup() {
    # Source the run.sh file to get plugin functions
    source "$BATS_TEST_DIRNAME/run.sh"
    
    # Mock tlog function
    tlog() {
        echo "TLOG [$1]: $2" >&2
    }
}

@test "response_plugin_partial: subset comparison works" {
    local actual='{"name": "alice", "age": 25, "city": "NYC"}'
    local expected='{"name": "alice", "age": 25}'
    
    run response_plugin_partial "$actual" "$expected"
    [ "$status" -eq 0 ]
    [[ "$output" == *"subset match successful"* ]]
}

@test "response_plugin_partial: non-subset fails" {
    local actual='{"name": "alice", "age": 25}'
    local expected='{"name": "bob", "age": 30}'
    
    run response_plugin_partial "$actual" "$expected"
    [ "$status" -eq 1 ]
    [[ "$output" == *"subset match failed"* ]]
}

@test "response_plugin_redact: removes specified fields" {
    local actual='{"name": "alice", "password": "secret", "age": 25}'
    local expected='{"name": "alice", "password": "secret", "age": 25}'
    
    run response_plugin_redact "$actual" "$expected" "password"
    [ "$status" -eq 0 ]
    
    # Check that password field was removed from both (compact JSON)
    local redacted_actual=$(echo "$output" | head -1)
    local redacted_expected=$(echo "$output" | tail -1)
    
    [[ "$redacted_actual" != *"password"* ]]
    [[ "$redacted_expected" != *"password"* ]]
    [[ "$redacted_actual" == *'"name":"alice"'* ]]
}

@test "response_plugin_redact: multiple fields" {
    local actual='{"name": "alice", "password": "secret", "ssn": "123-45-6789", "age": 25}'
    local expected='{"name": "alice", "password": "secret", "ssn": "123-45-6789", "age": 25}'
    
    run response_plugin_redact "$actual" "$expected" "password,ssn"
    [ "$status" -eq 0 ]
    
    local redacted_actual=$(echo "$output" | head -1)
    [[ "$redacted_actual" != *"password"* ]]
    [[ "$redacted_actual" != *"ssn"* ]]
    [[ "$redacted_actual" == *'"name":"alice"'* ]]
}

@test "response_plugin_unordered_arrays: sorts arrays" {
    local actual='{"items": [3, 1, 2], "name": "test"}'
    local expected='{"items": [1, 2, 3], "name": "test"}'
    
    run response_plugin_unordered_arrays "$actual" "$expected"
    [ "$status" -eq 0 ]
    
    local sorted_actual=$(echo "$output" | head -1)
    local sorted_expected=$(echo "$output" | tail -1)
    
    # Both should have same sorted array (compact JSON)
    [[ "$sorted_actual" == *'"items":[1,2,3]'* ]]
    [[ "$sorted_expected" == *'"items":[1,2,3]'* ]]
}

@test "response_plugin_tolerance: numeric comparison within tolerance" {
    local actual='{"price": 10.15, "quantity": 5}'
    local expected='{"price": 10.1, "quantity": 5}'
    
    run response_plugin_tolerance "$actual" "$expected" "0.1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"within 0.1"* ]]
}

@test "response_plugin_tolerance: fails outside tolerance" {
    local actual='{"price": 10.5, "quantity": 5}'
    local expected='{"price": 10.1, "quantity": 5}'
    
    run response_plugin_tolerance "$actual" "$expected" "0.1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"failed"* ]]
}

@test "response_plugins_execute: combines redact and exact comparison" {
    local actual='{"name": "alice", "password": "secret123", "age": 25}'
    local expected='{"name": "alice", "password": "secret456", "age": 25}'
    local options="--- RESPONSE redact=password"
    
    run response_plugins_execute "$actual" "$expected" "$options"
    [ "$status" -eq 0 ]
}

@test "response_plugins_execute: partial comparison" {
    local actual='{"name": "alice", "age": 25, "city": "NYC"}'
    local expected='{"name": "alice", "age": 25}'
    local options="--- RESPONSE type=partial"
    
    run response_plugins_execute "$actual" "$expected" "$options"
    [ "$status" -eq 0 ]
}

@test "response_plugins_execute: unordered arrays with exact comparison" {
    local actual='{"items": [3, 1, 2], "name": "test"}'
    local expected='{"items": [1, 2, 3], "name": "test"}'
    local options="--- RESPONSE unordered_arrays=true"
    
    run response_plugins_execute "$actual" "$expected" "$options"
    [ "$status" -eq 0 ]
}

@test "response_plugins_execute: tolerance comparison" {
    local actual='{"price": 10.15}'
    local expected='{"price": 10.1}'
    local options="--- RESPONSE tolerance=0.1"
    
    run response_plugins_execute "$actual" "$expected" "$options"
    [ "$status" -eq 0 ]
}

@test "response_plugins_execute: combined redact and unordered_arrays" {
    local actual='{"items": [3, 1, 2], "secret": "hidden", "name": "test"}'
    local expected='{"items": [1, 2, 3], "secret": "different", "name": "test"}'
    local options="--- RESPONSE redact=secret unordered_arrays=true"
    
    run response_plugins_execute "$actual" "$expected" "$options"
    [ "$status" -eq 0 ]
}
