#!/bin/bash

# state_database.sh - Enhanced state management with file-based persistence and atomic operations
# Extends test_state.sh functionality with database-like features

# Source existing test_state.sh as foundation
# source "$(dirname "${BASH_SOURCE[0]}")/test_state.sh"

# Enhanced state configuration
STATE_DB_DIR="${STATE_DB_DIR:-/tmp/grpctestify_state}"
STATE_DB_FILE="${STATE_DB_FILE:-$STATE_DB_DIR/state.db}"
STATE_SCHEMA_VERSION="${STATE_SCHEMA_VERSION:-1}"
STATE_BACKUP_INTERVAL="${STATE_BACKUP_INTERVAL:-300}"  # 5 minutes
STATE_MAX_BACKUPS="${STATE_MAX_BACKUPS:-10}"

# Transaction support
declare -g -A STATE_TRANSACTIONS=()       # transaction_id -> transaction_data
declare -g -A STATE_LOCKS=()              # key -> lock_info
declare -g -i STATE_TRANSACTION_COUNTER=0
declare -g STATE_AUTO_COMMIT="${STATE_AUTO_COMMIT:-true}"

# Schema management
declare -g -A STATE_SCHEMA=()             # field_name -> field_definition
declare -g -A STATE_VALIDATORS=()         # field_name -> validator_function

# Initialize enhanced state database
state_db_init() {
    tlog debug "Initializing enhanced state database..."
    
    # Create state directory
    mkdir -p "$STATE_DB_DIR"
    if [[ ! -d "$STATE_DB_DIR" ]]; then
    tlog error "Failed to create state database directory: $STATE_DB_DIR"
        return 1
    fi
    
    # Initialize existing test_state system first
    if command -v test_state_init >/dev/null 2>&1; then
        test_state_init
    else
        # Initialize basic state if test_state.sh not available
        # Only initialize if not already set (for test compatibility)
        [[ -z "${GRPCTESTIFY_STATE+x}" ]] && declare -g -A GRPCTESTIFY_STATE=()
        [[ -z "${GRPCTESTIFY_TEST_RESULTS+x}" ]] && declare -g -a GRPCTESTIFY_TEST_RESULTS=()
        [[ -z "${GRPCTESTIFY_FAILED_DETAILS+x}" ]] && declare -g -a GRPCTESTIFY_FAILED_DETAILS=()
        [[ -z "${GRPCTESTIFY_PLUGIN_METADATA+x}" ]] && declare -g -A GRPCTESTIFY_PLUGIN_METADATA=()
        [[ -z "${GRPCTESTIFY_TEST_METADATA+x}" ]] && declare -g -A GRPCTESTIFY_TEST_METADATA=()
    fi
    
    # Setup enhanced features
    state_db_setup_schema
    state_db_load_from_file
    
    # LAZY INITIALIZATION: Backup daemon will start when first backup is needed
    # No automatic background process spawn
    
    # Setup cleanup on exit
    # REMOVED: trap 'state_db_cleanup' EXIT  
    # Now using unified signal_manager for proper cleanup handling
    
    tlog debug "Enhanced state database initialized successfully"
    return 0
}

# Setup database schema
state_db_setup_schema() {
    tlog debug "Setting up state database schema..."
    
    # Define core schema
    STATE_SCHEMA["test_id"]="string:required:unique"
    STATE_SCHEMA["test_status"]="enum:PASS,FAIL,SKIP:required"
    STATE_SCHEMA["test_duration"]="integer:min:0"
    STATE_SCHEMA["test_timestamp"]="integer:required"
    STATE_SCHEMA["test_error"]="string:optional"
    STATE_SCHEMA["test_metadata"]="json:optional"
    STATE_SCHEMA["plugin_data"]="json:optional"
    
    # Define validators
    STATE_VALIDATORS["test_id"]="state_validate_test_id"
    STATE_VALIDATORS["test_status"]="state_validate_test_status"
    STATE_VALIDATORS["test_duration"]="state_validate_test_duration"
    STATE_VALIDATORS["test_timestamp"]="state_validate_timestamp"
    
    tlog debug "State database schema configured"
    return 0
}

