#!/bin/bash

# file_parser.sh - Core .gctf file parsing plugin using microkernel architecture
# Migrated from legacy parser.sh, utils.sh, and assertions.sh modules

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
readonly PLUGIN_FILE_PARSER_VERSION="1.0.0"
readonly PLUGIN_FILE_PARSER_DESCRIPTION="Kernel .gctf file parsing with microkernel integration"
readonly PLUGIN_FILE_PARSER_AUTHOR="grpctestify-team"
readonly PLUGIN_FILE_PARSER_TYPE="kernel"

# Supported sections in .gctf files
declare -A SUPPORTED_SECTIONS=(
    ["ADDRESS"]="Server address and port"
    ["ENDPOINT"]="gRPC service method"
    ["REQUEST"]="Request payload (JSON)"
    ["RESPONSE"]="Expected response (JSON)"
    ["ERROR"]="Expected error response"
    ["HEADERS"]="gRPC headers to send"
    ["REQUEST_HEADERS"]="Request-specific headers"
    ["ASSERTS"]="Response assertions"
    ["PROTO"]="Proto configuration"
    ["TLS"]="TLS configuration"
)

# Initialize file parser plugin
file_parser_init() {
    log_debug "Initializing file parser plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    log_warn "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "file_parser" "file_parser_handler" "$PLUGIN_FILE_PARSER_DESCRIPTION" "kernel" ""
    
    # Create resource pool for file parsing operations
    pool_create "file_parsing" 2
    
    # Subscribe to file parsing events
    event_subscribe "file_parser" "file.*" "file_parser_event_handler"
    
    log_debug "File parser plugin initialized successfully"
    return 0
}

# In-memory cache for parsed test files (key: path@mtime -> json)
declare -g -A FILE_PARSER_CACHE=()

# Get file modification time (portable: macOS/Linux)
file_parser_get_mtime() {
    local path="$1"
    if command -v stat >/dev/null 2>&1; then
        # macOS
        stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Main file parser handler
file_parser_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "parse")
            file_parser_parse_file "${args[@]}"
            ;;
        "extract_section")
            file_parser_extract_section "${args[@]}"
            ;;
        "validate")
            file_parser_validate_file "${args[@]}"
            ;;
        "list_sections")
            file_parser_list_sections "${args[@]}"
            ;;
        "parse_components")
            file_parser_parse_components "${args[@]}"
            ;;
        *)
    log_error "Unknown file parser command: $command"
            return 1
            ;;
    esac
}

# Parse complete .gctf test file with microkernel integration
file_parser_parse_file() {
    local test_file="$1"
    local parse_options="${2:-{}}"
    
    if [[ -z "$test_file" || ! -f "$test_file" ]]; then
    log_error "file_parser_parse_file: valid test_file required"
        return 1
    fi
    
    log_debug "Parsing test file: $test_file"
    
    # Publish parsing start event
    local parse_metadata
    parse_metadata=$(cat << EOF
{
  "test_file": "$test_file",
  "parser": "file_parser",
  "start_time": $(date +%s),
  "options": $parse_options
}
EOF
)
    event_publish "file.parsing.start" "$parse_metadata" "$EVENT_PRIORITY_NORMAL" "file_parser"
    
    # Begin transaction for file parsing
    local tx_id
    tx_id=$(state_db_begin_transaction "file_parsing_$(basename "$test_file")_$$")
    
    # Acquire resource for file parsing
    local resource_token
    resource_token=$(pool_acquire "file_parsing" 30)
    if [[ $? -ne 0 ]]; then
    log_error "Failed to acquire resource for file parsing: $test_file"
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
    
    # Parse file sections with error handling
    local parsing_result=0
    local parsed_data
    
    if parsed_data=$(parse_test_file "$test_file" "$parse_options"); then
    log_debug "File parsed successfully: $test_file"
        
        # Store parsed data in state database
        state_db_atomic "record_parsed_file" "$test_file" "SUCCESS" "$parsed_data"
        
        # Publish success event
        event_publish "file.parsing.success" "{\"test_file\":\"$test_file\"}" "$EVENT_PRIORITY_NORMAL" "file_parser"
        
        # Output parsed data
        echo "$parsed_data"
    else
        parsing_result=1
    log_error "File parsing failed: $test_file"
        
        # Record failed parsing
        state_db_atomic "record_parsed_file" "$test_file" "FAILED" ""
        
        # Publish failure event
        event_publish "file.parsing.failure" "{\"test_file\":\"$test_file\"}" "$EVENT_PRIORITY_HIGH" "file_parser"
    fi
    
    # Release resource
    pool_release "file_parsing" "$resource_token"
    
    # Commit transaction
    state_db_commit_transaction "$tx_id"
    
    return $parsing_result
}

