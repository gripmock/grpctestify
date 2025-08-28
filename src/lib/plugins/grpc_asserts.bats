#!/usr/bin/env bats

# grpc_asserts.bats - Tests for grpc_asserts.sh plugin

# Load the plugin system and asserts plugin
load "${BATS_TEST_DIRNAME}/../core/plugin_system_enhanced.sh"
load "${BATS_TEST_DIRNAME}/grpc_asserts.sh"

@test "grpc_asserts plugin registers correctly" {
    # Check if plugin is registered
    run list_plugins
    [ $status -eq 0 ]
    [[ "$output" =~ "asserts" ]]
}

@test "register_asserts_plugin function registers asserts plugin" {
    # Test plugin registration
    run register_asserts_plugin
    [ $status -eq 0 ]
}

@test "evaluate_enhanced_asserts function evaluates enhanced assertions" {
    # Test enhanced assertion evaluation
    local response='{"message": "Hello, World!", "status": 0}'
    local asserts='.message == "Hello, World!"
.status == 0'
    
    run evaluate_enhanced_asserts "$asserts" "$response"
    [ $status -eq 0 ]
}

@test "process_enhanced_asserts function processes enhanced assertions" {
    # Test enhanced assertion processing
    local response='{"message": "Hello, World!", "status": 0}'
    local asserts='.message == "Hello, World!"
.status == 0'
    
    run process_enhanced_asserts "$asserts" "$response"
    [ $status -eq 0 ]
}

@test "process_indexed_assertion function processes indexed assertions" {
    # Test indexed assertion processing
    local response='{"message": "Hello, World!", "status": 0}'
    local assertion='[1] .message == "Hello, World!"'
    
    run process_indexed_assertion "$assertion" "$response"
    [ $status -eq 0 ]
}

@test "process_plugin_assertion function processes plugin assertions" {
    # Test plugin assertion processing
    local response='{"message": "Hello, World!", "status": 0}'
    local assertion='@test_plugin:arg1:arg2'
    
    run process_plugin_assertion "$assertion" "$response"
    [ $status -ne 0 ]  # Expected to fail for non-existent plugin
}

# test for process_type_assertion removed - function no longer exists

@test "process_indexed_plugin_assertion function processes indexed plugin assertions" {
    # Test indexed plugin assertion processing
    local response='{"message": "Hello, World!", "status": 0}'
    local assertion='[1] @test_plugin:arg1'
    
    run process_indexed_plugin_assertion "$assertion" "$response"
    [ $status -ne 0 ]  # Expected to fail for non-existent plugin
}

# test for process_indexed_type_assertion removed - function no longer exists

@test "process_regular_assertion function processes regular assertions" {
    # Test regular assertion processing
    local response='{"message": "Hello, World!", "status": 0}'
    local assertion='.message == "Hello, World!"'
    
    run process_regular_assertion "$assertion" "$response"
    [ $status -eq 0 ]
}

@test "evaluate_single_assertion function evaluates single assertions" {
    # Test single assertion evaluation
    local response='{"message": "Hello, World!", "status": 0}'
    local assertion='.message == "Hello, World!"'
    
    run evaluate_single_assertion "$assertion" "$response"
    [ $status -eq 0 ]
}

@test "execute_plugin_assertion function executes plugin assertions" {
    # Test plugin assertion execution
    local response='{"message": "Hello, World!", "status": 0}'
    local plugin="test_plugin"
    local args="arg1:arg2"
    
    run execute_plugin_assertion "$plugin" "$response" "$args"
    [ $status -ne 0 ]  # Expected to fail for non-existent plugin
}

@test "evaluate_type_assertion function evaluates type assertions" {
    # Test type assertion evaluation
    local type_name="string"
    local assertion=".message"
    local response='{"message": "Hello, World!", "status": 0}'
    
    run evaluate_type_assertion "$type_name" "$assertion" "$response"
    [ $status -eq 0 ]
}