# Load state from persistent file
state_db_load_from_file() {
    if [[ ! -f "$STATE_DB_FILE" ]]; then
    tlog debug "No existing state database file found, starting fresh"
        return 0
    fi
    
    tlog debug "Loading state from file: $STATE_DB_FILE"
    
    # Read and validate file
    if [[ ! -s "$STATE_DB_FILE" ]]; then
    tlog debug "State database file is empty"
        return 0
    fi
    
    # Load state data (simplified JSON parsing)
    local line_num=0
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]] && continue
        
        # Parse key=value format
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Store in appropriate state structure
            case "$key" in
                "test_result:"*)
                    GRPCTESTIFY_TEST_RESULTS+=("$value")
                    ;;
                "test_metadata:"*)
                    local test_id="${key#test_metadata:}"
                    GRPCTESTIFY_TEST_METADATA["$test_id"]="$value"
                    ;;
                "plugin_metadata:"*)
                    local plugin_key="${key#plugin_metadata:}"
                    GRPCTESTIFY_PLUGIN_METADATA["$plugin_key"]="$value"
                    ;;
                "state:"*)
                    local state_key="${key#state:}"
                    GRPCTESTIFY_STATE["$state_key"]="$value"
                    ;;
                *)
    tlog warning "Unknown state key in database: $key (line $line_num)"
                    ;;
            esac
        else
    tlog warning "Invalid state database line format: $line (line $line_num)"
        fi
    done < "$STATE_DB_FILE"
    
    tlog debug "State loaded from database successfully"
    return 0
}

# Save state to persistent file
state_db_save_to_file() {
    tlog debug "Saving state to file: $STATE_DB_FILE"
    
    # Create temporary file for atomic write
    local temp_file="${STATE_DB_FILE}.tmp.$$"
    
    {
        echo "# grpctestify state database v${STATE_SCHEMA_VERSION}"
        echo "# Generated: $(date)"
        echo ""
        
        # Save core state
        for key in "${!GRPCTESTIFY_STATE[@]}"; do
            echo "state:$key=${GRPCTESTIFY_STATE[$key]}"
        done
        
        # Save test results
        local i=0
        for result in "${GRPCTESTIFY_TEST_RESULTS[@]}"; do
            echo "test_result:$i=$result"
            ((i++))
        done
        
        # Save test metadata
        for test_id in "${!GRPCTESTIFY_TEST_METADATA[@]}"; do
            echo "test_metadata:$test_id=${GRPCTESTIFY_TEST_METADATA[$test_id]}"
        done
        
        # Save plugin metadata
        for plugin_key in "${!GRPCTESTIFY_PLUGIN_METADATA[@]}"; do
            echo "plugin_metadata:$plugin_key=${GRPCTESTIFY_PLUGIN_METADATA[$plugin_key]}"
        done
        
    } > "$temp_file"
    
    # Atomic move
    if mv "$temp_file" "$STATE_DB_FILE"; then
    tlog debug "State saved to database successfully"
        return 0
    else
    tlog error "Failed to save state to database"
        rm -f "$temp_file"
        return 1
    fi
}

# Start transaction
state_db_begin_transaction() {
    local transaction_id="${1:-tx_$$_$(date +%s)}"
    
        if [[ -n "${STATE_TRANSACTIONS[$transaction_id]:-}" ]]; then
	tlog debug "Transaction '$transaction_id' already exists"
        return 0  # Return success for idempotency
    fi
    
    tlog debug "Beginning transaction: $transaction_id"
    
    # Create transaction snapshot
    local snapshot_data
    snapshot_data=$(state_db_create_snapshot)
    
    STATE_TRANSACTIONS["$transaction_id"]="$snapshot_data"
    
    echo "$transaction_id"
    return 0
}

