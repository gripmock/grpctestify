#!/bin/bash

# config.sh - Centralized configuration
# Single source of truth for all configuration values

# Application metadata
# shellcheck disable=SC2034  # Used by help system and future features
readonly APP_NAME="grpctestify"
# shellcheck disable=SC2034  # Used by version command and future features  
readonly APP_VERSION="v1.0.0"
# shellcheck disable=SC2034  # Used for config compatibility checks
readonly CONFIG_VERSION="1.0.0"

# Default values
readonly DEFAULT_TIMEOUT=30
# DEFAULT_ADDRESS removed - use GRPCTESTIFY_ADDRESS instead
# shellcheck disable=SC2034  # Used in future versions
readonly DEFAULT_CACHE_TTL=3600
# shellcheck disable=SC2034  # Used in future versions
readonly DEFAULT_RETRY_ATTEMPTS=3
readonly DEFAULT_RETRY_DELAY=1
readonly DEFAULT_PARALLEL_JOBS=1
# shellcheck disable=SC2034  # Used in future versions
readonly DEFAULT_PORT_START=50051

# Author information
# shellcheck disable=SC2034  # Used in future versions
readonly DEFAULT_AUTHOR="Your Name"
# shellcheck disable=SC2034  # Used in future versions
readonly DEFAULT_EMAIL="your.email@domain.com"

# File paths and directories (SECURITY: safe defaults)
# shellcheck disable=SC2034  # Used by plugin system
readonly DEFAULT_PLUGIN_DIR="$HOME/.grpctestify/plugins"
# shellcheck disable=SC2034  # Used by caching system
readonly DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/grpctestify"
# shellcheck disable=SC2034  # Used by config system
readonly DEFAULT_CONFIG_FILE="$HOME/.grpctestify/config"

# Performance settings
# shellcheck disable=SC2034  # Used by parser caching
readonly PARSE_CACHE_ENABLED=true
# shellcheck disable=SC2034  # Used by dependency caching
readonly DEPENDENCY_CACHE_TTL=3600
# shellcheck disable=SC2034  # Used by parallel execution limits
readonly MAX_PARALLEL_JOBS=16
readonly STARTUP_TIMEOUT=10

# Security settings
readonly ALLOW_INSECURE_CONNECTIONS=false
readonly VALIDATE_SSL_CERTIFICATES=true
readonly MAX_REQUEST_SIZE=1048576  # 1MB
readonly MAX_RESPONSE_SIZE=10485760  # 10MB

# Output formatting
readonly PROGRESS_LINE_LENGTH=80
readonly LOG_TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"
readonly COLOR_SUCCESS='\033[0;32m'
readonly COLOR_ERROR='\033[0;31m'

# Retry configuration helper functions
is_no_retry() {
    [[ "${RETRY_COUNT:-$DEFAULT_RETRY_ATTEMPTS}" -eq 0 ]]
}

get_retry_count() {
    echo "${RETRY_COUNT:-$DEFAULT_RETRY_ATTEMPTS}"
}

get_retry_delay() {
    echo "${RETRY_DELAY:-$DEFAULT_RETRY_DELAY}"
}
readonly COLOR_WARNING='\033[1;33m'
readonly COLOR_INFO='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Plugin configuration defaults
readonly PLUGIN_API_VERSION="1.0.0"
readonly PLUGIN_TIMEOUT=30
readonly PLUGIN_STRICT_MODE=false
readonly PLUGIN_DEBUG=false
readonly PLUGIN_MAX_RETRIES=3

# Validation rules
readonly VALID_SECTIONS="ADDRESS|ENDPOINT|REQUEST|RESPONSE|ERROR|HEADERS|REQUEST_HEADERS|OPTIONS|ASSERTS"

# Error codes (unified)
readonly ERROR_GENERAL=1
readonly ERROR_INVALID_ARGS=2
readonly ERROR_FILE_NOT_FOUND=3
readonly ERROR_DEPENDENCY_MISSING=4
readonly ERROR_NETWORK=5
readonly ERROR_PERMISSION=6
readonly ERROR_VALIDATION=7
readonly ERROR_TIMEOUT=8
readonly ERROR_RATE_LIMIT=9
readonly ERROR_QUOTA_EXCEEDED=10
readonly ERROR_SERVICE_UNAVAILABLE=11
readonly ERROR_CONFIGURATION=12

# Environment variable names
readonly ENV_ADDRESS="GRPCTESTIFY_ADDRESS"
# ENV variables for flags removed - use flags directly
readonly ENV_NO_COLOR="GRPCTESTIFY_NO_COLOR"
readonly ENV_PLUGIN_PATH="GRPCTESTIFY_PLUGIN_PATH"
readonly ENV_CACHE_DIR="GRPCTESTIFY_CACHE_DIR"

# Feature flags
readonly FEATURE_CACHING_ENABLED=true
readonly FEATURE_PLUGINS_ENABLED=true
readonly FEATURE_PARALLEL_ENABLED=true
readonly FEATURE_PROGRESS_ENABLED=true
readonly FEATURE_RECOVERY_ENABLED=true



# Secure path validation (SECURITY: prevent path traversal)
validate_plugin_path() {
    local plugin_path="$1"
    
    # Ensure path is absolute and within safe directories
    case "$plugin_path" in
        "$HOME/.grpctestify/plugins"*) 
            # Allow only in user's grpctestify directory
            if [[ "$plugin_path" != *".."* && "$plugin_path" == *.sh ]]; then
                return 0
            fi
            ;;
        *)
            log error "Plugin path not allowed: $plugin_path"
            return 1
            ;;
    esac
    
    log error "Invalid plugin path: $plugin_path"
    return 1
}

# Validate configuration value
validate_config() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        "timeout"|"cache_ttl"|"retry_delay"|"parallel_jobs")
            if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
                return 1
            fi
            ;;
        "strict_mode"|"debug"|"caching_enabled")
            if [[ ! "$value" =~ ^(true|false)$ ]]; then
                return 1
            fi
            ;;
        "address")
            if [[ ! "$value" =~ ^[a-zA-Z0-9.-]+:[0-9]+$ ]]; then
                return 1
            fi
            ;;
        "email")
            if [[ ! "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Initialize configuration
init_config() {
    # Set global variables from configuration
    # Only address uses ENV fallback (no flag equivalent)
    GRPCTESTIFY_ADDRESS=$(get_config "address" "localhost:4770" "$ENV_ADDRESS")
    GRPCTESTIFY_CACHE_DIR=$(get_config "cache_dir" "$DEFAULT_CACHE_DIR" "$ENV_CACHE_DIR")
    
    # Validation moved to flag processing in run.sh
    
    if ! validate_config "address" "$GRPCTESTIFY_ADDRESS"; then
        echo "Error: Invalid address format: $GRPCTESTIFY_ADDRESS" >&2
        return 1
    fi
    
    return 0
}

# Export configuration functions

export -f validate_config
export -f init_config
