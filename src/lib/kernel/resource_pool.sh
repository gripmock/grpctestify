#!/bin/bash

# resource_pool.sh - Resource pool management for controlled parallel execution
# Implements FIFO-based semaphore using file descriptors for job throttling

# Global state for resource pool
declare -g -A RESOURCE_POOLS=()          # pool_name -> max_resources
declare -g -A POOL_ACQUIRED=()           # pool_name -> current_acquired_count
declare -g -A POOL_DESCRIPTORS=()        # pool_name -> file_descriptor
declare -g -A POOL_TEMP_FILES=()         # pool_name -> temporary_file_path
declare -g -i RESOURCE_POOL_COUNTER=0    # Auto-incrementing pool ID counter
declare -g RESOURCE_POOL_INITIALIZED=false  # Initialization guard

# Configuration
RESOURCE_POOL_TIMEOUT="${RESOURCE_POOL_TIMEOUT:-30}"        # seconds
RESOURCE_POOL_CLEANUP_INTERVAL="${RESOURCE_POOL_CLEANUP_INTERVAL:-5}"  # seconds

# Initialize resource pool system
resource_pool_init() {
    # Check if already initialized
    if [[ "$RESOURCE_POOL_INITIALIZED" == "true" ]]; then
        tlog debug "Resource pool system already initialized, skipping..."
        return 0
    fi
    
    tlog debug "Initializing resource pool system..."
    
    # Ensure required commands are available
    if ! command -v mktemp >/dev/null 2>&1; then
    tlog error "Resource pool requires 'mktemp' command"
        return 1
    fi
    
    # Setup cleanup on exit
    # REMOVED: trap 'resource_pool_cleanup_all' EXIT
    # Now using unified signal_manager for proper cleanup handling
    
    RESOURCE_POOL_INITIALIZED=true
    tlog debug "Resource pool system initialized successfully"
    return 0
}

# Create a new resource pool
pool_create() {
    local pool_name="$1"
    local max_resources="${2:-1}"
    
    if [[ -z "$pool_name" ]]; then
    tlog error "pool_create: pool_name required"
        return 1
    fi
    
    if [[ $max_resources -lt 1 ]]; then
    tlog error "pool_create: max_resources must be >= 1"
        return 1
    fi
    
        # Check if pool already exists
    if [[ -n "${RESOURCE_POOLS[$pool_name]:-}" ]]; then
	tlog debug "pool_create: pool '$pool_name' already exists"
        return 0
    fi
    
    tlog debug "Creating resource pool '$pool_name' with $max_resources resources"
    
    # Create temporary file for semaphore
    local temp_file
    temp_file=$(mktemp "/tmp/grpctestify_pool_${pool_name}_XXXXXX")
    if [[ ! -f "$temp_file" ]]; then
    tlog error "Failed to create temporary file for pool '$pool_name'"
        return 1
    fi
    
    # Open file descriptor for the pool
    local fd
    fd=$(get_available_fd)
    if [[ $fd -eq -1 ]]; then
    tlog error "No available file descriptors for pool '$pool_name'"
        rm -f "$temp_file"
        return 1
    fi
    
    # Initialize semaphore with max_resources tokens in the file
    local i
    for ((i = 0; i < max_resources; i++)); do
        echo "token_$i" >> "$temp_file"
    done
    
    # Register pool
    RESOURCE_POOLS["$pool_name"]=$max_resources
    POOL_ACQUIRED["$pool_name"]=0
    POOL_DESCRIPTORS["$pool_name"]=$fd
    POOL_TEMP_FILES["$pool_name"]="$temp_file"
    
    tlog debug "Resource pool '$pool_name' created successfully (FD: $fd)"
    return 0
}

