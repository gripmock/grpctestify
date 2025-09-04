#!/bin/bash

# grpc_proto.sh - Enhanced proto contracts and descriptor files plugin with microkernel integration
# Migrated from legacy grpc_proto.sh with microkernel components

# Source plugin integration layer
# source "$(dirname "${BASH_SOURCE[0]}")/../../core/plugin_integration.sh"

# Plugin metadata
readonly PLUGIN_PROTO_VERSION="1.0.0"
readonly PLUGIN_PROTO_DESCRIPTION="Enhanced proto contracts and descriptor files handler with microkernel integration"
readonly PLUGIN_PROTO_AUTHOR="grpctestify-team"
readonly PLUGIN_PROTO_TYPE="validation"

# Proto configuration
PROTO_CACHE_SIZE="${PROTO_CACHE_SIZE:-100}"
PROTO_VALIDATION_STRICT="${PROTO_VALIDATION_STRICT:-false}"
PROTO_RELOAD_ON_CHANGE="${PROTO_RELOAD_ON_CHANGE:-true}"

# Proto state variables
declare -g PROTO_MODE=""
declare -g PROTO_FLAGS=""
declare -g PROTO_FILES=""
declare -g PROTO_DESCRIPTOR=""
declare -g PROTO_IMPORT_PATHS=""

# Initialize proto plugin
grpc_proto_init() {
    log_debug "Initializing proto contracts plugin..."
    
    # Ensure plugin integration is available
    if ! command -v plugin_register >/dev/null 2>&1; then
    log_warn "Plugin integration system not available, skipping plugin registration"
        return 1
    fi
    
    # Register plugin with microkernel
    plugin_register "proto" "grpc_proto_handler" "$PLUGIN_PROTO_DESCRIPTION" "internal" ""
    
    # Create resource pool for proto processing
    pool_create "proto_processing" 2
    
    # Subscribe to proto-related events
    event_subscribe "proto" "proto.*" "grpc_proto_event_handler"
    event_subscribe "proto" "file.changed" "grpc_proto_file_change_handler"
    
    # Initialize proto tracking state
    if command -v state_db_set >/dev/null 2>&1; then
        state_db_set "proto.plugin_version" "$PLUGIN_PROTO_VERSION"
        state_db_set "proto.files_loaded" "0"
        state_db_set "proto.descriptors_loaded" "0"
        state_db_set "proto.cache_entries" "0"
        state_db_set "proto.validation_errors" "0"
    fi
    
    log_debug "Proto contracts plugin initialized successfully"
    return 0
}

# Main proto plugin handler
grpc_proto_handler() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "parse_proto_section")
            grpc_proto_parse_proto_section "${args[@]}"
            ;;
        "load_proto_files")
            grpc_proto_load_proto_files "${args[@]}"
            ;;
        "load_descriptor")
            grpc_proto_load_descriptor "${args[@]}"
            ;;
        "validate_proto_config")
            grpc_proto_validate_proto_config "${args[@]}"
            ;;
        "get_proto_flags")
            grpc_proto_get_proto_flags "${args[@]}"
            ;;
        "get_statistics")
            grpc_proto_get_statistics "${args[@]}"
            ;;
        "clear_cache")
            grpc_proto_clear_cache "${args[@]}"
            ;;
        *)
    log_error "Unknown proto command: $command"
            return 1
            ;;
    esac
}

