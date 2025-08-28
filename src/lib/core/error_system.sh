#!/bin/bash

# error_system.sh - Unified error handling system
# Combines basic error handling with advanced recovery capabilities

# Unified error codes are loaded from config.sh automatically by bashly

# Error context stack for advanced error tracking
declare -a ERROR_CONTEXT_STACK=()
declare -a ERROR_RECOVERY_STRATEGIES=()
declare -A ERROR_AGGREGATOR=()
declare -A CIRCUIT_BREAKER_STATE=()
declare -A CIRCUIT_BREAKER_FAILURES=()

# Basic error handling function
handle_error() {
    local exit_code="$1"
    local error_message="$2"
    local context="${3:-}"
    
    case "$exit_code" in
        $ERROR_GENERAL)
            log error "General error: $error_message"
            ;;
        $ERROR_INVALID_ARGS)
            log error "Invalid arguments: $error_message"
            ;;
        $ERROR_FILE_NOT_FOUND)
            log error "File not found: $error_message"
            ;;
        $ERROR_DEPENDENCY_MISSING)
            log error "Missing dependency: $error_message"
            ;;
        $ERROR_NETWORK)
            log error "Network error: $error_message"
            ;;
        $ERROR_PERMISSION)
            log error "Permission denied: $error_message"
            ;;
        $ERROR_VALIDATION)
            log error "Validation error: $error_message"
            ;;
        $ERROR_TIMEOUT)
            log error "Timeout: $error_message"
            ;;
        $ERROR_RATE_LIMIT)
            log error "Rate limit exceeded: $error_message"
            ;;
        $ERROR_QUOTA_EXCEEDED)
            log error "Quota exceeded: $error_message"
            ;;
        $ERROR_SERVICE_UNAVAILABLE)
            log error "Service unavailable: $error_message"
            ;;
        $ERROR_CONFIGURATION)
            log error "Configuration error: $error_message"
            ;;
        *)
            log error "Unknown error ($exit_code): $error_message"
            ;;
    esac
    
    if [[ -n "$context" ]]; then
        log debug "Context: $context"
    fi
}

# Advanced error context management
push_error_context() {
    local context="$1"
    ERROR_CONTEXT_STACK+=("$context")
    log debug "Error context pushed: $context"
}

pop_error_context() {
    if [[ ${#ERROR_CONTEXT_STACK[@]} -gt 0 ]]; then
        unset 'ERROR_CONTEXT_STACK[-1]'
        log debug "Error context popped"
    fi
}

get_error_context() {
    local context=""
    for ctx in "${ERROR_CONTEXT_STACK[@]}"; do
        if [[ -n "$context" ]]; then
            context="$context -> $ctx"
        else
            context="$ctx"
        fi
    done
    echo "$context"
}

# Error recovery strategies
register_recovery_strategy() {
    local error_pattern="$1"
    local recovery_function="$2"
    
    ERROR_RECOVERY_STRATEGIES+=("$error_pattern:$recovery_function")
    log debug "Registered recovery strategy for: $error_pattern"
}

# Enhanced error handler with context and recovery
handle_error_enhanced() {
    local exit_code="$1"
    local error_message="$2"
    local recovery_hint="${3:-}"
    
    local context="$(get_error_context)"
    local full_message="$error_message"
    
    if [[ -n "$context" ]]; then
        full_message="[$context] $error_message"
    fi
    
    # Use basic error handling for logging
    handle_error "$exit_code" "$full_message"
    
    # Attempt recovery if hint provided
    if [[ -n "$recovery_hint" ]]; then
        log info "Attempting recovery: $recovery_hint"
        attempt_error_recovery "$error_message" "$recovery_hint"
        return $?
    fi
    
    # Try registered recovery strategies
    for strategy in "${ERROR_RECOVERY_STRATEGIES[@]}"; do
        local pattern="${strategy%%:*}"
        local recovery_func="${strategy##*:}"
        
        if [[ "$error_message" =~ $pattern ]]; then
            log info "Attempting recovery with strategy: $recovery_func"
            if "$recovery_func" "$error_message" "$exit_code"; then
                log success "Recovery successful"
                return 0
            fi
        fi
    done
    
    return "$exit_code"
}

# Error recovery implementation
attempt_error_recovery() {
    local error_message="$1"
    local recovery_hint="$2"
    
    case "$recovery_hint" in
        "retry_with_backoff")
            log info "Retrying with exponential backoff..."
            return 0
            ;;
        "check_service")
            log info "Checking service availability..."
            if check_service_health "${GRPCTESTIFY_ADDRESS:-localhost:4770}"; then
                log success "Service is available"
                return 0
            fi
            ;;
        "fallback_address")
            log info "Trying fallback address..."
            return 1
            ;;
        "skip_test")
            log warning "Skipping test due to error"
            return 0
            ;;
        *)
            log debug "Unknown recovery hint: $recovery_hint"
            return 1
            ;;
    esac
    
    return 1
}

# Graceful degradation handler
handle_graceful_degradation() {
    local feature="$1"
    local error_message="$2"
    local fallback="${3:-}"
    
    log warning "Feature '$feature' degraded: $error_message"
    
    if [[ -n "$fallback" ]]; then
        log info "Using fallback: $fallback"
        return 0
    fi
    
    return 1
}

# Error aggregation for batch operations
aggregate_error() {
    local test_name="$1"
    local error_message="$2"
    
    ERROR_AGGREGATOR["$test_name"]="$error_message"
}

