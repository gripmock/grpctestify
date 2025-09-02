#!/usr/bin/env bats

# native_utils.bats - Tests for Python-free native shell utilities
# Tests all functions in native_utils.sh

setup() {
    # Load the native_utils module
    source "$BATS_TEST_DIRNAME/native_utils.sh"
}

# ===== JSON VALIDATION TESTS =====

@test "validate_json_native: valid JSON object" {
    run validate_json_native '{"name": "test", "value": 42}'
    [ "$status" -eq 0 ]
}

@test "validate_json_native: valid JSON array" {
    run validate_json_native '[1, 2, 3, "test"]'
    [ "$status" -eq 0 ]
}

@test "validate_json_native: valid JSON string" {
    run validate_json_native '"hello world"'
    [ "$status" -eq 0 ]
}

@test "validate_json_native: valid JSON number" {
    run validate_json_native '42'
    [ "$status" -eq 0 ]
}

@test "validate_json_native: valid JSON boolean" {
    run validate_json_native 'true'
    [ "$status" -eq 0 ]
    
    run validate_json_native 'false'
    [ "$status" -eq 0 ]
}

@test "validate_json_native: valid JSON null" {
    run validate_json_native 'null'
    [ "$status" -eq 0 ]
}

@test "validate_json_native: invalid JSON - unbalanced braces" {
    run validate_json_native '{"name": "test"'
    [ "$status" -eq 1 ]
}

@test "validate_json_native: invalid JSON - unbalanced brackets" {
    run validate_json_native '[1, 2, 3'
    [ "$status" -eq 1 ]
}

@test "validate_json_native: invalid JSON - unclosed string" {
    run validate_json_native '{"name": "test'
    [ "$status" -eq 1 ]
}

@test "validate_json_native: empty string" {
    run validate_json_native ''
    [ "$status" -eq 1 ]
}

@test "validate_json_native: complex nested JSON" {
    local complex_json='{"users": [{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}], "total": 2}'
    run validate_json_native "$complex_json"
    [ "$status" -eq 0 ]
}

# ===== TIMESTAMP TESTS =====