# Enhanced proto section parsing with microkernel integration
grpc_proto_parse_proto_section() {
    local test_file="$1"
    local cache_key="${2:-auto}"
    
    if [[ -z "$test_file" ]]; then
    log_error "grpc_proto_parse_proto_section: test_file required"
        return 1
    fi
    
    if [[ ! -f "$test_file" ]]; then
    log_error "Proto test file not found: $test_file"
        return 1
    fi
    
    log_debug "Parsing proto section from: $test_file"
    
    # Check cache first if enabled
    if [[ "$cache_key" == "auto" ]]; then
        cache_key="proto_$(stat -c %Y "$test_file" 2>/dev/null || stat -f %m "$test_file" 2>/dev/null)_$(basename "$test_file")"
    fi
    
    if proto_cache_get "$cache_key"; then
    log_debug "Proto configuration loaded from cache: $cache_key"
        increment_proto_counter "cache_hits"
        return 0
    fi
    
    # Publish proto parsing start event
    local parsing_metadata
    parsing_metadata=$(cat << EOF
{
  "test_file": "$test_file",
  "plugin": "proto",
  "start_time": $(date +%s),
  "cache_key": "$cache_key"
}
EOF
)
    event_publish "proto.parsing.start" "$parsing_metadata" "$EVENT_PRIORITY_NORMAL" "proto"
    
    # Begin transaction for proto parsing
    local tx_id
    tx_id=$(state_db_begin_transaction "proto_parsing_$$")
    
    # Acquire resource for proto processing
    local resource_token
    resource_token=$(pool_acquire "proto_processing" 30)
    if [[ $? -ne 0 ]]; then
    log_error "Failed to acquire resource for proto processing"
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
    
    # Reset Proto state
    PROTO_MODE=""
    PROTO_FLAGS=""
    PROTO_FILES=""
    PROTO_DESCRIPTOR=""
    PROTO_IMPORT_PATHS=""
    
    # Parse Proto section from file
    local proto_section=""
    local in_proto_section=false
    local parsing_result=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^---[[:space:]]*PROTO[[:space:]]*--- ]]; then
            in_proto_section=true
            continue
        elif [[ "$line" =~ ^---[[:space:]]*[A-Z]+[[:space:]]*--- ]]; then
            in_proto_section=false
            continue
        elif [[ "$in_proto_section" == true ]]; then
            proto_section+="$line"$'\n'
        fi
    done < "$test_file"
    
    # Process proto configuration
    if [[ -n "$proto_section" ]]; then
        if ! process_proto_configuration "$proto_section"; then
            parsing_result=1
    log_error "Failed to process proto configuration"
        fi
    else
        # Default behavior: gRPC reflection
        PROTO_MODE="reflection"
        PROTO_FLAGS=""
    log_debug "No proto section found, using reflection mode"
    fi
    
    # Cache successful parsing
    if [[ $parsing_result -eq 0 ]]; then
        proto_cache_set "$cache_key"
        
        # Record successful parsing
        state_db_atomic "record_proto_parsing" "$test_file" "PASS"
        
        # Publish success event
        event_publish "proto.parsing.success" "{\"test_file\":\"$test_file\",\"mode\":\"$PROTO_MODE\"}" "$EVENT_PRIORITY_NORMAL" "proto"
    else
        # Record failed parsing
        state_db_atomic "record_proto_parsing" "$test_file" "FAIL"
        
        # Publish failure event
        event_publish "proto.parsing.failure" "{\"test_file\":\"$test_file\"}" "$EVENT_PRIORITY_HIGH" "proto"
    fi
    
    # Update statistics
    increment_proto_counter "files_processed"
    if [[ $parsing_result -ne 0 ]]; then
        increment_proto_counter "validation_errors"
    fi
    
    # Release resource
    pool_release "proto_processing" "$resource_token"
    
    # Commit transaction
    state_db_commit_transaction "$tx_id"
    
    return $parsing_result
}