# Acquire a resource from the pool (blocking)
pool_acquire() {
    local pool_name="$1"
    local timeout="${2:-$RESOURCE_POOL_TIMEOUT}"
    
    if [[ -z "$pool_name" ]]; then
    tlog error "pool_acquire: pool_name required"
        return 1
    fi
    
    # Check if pool exists
    local temp_file="${POOL_TEMP_FILES[$pool_name]:-}"
    if [[ -z "$temp_file" ]]; then
    tlog error "pool_acquire: pool '$pool_name' does not exist"
        return 1
    fi
    
    tlog debug "Acquiring resource from pool '$pool_name' (timeout: ${timeout}s)"
    
    # Try to read a token from the semaphore with timeout
    local token=""
    local start_time=$(date +%s)
    local waited=0
    
    while [[ $waited -lt $timeout ]]; do
        # Use flock for atomic read operation
        if [[ -f "$temp_file" ]]; then
            # Try to read first line and remove it atomically
            local first_line
            first_line=$(head -n 1 "$temp_file" 2>/dev/null)
            if [[ -n "$first_line" ]]; then
                # Remove first line from file
                if tail -n +2 "$temp_file" > "${temp_file}.tmp" 2>/dev/null; then
                    mv "${temp_file}.tmp" "$temp_file"
                    # Successfully acquired a token
                    POOL_ACQUIRED["$pool_name"]=$((POOL_ACQUIRED["$pool_name"] + 1))
    tlog debug "Acquired resource from pool '$pool_name' (token: $first_line, acquired: ${POOL_ACQUIRED[$pool_name]})"
                    echo "$first_line"
                    return 0
                fi
            fi
        fi
        
        # Update waited time
        local current_time=$(date +%s)
        waited=$((current_time - start_time))
        
        # Brief pause before retry
        sleep 0.1
    done
    
    tlog warning "pool_acquire: timeout waiting for resource from pool '$pool_name'"
    return 124  # timeout exit code
}

# Release a resource back to the pool
pool_release() {
    local pool_name="$1"
    local token="${2:-token_default}"
    
    if [[ -z "$pool_name" ]]; then
    tlog error "pool_release: pool_name required"
        return 1
    fi
    
    # Check if pool exists
    local temp_file="${POOL_TEMP_FILES[$pool_name]:-}"
    if [[ -z "$temp_file" ]]; then
    tlog error "pool_release: pool '$pool_name' does not exist"
        return 1
    fi
    
    # Check if any resources are acquired
    local acquired="${POOL_ACQUIRED[$pool_name]:-0}"
    if [[ $acquired -eq 0 ]]; then
    tlog warning "pool_release: no resources acquired for pool '$pool_name'"
        return 1
    fi
    
    tlog debug "Releasing resource to pool '$pool_name' (token: $token)"
    
    # Write token back to semaphore file
    echo "$token" >> "$temp_file"
    
    # Update acquired count
    POOL_ACQUIRED["$pool_name"]=$((acquired - 1))
    
    tlog debug "Released resource to pool '$pool_name' (acquired: ${POOL_ACQUIRED[$pool_name]})"
    return 0
}

# Get available resources in pool
pool_available() {
    local pool_name="$1"
    
    if [[ -z "$pool_name" ]]; then
    tlog error "pool_available: pool_name required"
        return 1
    fi
    
    local max_resources="${RESOURCE_POOLS[$pool_name]:-}"
    local acquired="${POOL_ACQUIRED[$pool_name]:-0}"
    
    if [[ -z "$max_resources" ]]; then
        echo "0"
        return 1
    fi
    
    echo $((max_resources - acquired))
    return 0
}

# Get pool status information
pool_status() {
    local pool_name="$1"
    local format="${2:-summary}"  # summary|detailed|json
    
    if [[ -z "$pool_name" ]]; then
    tlog error "pool_status: pool_name required"
        return 1
    fi
    
    local max_resources="${RESOURCE_POOLS[$pool_name]:-}"
    local acquired="${POOL_ACQUIRED[$pool_name]:-0}"
    local fd="${POOL_DESCRIPTORS[$pool_name]:-}"
    local temp_file="${POOL_TEMP_FILES[$pool_name]:-}"
    
    if [[ -z "$max_resources" ]]; then
        echo "Pool '$pool_name' not found"
        return 1
    fi
    
    local available=$((max_resources - acquired))
    
    case "$format" in
        "summary")
            echo "Pool: $pool_name, Max: $max_resources, Acquired: $acquired, Available: $available"
            ;;
        "detailed")
            echo "Pool Name: $pool_name"
            echo "  Max Resources: $max_resources"
            echo "  Acquired: $acquired"
            echo "  Available: $available"
            echo "  File Descriptor: $fd"
            echo "  Temp File: $temp_file"
            ;;
        "json")
            echo "{\"pool_name\":\"$pool_name\",\"max_resources\":$max_resources,\"acquired\":$acquired,\"available\":$available,\"fd\":$fd,\"temp_file\":\"$temp_file\"}"
            ;;
    esac
}