# Commit transaction
state_db_commit_transaction() {
    local transaction_id="$1"
    
    if [[ -z "$transaction_id" ]]; then
    tlog error "state_db_commit_transaction: transaction_id required"
        return 1
    fi
    
    if [[ -z "${STATE_TRANSACTIONS[$transaction_id]:-}" ]]; then
    tlog error "Transaction '$transaction_id' not found"
        return 1
    fi
    
    tlog debug "Committing transaction: $transaction_id"
    
    # Save current state to file
    if state_db_save_to_file; then
        # Remove transaction
        unset STATE_TRANSACTIONS["$transaction_id"]
    tlog debug "Transaction '$transaction_id' committed successfully"
        return 0
    else
    tlog error "Failed to commit transaction '$transaction_id'"
        return 1
    fi
}

# Rollback transaction
state_db_rollback_transaction() {
    local transaction_id="$1"
    
    if [[ -z "$transaction_id" ]]; then
    tlog error "state_db_rollback_transaction: transaction_id required"
        return 1
    fi
    
    local snapshot_data="${STATE_TRANSACTIONS[$transaction_id]:-}"
    if [[ -z "$snapshot_data" ]]; then
    tlog error "Transaction '$transaction_id' not found"
        return 1
    fi
    
    tlog debug "Rolling back transaction: $transaction_id"
    
    # Restore state from snapshot
    if state_db_restore_snapshot "$snapshot_data"; then
        unset STATE_TRANSACTIONS["$transaction_id"]
    tlog debug "Transaction '$transaction_id' rolled back successfully"
        return 0
    else
    tlog error "Failed to rollback transaction '$transaction_id'"
        return 1
    fi
}

# Create state snapshot
state_db_create_snapshot() {
    # Create compressed snapshot of current state
    local snapshot_file="${STATE_DB_DIR}/snapshot_$$_$(date +%s).snap"
    
    {
        # Export current state
        declare -p GRPCTESTIFY_STATE 2>/dev/null || echo "declare -A GRPCTESTIFY_STATE=()"
        declare -p GRPCTESTIFY_TEST_RESULTS 2>/dev/null || echo "declare -a GRPCTESTIFY_TEST_RESULTS=()"
        declare -p GRPCTESTIFY_TEST_METADATA 2>/dev/null || echo "declare -A GRPCTESTIFY_TEST_METADATA=()"
        declare -p GRPCTESTIFY_PLUGIN_METADATA 2>/dev/null || echo "declare -A GRPCTESTIFY_PLUGIN_METADATA=()"
    } > "$snapshot_file"
    
    echo "$snapshot_file"
    return 0
}

# Restore state from snapshot
state_db_restore_snapshot() {
    local snapshot_file="$1"
    
    if [[ ! -f "$snapshot_file" ]]; then
    tlog error "Snapshot file not found: $snapshot_file"
        return 1
    fi
    
    tlog debug "Restoring state from snapshot: $snapshot_file"
    
    # Source the snapshot to restore state
    source "$snapshot_file"
    
    # Clean up snapshot file
    rm -f "$snapshot_file"
    
    tlog debug "State restored from snapshot successfully"
    return 0
}

# Acquire lock on key
state_db_acquire_lock() {
    local key="$1"
    local timeout="${2:-10}"
    local lock_id="lock_$$_$(date +%s)"
    
    if [[ -z "$key" ]]; then
    tlog error "state_db_acquire_lock: key required"
        return 1
    fi
    
    tlog debug "Acquiring lock on key '$key' (timeout: ${timeout}s)"
    
    local waited=0
    while [[ $waited -lt $timeout ]]; do
        if [[ -z "${STATE_LOCKS[$key]:-}" ]]; then
            # Lock is available
            STATE_LOCKS["$key"]="$lock_id:$(date +%s):$$"
    tlog debug "Lock acquired on key '$key' (lock_id: $lock_id)"
            echo "$lock_id"
            return 0
        fi
        
        # Check if existing lock is stale
        local lock_info="${STATE_LOCKS[$key]}"
        local lock_timestamp
        lock_timestamp=$(echo "$lock_info" | cut -d: -f2)
        local current_time=$(date +%s)
        
        if [[ $((current_time - lock_timestamp)) -gt 60 ]]; then
            # Lock is stale, take it over
            STATE_LOCKS["$key"]="$lock_id:$current_time:$$"
    tlog debug "Stale lock overtaken on key '$key' (lock_id: $lock_id)"
            echo "$lock_id"
            return 0
        fi
        
        sleep 1
        ((waited++))
    done
    
    tlog warning "Timeout acquiring lock on key '$key'"
    return 124
}