@test "native_timestamp_ms: returns numeric timestamp" {
    run native_timestamp_ms
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "native_timestamp_ms: returns 13-digit millisecond timestamp" {
    run native_timestamp_ms
    [ "$status" -eq 0 ]
    # Timestamp should be 13 digits (milliseconds since epoch)
    [ ${#output} -eq 13 ]
}

@test "native_timestamp_ms: consecutive calls increase" {
    local time1 time2
    time1=$(native_timestamp_ms)
    sleep 0.01  # Sleep 10ms
    time2=$(native_timestamp_ms)
    
    [ "$time2" -gt "$time1" ]
}

@test "native_timestamp_ms: reasonable timestamp range" {
    local timestamp
    timestamp=$(native_timestamp_ms)
    
    # Should be after 2020-01-01 (1577836800000) and before 2030-01-01 (1893456000000)
    [ "$timestamp" -gt 1577836800000 ]
    [ "$timestamp" -lt 1893456000000 ]
}

# ===== CPU COUNT TESTS =====

@test "native_cpu_count: returns positive integer" {
    run native_cpu_count
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -gt 0 ]
}

@test "native_cpu_count: returns reasonable count" {
    run native_cpu_count
    [ "$status" -eq 0 ]
    # Should be between 1 and 128 cores (reasonable range)
    [ "$output" -ge 1 ]
    [ "$output" -le 128 ]
}

@test "native_cpu_count: consistent results" {
    local count1 count2
    count1=$(native_cpu_count)
    count2=$(native_cpu_count)
    
    [ "$count1" -eq "$count2" ]
}

# ===== JSON KEY EXTRACTION TESTS =====

@test "extract_json_key_native: extract string value" {
    local json='{"name": "Alice", "age": 30}'
    run extract_json_key_native "$json" "name"
    [ "$status" -eq 0 ]
    [ "$output" = "Alice" ]
}

@test "extract_json_key_native: extract number value" {
    local json='{"name": "Alice", "age": 30}'
    run extract_json_key_native "$json" "age"
    [ "$status" -eq 0 ]
    [ "$output" = "30" ]
}

@test "extract_json_key_native: extract boolean value" {
    local json='{"active": true, "verified": false}'
    run extract_json_key_native "$json" "active"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "extract_json_key_native: extract null value" {
    local json='{"data": null}'
    run extract_json_key_native "$json" "data"
    [ "$status" -eq 0 ]
    [ "$output" = "null" ]
}

@test "extract_json_key_native: non-existent key" {
    local json='{"name": "Alice"}'
    run extract_json_key_native "$json" "nonexistent"
    # Should return empty string for non-existent keys
    [ "$output" = "" ]
}

# ===== UTILITY FUNCTION TESTS =====

@test "count_matches_native: count pattern occurrences" {
    local input=$'line1 test\nline2 test\nline3 other'
    run count_matches_native "test" "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "count_lines_native: count lines" {
    local input=$'line1\nline2\nline3'
    run count_lines_native "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "count_lines_native: empty input" {
    run count_lines_native ""
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "count_lines_native: single line without newline" {
    run count_lines_native "single line"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "generate_uuid_native: generates UUID format" {
    run generate_uuid_native
    [ "$status" -eq 0 ]
    # UUID format: 8-4-4-4-12 characters
    [[ "$output" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

@test "generate_uuid_native: generates unique UUIDs" {
    local uuid1 uuid2
    uuid1=$(generate_uuid_native)
    uuid2=$(generate_uuid_native)
    
    [ "$uuid1" != "$uuid2" ]
}

@test "command_exists_native: existing command" {
    run command_exists_native "echo"
    [ "$status" -eq 0 ]
}

@test "command_exists_native: non-existing command" {
    run command_exists_native "nonexistent_command_12345"
    [ "$status" -eq 1 ]
}

# ===== PERFORMANCE TESTS =====

@test "native_timestamp_ms: performance under load" {
    local start_time end_time
    start_time=$(date +%s)
    
    # Call function 50 times (reduced for stability)
    for i in {1..50}; do
        native_timestamp_ms >/dev/null
    done
    
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Should complete 50 calls in under 3 seconds
    [ "$duration" -lt 3 ]
}

@test "validate_json_native: performance with large JSON" {
    # Create a moderate JSON string (reduced for stability)
    local large_json='{"data": ['
    for i in {1..50}; do
        large_json+='{"id": '$i', "name": "item'$i'"},'
    done
    large_json="${large_json%,}]}"
    
    local start_time end_time
    start_time=$(date +%s)
    
    run validate_json_native "$large_json"
    
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    # Should validate JSON in under 2 seconds
    [ "$duration" -lt 2 ]
}

# ===== EDGE CASE TESTS =====

@test "validate_json_native: JSON with escaped quotes" {
    local json='{"message": "She said \"Hello\" to me"}'
    run validate_json_native "$json"
    [ "$status" -eq 0 ]
}

@test "validate_json_native: JSON with whitespace" {
    local json='{
        "name": "test",
        "value": 42
    }'
    run validate_json_native "$json"
    [ "$status" -eq 0 ]
}

@test "extract_json_key_native: key with whitespace in JSON" {
    local json='{ "name" : "Alice" , "age" : 30 }'
    run extract_json_key_native "$json" "name"
    [ "$status" -eq 0 ]
    [ "$output" = "Alice" ]
}

# ===== INTEGRATION TESTS =====

@test "native functions work together: timestamp and JSON validation" {
    local timestamp
    timestamp=$(native_timestamp_ms)
    
    local json='{"timestamp": '$timestamp', "status": "active"}'
    
    run validate_json_native "$json"
    [ "$status" -eq 0 ]
    
    local extracted_timestamp
    extracted_timestamp=$(extract_json_key_native "$json" "timestamp")
    [ "$extracted_timestamp" = "$timestamp" ]
}

@test "native functions work together: CPU count in JSON" {
    local cpu_count
    cpu_count=$(native_cpu_count)
    
    local json='{"system": {"cpu_cores": '$cpu_count', "available": true}}'
    
    run validate_json_native "$json"
    [ "$status" -eq 0 ]
    
    local extracted_count
    extracted_count=$(extract_json_key_native "$json" "cpu_cores")
    [ "$extracted_count" = "$cpu_count" ]
}