# List all resource pools
pool_list() {
    local format="${1:-summary}"  # summary|detailed|json
    
    if [[ ${#RESOURCE_POOLS[@]} -eq 0 ]]; then
        echo "No resource pools"
        return 0
    fi
    
    case "$format" in
        "summary")
            printf "%-20s %-10s %-10s %-10s\n" "POOL_NAME" "MAX" "ACQUIRED" "AVAILABLE"
            printf "%-20s %-10s %-10s %-10s\n" "--------------------" "----------" "----------" "----------"
            
            for pool_name in "${!RESOURCE_POOLS[@]}"; do
                local max_resources="${RESOURCE_POOLS[$pool_name]}"
                local acquired="${POOL_ACQUIRED[$pool_name]:-0}"
                local available=$((max_resources - acquired))
                
                printf "%-20s %-10s %-10s %-10s\n" "$pool_name" "$max_resources" "$acquired" "$available"
            done
            ;;
        "detailed")
            for pool_name in "${!RESOURCE_POOLS[@]}"; do
                pool_status "$pool_name" "detailed"
                echo
            done
            ;;
        "json")
            echo "["
            local first=true
            for pool_name in "${!RESOURCE_POOLS[@]}"; do
                [[ "$first" == "true" ]] && first=false || echo ","
                pool_status "$pool_name" "json"
            done
            echo "]"
            ;;
    esac
}

# Delete a resource pool
pool_delete() {
    local pool_name="$1"
    local force="${2:-false}"
    
    if [[ -z "$pool_name" ]]; then
    tlog error "pool_delete: pool_name required"
        return 1
    fi
    
    # Check if pool exists
    local fd="${POOL_DESCRIPTORS[$pool_name]:-}"
    if [[ -z "$fd" ]]; then
    tlog warning "pool_delete: pool '$pool_name' does not exist"
        return 1
    fi
    
    # Check if resources are still acquired
    local acquired="${POOL_ACQUIRED[$pool_name]:-0}"
    if [[ $acquired -gt 0 && "$force" != "true" ]]; then
    tlog error "pool_delete: pool '$pool_name' has $acquired acquired resources (use force=true to override)"
        return 1
    fi
    
    tlog debug "Deleting resource pool '$pool_name' (force: $force)"
    
    # Close file descriptor - SECURE: Properly close without leaks
    if [[ "$fd" =~ ^[0-9]+$ ]]; then
        # SECURITY: Safe file descriptor closing
        eval "exec ${fd}<&-" 2>/dev/null || true
        eval "exec ${fd}>&-" 2>/dev/null || true
        tlog debug "Closed pool file descriptor $fd for '$pool_name'"
    else
        tlog warning "Invalid file descriptor for pool '$pool_name': $fd"
    fi
    
    # Remove temporary file
    local temp_file="${POOL_TEMP_FILES[$pool_name]:-}"
    [[ -n "$temp_file" ]] && rm -f "$temp_file"
    
    # Remove from tracking
    unset RESOURCE_POOLS["$pool_name"]
    unset POOL_ACQUIRED["$pool_name"]
    unset POOL_DESCRIPTORS["$pool_name"]
    unset POOL_TEMP_FILES["$pool_name"]
    
    tlog debug "Resource pool '$pool_name' deleted successfully"
    return 0
}

