#!/usr/bin/env bats

# grpc_proto.bats - Tests for grpc_proto.sh plugin

# Load the plugin system and proto plugin
load "${BATS_TEST_DIRNAME}/../core/plugin_system_enhanced.sh"
load "${BATS_TEST_DIRNAME}/grpc_proto.sh"

@test "grpc_proto plugin registers correctly" {
    # Check if plugin is registered
    run list_plugins
    [ $status -eq 0 ]
    [[ "$output" =~ "proto" ]]
}

@test "register_proto_plugin function registers proto plugin" {
    # Test plugin registration
    run register_proto_plugin
    [ $status -eq 0 ]
}

@test "parse_proto_section function parses proto sections" {
    # Create test file
    local test_file=$(mktemp)
    cat > "$test_file" << 'EOF'
--- PROTO ---
mode: proto
files: test.proto
EOF
    
    # Test proto section parsing
    run parse_proto_section "$test_file"
    [ $status -eq 0 ]
    
    # Cleanup
    rm -f "$test_file"
}

@test "process_proto_configuration function processes proto configuration" {
    # Test proto configuration processing
    run process_proto_configuration "proto" "test.proto" "" ""
    [ $status -eq 0 ]
}

@test "validate_proto_configuration function validates proto configuration" {
    # Test proto configuration validation
    run validate_proto_configuration "proto" "test.proto" "" ""
    [ $status -eq 0 ]
}

@test "generate_proto_flags function generates proto flags" {
    # Test proto flag generation
    run generate_proto_flags "proto" "test.proto" "" ""
    [ $status -eq 0 ]
}

@test "resolve_proto_path function resolves proto paths" {
    # Test proto path resolution
    run resolve_proto_path "test.proto"
    [ $status -eq 0 ]
}

@test "get_proto_summary function gets proto summary" {
    # Test proto summary retrieval
    run get_proto_summary
    [ $status -eq 0 ]
}

@test "get_proto_flags function gets proto flags" {
    # Test proto flags retrieval
    run get_proto_flags
    [ $status -eq 0 ]
}

@test "get_proto_mode function gets proto mode" {
    # Test proto mode retrieval
    run get_proto_mode
    [ $status -eq 0 ]
}

@test "get_proto_files function gets proto files" {
    # Test proto files retrieval
    run get_proto_files
    [ $status -eq 0 ]
}

@test "get_proto_descriptor function gets proto descriptor" {
    # Test proto descriptor retrieval
    run get_proto_descriptor
    [ $status -eq 0 ]
}

@test "get_proto_import_paths function gets proto import paths" {
    # Test proto import paths retrieval
    run get_proto_import_paths
    [ $status -eq 0 ]
}