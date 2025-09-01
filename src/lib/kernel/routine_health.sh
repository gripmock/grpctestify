#!/bin/bash

# routine_health.sh - Health probe system for routines
# Integrates routine_manager with health_monitor for comprehensive process monitoring

# Source dependencies
# These will be loaded by bashly automatically, but we define dependencies here
# source "$(dirname "${BASH_SOURCE[0]}")/routine_manager.sh"
# source "$(dirname "${BASH_SOURCE[0]}")/health_monitor.sh"

# Global state for routine health probes
declare -g -A ROUTINE_HEALTH_CONFIG=()    # routine_id -> health_config
declare -g -A ROUTINE_HEALTH_STATUS=()    # routine_id -> health_status
declare -g -A ROUTINE_PROBE_COMMANDS=()   # routine_id -> probe_command
declare -g -A ROUTINE_TIMEOUTS=()         # routine_id -> timeout_seconds
declare -g -A ROUTINE_LAST_PROBE=()       # routine_id -> last_probe_timestamp
declare -g -A ROUTINE_PROBE_FAILURES=()   # routine_id -> consecutive_failure_count
declare -g ROUTINE_HEALTH_INITIALIZED=false  # Initialization guard

# Configuration
ROUTINE_PROBE_INTERVAL="${ROUTINE_PROBE_INTERVAL:-10}"     # seconds
ROUTINE_PROBE_TIMEOUT="${ROUTINE_PROBE_TIMEOUT:-5}"       # seconds
ROUTINE_MAX_FAILURES="${ROUTINE_MAX_FAILURES:-3}"         # consecutive failures before kill
ROUTINE_PROBE_RETRY_DELAY="${ROUTINE_PROBE_RETRY_DELAY:-2}" # seconds between retries

# Health probe types
readonly PROBE_TYPE_HEARTBEAT="heartbeat"    # Check heartbeat file
readonly PROBE_TYPE_COMMAND="command"        # Execute custom command
readonly PROBE_TYPE_RESPONSE="response"      # Check process responsiveness
readonly PROBE_TYPE_RESOURCE="resource"      # Check resource usage

# Initialize routine health system
routine_health_init() {
    # Check if already initialized
    if [[ "$ROUTINE_HEALTH_INITIALIZED" == "true" ]]; then
        tlog debug "Routine health system already initialized, skipping..."
        return 0
    fi
    
    tlog debug "Initializing routine health probe system..."
    
    # Ensure dependencies are available
    if ! command -v routine_manager_init >/dev/null 2>&1; then
    tlog error "Routine health requires routine_manager.sh"
        return 1
    fi
    
    if ! command -v health_monitor_init >/dev/null 2>&1; then
    tlog error "Routine health requires health_monitor.sh"
        return 1
    fi
    
    # Initialize underlying systems
    routine_manager_init
    health_monitor_init
    
    # Create health monitor for routines
    health_monitor_create "routine_health" "$ROUTINE_PROBE_INTERVAL" "$ROUTINE_PROBE_TIMEOUT" "restart"
    
    # Setup cleanup
    # REMOVED: trap 'routine_health_cleanup' EXIT
    # Now using unified signal_manager for proper cleanup handling
    
    ROUTINE_HEALTH_INITIALIZED=true
    tlog debug "Routine health probe system initialized successfully"
    return 0
}

# Spawn routine with health monitoring
routine_spawn_monitored() {
    local command="$1"
    local routine_id="${2:-routine_$((++ROUTINE_COUNTER))}"
    local probe_type="${3:-$PROBE_TYPE_HEARTBEAT}"
    local probe_config="${4:-}"
    local timeout="${5:-$ROUTINE_PROBE_TIMEOUT}"
    local max_failures="${6:-$ROUTINE_MAX_FAILURES}"
    
    if [[ -z "$command" ]]; then
    tlog error "routine_spawn_monitored: command required"
        return 1
    fi
    
    tlog debug "Spawning monitored routine '$routine_id' with probe type '$probe_type'"
    
    # Spawn the routine using routine_manager
    local spawned_routine_id
    spawned_routine_id=$(routine_spawn "$command" "$routine_id")
    if [[ $? -ne 0 ]]; then
    tlog error "Failed to spawn routine '$routine_id'"
        return 1
    fi
    
    # Get routine PID
    local routine_pid="${ROUTINE_PIDS[$routine_id]:-}"
    if [[ -z "$routine_pid" ]]; then
    tlog error "No PID found for routine '$routine_id'"
        return 1
    fi
    
    # Setup health monitoring
    routine_health_register "$routine_id" "$routine_pid" "$probe_type" "$probe_config" "$timeout" "$max_failures"
    
    echo "$spawned_routine_id"
    return 0
}