# Release lock
state_db_release_lock() {
    local key="$1"
    local lock_id="$2"
    
    if [[ -z "$key" || -z "$lock_id" ]]; then
    tlog error "state_db_release_lock: key and lock_id required"
        return 1
    fi
    
    local current_lock="${STATE_LOCKS[$key]:-}"
    if [[ -z "$current_lock" ]]; then
    tlog warning "No lock found on key '$key'"
        return 1
    fi
    
    local current_lock_id
    current_lock_id=$(echo "$current_lock" | cut -d: -f1)
    
    if [[ "$current_lock_id" != "$lock_id" ]]; then
    tlog error "Lock ID mismatch for key '$key': expected '$lock_id', got '$current_lock_id'"
        return 1
    fi
    
    unset STATE_LOCKS["$key"]
    tlog debug "Lock released on key '$key' (lock_id: $lock_id)"
    return 0
}

# Atomic operation wrapper
state_db_atomic() {
    local operation="$1"
    shift
    local args=("$@")
    
    if [[ -z "$operation" ]]; then
    tlog error "state_db_atomic: operation required"
        return 1
    fi
    
    # Start transaction
    local tx_id
    tx_id=$(state_db_begin_transaction)
    
    # Execute operation
    if "$operation" "${args[@]}"; then
        # Commit on success
        state_db_commit_transaction "$tx_id"
        return 0
    else
        # Rollback on failure
        state_db_rollback_transaction "$tx_id"
        return 1
    fi
}

# Validation functions
state_validate_test_id() {
    local value="$1"
    [[ -n "$value" && ${#value} -le 255 ]]
}

state_validate_test_status() {
    local value="$1"
    [[ "$value" =~ ^(PASS|FAIL|SKIP)$ ]]
}

state_validate_test_duration() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]] && [[ $value -ge 0 ]]
}

state_validate_timestamp() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]] && [[ $value -gt 0 ]]
}

# Create backup
state_db_create_backup() {
    local backup_dir="${STATE_DB_DIR}/backups"
    mkdir -p "$backup_dir"
    
    local backup_file="${backup_dir}/state_backup_$(date +%Y%m%d_%H%M%S).db"
    
    if [[ -f "$STATE_DB_FILE" ]]; then
        cp "$STATE_DB_FILE" "$backup_file"
    tlog debug "State backup created: $backup_file"
        
        # Cleanup old backups
        local backup_count
        backup_count=$(find "$backup_dir" -name "state_backup_*.db" | wc -l)
        if [[ $backup_count -gt $STATE_MAX_BACKUPS ]]; then
            find "$backup_dir" -name "state_backup_*.db" -type f | sort | head -n $((backup_count - STATE_MAX_BACKUPS)) | xargs rm -f
    tlog debug "Old backups cleaned up"
        fi
        
        return 0
    else
    tlog warning "No state database file to backup"
        return 1
    fi
}

# Start backup daemon
state_db_start_backup_daemon() {
    tlog debug "Starting state database backup daemon..."
    
    local backup_iterations=0
    local max_backup_iterations=${STATE_MAX_BACKUP_ITERATIONS:-72}  # Default 72 iterations (12 hours with 10min interval)
    
    while [[ $backup_iterations -lt $max_backup_iterations ]]; do
        sleep "$STATE_BACKUP_INTERVAL"
        state_db_create_backup
        ((backup_iterations++))
    done
    
    tlog debug "State database backup daemon completed after $backup_iterations iterations"
}

