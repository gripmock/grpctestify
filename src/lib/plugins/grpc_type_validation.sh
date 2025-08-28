#!/bin/bash

# grpc_type_validation.sh - Enhanced type validation plugin
# Provides UUID, timestamp, URL, email, and other advanced validation types

# UUID validation (RFC 4122)
validate_uuid() {
    local value="$1"
    local version="${2:-any}"  # v1, v4, v5, or any
    
    # Basic UUID format check (8-4-4-4-12 hex digits)
    if [[ ! "$value" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        return 1
    fi
    
    # Version-specific validation
    if [[ "$version" != "any" ]]; then
        local version_digit="${value:14:1}"
        case "$version" in
            "v1"|"1") [[ "$version_digit" == "1" ]] || return 1 ;;
            "v4"|"4") [[ "$version_digit" == "4" ]] || return 1 ;;
            "v5"|"5") [[ "$version_digit" == "5" ]] || return 1 ;;
            *) return 1 ;;
        esac
    fi
    
    return 0
}

# ISO 8601 timestamp validation
validate_iso8601() {
    local value="$1"
    local strict="${2:-false}"
    
    if [[ "$strict" == "true" ]]; then
        # Strict ISO 8601: YYYY-MM-DDTHH:MM:SS[.sss]Z or YYYY-MM-DDTHH:MM:SS[.sss]±HH:MM
        [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,3})?(Z|[+-][0-9]{2}:[0-9]{2})$ ]]
    else
        # Relaxed timestamp format
        [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]
    fi
}

# RFC 3339 timestamp validation
validate_rfc3339() {
    local value="$1"
    # RFC 3339: YYYY-MM-DDTHH:MM:SS[.sss]Z or YYYY-MM-DDTHH:MM:SS[.sss]±HH:MM
    [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$ ]]
}

