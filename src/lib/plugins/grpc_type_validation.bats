#!/usr/bin/env bats

# grpc_type_validation.bats - Tests for advanced type validation plugin

# Load the type validation module
load "${BATS_TEST_DIRNAME}/grpc_type_validation.sh"

@test "validate_uuid accepts valid UUID v4" {
    run validate_uuid "550e8400-e29b-41d4-a716-446655440000"
    [ $status -eq 0 ]
    
    run validate_uuid "550e8400-e29b-41d4-a716-446655440000" "v4"
    [ $status -eq 0 ]
}

@test "validate_uuid rejects invalid UUID" {
    run validate_uuid "invalid-uuid"
    [ $status -ne 0 ]
    
    run validate_uuid "550e8400-e29b-41d4-a716-44665544000"  # too short
    [ $status -ne 0 ]
    
    run validate_uuid "550e8400-e29b-41d4-a716-446655440000g"  # invalid character
    [ $status -ne 0 ]
}

@test "validate_uuid version validation" {
    # Valid v4 UUID
    run validate_uuid "550e8400-e29b-41d4-a716-446655440000" "v4"
    [ $status -eq 0 ]
    
    # Invalid version for v4 (this is actually v1)
    run validate_uuid "550e8400-e29b-11d4-a716-446655440000" "v4"
    [ $status -ne 0 ]
}

@test "validate_iso8601 accepts valid timestamps" {
    run validate_iso8601 "2024-01-15T10:30:00Z"
    [ $status -eq 0 ]
    
    run validate_iso8601 "2024-01-15T10:30:00.123Z"
    [ $status -eq 0 ]
    
    run validate_iso8601 "2024-01-15T10:30:00+03:00"
    [ $status -eq 0 ]
    
    run validate_iso8601 "2024-01-15T10:30:00"
    [ $status -eq 0 ]
}

@test "validate_iso8601 rejects invalid timestamps" {
    run validate_iso8601 "2024-01-15 10:30:00"  # space instead of T
    [ $status -ne 0 ]
    
    run validate_iso8601 "invalid-timestamp"
    [ $status -ne 0 ]
    
    run validate_iso8601 "2024/01/15T10:30:00Z"  # slashes instead of dashes
    [ $status -ne 0 ]
}

@test "validate_iso8601 strict mode" {
    run validate_iso8601 "2024-01-15T10:30:00Z" "true"
    [ $status -eq 0 ]
    
    run validate_iso8601 "2024-01-15T10:30:00" "true"  # missing timezone
    [ $status -ne 0 ]
}

@test "validate_rfc3339 accepts valid timestamps" {
    run validate_rfc3339 "2024-01-15T10:30:00Z"
    [ $status -eq 0 ]
    
    run validate_rfc3339 "2024-01-15T10:30:00.123456Z"
    [ $status -eq 0 ]
    
    run validate_rfc3339 "2024-01-15T10:30:00+03:00"
    [ $status -eq 0 ]
}

@test "validate_rfc3339 rejects invalid timestamps" {
    run validate_rfc3339 "2024-01-15T10:30:00"  # missing timezone
    [ $status -ne 0 ]
    
    run validate_rfc3339 "2024-01-15 10:30:00Z"  # space instead of T
    [ $status -ne 0 ]
}

@test "validate_unix_timestamp validates different formats" {
    # Seconds (10 digits)
    run validate_unix_timestamp "1642248600" "seconds"
    [ $status -eq 0 ]
    
    # Milliseconds (13 digits)
    run validate_unix_timestamp "1642248600123" "milliseconds"
    [ $status -eq 0 ]
    
    # Microseconds (16 digits)
    run validate_unix_timestamp "1642248600123456" "microseconds"
    [ $status -eq 0 ]
}

@test "validate_unix_timestamp rejects invalid formats" {
    run validate_unix_timestamp "164224860"  # too short for seconds
    [ $status -ne 0 ]
    
    run validate_unix_timestamp "16422486001234"  # wrong length for milliseconds
    [ $status -ne 0 ]
    
    run validate_unix_timestamp "abc123" "seconds"
    [ $status -ne 0 ]
}

@test "validate_url accepts valid URLs" {
    run validate_url "https://example.com"
    [ $status -eq 0 ]
    
    run validate_url "http://localhost:8080/path"
    [ $status -eq 0 ]
    
    run validate_url "ftp://files.example.com/file.txt"
    [ $status -eq 0 ]
    
    run validate_url "ws://websocket.example.com"
    [ $status -eq 0 ]
}

@test "validate_url rejects invalid URLs" {
    run validate_url "not-a-url"
    [ $status -ne 0 ]
    
    run validate_url "http://"
    [ $status -ne 0 ]
    
    run validate_url "://example.com"
    [ $status -ne 0 ]
}

