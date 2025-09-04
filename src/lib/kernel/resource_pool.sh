#!/bin/bash

# resource_pool.sh - Resource pool management for controlled parallel execution
# Implements FIFO-based semaphore using file descriptors for job throttling

# Global state for resource pool
declare -g -A RESOURCE_POOLS=()            # pool_name -> max_resources
declare -g -A POOL_ACQUIRED=()             # pool_name -> current_acquired_count
declare -g -A POOL_TOKENS=()               # pool_name_token -> status (available/acquired)
declare -g RESOURCE_POOL_INITIALIZED=false # Initialization guard

# Configuration
RESOURCE_POOL_TIMEOUT="${RESOURCE_POOL_TIMEOUT:-30}" # seconds

# Initialize resource pool system
resource_pool_init() {
	# Check if already initialized
	if [[ "$RESOURCE_POOL_INITIALIZED" == "true" ]]; then
		log_debug "Resource pool system already initialized, skipping..."
		return 0
	fi

	log_debug "Initializing resource pool system..."

	# Setup cleanup on exit
	# REMOVED: trap 'resource_pool_cleanup_all' EXIT
	# Now using unified signal_manager for proper cleanup handling

	RESOURCE_POOL_INITIALIZED=true
	log_debug "Resource pool system initialized successfully"
	return 0
}

# Create a new resource pool
pool_create() {
	local pool_name="$1"
	local max_resources="${2:-10}"

	if [[ -z "$pool_name" ]]; then
		log_error "pool_create: pool_name required"
		return 1
	fi

	if [[ ${RESOURCE_POOLS[$pool_name]:-0} -gt 0 ]]; then
		log_debug "pool_create: pool '$pool_name' already exists"
		return 0
	fi

	log_debug "Creating resource pool '$pool_name' with $max_resources resources"

	# Create in-memory token array instead of temporary file
	local i
	for ((i = 0; i < max_resources; i++)); do
		POOL_TOKENS["${pool_name}_$i"]="available"
	done

	# Register pool
	RESOURCE_POOLS["$pool_name"]=$max_resources
	POOL_ACQUIRED["$pool_name"]=0

	log_debug "Resource pool '$pool_name' created successfully (in-memory)"
	return 0
}

# Acquire a resource from the pool (blocking)
pool_acquire() {
	local pool_name="$1"
	local timeout="${2:-$RESOURCE_POOL_TIMEOUT}"

	if [[ -z "$pool_name" ]]; then
		log_error "pool_acquire: pool_name required"
		return 1
	fi

	# Check if pool exists
	if [[ ${RESOURCE_POOLS[$pool_name]:-0} -eq 0 ]]; then
		log_error "pool_acquire: pool '$pool_name' does not exist"
		return 1
	fi

	log_debug "Acquiring resource from pool '$pool_name' (timeout: ${timeout}s)"

	# Try to acquire a token with timeout
	local start_time=$(date +%s)
	local waited=0

	while [[ $waited -lt $timeout ]]; do
		# Find available token
		local i
		for ((i = 0; i < ${RESOURCE_POOLS[$pool_name]}; i++)); do
			local token_key="${pool_name}_$i"
			if [[ "${POOL_TOKENS[$token_key]}" == "available" ]]; then
				# Mark token as acquired
				POOL_TOKENS["$token_key"]="acquired"
				POOL_ACQUIRED["$pool_name"]=$((POOL_ACQUIRED["$pool_name"] + 1))
				log_debug "Acquired resource from pool '$pool_name' (token: $i, acquired: ${POOL_ACQUIRED[$pool_name]})"
				echo "token_$i"
				return 0
			fi
		done

		# Update waited time
		local current_time=$(date +%s)
		waited=$((current_time - start_time))

		# Brief pause before retry
		sleep 0.1
	done

	log_warn "pool_acquire: timeout waiting for resource from pool '$pool_name'"
	return 124 # timeout exit code
}

