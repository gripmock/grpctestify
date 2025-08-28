#!/bin/bash

# performance_cache.sh - Performance optimization and caching utilities
# Improves startup time and reduces repeated computations

# Dependencies are loaded automatically by bashly

# Cache directory for parsed files
PARSE_CACHE_DIR="${DEFAULT_CACHE_DIR}"

# Initialize cache system
init_performance_cache() {
    if [[ ! -d "$PARSE_CACHE_DIR" ]]; then
        # Create cache directory with secure permissions
        if ! mkdir -p "$PARSE_CACHE_DIR" 2>/dev/null; then
            # Fallback to user-specific temp directory
            PARSE_CACHE_DIR="${HOME}/.cache/grpctestify"
            mkdir -p "$PARSE_CACHE_DIR" 2>/dev/null || return 1
        fi
        
        # Set secure permissions (owner only)
        chmod 700 "$PARSE_CACHE_DIR" 2>/dev/null || true
    fi
}

# Generate cache key for file
get_cache_key() {
    local file="$1"
    local file_hash=""
    
    if command -v md5sum >/dev/null 2>&1; then
        file_hash=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        file_hash=$(shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1)
    else
        # Fallback to file stats
        file_hash=$(stat -c '%Y-%s' "$file" 2>/dev/null || stat -f '%m-%z' "$file" 2>/dev/null || date +%s)
    fi
    
    echo "${file_hash}"
}

# Cached version of extract_section
extract_section_cached() {
    local test_file="$1"
    local section="$2"
    
    # Initialize cache if needed
    init_performance_cache
    
    # Generate cache key
    local cache_key
    cache_key="$(get_cache_key "$test_file")"
    local cache_file="$PARSE_CACHE_DIR/${cache_key}_${section}"
    
    # Check if cached version exists and is newer than source
    if [[ -f "$cache_file" && "$cache_file" -nt "$test_file" ]]; then
        cat "$cache_file" 2>/dev/null
        return $?
    fi
    
    # Parse and cache the result
    local result
    result=$(extract_section_awk "$test_file" "$section")
    local status=$?
    
    # Cache successful results
    if [[ $status -eq 0 && -n "$result" ]]; then
        echo "$result" > "$cache_file" 2>/dev/null || true
    fi
    
    echo "$result"
    return $status
}

# Fast dependency check with caching
check_dependencies_cached() {
    local deps_cache="$PARSE_CACHE_DIR/dependencies_check"
    local cache_ttl=3600  # 1 hour
    
    # Check if cache is fresh
    if [[ -f "$deps_cache" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$deps_cache" 2>/dev/null || stat -f %m "$deps_cache" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt $cache_ttl ]]; then
            cat "$deps_cache"
            return $?
        fi
    fi
    
    # Check dependencies and cache result
    local result=""
    local status=0
    
    for cmd in grpcurl jq bc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            result+="Missing dependency: $cmd\n"
            status=1
        fi
    done
    
    # Cache the result
    init_performance_cache
    echo -e "$result" > "$deps_cache" 2>/dev/null || true
    
    if [[ $status -eq 0 ]]; then
        echo "All dependencies available"
    else
        echo -e "$result"
    fi
    
    return $status
}

# Clean old cache files
cleanup_cache() {
    local max_age="${1:-86400}"  # 24 hours default
    
    if [[ -d "$PARSE_CACHE_DIR" ]]; then
        find "$PARSE_CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null || true
        
        # Remove empty directory
        rmdir "$PARSE_CACHE_DIR" 2>/dev/null || true
    fi
}

# Performance monitoring
start_timer() {
    PERF_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
}

end_timer() {
    local label="${1:-Operation}"
    local end_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    if command -v bc >/dev/null 2>&1; then
        local duration=$(echo "$end_time - $PERF_START_TIME" | bc -l 2>/dev/null || echo "0")
        log debug "$label took ${duration}s"
    fi
}

# Optimized file parsing with early exit
parse_test_file_fast() {
    local test_file="$1"
    
    # Quick validation
    if [[ ! -f "$test_file" || ! -r "$test_file" ]]; then
        return 1
    fi
    
    start_timer
    
    # Use cached extraction
    local address="$(extract_section_cached "$test_file" "ADDRESS")"
    local endpoint="$(extract_section_cached "$test_file" "ENDPOINT")"
    
    # Early exit if endpoint is missing
    if [[ -z "$endpoint" ]]; then
        end_timer "Fast parse (failed)"
        return 1
    fi
    
    local request="$(extract_section_cached "$test_file" "REQUEST")"
    local response="$(extract_section_cached "$test_file" "RESPONSE")"
    local error="$(extract_section_cached "$test_file" "ERROR")"
    local headers="$(extract_section_cached "$test_file" "HEADERS")"
    local request_headers="$(extract_section_cached "$test_file" "REQUEST_HEADERS")"
    
    # Set defaults efficiently
    [[ -z "$address" ]] && address="${GRPCTESTIFY_ADDRESS:-localhost:4770}"
    [[ -z "$headers" ]] && headers="$request_headers"
    
    # Generate JSON output efficiently
    jq -n \
        --arg address "$address" \
        --arg endpoint "$endpoint" \
        --arg request "$request" \
        --arg response "$response" \
        --arg error "$error" \
        --arg request_headers "$headers" \
        '{
            address: $address,
            endpoint: $endpoint,
            request: $request,
            response: $response,
            error: $error,
            request_headers: $request_headers
        }'
    
    end_timer "Fast parse"
    return 0
}