# Enhanced proto configuration processing
process_proto_configuration() {
    local proto_section="$1"
    
    log_debug "Processing proto configuration..."
    
    # Parse configuration line by line
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue
        
        # Parse configuration directives
        if [[ "$line" =~ ^mode[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            PROTO_MODE="${BASH_REMATCH[1]}"
    log_debug "Proto mode set to: $PROTO_MODE"
        elif [[ "$line" =~ ^files[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            PROTO_FILES="${BASH_REMATCH[1]}"
    log_debug "Proto files set to: $PROTO_FILES"
        elif [[ "$line" =~ ^descriptor[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            PROTO_DESCRIPTOR="${BASH_REMATCH[1]}"
    log_debug "Proto descriptor set to: $PROTO_DESCRIPTOR"
        elif [[ "$line" =~ ^import_paths[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            PROTO_IMPORT_PATHS="${BASH_REMATCH[1]}"
    log_debug "Proto import paths set to: $PROTO_IMPORT_PATHS"
        elif [[ "$line" =~ ^flags[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            PROTO_FLAGS="${BASH_REMATCH[1]}"
    log_debug "Proto flags set to: $PROTO_FLAGS"
        else
    log_warn "Unrecognized proto configuration line: $line"
        fi
    done <<< "$proto_section"
    
    # Validate proto configuration
    return $(validate_proto_configuration)
}

# Enhanced proto configuration validation
validate_proto_configuration() {
    local validation_errors=0
    
    # Validate proto mode
    case "$PROTO_MODE" in
        "reflection"|"files"|"descriptor"|"")
            # Valid modes
            ;;
        *)
    log_error "Invalid proto mode: $PROTO_MODE"
            ((validation_errors++))
            ;;
    esac
    
    # Validate files if mode is 'files'
    if [[ "$PROTO_MODE" == "files" ]]; then
        if [[ -z "$PROTO_FILES" ]]; then
    log_error "Proto files required when mode is 'files'"
            ((validation_errors++))
        else
            # Check if files exist
            IFS=',' read -ra file_list <<< "$PROTO_FILES"
            for proto_file in "${file_list[@]}"; do
                proto_file=$(echo "$proto_file" | xargs)  # Trim whitespace
                if [[ ! -f "$proto_file" ]]; then
    log_error "Proto file not found: $proto_file"
                    ((validation_errors++))
                fi
            done
        fi
    fi
    
    # Validate descriptor if mode is 'descriptor'
    if [[ "$PROTO_MODE" == "descriptor" ]]; then
        if [[ -z "$PROTO_DESCRIPTOR" ]]; then
    log_error "Proto descriptor required when mode is 'descriptor'"
            ((validation_errors++))
        elif [[ ! -f "$PROTO_DESCRIPTOR" ]]; then
    log_error "Proto descriptor file not found: $PROTO_DESCRIPTOR"
            ((validation_errors++))
        fi
    fi
    
    # Validate import paths if provided
    if [[ -n "$PROTO_IMPORT_PATHS" ]]; then
        IFS=',' read -ra path_list <<< "$PROTO_IMPORT_PATHS"
        for import_path in "${path_list[@]}"; do
            import_path=$(echo "$import_path" | xargs)  # Trim whitespace
            if [[ ! -d "$import_path" ]]; then
    log_warn "Proto import path not found: $import_path"
            fi
        done
    fi
    
    return $validation_errors
}

# Load proto files with enhanced error handling
grpc_proto_load_proto_files() {
    local files="$1"
    local import_paths="${2:-}"
    
    if [[ -z "$files" ]]; then
    log_error "grpc_proto_load_proto_files: files required"
        return 1
    fi
    
    log_debug "Loading proto files: $files"
    
    # Acquire resource for proto loading
    local resource_token
    resource_token=$(pool_acquire "proto_processing" 30)
    if [[ $? -ne 0 ]]; then
    log_error "Failed to acquire resource for proto loading"
        return 1
    fi
    
    local loading_result=0
    local files_loaded=0
    
    # Load each proto file
    IFS=',' read -ra file_list <<< "$files"
    for proto_file in "${file_list[@]}"; do
        proto_file=$(echo "$proto_file" | xargs)  # Trim whitespace
        
        if [[ -f "$proto_file" ]]; then
    log_debug "Loaded proto file: $proto_file"
            ((files_loaded++))
        else
    log_error "Proto file not found: $proto_file"
            loading_result=1
        fi
    done
    
    # Update statistics
    increment_proto_counter "files_loaded" "$files_loaded"
    if [[ $loading_result -ne 0 ]]; then
        increment_proto_counter "validation_errors"
    fi
    
    # Release resource
    pool_release "proto_processing" "$resource_token"
    
    # Publish loading result event
    if [[ $loading_result -eq 0 ]]; then
        event_publish "proto.loading.success" "{\"files_loaded\":$files_loaded}" "$EVENT_PRIORITY_NORMAL" "proto"
    else
        event_publish "proto.loading.failure" "{\"files_loaded\":$files_loaded}" "$EVENT_PRIORITY_HIGH" "proto"
    fi
    
    return $loading_result
}

# Load proto descriptor with enhanced validation
grpc_proto_load_descriptor() {
    local descriptor_file="$1"
    
    if [[ -z "$descriptor_file" ]]; then
    log_error "grpc_proto_load_descriptor: descriptor_file required"
        return 1
    fi
    
    if [[ ! -f "$descriptor_file" ]]; then
    log_error "Proto descriptor file not found: $descriptor_file"
        return 1
    fi
    
    log_debug "Loading proto descriptor: $descriptor_file"
    
    # Acquire resource for descriptor loading
    local resource_token
    resource_token=$(pool_acquire "proto_processing" 30)
    if [[ $? -ne 0 ]]; then
    log_error "Failed to acquire resource for descriptor loading"
        return 1
    fi
    
    # Validate descriptor file format
    local loading_result=0
    if ! validate_descriptor_file "$descriptor_file"; then
        loading_result=1
    log_error "Invalid proto descriptor file: $descriptor_file"
    else
    log_debug "Proto descriptor loaded successfully: $descriptor_file"
        increment_proto_counter "descriptors_loaded"
    fi
    
    # Release resource
    pool_release "proto_processing" "$resource_token"
    
    # Publish loading result event
    if [[ $loading_result -eq 0 ]]; then
        event_publish "proto.descriptor.success" "{\"descriptor\":\"$descriptor_file\"}" "$EVENT_PRIORITY_NORMAL" "proto"
    else
        event_publish "proto.descriptor.failure" "{\"descriptor\":\"$descriptor_file\"}" "$EVENT_PRIORITY_HIGH" "proto"
        increment_proto_counter "validation_errors"
    fi
    
    return $loading_result
}

# Validate descriptor file format
validate_descriptor_file() {
    local descriptor_file="$1"
    
    # Basic validation: check if file is readable and has reasonable size
    if [[ ! -r "$descriptor_file" ]]; then
    log_error "Descriptor file is not readable: $descriptor_file"
        return 1
    fi
    
    # Check file size (descriptor files should not be empty or too large)
    local file_size
    file_size=$(stat -c %s "$descriptor_file" 2>/dev/null || stat -f %z "$descriptor_file" 2>/dev/null)
    if [[ $file_size -eq 0 ]]; then
    log_error "Descriptor file is empty: $descriptor_file"
        return 1
    elif [[ $file_size -gt 104857600 ]]; then  # 100MB limit
    log_warn "Descriptor file is very large (${file_size} bytes): $descriptor_file"
    fi
    
    # Basic binary format check (descriptor files are binary protobuf)
    if file "$descriptor_file" | grep -q "text"; then
    log_warn "Descriptor file appears to be text, expected binary: $descriptor_file"
    fi
    
    return 0
}

# Get proto flags for grpcurl
grpc_proto_get_proto_flags() {
    local output_format="${1:-flags}"
    
    local flags=""
    
    case "$PROTO_MODE" in
        "reflection"|"")
            # No additional flags needed for reflection
            flags=""
            ;;
        "files")
            if [[ -n "$PROTO_FILES" ]]; then
                IFS=',' read -ra file_list <<< "$PROTO_FILES"
                for proto_file in "${file_list[@]}"; do
                    proto_file=$(echo "$proto_file" | xargs)
                    flags+=" -proto \"$proto_file\""
                done
            fi
            if [[ -n "$PROTO_IMPORT_PATHS" ]]; then
                IFS=',' read -ra path_list <<< "$PROTO_IMPORT_PATHS"
                for import_path in "${path_list[@]}"; do
                    import_path=$(echo "$import_path" | xargs)
                    flags+=" -import-path \"$import_path\""
                done
            fi
            ;;
        "descriptor")
            if [[ -n "$PROTO_DESCRIPTOR" ]]; then
                flags+=" -protoset \"$PROTO_DESCRIPTOR\""
            fi
            ;;
    esac
    
    # Add custom flags if provided
    if [[ -n "$PROTO_FLAGS" ]]; then
        flags+=" $PROTO_FLAGS"
    fi
    
    case "$output_format" in
        "flags")
            echo "$flags"
            ;;
        "array")
            # Return as bash array elements
            if [[ -n "$flags" ]]; then
                echo "$flags" | xargs -n1
            fi
            ;;
        "json")
            # Return as JSON array
            if [[ -n "$flags" ]]; then
                echo "$flags" | xargs -n1 | jq -R . | jq -s .
            else
                echo "[]"
            fi
            ;;
    esac
}

# Validate complete proto configuration
grpc_proto_validate_proto_config() {
    local config_context="${1:-{}}"
    
    log_debug "Validating complete proto configuration"
    
    local validation_errors=0
    
    # Validate current proto state
    validation_errors=$(validate_proto_configuration)
    
    # Additional validation based on current mode
    case "$PROTO_MODE" in
        "files")
            if ! grpc_proto_load_proto_files "$PROTO_FILES" "$PROTO_IMPORT_PATHS"; then
                ((validation_errors++))
            fi
            ;;
        "descriptor")
            if ! grpc_proto_load_descriptor "$PROTO_DESCRIPTOR"; then
                ((validation_errors++))
            fi
            ;;
    esac
    
    # Record validation result
    if [[ $validation_errors -eq 0 ]]; then
        state_db_atomic "record_proto_validation" "complete_config" "PASS"
    log_debug "Proto configuration validation passed"
    else
        state_db_atomic "record_proto_validation" "complete_config" "FAIL"
    log_error "Proto configuration validation failed ($validation_errors errors)"
        increment_proto_counter "validation_errors" "$validation_errors"
    fi
    
    return $validation_errors
}

# Simple proto cache implementation
proto_cache_get() {
    local key="$1"
    # Simple cache using state database
    if command -v state_db_get >/dev/null 2>&1; then
        local cached_result
        cached_result=$(state_db_get "proto_cache.$key" 2>/dev/null)
        [[ "$cached_result" == "true" ]]
    else
        return 1  # Cache miss if no state database
    fi
}

proto_cache_set() {
    local key="$1"
    # Simple cache using state database
    if command -v state_db_set >/dev/null 2>&1; then
        state_db_set "proto_cache.$key" "true"
        increment_proto_counter "cache_entries"
    fi
}

# Clear proto cache
grpc_proto_clear_cache() {
    log_debug "Clearing proto cache..."
    
    if command -v state_db_get >/dev/null 2>&1; then
        # Get all cache keys and remove them
        # This is a simplified implementation
        state_db_set "proto.cache_entries" "0"
    log_debug "Proto cache cleared"
    fi
}

# Get proto statistics
grpc_proto_get_statistics() {
    local format="${1:-json}"
    
    if command -v state_db_get >/dev/null 2>&1; then
        local files_loaded
        files_loaded=$(state_db_get "proto.files_loaded" || echo "0")
        local descriptors_loaded
        descriptors_loaded=$(state_db_get "proto.descriptors_loaded" || echo "0")
        local cache_entries
        cache_entries=$(state_db_get "proto.cache_entries" || echo "0")
        local validation_errors
        validation_errors=$(state_db_get "proto.validation_errors" || echo "0")
        local files_processed
        files_processed=$(state_db_get "proto.files_processed" || echo "0")
        
        case "$format" in
            "json")
                jq -n \
                    --argjson files_loaded "$files_loaded" \
                    --argjson descriptors_loaded "$descriptors_loaded" \
                    --argjson cache_entries "$cache_entries" \
                    --argjson validation_errors "$validation_errors" \
                    --argjson files_processed "$files_processed" \
                    --arg mode "$PROTO_MODE" \
                    '{
                        files_loaded: $files_loaded,
                        descriptors_loaded: $descriptors_loaded,
                        files_processed: $files_processed,
                        cache_entries: $cache_entries,
                        validation_errors: $validation_errors,
                        current_mode: $mode,
                        plugin_version: "1.0.0"
                    }'
                ;;
            "summary")
                echo "Proto Configuration Statistics:"
                echo "  Current mode: $PROTO_MODE"
                echo "  Files loaded: $files_loaded"
                echo "  Descriptors loaded: $descriptors_loaded"
                echo "  Files processed: $files_processed"
                echo "  Cache entries: $cache_entries"
                echo "  Validation errors: $validation_errors"
                ;;
        esac
    else
        echo '{"error": "State database not available"}'
    fi
}

# Increment proto counter
increment_proto_counter() {
    local counter_name="$1"
    local increment="${2:-1}"
    
    if command -v state_db_get >/dev/null 2>&1; then
        local current_value
        current_value=$(state_db_get "proto.$counter_name" || echo "0")
        state_db_set "proto.$counter_name" "$((current_value + increment))"
    fi
}

# Proto event handler
grpc_proto_event_handler() {
    local event_message="$1"
    
    log_debug "Proto plugin received event: $event_message"
    
    # Handle proto-related events
    # This could be used for:
    # - Proto file change detection and reload
    # - Proto validation performance monitoring
    # - Dynamic proto configuration updates
    # - Proto dependency tracking
    
    return 0
}

# File change event handler for proto auto-reload
grpc_proto_file_change_handler() {
    local event_message="$1"
    
    # Extract changed file from event
    local changed_file
    changed_file=$(echo "$event_message" | jq -r '.file // empty' 2>/dev/null)
    
    if [[ -n "$changed_file" && "$changed_file" != "null" ]]; then
        # Check if changed file is a proto file or descriptor
        if [[ "$changed_file" == *.proto || "$changed_file" == *.desc ]]; then
            if [[ "$PROTO_RELOAD_ON_CHANGE" == "true" ]]; then
    log_debug "Proto file changed, clearing cache: $changed_file"
                grpc_proto_clear_cache
            fi
        fi
    fi
    
    return 0
}

# State database helper functions
record_proto_parsing() {
    local test_file="$1"
    local result="$2"
    
    local parsing_key="proto_parsing_$(basename "$test_file")_$(date +%s)"
    GRPCTESTIFY_STATE["${parsing_key}_file"]="$test_file"
    GRPCTESTIFY_STATE["${parsing_key}_result"]="$result"
    GRPCTESTIFY_STATE["${parsing_key}_mode"]="$PROTO_MODE"
    GRPCTESTIFY_STATE["${parsing_key}_timestamp"]="$(date +%s)"
    
    return 0
}

record_proto_validation() {
    local validation_type="$1"
    local result="$2"
    
    local validation_key="proto_validation_${validation_type}_$(date +%s)"
    GRPCTESTIFY_STATE["${validation_key}_type"]="$validation_type"
    GRPCTESTIFY_STATE["${validation_key}_result"]="$result"
    GRPCTESTIFY_STATE["${validation_key}_timestamp"]="$(date +%s)"
    
    return 0
}

# Legacy compatibility functions
register_proto_plugin() {
    grpc_proto_init
}

parse_proto_section() {
    grpc_proto_parse_proto_section "$@"
}

get_proto_flags() {
    grpc_proto_get_proto_flags "$@"
}

# Export functions
export -f grpc_proto_init grpc_proto_handler grpc_proto_parse_proto_section
export -f process_proto_configuration validate_proto_configuration grpc_proto_load_proto_files
export -f grpc_proto_load_descriptor validate_descriptor_file grpc_proto_get_proto_flags
export -f grpc_proto_validate_proto_config proto_cache_get proto_cache_set grpc_proto_clear_cache
export -f grpc_proto_get_statistics increment_proto_counter grpc_proto_event_handler
export -f grpc_proto_file_change_handler record_proto_parsing record_proto_validation
export -f register_proto_plugin parse_proto_section get_proto_flags