# Get database statistics
state_db_stats() {
    local format="${1:-summary}"
    
    local total_tests=${#GRPCTESTIFY_TEST_RESULTS[@]}
    local total_metadata=${#GRPCTESTIFY_TEST_METADATA[@]}
    local total_plugin_data=${#GRPCTESTIFY_PLUGIN_METADATA[@]}
    local total_state_keys=${#GRPCTESTIFY_STATE[@]}
    local active_locks=${#STATE_LOCKS[@]}
    local active_transactions=${#STATE_TRANSACTIONS[@]}
    
    case "$format" in
        "summary")
            echo "Tests: $total_tests, Metadata: $total_metadata, Plugin Data: $total_plugin_data, State Keys: $total_state_keys, Locks: $active_locks, Transactions: $active_transactions"
            ;;
        "detailed")
            echo "State Database Statistics:"
            echo "  Total Tests: $total_tests"
            echo "  Test Metadata Entries: $total_metadata"
            echo "  Plugin Data Entries: $total_plugin_data"
            echo "  State Keys: $total_state_keys"
            echo "  Active Locks: $active_locks"
            echo "  Active Transactions: $active_transactions"
            echo "  Database File: $STATE_DB_FILE"
            echo "  Schema Version: $STATE_SCHEMA_VERSION"
            ;;
        "json")
            echo "{\"total_tests\":$total_tests,\"metadata_entries\":$total_metadata,\"plugin_data\":$total_plugin_data,\"state_keys\":$total_state_keys,\"active_locks\":$active_locks,\"active_transactions\":$active_transactions}"
            ;;
    esac
}

# Cleanup state database
state_db_cleanup() {
    tlog debug "Cleaning up state database..."
    
    # Save final state
    state_db_save_to_file
    
    # Release all locks
    for key in "${!STATE_LOCKS[@]}"; do
        unset STATE_LOCKS["$key"]
    done
    
    # Rollback any active transactions
    for tx_id in "${!STATE_TRANSACTIONS[@]}"; do
        state_db_rollback_transaction "$tx_id"
    done
    
    tlog debug "State database cleaned up"
}

# Core state access functions
state_db_set() {
    local key="$1"
    local value="$2"
    
    if [[ -z "$key" ]]; then
        tlog error "state_db_set: key required"
        return 1
    fi
    
    # Validate key format (alphanumeric, underscores, and dots for namespacing)
    if [[ ! "$key" =~ ^[a-zA-Z0-9_.]+$ ]]; then
        tlog error "state_db_set: invalid key format '$key'"
        return 1
    fi
    
    GRPCTESTIFY_STATE["$key"]="$value"
    tlog debug "Set state: $key = $value"
    return 0
}

state_db_get() {
    local key="$1"
    local default_value="${2:-}"
    
    if [[ -z "$key" ]]; then
        tlog error "state_db_get: key required"
        return 1
    fi
    
    if [[ -v "GRPCTESTIFY_STATE[$key]" ]]; then
        echo "${GRPCTESTIFY_STATE[$key]}"
        return 0
    elif [[ -n "$default_value" ]]; then
        echo "$default_value"
        return 0
    else
        return 1
    fi
}

# Export functions
export -f state_db_init state_db_setup_schema state_db_load_from_file state_db_save_to_file
export -f state_db_begin_transaction state_db_commit_transaction state_db_rollback_transaction
export -f state_db_create_snapshot state_db_restore_snapshot state_db_acquire_lock state_db_release_lock
export -f state_db_atomic state_db_create_backup state_db_start_backup_daemon state_db_stats state_db_cleanup
export -f state_validate_test_id state_validate_test_status state_validate_test_duration state_validate_timestamp
export -f state_db_set state_db_get