# Register routine for health monitoring
routine_health_register() {
    local routine_id="$1"
    local routine_pid="$2"
    local probe_type="$3"
    local probe_config="$4"
    local timeout="${5:-$ROUTINE_PROBE_TIMEOUT}"
    local max_failures="${6:-$ROUTINE_MAX_FAILURES}"
    
    if [[ -z "$routine_id" || -z "$routine_pid" ]]; then
    tlog error "routine_health_register: routine_id and routine_pid required"
        return 1
    fi
    
    tlog debug "Registering routine '$routine_id' (PID: $routine_pid) for health monitoring"
    
    # Create probe command based on type
    local probe_command
    case "$probe_type" in
        "$PROBE_TYPE_HEARTBEAT")
            probe_command="routine_health_probe_heartbeat '$routine_id'"
            ;;
        "$PROBE_TYPE_COMMAND")
            if [[ -z "$probe_config" ]]; then
    tlog error "Custom command required for probe type '$probe_type'"
                return 1
            fi
            # SECURITY: Validate custom probe command to prevent injection
            if [[ ! "$probe_config" =~ ^[a-zA-Z0-9_/.-]+(\s+[a-zA-Z0-9_/.-]+)*$ ]]; then
    tlog error "Invalid probe command (security): $probe_config"
                return 1
            fi
            probe_command="$probe_config"
            ;;
        "$PROBE_TYPE_RESPONSE")
            probe_command="routine_health_probe_response '$routine_id'"
            ;;
        "$PROBE_TYPE_RESOURCE")
            probe_command="routine_health_probe_resource '$routine_id'"
            ;;
        *)
    tlog error "Unknown probe type: $probe_type"
            return 1
            ;;
    esac
    
    # Store configuration
    ROUTINE_HEALTH_CONFIG["$routine_id"]="type:$probe_type,timeout:$timeout,max_failures:$max_failures"
    ROUTINE_HEALTH_STATUS["$routine_id"]="$HEALTH_UNKNOWN"
    ROUTINE_PROBE_COMMANDS["$routine_id"]="$probe_command"
    ROUTINE_TIMEOUTS["$routine_id"]="$timeout"
    ROUTINE_LAST_PROBE["$routine_id"]=$(date +%s)
    ROUTINE_PROBE_FAILURES["$routine_id"]=0
    
    # Register with health monitor
    health_monitor_register "$routine_id" "$routine_pid" "routine_health" "$probe_command"
    
    tlog debug "Routine '$routine_id' registered for health monitoring successfully"
    return 0
}

# Heartbeat probe - checks if heartbeat file is recent
routine_health_probe_heartbeat() {
    local routine_id="$1"
    
    local heartbeat_file="/tmp/grpctestify_heartbeat_${routine_id}"
    local timeout="${ROUTINE_TIMEOUTS[$routine_id]:-$ROUTINE_PROBE_TIMEOUT}"
    local current_time=$(date +%s)
    
    if [[ ! -f "$heartbeat_file" ]]; then
    tlog warning "Heartbeat file missing for routine '$routine_id'"
        return 1
    fi
    
    local last_heartbeat
    last_heartbeat=$(cat "$heartbeat_file" 2>/dev/null || echo "0")
    local heartbeat_age=$((current_time - last_heartbeat))
    
    if [[ $heartbeat_age -gt $timeout ]]; then
    tlog warning "Heartbeat stale for routine '$routine_id' (age: ${heartbeat_age}s, timeout: ${timeout}s)"
        return 1
    fi
    
    tlog debug "Heartbeat healthy for routine '$routine_id' (age: ${heartbeat_age}s)"
    return 0
}

# Response probe - checks if process responds to signals
routine_health_probe_response() {
    local routine_id="$1"
    
    local routine_pid="${ROUTINE_PIDS[$routine_id]:-}"
    if [[ -z "$routine_pid" ]]; then
    tlog error "No PID found for routine '$routine_id'"
        return 1
    fi
    
    # Send USR1 signal to test responsiveness
    if kill -USR1 "$routine_pid" 2>/dev/null; then
    tlog debug "Process responsive for routine '$routine_id'"
        return 0
    else
    tlog warning "Process unresponsive for routine '$routine_id'"
        return 1
    fi
}

# Resource probe - checks resource usage
routine_health_probe_resource() {
    local routine_id="$1"
    
    local routine_pid="${ROUTINE_PIDS[$routine_id]:-}"
    if [[ -z "$routine_pid" ]]; then
    tlog error "No PID found for routine '$routine_id'"
        return 1
    fi
    
    # Check if process exists and get basic stats
    if kill -0 "$routine_pid" 2>/dev/null; then
        # Could check memory usage, CPU usage, etc. here
        # For now, just verify process exists
    tlog debug "Resource check passed for routine '$routine_id'"
        return 0
    else
    tlog warning "Process not found for routine '$routine_id'"
        return 1
    fi
}