# Enhanced .gctf file parsing with microkernel integration
parse_test_file() {
    local test_file="$1"
    local parse_options="$2"
    
    # Fast-path: return cached result if file not changed
    local mtime
    mtime="$(file_parser_get_mtime "$test_file")"
    local cache_key
    cache_key="${test_file}@${mtime}"
    if [[ -n "${FILE_PARSER_CACHE[$cache_key]:-}" ]]; then
        echo "${FILE_PARSER_CACHE[$cache_key]}"
        return 0
    fi
    
    # Extract all sections using the robust AWK parser
    local address
    address="$(extract_section "$test_file" "ADDRESS")"
    local endpoint
    endpoint="$(extract_section "$test_file" "ENDPOINT")"
    local request
    request="$(extract_all_request_sections "$test_file")"
    local response
    response="$(extract_section "$test_file" "RESPONSE")"
    local error
    error="$(extract_section "$test_file" "ERROR")"
    local headers
    headers="$(extract_section "$test_file" "HEADERS")"
    
    # Warn about deprecated HEADERS section
    if [[ -n "$headers" ]]; then
        echo "⚠️  WARNING: HEADERS section is deprecated. Use REQUEST_HEADERS instead." >&2
    fi
    
    local request_headers
    request_headers="$(extract_section "$test_file" "REQUEST_HEADERS")"
    local asserts
    asserts="$(extract_section "$test_file" "ASSERTS")"
    local proto
    proto="$(extract_section "$test_file" "PROTO")"
    local tls
    tls="$(extract_section "$test_file" "TLS")"
    
    # Parse response inline options
    local response_header
    response_header="$(extract_section_header "$test_file" "RESPONSE")"
    local response_options
    response_options="$(parse_inline_options "$response_header")"
    
    # Set defaults for backward compatibility  
    # ADDRESS section has priority over environment variable
    if [[ -z "$address" ]]; then
        # Use GRPCTESTIFY_ADDRESS as fallback if no ADDRESS section
        address="${GRPCTESTIFY_ADDRESS:-localhost:4770}"
    fi
    
    # Validate required sections
    if [[ -z "$endpoint" ]]; then
    log_error "Missing ENDPOINT section in $test_file"
        return 1
    fi
    
    # Build comprehensive parsed data structure
    local parsed
    parsed=$(jq -n \
        --arg address "$address" \
        --arg endpoint "$endpoint" \
        --arg request "$request" \
        --arg response "$response" \
        --arg error "$error" \
        --arg headers "$headers" \
        --arg request_headers "$request_headers" \
        --arg asserts "$asserts" \
        --arg proto "$proto" \
        --arg tls "$tls" \
        --arg response_options "$response_options" \
        --arg test_file "$test_file" \
        --arg parsed_at "$(date -Iseconds)" \
        '{
            metadata: {
                test_file: $test_file,
                parsed_at: $parsed_at,
                parser_version: "1.0.0"
            },
            sections: {
                address: $address,
                endpoint: $endpoint,
                request: $request,
                response: $response,
                error: $error,
                headers: $headers,
                request_headers: $request_headers,
                asserts: $asserts,
                proto: $proto,
                tls: $tls
            },
            options: {
                response: $response_options
            },
            validation: {
                has_endpoint: ($endpoint | length > 0),
                has_request: ($request | length > 0),
                has_response: ($response | length > 0),
                has_error: ($error | length > 0),
                has_asserts: ($asserts | length > 0),
                has_proto: ($proto | length > 0),
                has_tls: ($tls | length > 0)
            }
        }')
    
    # Store in cache and output
    FILE_PARSER_CACHE["$cache_key"]="$parsed"
    echo "$parsed"
}

# Extract section from test file using enhanced AWK parser
extract_section() {
    local test_file="$1"
    local section="$2"
    
    # Use the robust AWK parser from utils.sh
    awk -v sec="$section" '
    # Smart comment removal: processes line character-by-character to handle quotes correctly
    function process_line(line) {
        in_str = 0
        escaped = 0
        res = ""
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (escaped) {
                res = res c
                escaped = 0
            } else if (c == "\\") {
                res = res c
                escaped = 1
            } else if (c == "\"") {
                res = res c
                in_str = !in_str
            } else if (c == "#" && !in_str) {
                break
            } else {
                res = res c
            }
        }
        return res
    }
    $0 ~ /^[[:space:]]*#/ { next }
    $0 ~ "^[[:space:]]*---[[:space:]]*" sec "([[:space:]]+.*)?[[:space:]]*---" { 
        found=1
        # Capture the full line for modifier detection
        modifier_line = $0
        next 
    } 
    /^[[:space:]]*---/ { 
        found=0 
    } 
    found {
        processed = process_line($0)
        gsub(/^[[:space:]]*/, "", processed)
        gsub(/[[:space:]]*$/, "", processed)
        if (processed != "") {
            printf "%s\n", processed
        }
    }' "$test_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Extract ALL REQUEST sections for client streaming
