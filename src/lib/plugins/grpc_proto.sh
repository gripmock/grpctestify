#!/bin/bash

# Proto Plugin for grpctestify
# shellcheck disable=SC2155 # Declare and assign separately - many simple variable assignments
# Handles proto contracts and descriptor files configuration

# Proto state management - using local variables to avoid race conditions

# Function to register Proto plugin
register_proto_plugin() {
    register_plugin "proto" "parse_proto_section" "Proto contracts and descriptor files handler" "internal"
}

# Function to parse Proto section from .gctf file
parse_proto_section() {
    local test_file="$1"
    local proto_section=""
    local in_proto_section=false
    
    # Reset Proto state
    PROTO_MODE=""
    PROTO_FLAGS=""
    PROTO_FILES=""
    PROTO_DESCRIPTOR=""
    PROTO_IMPORT_PATHS=""
    
    # Parse Proto section from file
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
    
    if [[ -n "$proto_section" ]]; then
        process_proto_configuration "$proto_section"
    else
        # Default behavior: gRPC reflection
        PROTO_MODE="reflection"
        PROTO_FLAGS=""
    fi
}

# Function to process Proto configuration
process_proto_configuration() {
    local config="$1"
    local mode=""
    local files=""
    local descriptor=""
    local import_paths=""
    
    # Parse key=value pairs
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key_name="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            case "$key_name" in
                "mode")
                    mode="$value"
                    ;;
                "files")
                    files="$value"
                    ;;
                "descriptor")
                    descriptor="$value"
                    ;;
                "import_paths")
                    import_paths="$value"
                    ;;
            esac
        fi
    done <<< "$config"
    
    # Determine mode if not specified
    if [[ -z "$mode" ]]; then
        if [[ -n "$descriptor" ]]; then
            mode="descriptor"
        elif [[ -n "$files" ]]; then
            mode="proto"
        else
            mode="reflection"
        fi
    fi
    
    # Validate configuration
    validate_proto_configuration "$mode" "$files" "$descriptor"
    
    # Generate Proto flags
    generate_proto_flags "$mode" "$files" "$descriptor" "$import_paths"
}

# Function to validate Proto configuration
validate_proto_configuration() {
    local mode="$1"
    local files="$2"
    local descriptor="$3"
    
    case "$mode" in
        "reflection")
            # No validation needed for reflection mode
            ;;
        "proto")
            if [[ -z "$files" ]]; then
                error "Proto mode requires files parameter"
                exit 1
            fi
            ;;
        "descriptor")
            if [[ -z "$descriptor" ]]; then
                error "Descriptor mode requires descriptor parameter"
                exit 1
            fi
            ;;
        *)
            error "Invalid proto mode: $mode. Valid modes: reflection, proto, descriptor"
            exit 1
            ;;
    esac
}

# Function to generate Proto flags
generate_proto_flags() {
    local mode="$1"
    local files="$2"
    local descriptor="$3"
    local import_paths="$4"
    
    PROTO_MODE="$mode"
    PROTO_FLAGS=""
    PROTO_FILES="$files"
    PROTO_DESCRIPTOR="$descriptor"
    PROTO_IMPORT_PATHS="$import_paths"
    
    case "$mode" in
        "reflection")
            # No additional flags needed for reflection
            PROTO_FLAGS=""
            ;;
        "proto")
            # Add proto files
            if [[ -n "$files" ]]; then
                # Support multiple files separated by comma or space
                local file_list=$(echo "$files" | tr ',' ' ')
                for file in $file_list; do
                    file=$(echo "$file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$file" ]]; then
                        PROTO_FLAGS+=" -proto $file"
                    fi
                done
            fi
            
            # Add import paths
            if [[ -n "$import_paths" ]]; then
                local path_list=$(echo "$import_paths" | tr ',' ' ')
                for path in $path_list; do
                    path=$(echo "$path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$path" ]]; then
                        PROTO_FLAGS+=" -import-path $path"
                    fi
                done
            fi
            ;;
        "descriptor")
            # Add descriptor file
            if [[ -n "$descriptor" ]]; then
                PROTO_FLAGS+=" -proto $descriptor"
            fi
            ;;
    esac
    
    # Trim leading space
    PROTO_FLAGS="${PROTO_FLAGS#"${PROTO_FLAGS%%[![:space:]]*}"}"
}

# Function to resolve proto paths (support ENV variables)
resolve_proto_path() {
    local path="$1"
    
    # If path starts with $, treat as ENV variable
    if [[ "$path" =~ ^\$([A-Z_][A-Z0-9_]*) ]]; then
        local env_var="${BASH_REMATCH[1]}"
        if [[ -n "${!env_var}" ]]; then
            echo "${!env_var}"
        else
            error "Environment variable $env_var is not set"
            exit 1
        fi
    else
        echo "$path"
    fi
}

# Function to get Proto summary for verbose logging
get_proto_summary() {
    local flag_count=$(echo "$PROTO_FLAGS" | wc -w)
    echo "mode=$PROTO_MODE, flags=$flag_count"
}

# Function to get Proto flags for grpcurl
get_proto_flags() {
    echo "$PROTO_FLAGS"
}

# Function to get Proto mode
get_proto_mode() {
    echo "$PROTO_MODE"
}

# Function to get Proto files
get_proto_files() {
    echo "$PROTO_FILES"
}

# Function to get Proto descriptor
get_proto_descriptor() {
    echo "$PROTO_DESCRIPTOR"
}

# Function to get Proto import paths
get_proto_import_paths() {
    echo "$PROTO_IMPORT_PATHS"
}

# Export functions
export -f register_proto_plugin
export -f parse_proto_section
export -f process_proto_configuration
export -f validate_proto_configuration
export -f generate_proto_flags
export -f resolve_proto_path
export -f get_proto_summary
export -f get_proto_flags
export -f get_proto_mode
export -f get_proto_files
export -f get_proto_descriptor
export -f get_proto_import_paths

# Register the plugin
register_proto_plugin