# Perform health probe on routine
routine_health_probe() {
    local routine_id="$1"
    
    if [[ -z "$routine_id" ]]; then
    tlog error "routine_health_probe: routine_id required"
        return 1
    fi
    
    local probe_command="${ROUTINE_PROBE_COMMANDS[$routine_id]:-}"
    if [[ -z "$probe_command" ]]; then
    tlog error "No probe command configured for routine '$routine_id'"
        return 1
    fi
    
    tlog debug "Performing health probe on routine '$routine_id'"
    
    local probe_result
    local probe_start_time=$(date +%s)
    
    # Execute probe command with timeout
    if timeout "${ROUTINE_TIMEOUTS[$routine_id]}" bash -c "$probe_command"; then
        probe_result="$HEALTH_HEALTHY"
        ROUTINE_PROBE_FAILURES["$routine_id"]=0
    tlog debug "Health probe successful for routine '$routine_id'"
    else
        probe_result="$HEALTH_UNHEALTHY"
        local failures=$((ROUTINE_PROBE_FAILURES["$routine_id"] + 1))
        ROUTINE_PROBE_FAILURES["$routine_id"]=$failures
    tlog warning "Health probe failed for routine '$routine_id' (failure count: $failures)"
        
        # Check if we should kill the routine
        local max_failures
        max_failures=$(echo "${ROUTINE_HEALTH_CONFIG[$routine_id]}" | sed -n 's/.*max_failures:\([^,]*\).*/\1/p')
        if [[ $failures -ge ${max_failures:-$ROUTINE_MAX_FAILURES} ]]; then
    tlog error "Routine '$routine_id' exceeded max failures ($failures), killing..."
            routine_health_kill_unresponsive "$routine_id"
            probe_result="$HEALTH_CRITICAL"
        fi
    fi
    
    # Update status
    ROUTINE_HEALTH_STATUS["$routine_id"]="$probe_result"
    ROUTINE_LAST_PROBE["$routine_id"]=$(date +%s)
    
    echo "$probe_result"
    return 0
}

# Kill unresponsive routine
routine_health_kill_unresponsive() {
    local routine_id="$1"
    
    tlog warning "Killing unresponsive routine '$routine_id'"
    
    # Try graceful termination first
    if routine_kill "$routine_id" "TERM"; then
        sleep 2
        
        # Check if still running
        local routine_pid="${ROUTINE_PIDS[$routine_id]:-}"
        if [[ -n "$routine_pid" ]] && kill -0 "$routine_pid" 2>/dev/null; then
            # Force kill
    tlog warning "Force killing routine '$routine_id'"
            routine_kill "$routine_id" "KILL"
        fi
    fi
    
    # Update status
    ROUTINE_HEALTH_STATUS["$routine_id"]="$HEALTH_CRITICAL"
    
    # Unregister from health monitoring
    routine_health_unregister "$routine_id"
    
    return 0
}

# Unregister routine from health monitoring
routine_health_unregister() {
    local routine_id="$1"
    
    if [[ -z "$routine_id" ]]; then
    tlog error "routine_health_unregister: routine_id required"
        return 1
    fi
    
    tlog debug "Unregistering routine '$routine_id' from health monitoring"
    
    # Unregister from health monitor
    health_monitor_unregister "$routine_id"
    
    # Clean up tracking
    unset ROUTINE_HEALTH_CONFIG["$routine_id"]
    unset ROUTINE_HEALTH_STATUS["$routine_id"]
    unset ROUTINE_PROBE_COMMANDS["$routine_id"]
    unset ROUTINE_TIMEOUTS["$routine_id"]
    unset ROUTINE_LAST_PROBE["$routine_id"]
    unset ROUTINE_PROBE_FAILURES["$routine_id"]
    
    tlog debug "Routine '$routine_id' unregistered from health monitoring"
    return 0
}

# Get routine health status
routine_health_status() {
    local routine_id="$1"
    local format="${2:-status}"  # status|detailed|json
    
    if [[ -z "$routine_id" ]]; then
    tlog error "routine_health_status: routine_id required"
        return 1
    fi
    
    local health_status="${ROUTINE_HEALTH_STATUS[$routine_id]:-$HEALTH_UNKNOWN}"
    local last_probe="${ROUTINE_LAST_PROBE[$routine_id]:-0}"
    local failures="${ROUTINE_PROBE_FAILURES[$routine_id]:-0}"
    local config="${ROUTINE_HEALTH_CONFIG[$routine_id]:-}"
    
    case "$format" in
        "status")
            echo "$health_status"
            ;;
        "detailed")
            echo "Routine: $routine_id"
            echo "  Health Status: $health_status"
            echo "  Last Probe: $(date -d "@$last_probe" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")"
            echo "  Failure Count: $failures"
            echo "  Configuration: $config"
            ;;
        "json")
            echo "{\"routine_id\":\"$routine_id\",\"health_status\":\"$health_status\",\"last_probe\":$last_probe,\"failures\":$failures}"
            ;;
    esac
}