extract_all_request_sections() {
    local test_file="$1"
    
    awk '
    # Smart comment removal: processes line character-by-character to handle quotes correctly
    function process_line(line) {
        in_str = 0
        escaped = 0
        res = ""
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (escaped) {
                res = res c
                escaped = 0
            } else if (c == "\\") {
                res = res c
                escaped = 1
            } else if (c == "\"") {
                res = res c
                in_str = !in_str
            } else if (c == "#" && !in_str) {
                break
            } else {
                res = res c
            }
        }
        return res
    }
    $0 ~ /^[[:space:]]*#/ { next } # skip comment lines
    $0 ~ "^[[:space:]]*---[[:space:]]*REQUEST[[:space:]]*---" { 
        found=1 
        next 
    } 
    /^[[:space:]]*---/ { 
        found=0 
    } 
    found {
        # Process comments inside JSON strings
        processed = process_line($0)
        gsub(/[[:space:]]+$/, "", processed)
        if (length(processed) > 0) {
            printf "%s\n", processed
        }
    }' "$test_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Extract section header (the --- SECTION_NAME ... --- line itself)
extract_section_header() {
    local test_file="$1"
    local section="$2"
    
    grep -n "^[[:space:]]*---[[:space:]]*${section}" "$test_file" | head -1 | cut -d: -f2-
}

# Parse inline options from section headers
parse_inline_options() {
    local header="$1"
    
    # Extract options from header: --- RESPONSE key=value ... ---
    if [[ "$header" =~ ---[[:space:]]*RESPONSE[[:space:]]+(.+)[[:space:]]*--- ]]; then
        local options_str="${BASH_REMATCH[1]}"
        
        # Simple approach: split by spaces and process each token
        local tokens=()
        local in_quotes=false
        local current_token=""
        
        # Tokenize the options string, respecting quotes
        for ((i=0; i<${#options_str}; i++)); do
            local char="${options_str:$i:1}"
            
            if [[ "$char" == '"' ]]; then
                in_quotes=$((!in_quotes))
                current_token+="$char"
            elif [[ "$char" == ' ' && $in_quotes -eq 0 ]]; then
                if [[ -n "$current_token" ]]; then
                    tokens+=("$current_token")
                    current_token=""
                fi
            else
                current_token+="$char"
            fi
        done
        
        # Add the last token if any
        if [[ -n "$current_token" ]]; then
            tokens+=("$current_token")
        fi
        
        # Build JSON object from parsed tokens
        local options_json="{"
        local first=true
        
        # Process each token as key=value pair or standalone flags
        for token in "${tokens[@]}"; do
            [[ "$first" == "true" ]] && first=false || options_json+=","
            
            if [[ "$token" =~ ^([a-zA-Z_][a-zA-Z0-9_]*(\[[^\]]*\])?)=(.*)$ ]]; then
                # Key=value format
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[3]}"
                
                # Remove quotes from value
                value="${value%\"}"
                value="${value#\"}"
                
                options_json+="\"$key\":\"$value\""
            elif [[ "$token" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)$ ]]; then
                # Standalone flag (e.g., with_asserts)
                options_json+="\"${BASH_REMATCH[1]}\":true"
            fi
        done
        
        options_json+="}"
        echo "$options_json"
    else
        echo "{}"
    fi
}

# Extract specific section using the plugin interface
file_parser_extract_section() {
    local test_file="$1"
    local section="$2"
    
    if [[ -z "$test_file" || -z "$section" ]]; then
    log_error "file_parser_extract_section: test_file and section required"
        return 1
    fi
    
    if [[ ! -f "$test_file" ]]; then
    log_error "Test file does not exist: $test_file"
        return 1
    fi
    
    # Check if section is supported
    if [[ -z "${SUPPORTED_SECTIONS[$section]:-}" ]]; then
    log_warn "Unsupported section: $section"
    fi
    
    extract_section "$test_file" "$section"
}