# Release a resource back to the pool
pool_release() {
	local pool_name="$1"
	local token="${2:-token_default}"

	if [[ -z "$pool_name" ]]; then
		log_error "pool_release: pool_name required"
		return 1
	fi

	# Check if pool exists
	if [[ ${RESOURCE_POOLS[$pool_name]:-0} -eq 0 ]]; then
		log_error "pool_release: pool '$pool_name' does not exist"
		return 1
	fi

	# Extract token number from token string (e.g., "token_5" -> "5")
	local token_num
	if [[ "$token" =~ ^token_([0-9]+)$ ]]; then
		token_num="${BASH_REMATCH[1]}"
	else
		log_error "pool_release: invalid token format '$token'"
		return 1
	fi

	# Check if token is valid for this pool
	if [[ $token_num -ge ${RESOURCE_POOLS[$pool_name]} ]]; then
		log_error "pool_release: token $token_num is invalid for pool '$pool_name'"
		return 1
	fi

	local token_key="${pool_name}_$token_num"

	# Check if token was actually acquired
	if [[ "${POOL_TOKENS[$token_key]}" != "acquired" ]]; then
		log_warn "pool_release: token $token was not acquired from pool '$pool_name'"
		return 1
	fi

	# Mark token as available again
	POOL_TOKENS["$token_key"]="available"
	POOL_ACQUIRED["$pool_name"]=$((POOL_ACQUIRED["$pool_name"] - 1))

	log_debug "Released resource to pool '$pool_name' (token: $token, acquired: ${POOL_ACQUIRED[$pool_name]})"
	return 0
}

# Get available resources in pool
pool_available() {
	local pool_name="$1"

	if [[ -z "$pool_name" ]]; then
		log_error "pool_available: pool_name required"
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
	local format="${2:-summary}" # summary|detailed|json

	if [[ -z "$pool_name" ]]; then
		log_error "pool_status: pool_name required"
		return 1
	fi

	local max_resources="${RESOURCE_POOLS[$pool_name]:-}"
	local acquired="${POOL_ACQUIRED[$pool_name]:-0}"

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
		echo "  Available: $available"
		echo "  Acquired: $acquired"
		echo "  Type: In-memory semaphore"
		;;
	"json")
		echo "{\"pool_name\":\"$pool_name\",\"max_resources\":$max_resources,\"acquired\":$acquired,\"available\":$available,\"type\":\"in-memory\"}"
		;;
	esac
}

# List all resource pools
pool_list() {
	local format="${1:-summary}" # summary|detailed|json

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
		log_error "pool_delete: pool_name required"
		return 1
	fi

	# Check if pool exists
	if [[ ${RESOURCE_POOLS[$pool_name]:-0} -eq 0 ]]; then
		log_warn "pool_delete: pool '$pool_name' does not exist"
		return 1
	fi

	# Check if resources are still acquired
	local acquired="${POOL_ACQUIRED[$pool_name]:-0}"
	if [[ $acquired -gt 0 && "$force" != "true" ]]; then
		log_error "pool_delete: pool '$pool_name' has $acquired acquired resources (use force=true to override)"
		return 1
	fi

	log_debug "Deleting resource pool '$pool_name' (force: $force)"

	# Clean up tokens for this pool
	local i
	for ((i = 0; i < ${RESOURCE_POOLS[$pool_name]}; i++)); do
		unset POOL_TOKENS["${pool_name}_$i"]
	done

	# Remove from tracking
	unset RESOURCE_POOLS["$pool_name"]
	unset POOL_ACQUIRED["$pool_name"]

	log_debug "Resource pool '$pool_name' deleted successfully"
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

# Cleanup all resource pools
resource_pool_cleanup_all() {
	log_debug "Cleaning up all resource pools..."

	for pool_name in "${!RESOURCE_POOLS[@]}"; do
		pool_delete "$pool_name" true
	done

	log_debug "All resource pools cleaned up"
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
		log_error "pool_wait_available: pool_name required"
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

	log_warn "pool_wait_available: timeout waiting for $required resources in pool '$pool_name'"
	return 124
}

# Batch acquire multiple resources
pool_acquire_batch() {
	local pool_name="$1"
	local count="${2:-1}"
	local timeout="${3:-$RESOURCE_POOL_TIMEOUT}"

	if [[ $count -lt 1 ]]; then
		log_error "pool_acquire_batch: count must be >= 1"
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
			log_error "pool_acquire_batch: failed to acquire $count resources from '$pool_name' (got $acquired)"
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
		log_error "pool_release_batch: no tokens provided"
		return 1
	fi

	local released=0
	for token in "${tokens[@]}"; do
		if pool_release "$pool_name" "$token"; then
			((released++))
		fi
	done

	log_debug "pool_release_batch: released $released/${#tokens[@]} resources to pool '$pool_name'"
	[[ $released -eq ${#tokens[@]} ]]
}

# Export functions
export -f resource_pool_init pool_create pool_acquire pool_release pool_available
export -f pool_status pool_list pool_delete pool_stats pool_exists pool_wait_available
export -f pool_acquire_batch pool_release_batch resource_pool_cleanup_all