# List all monitored routines
routine_health_list() {
    local format="${1:-summary}"  # summary|detailed|json
    
    if [[ ${#ROUTINE_HEALTH_STATUS[@]} -eq 0 ]]; then
        echo "No monitored routines"
        return 0
    fi
    
    case "$format" in
        "summary")
            printf "%-20s %-15s %-15s %-10s\n" "ROUTINE_ID" "HEALTH" "LAST_PROBE" "FAILURES"
            printf "%-20s %-15s %-15s %-10s\n" "--------------------" "---------------" "---------------" "----------"
            
            for routine_id in "${!ROUTINE_HEALTH_STATUS[@]}"; do
                local health_status="${ROUTINE_HEALTH_STATUS[$routine_id]}"
                local last_probe="${ROUTINE_LAST_PROBE[$routine_id]}"
                local failures="${ROUTINE_PROBE_FAILURES[$routine_id]}"
                local probe_time_str="$(date -d "@$last_probe" '+%H:%M:%S' 2>/dev/null || echo "N/A")"
                
                printf "%-20s %-15s %-15s %-10s\n" "$routine_id" "$health_status" "$probe_time_str" "$failures"
            done
            ;;
        "detailed")
            for routine_id in "${!ROUTINE_HEALTH_STATUS[@]}"; do
                routine_health_status "$routine_id" "detailed"
                echo
            done
            ;;
        "json")
            echo "["
            local first=true
            for routine_id in "${!ROUTINE_HEALTH_STATUS[@]}"; do
                [[ "$first" == "true" ]] && first=false || echo ","
                routine_health_status "$routine_id" "json"
            done
            echo "]"
            ;;
    esac
}

# Get health statistics
routine_health_stats() {
    local total_routines=${#ROUTINE_HEALTH_STATUS[@]}
    local healthy=0
    local unhealthy=0
    local critical=0
    local unknown=0
    
    for routine_id in "${!ROUTINE_HEALTH_STATUS[@]}"; do
        local status="${ROUTINE_HEALTH_STATUS[$routine_id]}"
        case "$status" in
            "$HEALTH_HEALTHY") ((healthy++)) ;;
            "$HEALTH_UNHEALTHY") ((unhealthy++)) ;;
            "$HEALTH_CRITICAL") ((critical++)) ;;
            *) ((unknown++)) ;;
        esac
    done
    
    echo "Total Monitored: $total_routines, Healthy: $healthy, Unhealthy: $unhealthy, Critical: $critical, Unknown: $unknown"
}

# Force health check on all routines
routine_health_check_all() {
    tlog debug "Performing health check on all monitored routines..."
    
    local checked=0
    for routine_id in "${!ROUTINE_HEALTH_STATUS[@]}"; do
        routine_health_probe "$routine_id" >/dev/null
        ((checked++))
    done
    
    tlog debug "Health check completed on $checked routines"
    return 0
}

# Cleanup routine health system
routine_health_cleanup() {
    tlog debug "Cleaning up routine health system..."
    
    # Unregister all routines
    for routine_id in "${!ROUTINE_HEALTH_STATUS[@]}"; do
        routine_health_unregister "$routine_id"
    done
    
    tlog debug "Routine health system cleaned up"
}

# Check if routine is being monitored
routine_health_is_monitored() {
    local routine_id="$1"
    [[ -n "${ROUTINE_HEALTH_STATUS[$routine_id]:-}" ]]
}

# Set timeout for specific routine
routine_health_set_timeout() {
    local routine_id="$1"
    local timeout="$2"
    
    if [[ -z "$routine_id" || -z "$timeout" ]]; then
    tlog error "routine_health_set_timeout: routine_id and timeout required"
        return 1
    fi
    
    ROUTINE_TIMEOUTS["$routine_id"]="$timeout"
    tlog debug "Timeout set to ${timeout}s for routine '$routine_id'"
    return 0
}

# Export functions
export -f routine_health_init routine_spawn_monitored routine_health_register
export -f routine_health_probe_heartbeat routine_health_probe_response routine_health_probe_resource
export -f routine_health_probe routine_health_kill_unresponsive routine_health_unregister
export -f routine_health_status routine_health_list routine_health_stats routine_health_check_all
export -f routine_health_cleanup routine_health_is_monitored routine_health_set_timeout