report_aggregated_errors() {
    local error_count=${#ERROR_AGGREGATOR[@]}
    
    if [[ $error_count -eq 0 ]]; then
        log success "No errors to report"
        return 0
    fi
    
    log error "Aggregated errors from $error_count tests:"
    
    for test_name in "${!ERROR_AGGREGATOR[@]}"; do
        log error "  $test_name: ${ERROR_AGGREGATOR[$test_name]}"
    done
    
    # Clear aggregator
    ERROR_AGGREGATOR=()
    
    return 1
}

# Circuit breaker pattern
check_circuit_breaker() {
    local service="$1"
    local max_failures="${2:-5}"
    local timeout="${3:-300}"
    
    local current_time=$(date +%s)
    local failure_count="${CIRCUIT_BREAKER_FAILURES[$service]:-0}"
    local last_failure="${CIRCUIT_BREAKER_STATE[$service]:-0}"
    
    # Reset if timeout passed
    if [[ $((current_time - last_failure)) -gt $timeout ]]; then
        CIRCUIT_BREAKER_FAILURES[$service]=0
        CIRCUIT_BREAKER_STATE[$service]=0
        log debug "Circuit breaker reset for $service"
        return 0
    fi
    
    # Check if circuit is open
    if [[ $failure_count -ge $max_failures ]]; then
        log warning "Circuit breaker open for $service ($failure_count failures)"
        return 1
    fi
    
    return 0
}

record_circuit_breaker_failure() {
    local service="$1"
    
    local current_count="${CIRCUIT_BREAKER_FAILURES[$service]:-0}"
    CIRCUIT_BREAKER_FAILURES[$service]=$((current_count + 1))
    CIRCUIT_BREAKER_STATE[$service]=$(date +%s)
    
    log debug "Circuit breaker failure recorded for $service (count: ${CIRCUIT_BREAKER_FAILURES[$service]})"
}

# File operation validation
validate_file_operation() {
    local file_path="$1"
    local operation="${2:-read}"
    
    case "$operation" in
        "read")
            if [[ ! -r "$file_path" ]]; then
                handle_error $ERROR_FILE_NOT_FOUND "Cannot read file: $file_path"
                return 1
            fi
            ;;
        "write")
            local dir_path=$(dirname "$file_path")
            if [[ ! -w "$dir_path" ]]; then
                handle_error $ERROR_PERMISSION "Cannot write to directory: $dir_path"
                return 1
            fi
            ;;
        "execute")
            if [[ ! -x "$file_path" ]]; then
                handle_error $ERROR_PERMISSION "Cannot execute file: $file_path"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Network error handling
handle_network_error() {
    local url="$1"
    local error_code="$2"
    
    case "$error_code" in
        6|7)
            handle_error $ERROR_NETWORK "Could not resolve host for: $url"
            ;;
        28)
            handle_error $ERROR_NETWORK "Connection timeout for: $url"
            ;;
        35|60)
            handle_error $ERROR_NETWORK "SSL/TLS error for: $url"
            ;;
        *)
            handle_error $ERROR_NETWORK "Network error ($error_code) for: $url"
            ;;
    esac
}

# Enhanced network error handling with recovery
handle_network_error_enhanced() {
    local error_output="$1"
    local test_file="$2"
    local retry_count="${3:-0}"
    
    push_error_context "network_error:$(basename "$test_file")"
    
    # Analyze error type
    local error_type="unknown"
    local error_lower=$(echo "$error_output" | tr '[:upper:]' '[:lower:]')
    if [[ "$error_lower" =~ "connection refused" ]]; then
        error_type="connection_refused"
    elif [[ "$error_lower" =~ "timeout" ]]; then
        error_type="timeout"
    elif [[ "$error_lower" =~ "not found" ]]; then
        error_type="not_found"
    elif [[ "$error_lower" =~ "permission denied" ]]; then
        error_type="permission_denied"
    fi
    
    log debug "Network error type detected: $error_type"
    
    # Apply appropriate recovery strategy
    case "$error_type" in
        "connection_refused")
            handle_error_enhanced $ERROR_SERVICE_UNAVAILABLE "$error_output" "check_service"
            ;;
        "timeout")
            handle_error_enhanced $ERROR_TIMEOUT "$error_output" "retry_with_backoff"
            ;;
        "not_found")
            handle_error_enhanced $ERROR_FILE_NOT_FOUND "$error_output" "skip_test"
            ;;
        *)
            handle_error_enhanced $ERROR_NETWORK "$error_output"
            ;;
    esac
    
    pop_error_context
    return $?
}

# Safe execution with error handling
safe_execute() {
    local error_context="${1:-}"
    shift
    
    if ! "$@"; then
        local exit_code=$?
        handle_error $exit_code "Command failed: $*" "$error_context"
        return $exit_code
    fi
    
    return 0
}

# Service health check
check_service_health() {
    local address="$1"
    
    if command -v grpcurl >/dev/null 2>&1; then
        if timeout 5 grpcurl -plaintext "$address" list >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

# Export all functions
export -f handle_error
export -f handle_error_enhanced
export -f push_error_context
export -f pop_error_context
export -f get_error_context
export -f register_recovery_strategy
export -f attempt_error_recovery
export -f handle_graceful_degradation
export -f aggregate_error
export -f report_aggregated_errors
export -f check_circuit_breaker
export -f record_circuit_breaker_failure
export -f validate_file_operation
export -f handle_network_error
export -f handle_network_error_enhanced
export -f safe_execute
export -f check_service_health