# Unix timestamp validation
validate_unix_timestamp() {
    local value="$1"
    local format="${2:-seconds}"  # seconds, milliseconds, microseconds
    
    case "$format" in
        "seconds")
            # 10 digits for current era (until year 2286)
            [[ "$value" =~ ^[0-9]{10}$ ]] && [[ "$value" -gt 0 ]]
            ;;
        "milliseconds"|"ms")
            # 13 digits
            [[ "$value" =~ ^[0-9]{13}$ ]] && [[ "$value" -gt 0 ]]
            ;;
        "microseconds"|"us")
            # 16 digits
            [[ "$value" =~ ^[0-9]{16}$ ]] && [[ "$value" -gt 0 ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# URL validation (RFC 3986)
validate_url() {
    local value="$1"
    local scheme="${2:-any}"  # http, https, ftp, or any
    
    # Basic URL structure check
    if [[ ! "$value" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:]]+$ ]]; then
        return 1
    fi
    
    # Scheme-specific validation
    if [[ "$scheme" != "any" ]]; then
        case "$scheme" in
            "http")
                [[ "$value" =~ ^http://[^[:space:]]+$ ]] || return 1
                ;;
            "https")
                [[ "$value" =~ ^https://[^[:space:]]+$ ]] || return 1
                ;;
            "ftp")
                [[ "$value" =~ ^ftp://[^[:space:]]+$ ]] || return 1
                ;;
            "ws")
                [[ "$value" =~ ^ws://[^[:space:]]+$ ]] || return 1
                ;;
            "wss")
                [[ "$value" =~ ^wss://[^[:space:]]+$ ]] || return 1
                ;;
            *)
                return 1
                ;;
        esac
    fi
    
    return 0
}

# Email validation (RFC 5322 simplified)
validate_email() {
    local value="$1"
    local strict="${2:-false}"
    
    if [[ "$strict" == "true" ]]; then
        # Strict email validation
        [[ "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
    else
        # Basic email validation
        [[ "$value" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]
    fi
}

# JSON Web Token (JWT) validation
validate_jwt() {
    local value="$1"
    local check_structure="${2:-true}"
    
    # Basic JWT structure: header.payload.signature
    if [[ ! "$value" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        return 1
    fi
    
    if [[ "$check_structure" == "true" ]]; then
        # Check if header and payload are valid base64url
        local header payload
        header=$(echo "$value" | cut -d. -f1)
        payload=$(echo "$value" | cut -d. -f2)
        
        # Try to decode header and payload (basic check)
        if command -v base64 >/dev/null 2>&1; then
            # Add padding if needed and try to decode
            local padded_header="${header}$(printf '%*s' $(((4 - ${#header} % 4) % 4)) | tr ' ' '=')"
            local padded_payload="${payload}$(printf '%*s' $(((4 - ${#payload} % 4) % 4)) | tr ' ' '=')"
            
            echo "$padded_header" | tr '_-' '/+' | base64 -d >/dev/null 2>&1 || return 1
            echo "$padded_payload" | tr '_-' '/+' | base64 -d >/dev/null 2>&1 || return 1
        fi
    fi
    
    return 0
}

# IP address validation
validate_ip() {
    local value="$1"
    local version="${2:-any}"  # v4, v6, or any
    
    case "$version" in
        "v4"|"4")
            validate_ipv4 "$value"
            ;;
        "v6"|"6")
            validate_ipv6 "$value"
            ;;
        "any")
            validate_ipv4 "$value" || validate_ipv6 "$value"
            ;;
        *)
            return 1
            ;;
    esac
}

# IPv4 validation
validate_ipv4() {
    local value="$1"
    
    # Check basic format
    if [[ ! "$value" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # Check each octet is 0-255
    local IFS='.'
    local octets=($value)
    for octet in "${octets[@]}"; do
        if [[ $octet -gt 255 ]] || [[ $octet -lt 0 ]]; then
            return 1
        fi
        # No leading zeros unless it's just "0"
        if [[ ${#octet} -gt 1 && $octet == 0* ]]; then
            return 1
        fi
    done
    
    return 0
}

# IPv6 validation (simplified)
validate_ipv6() {
    local value="$1"
    
    # Basic IPv6 pattern check
    [[ "$value" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]] || \
    [[ "$value" =~ ^::1$ ]] || \
    [[ "$value" =~ ^::$ ]] || \
    [[ "$value" =~ ^([0-9a-fA-F]{1,4}:){1,7}:$ ]] || \
    [[ "$value" =~ ^:([0-9a-fA-F]{1,4}:){1,7}$ ]]
}

# Semantic version validation
validate_semver() {
    local value="$1"
    local allow_prerelease="${2:-true}"
    
    if [[ "$allow_prerelease" == "true" ]]; then
        # Allow prerelease and build metadata
        [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]
    else
        # Strict semver (major.minor.patch only)
        [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    fi
}

# MAC address validation
validate_mac_address() {
    local value="$1"
    local format="${2:-any}"  # colon, dash, or any
    
    case "$format" in
        "colon")
            [[ "$value" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]
            ;;
        "dash")
            [[ "$value" =~ ^([0-9a-fA-F]{2}-){5}[0-9a-fA-F]{2}$ ]]
            ;;
        "any")
            [[ "$value" =~ ^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$ ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Base64 validation
validate_base64() {
    local value="$1"
    local strict="${2:-false}"
    
    if [[ "$strict" == "true" ]]; then
        # Strict base64: only A-Z, a-z, 0-9, +, /, and = for padding
        [[ "$value" =~ ^[A-Za-z0-9+/]*={0,2}$ ]] && [[ $((${#value} % 4)) -eq 0 ]]
    else
        # Basic base64 pattern
        [[ "$value" =~ ^[A-Za-z0-9+/].*$ ]]
    fi
}

# Credit card number validation (Luhn algorithm)
validate_credit_card() {
    local value="$1"
    local brand="${2:-any}"  # visa, mastercard, amex, or any
    
    # Remove spaces and dashes
    value="${value// /}"
    value="${value//-/}"
    
    # Check if all digits
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    
    # Brand-specific validation
    case "$brand" in
        "visa")
            [[ "$value" =~ ^4[0-9]{12,18}$ ]] || return 1
            ;;
        "mastercard")
            [[ "$value" =~ ^5[1-5][0-9]{14}$ ]] || return 1
            ;;
        "amex"|"american_express")
            [[ "$value" =~ ^3[47][0-9]{13}$ ]] || return 1
            ;;
        "discover")
            [[ "$value" =~ ^6011[0-9]{12}$ ]] || return 1
            ;;
        "any")
            # General credit card length check
            [[ ${#value} -ge 13 && ${#value} -le 19 ]] || return 1
            ;;
        *)
            return 1
            ;;
    esac
    
    # Luhn algorithm validation
    luhn_check "$value"
}

# Luhn algorithm implementation
luhn_check() {
    local number="$1"
    local sum=0
    local alternate=false
    
    # Process digits from right to left
    for ((i=${#number}-1; i>=0; i--)); do
        local digit=${number:$i:1}
        
        if [[ "$alternate" == "true" ]]; then
            digit=$((digit * 2))
            if [[ $digit -gt 9 ]]; then
                digit=$((digit - 9))
            fi
        fi
        
        sum=$((sum + digit))
        alternate=$([ "$alternate" == "true" ] && echo "false" || echo "true")
    done
    
    [[ $((sum % 10)) -eq 0 ]]
}

# Phone number validation (international format)
validate_phone() {
    local value="$1"
    local format="${2:-international}"  # international, us, or any
    
    case "$format" in
        "international")
            # E.164 format: +[1-4 digits country code][4-15 digits]
            [[ "$value" =~ ^\+[1-9][0-9]{4,14}$ ]]
            ;;
        "us")
            # US format: (XXX) XXX-XXXX or XXX-XXX-XXXX or XXXXXXXXXX
            [[ "$value" =~ ^\([0-9]{3}\)[[:space:]]*[0-9]{3}-[0-9]{4}$ ]] || \
            [[ "$value" =~ ^[0-9]{3}-[0-9]{3}-[0-9]{4}$ ]] || \
            [[ "$value" =~ ^[0-9]{10}$ ]]
            ;;
        "any")
            # Basic phone number pattern
            [[ "$value" =~ ^[\+]?[0-9\(\)\-\s\.]{7,15}$ ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Color code validation
validate_color() {
    local value="$1"
    local format="${2:-any}"  # hex, rgb, hsl, or any
    
    case "$format" in
        "hex")
            [[ "$value" =~ ^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$ ]]
            ;;
        "rgb")
            [[ "$value" =~ ^rgb\([[:space:]]*([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])[[:space:]]*,[[:space:]]*([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])[[:space:]]*,[[:space:]]*([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])[[:space:]]*\)$ ]]
            ;;
        "hsl")
            [[ "$value" =~ ^hsl\([[:space:]]*([0-9]|[1-9][0-9]|[12][0-9][0-9]|3[0-5][0-9]|360)[[:space:]]*,[[:space:]]*([0-9]|[1-9][0-9]|100)%[[:space:]]*,[[:space:]]*([0-9]|[1-9][0-9]|100)%[[:space:]]*\)$ ]]
            ;;
        "any")
            validate_color "$value" "hex" || \
            validate_color "$value" "rgb" || \
            validate_color "$value" "hsl"
            ;;
        *)
            return 1
            ;;
    esac
}

# Plugin assertion functions for jq integration
assert_type_uuid() {
    local response="$1"
    local field_path="$2"
    local uuid_version="${3:-any}"
    
    local value
    value=$(echo "$response" | jq -r "$field_path" 2>/dev/null)
    
    if [[ "$value" == "null" || -z "$value" ]]; then
        log error "Field '$field_path' is null or empty"
        return 1
    fi
    
    if validate_uuid "$value" "$uuid_version"; then
        log debug "UUID validation passed for field '$field_path': $value"
        return 0
    else
        log error "UUID validation failed for field '$field_path': $value"
        return 1
    fi
}

assert_type_timestamp() {
    local response="$1"
    local field_path="$2"
    local timestamp_format="${3:-iso8601}"
    
    local value
    value=$(echo "$response" | jq -r "$field_path" 2>/dev/null)
    
    if [[ "$value" == "null" || -z "$value" ]]; then
        log error "Field '$field_path' is null or empty"
        return 1
    fi
    
    case "$timestamp_format" in
        "iso8601"|"iso")
            validate_iso8601 "$value"
            ;;
        "rfc3339"|"rfc")
            validate_rfc3339 "$value"
            ;;
        "unix"|"epoch")
            validate_unix_timestamp "$value" "seconds"
            ;;
        "unix_ms"|"epoch_ms")
            validate_unix_timestamp "$value" "milliseconds"
            ;;
        *)
            log error "Unknown timestamp format: $timestamp_format"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log debug "Timestamp validation passed for field '$field_path': $value"
    else
        log error "Timestamp validation failed for field '$field_path': $value (format: $timestamp_format)"
    fi
    return $result
}

assert_type_url() {
    local response="$1"
    local field_path="$2"
    local scheme="${3:-any}"
    
    local value
    value=$(echo "$response" | jq -r "$field_path" 2>/dev/null)
    
    if [[ "$value" == "null" || -z "$value" ]]; then
        log error "Field '$field_path' is null or empty"
        return 1
    fi
    
    if validate_url "$value" "$scheme"; then
        log debug "URL validation passed for field '$field_path': $value"
        return 0
    else
        log error "URL validation failed for field '$field_path': $value (scheme: $scheme)"
        return 1
    fi
}

assert_type_email() {
    local response="$1"
    local field_path="$2"
    local strict="${3:-false}"
    
    local value
    value=$(echo "$response" | jq -r "$field_path" 2>/dev/null)
    
    if [[ "$value" == "null" || -z "$value" ]]; then
        log error "Field '$field_path' is null or empty"
        return 1
    fi
    
    if validate_email "$value" "$strict"; then
        log debug "Email validation passed for field '$field_path': $value"
        return 0
    else
        log error "Email validation failed for field '$field_path': $value"
        return 1
    fi
}

assert_type_ip() {
    local response="$1"
    local field_path="$2"
    local version="${3:-any}"
    
    local value
    value=$(echo "$response" | jq -r "$field_path" 2>/dev/null)
    
    if [[ "$value" == "null" || -z "$value" ]]; then
        log error "Field '$field_path' is null or empty"
        return 1
    fi
    
    if validate_ip "$value" "$version"; then
        log debug "IP validation passed for field '$field_path': $value"
        return 0
    else
        log error "IP validation failed for field '$field_path': $value (version: $version)"
        return 1
    fi
}

# Register type validation plugin
register_type_validation_plugin() {
    register_plugin "uuid" "assert_type_uuid" "UUID validation plugin" "internal"
    register_plugin "timestamp" "assert_type_timestamp" "Timestamp validation plugin" "internal"
    register_plugin "url" "assert_type_url" "URL validation plugin" "internal"
    register_plugin "email" "assert_type_email" "Email validation plugin" "internal"
    register_plugin "ip" "assert_type_ip" "IP address validation plugin" "internal"
}

# Export validation functions for direct use
export -f validate_uuid
export -f validate_iso8601
export -f validate_rfc3339
export -f validate_unix_timestamp
export -f validate_url
export -f validate_email
export -f validate_jwt
export -f validate_ip
export -f validate_ipv4
export -f validate_ipv6
export -f validate_semver
export -f validate_mac_address
export -f validate_base64
export -f validate_credit_card
export -f validate_phone
export -f validate_color

# Export plugin functions
export -f assert_type_uuid
export -f assert_type_timestamp
export -f assert_type_url
export -f assert_type_email
export -f assert_type_ip
export -f register_type_validation_plugin