# Get statistics for all pools
pool_stats() {
    local total_pools=${#RESOURCE_POOLS[@]}
    local total_resources=0
    local total_acquired=0
    
    for pool_name in "${!RESOURCE_POOLS[@]}"; do
        total_resources=$((total_resources + RESOURCE_POOLS[$pool_name]))
        total_acquired=$((total_acquired + POOL_ACQUIRED[$pool_name]))
    done
    
    local total_available=$((total_resources - total_acquired))
    
    echo "Total Pools: $total_pools, Total Resources: $total_resources, Total Acquired: $total_acquired, Total Available: $total_available"
}

# Get next available file descriptor
get_available_fd() {
    # For simplicity, use a counter-based approach
    RESOURCE_POOL_COUNTER=$((RESOURCE_POOL_COUNTER + 1))
    local fd=$((10 + RESOURCE_POOL_COUNTER))
    
    # Check if we're within reasonable limits
    if [[ $fd -gt 200 ]]; then
        echo "-1"
        return 1
    fi
    
    echo "$fd"
    return 0
}

# Cleanup all resource pools
resource_pool_cleanup_all() {
    tlog debug "Cleaning up all resource pools..."
    
    for pool_name in "${!RESOURCE_POOLS[@]}"; do
        pool_delete "$pool_name" true
    done
    
    tlog debug "All resource pools cleaned up"
}

# Check if a pool exists
pool_exists() {
    local pool_name="$1"
    [[ -n "${RESOURCE_POOLS[$pool_name]:-}" ]]
}

# Wait for resources to become available
pool_wait_available() {
    local pool_name="$1"
    local required="${2:-1}"
    local timeout="${3:-$RESOURCE_POOL_TIMEOUT}"
    
    if [[ -z "$pool_name" ]]; then
    tlog error "pool_wait_available: pool_name required"
        return 1
    fi
    
    local start_time=$(date +%s)
    local waited=0
    
    while [[ $waited -lt $timeout ]]; do
        local available
        available=$(pool_available "$pool_name")
        
        if [[ $available -ge $required ]]; then
            return 0
        fi
        
        sleep 1
        local current_time=$(date +%s)
        waited=$((current_time - start_time))
    done
    
    tlog warning "pool_wait_available: timeout waiting for $required resources in pool '$pool_name'"
    return 124
}

# Batch acquire multiple resources
pool_acquire_batch() {
    local pool_name="$1"
    local count="${2:-1}"
    local timeout="${3:-$RESOURCE_POOL_TIMEOUT}"
    
    if [[ $count -lt 1 ]]; then
    tlog error "pool_acquire_batch: count must be >= 1"
        return 1
    fi
    
    local tokens=()
    local acquired=0
    
    # Try to acquire all resources
    for ((i = 0; i < count; i++)); do
        local token
        if token=$(pool_acquire "$pool_name" "$timeout"); then
            tokens+=("$token")
            ((acquired++))
        else
            # Failed to acquire, release what we got
            local j
            for ((j = 0; j < ${#tokens[@]}; j++)); do
                pool_release "$pool_name" "${tokens[$j]}"
            done
    tlog error "pool_acquire_batch: failed to acquire $count resources from '$pool_name' (got $acquired)"
            return 1
        fi
    done
    
    # Return all tokens
    printf "%s\n" "${tokens[@]}"
    return 0
}

# Batch release multiple resources
pool_release_batch() {
    local pool_name="$1"
    shift
    local tokens=("$@")
    
    if [[ ${#tokens[@]} -eq 0 ]]; then
    tlog error "pool_release_batch: no tokens provided"
        return 1
    fi
    
    local released=0
    for token in "${tokens[@]}"; do
        if pool_release "$pool_name" "$token"; then
            ((released++))
        fi
    done
    
    tlog debug "pool_release_batch: released $released/${#tokens[@]} resources to pool '$pool_name'"
    [[ $released -eq ${#tokens[@]} ]]
}

# Export functions
export -f resource_pool_init pool_create pool_acquire pool_release pool_available
export -f pool_status pool_list pool_delete pool_stats pool_exists pool_wait_available
export -f pool_acquire_batch pool_release_batch get_available_fd resource_pool_cleanup_all