@test "validate_url scheme validation" {
    run validate_url "https://example.com" "https"
    [ $status -eq 0 ]
    
    run validate_url "http://example.com" "https"
    [ $status -ne 0 ]
    
    run validate_url "ftp://example.com" "http"
    [ $status -ne 0 ]
}

@test "validate_email accepts valid emails" {
    run validate_email "user@example.com"
    [ $status -eq 0 ]
    
    run validate_email "test.email+tag@domain.co.uk"
    [ $status -eq 0 ]
    
    run validate_email "user123@test-domain.org"
    [ $status -eq 0 ]
}

@test "validate_email rejects invalid emails" {
    run validate_email "invalid-email"
    [ $status -ne 0 ]
    
    run validate_email "@example.com"
    [ $status -ne 0 ]
    
    run validate_email "user@"
    [ $status -ne 0 ]
    
    run validate_email "user@domain"  # no TLD
    [ $status -ne 0 ]
}

@test "validate_jwt accepts valid JWT structure" {
    # Valid JWT structure (header.payload.signature)
    local jwt="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    
    run validate_jwt "$jwt"
    [ $status -eq 0 ]
}

@test "validate_jwt rejects invalid JWT structure" {
    run validate_jwt "invalid.jwt"  # only two parts
    [ $status -ne 0 ]
    
    run validate_jwt "header.payload.signature.extra"  # too many parts
    [ $status -ne 0 ]
    
    run validate_jwt "invalid jwt structure"  # spaces
    [ $status -ne 0 ]
}

@test "validate_ipv4 accepts valid IPv4 addresses" {
    run validate_ipv4 "192.168.1.1"
    [ $status -eq 0 ]
    
    run validate_ipv4 "10.0.0.1"
    [ $status -eq 0 ]
    
    run validate_ipv4 "255.255.255.255"
    [ $status -eq 0 ]
    
    run validate_ipv4 "0.0.0.0"
    [ $status -eq 0 ]
}

@test "validate_ipv4 rejects invalid IPv4 addresses" {
    run validate_ipv4 "256.1.1.1"  # octet > 255
    [ $status -ne 0 ]
    
    run validate_ipv4 "192.168.1"  # incomplete
    [ $status -ne 0 ]
    
    run validate_ipv4 "192.168.1.01"  # leading zero
    [ $status -ne 0 ]
    
    run validate_ipv4 "192.168.1.1.1"  # too many octets
    [ $status -ne 0 ]
}

@test "validate_ipv6 accepts valid IPv6 addresses" {
    run validate_ipv6 "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    [ $status -eq 0 ]
    
    run validate_ipv6 "2001:db8:85a3::8a2e:370:7334"
    [ $status -eq 0 ]
    
    run validate_ipv6 "::1"
    [ $status -eq 0 ]
    
    run validate_ipv6 "::"
    [ $status -eq 0 ]
}

@test "validate_semver accepts valid semantic versions" {
    run validate_semver "1.0.0"
    [ $status -eq 0 ]
    
    run validate_semver "2.1.3"
    [ $status -eq 0 ]
    
    run validate_semver "1.0.0-alpha"
    [ $status -eq 0 ]
    
    run validate_semver "1.0.0-beta.1"
    [ $status -eq 0 ]
    
    run validate_semver "1.0.0+build.123"
    [ $status -eq 0 ]
}

@test "validate_semver rejects invalid semantic versions" {
    run validate_semver "1.0"  # incomplete
    [ $status -ne 0 ]
    
    run validate_semver "v1.0.0"  # with v prefix
    [ $status -ne 0 ]
    
    run validate_semver "1.0.0.0"  # too many parts
    [ $status -ne 0 ]
}

@test "validate_semver strict mode" {
    run validate_semver "1.0.0" "false"
    [ $status -eq 0 ]
    
    run validate_semver "1.0.0-alpha" "false"  # strict mode, no prerelease
    [ $status -ne 0 ]
}

@test "validate_mac_address accepts valid MAC addresses" {
    run validate_mac_address "00:11:22:33:44:55"
    [ $status -eq 0 ]
    
    run validate_mac_address "00-11-22-33-44-55"
    [ $status -eq 0 ]
    
    run validate_mac_address "AA:BB:CC:DD:EE:FF"
    [ $status -eq 0 ]
}

@test "validate_mac_address format validation" {
    run validate_mac_address "00:11:22:33:44:55" "colon"
    [ $status -eq 0 ]
    
    run validate_mac_address "00-11-22-33-44-55" "colon"
    [ $status -ne 0 ]
    
    run validate_mac_address "00-11-22-33-44-55" "dash"
    [ $status -eq 0 ]
}

@test "validate_base64 accepts valid base64" {
    run validate_base64 "SGVsbG8gV29ybGQ="
    [ $status -eq 0 ]
    
    run validate_base64 "dGVzdA=="
    [ $status -eq 0 ]
    
    run validate_base64 "YWJjZGVmZw=="
    [ $status -eq 0 ]
}

