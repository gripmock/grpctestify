#!/usr/bin/env bats

# grpc_tls.bats - Tests for grpc_tls.sh plugin

# Load the plugin system and TLS plugin
load "${BATS_TEST_DIRNAME}/../core/plugin_system_enhanced.sh"
load "${BATS_TEST_DIRNAME}/grpc_tls.sh"

@test "grpc_tls plugin registers correctly" {
    # Check if plugin is registered
    run list_plugins
    [ $status -eq 0 ]
    [[ "$output" =~ "tls" ]]
}

@test "register_tls_plugin function registers TLS plugin" {
    # Test plugin registration
    run register_tls_plugin
    [ $status -eq 0 ]
}

@test "parse_tls_section function parses TLS sections" {
    # Create test file
    local test_file=$(mktemp)
    cat > "$test_file" << 'EOF'
--- TLS ---
mode: tls
cert: /path/to/cert.pem
key: /path/to/key.pem
EOF
    
    # Test TLS section parsing
    run parse_tls_section "$test_file"
    [ $status -eq 0 ]
    
    # Cleanup
    rm -f "$test_file"
}

@test "process_tls_configuration function processes TLS configuration" {
    # Test TLS configuration processing
    run process_tls_configuration "tls" "/path/to/cert.pem" "/path/to/key.pem" "" "" ""
    [ $status -eq 0 ]
}

@test "validate_tls_configuration function validates TLS configuration" {
    # Test TLS configuration validation
    run validate_tls_configuration "tls" "/path/to/cert.pem" "/path/to/key.pem" "" "" ""
    [ $status -eq 0 ]
}

@test "generate_tls_flags function generates TLS flags" {
    # Test TLS flag generation
    run generate_tls_flags "tls" "/path/to/cert.pem" "/path/to/key.pem" "" "" ""
    [ $status -eq 0 ]
}

@test "resolve_tls_path function resolves TLS paths" {
    # Test TLS path resolution
    run resolve_tls_path "/path/to/cert.pem"
    [ $status -eq 0 ]
}

@test "create_temp_pem_from_env function creates temp PEM from environment" {
    # Test temp PEM creation from environment
    export TEST_CERT="-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----"
    run create_temp_pem_from_env "TEST_CERT"
    [ $status -eq 0 ]
    unset TEST_CERT
}

@test "get_tls_summary function gets TLS summary" {
    # Test TLS summary retrieval
    run get_tls_summary
    [ $status -eq 0 ]
}

@test "get_tls_flags function gets TLS flags" {
    # Test TLS flags retrieval
    run get_tls_flags
    [ $status -eq 0 ]
}