# Validate .gctf file structure
file_parser_validate_file() {
    local test_file="$1"
    local validation_rules="${2:-strict}"
    
    if [[ -z "$test_file" ]]; then
    log_error "file_parser_validate_file: test_file required"
        return 1
    fi
    
    if [[ ! -f "$test_file" ]]; then
    log_error "Test file does not exist: $test_file"
        return 1
    fi
    
    if [[ ! -r "$test_file" ]]; then
    log_error "Test file is not readable: $test_file"
        return 1
    fi
    
    # Check file extension
    if [[ ! "$test_file" =~ \.gctf$ ]]; then
    log_warn "Test file does not have .gctf extension: $test_file"
        if [[ "$validation_rules" == "strict" ]]; then
            return 1
        fi
    fi
    
    # Basic content validation
    if [[ ! -s "$test_file" ]]; then
    log_error "Test file is empty: $test_file"
        return 1
    fi
    
    # Validate required sections
    local endpoint
    endpoint="$(extract_section "$test_file" "ENDPOINT")"
    if [[ -z "$endpoint" ]]; then
    log_error "Missing required ENDPOINT section in: $test_file"
        return 1
    fi
    
    # Validate JSON sections if present
    local sections_to_validate=("REQUEST" "RESPONSE" "ERROR" "HEADERS" "REQUEST_HEADERS")
    for section in "${sections_to_validate[@]}"; do
        local content
        content="$(extract_section "$test_file" "$section")"
        if [[ -n "$content" ]]; then
            if ! echo "$content" | jq . >/dev/null 2>&1; then
    log_error "Invalid JSON in $section section of: $test_file"
                if [[ "$validation_rules" == "strict" ]]; then
                    return 1
                fi
            fi
        fi
    done
    
    log_debug "File validation passed: $test_file"
    return 0
}

# List all sections found in a .gctf file
file_parser_list_sections() {
    local test_file="$1"
    local output_format="${2:-summary}"
    
    if [[ -z "$test_file" || ! -f "$test_file" ]]; then
    log_error "file_parser_list_sections: valid test_file required"
        return 1
    fi
    
    local found_sections=()
    
    # Check each supported section
    for section in "${!SUPPORTED_SECTIONS[@]}"; do
        local content
        content="$(extract_section "$test_file" "$section")"
        if [[ -n "$content" ]]; then
            found_sections+=("$section")
        fi
    done
    
    case "$output_format" in
        "summary")
            printf "Found %d sections in %s:\n" "${#found_sections[@]}" "$(basename "$test_file")"
            for section in "${found_sections[@]}"; do
                printf "  - %s: %s\n" "$section" "${SUPPORTED_SECTIONS[$section]}"
            done
            ;;
        "list")
            for section in "${found_sections[@]}"; do
                echo "$section"
            done
            ;;
        "json")
            printf "{"
            printf "\"test_file\":\"%s\"," "$test_file"
            printf "\"sections\":["
            local first=true
            for section in "${found_sections[@]}"; do
                [[ "$first" == "true" ]] && first=false || printf ","
                printf "{\"name\":\"%s\",\"description\":\"%s\"}" "$section" "${SUPPORTED_SECTIONS[$section]}"
            done
            printf "]}"
            ;;
    esac
}

# Parse file components for test execution
file_parser_parse_components() {
    local test_file="$1"
    
    if [[ -z "$test_file" || ! -f "$test_file" ]]; then
    log_error "file_parser_parse_components: valid test_file required"
        return 1
    fi
    
    # Parse file and extract components for execution
    local parsed_data
    parsed_data=$(parse_test_file "$test_file" "{}")
    
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Transform parsed data into execution components format
    echo "$parsed_data" | jq '{
        grpc_calls: {
            address: .sections.address,
            endpoint: .sections.endpoint,
            request: .sections.request,
            headers: .sections.headers,
            request_headers: .sections.request_headers,
            proto: .sections.proto,
            tls: .sections.tls
        },
        assertions: {
            response: .sections.response,
            error: .sections.error,
            asserts: .sections.asserts,
            options: .options.response
        },
        metadata: {
            test_file: .metadata.test_file,
            validation: .validation
        }
    }'
}

# File parser event handler
file_parser_event_handler() {
    local event_message="$1"
    
    log_debug "File parser received event: $event_message"
    
    # Handle file parsing events
    # This could be used for:
    # - File parsing performance monitoring
    # - Cache management for parsed files
    # - Parsing error pattern analysis
    # - File format evolution tracking
    
    return 0
}

# State database helper functions
record_parsed_file() {
    local test_file="$1"
    local status="$2"
    local parsed_data="$3"
    
    local file_key="parsed_file_$(basename "$test_file")"
    GRPCTESTIFY_STATE["${file_key}_status"]="$status"
    GRPCTESTIFY_STATE["${file_key}_timestamp"]="$(date +%s)"
    [[ -n "$parsed_data" ]] && GRPCTESTIFY_STATE["${file_key}_data"]="$parsed_data"
    
    return 0
}

 

# extract_asserts is now handled by the assertion coordinator plugin

# Export functions - CLEANED UP DUPLICATES
export -f file_parser_init file_parser_handler file_parser_parse_file
export -f parse_test_file extract_section extract_all_request_sections
export -f extract_section_header parse_inline_options file_parser_extract_section
export -f file_parser_validate_file file_parser_list_sections file_parser_parse_components
export -f file_parser_event_handler record_parsed_file
 