@test "validate_base64 strict mode" {
    run validate_base64 "SGVsbG8gV29ybGQ=" "true"
    [ $status -eq 0 ]
    
    run validate_base64 "invalid base64!" "true"
    [ $status -ne 0 ]
    
    run validate_base64 "SGVsbG8=" "true"  # wrong padding
    [ $status -ne 0 ]
}

@test "validate_phone accepts valid phone numbers" {
    run validate_phone "+1234567890"
    [ $status -eq 0 ]
    
    run validate_phone "\(555\) 123-4567" "us"
    [ $status -eq 0 ]
    
    run validate_phone "555-123-4567" "us"
    [ $status -eq 0 ]
    
    run validate_phone "5551234567" "us"
    [ $status -eq 0 ]
}

@test "validate_phone rejects invalid phone numbers" {
    run validate_phone "123" "international"
    [ $status -ne 0 ]
    
    run validate_phone "abc-def-ghij" "us"
    [ $status -ne 0 ]
}

@test "validate_color accepts valid color codes" {
    run validate_color "#FF0000" "hex"
    [ $status -eq 0 ]
    
    run validate_color "#f00" "hex"
    [ $status -eq 0 ]
    
    run validate_color "rgb(255, 0, 0)" "rgb"
    [ $status -eq 0 ]
    
    run validate_color "hsl(0, 100%, 50%)" "hsl"
    [ $status -eq 0 ]
}

@test "validate_color rejects invalid color codes" {
    run validate_color "#GG0000" "hex"  # invalid hex characters
    [ $status -ne 0 ]
    
    run validate_color "rgb(256, 0, 0)" "rgb"  # value > 255
    [ $status -ne 0 ]
    
    run validate_color "hsl(361, 100%, 50%)" "hsl"  # hue > 360
    [ $status -ne 0 ]
}

@test "luhn_check validates credit card checksums" {
    # Valid credit card number (test number)
    run luhn_check "4111111111111111"
    [ $status -eq 0 ]
    
    run luhn_check "5555555555554444"
    [ $status -eq 0 ]
    
    # Invalid checksum
    run luhn_check "4111111111111112"
    [ $status -ne 0 ]
}

@test "validate_credit_card validates card numbers" {
    # Visa
    run validate_credit_card "4111111111111111" "visa"
    [ $status -eq 0 ]
    
    # Mastercard
    run validate_credit_card "5555555555554444" "mastercard"
    [ $status -eq 0 ]
    
    # Wrong brand
    run validate_credit_card "4111111111111111" "mastercard"
    [ $status -ne 0 ]
}

@test "assert_type_uuid validates UUID fields in JSON" {
    local json='{"id": "550e8400-e29b-41d4-a716-446655440000", "name": "test"}'
    
    run assert_type_uuid "$json" ".id"
    [ $status -eq 0 ]
    
    run assert_type_uuid "$json" ".name"  # not a UUID
    [ $status -ne 0 ]
    
    run assert_type_uuid "$json" ".missing"  # missing field
    [ $status -ne 0 ]
}

@test "assert_type_email validates email fields in JSON" {
    local json='{"email": "user@example.com", "name": "test"}'
    
    run assert_type_email "$json" ".email"
    [ $status -eq 0 ]
    
    run assert_type_email "$json" ".name"  # not an email
    [ $status -ne 0 ]
}

@test "assert_type_url validates URL fields in JSON" {
    local json='{"url": "https://example.com", "name": "test"}'
    
    run assert_type_url "$json" ".url"
    [ $status -eq 0 ]
    
    run assert_type_url "$json" ".url" "https"
    [ $status -eq 0 ]
    
    run assert_type_url "$json" ".url" "http"
    [ $status -ne 0 ]
    
    run assert_type_url "$json" ".name"  # not a URL
    [ $status -ne 0 ]
}

@test "assert_type_timestamp validates timestamp fields in JSON" {
    local json='{"created_at": "2024-01-15T10:30:00Z", "unix_time": 1642248600}'
    
    run assert_type_timestamp "$json" ".created_at" "iso8601"
    [ $status -eq 0 ]
    
    run assert_type_timestamp "$json" ".unix_time" "unix"
    [ $status -eq 0 ]
    
    run assert_type_timestamp "$json" ".created_at" "unix"  # wrong format
    [ $status -ne 0 ]
}

@test "assert_type_ip validates IP address fields in JSON" {
    local json='{"ipv4": "192.168.1.1", "ipv6": "2001:db8::1", "name": "test"}'
    
    run assert_type_ip "$json" ".ipv4" "v4"
    [ $status -eq 0 ]
    
    run assert_type_ip "$json" ".ipv6" "v6"
    [ $status -eq 0 ]
    
    run assert_type_ip "$json" ".ipv4" "any"
    [ $status -eq 0 ]
    
    run assert_type_ip "$json" ".name" "v4"  # not an IP
    [ $status -ne 0 ]
}
