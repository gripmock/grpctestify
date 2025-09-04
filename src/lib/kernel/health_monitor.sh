#!/bin/bash

# health_monitor.sh - Process health monitoring system
# Provides background monitoring, heartbeat validation, and recovery policies

# Global state for health monitoring
declare -g -A HEALTH_MONITORS=()            # monitor_id -> config
declare -g -A MONITOR_PIDS=()               # monitor_id -> background_monitor_pid
declare -g -A MONITOR_STATUS=()             # monitor_id -> status (active|paused|stopped)
declare -g -A MONITORED_PROCESSES=()        # process_id -> monitor_config
declare -g -A PROCESS_HEALTH=()             # process_id -> health_status
declare -g -A PROCESS_LAST_CHECK=()         # process_id -> last_check_timestamp
declare -g -A RECOVERY_ATTEMPTS=()          # process_id -> attempt_count
declare -g HEALTH_MONITOR_INITIALIZED=false # Initialization guard

# Configuration
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-5}" # seconds
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-10}"              # seconds
MAX_RECOVERY_ATTEMPTS="${MAX_RECOVERY_ATTEMPTS:-3}" # attempts
RECOVERY_BACKOFF_BASE="${RECOVERY_BACKOFF_BASE:-2}" # exponential backoff base
HEALTH_LOG_LEVEL="${HEALTH_LOG_LEVEL:-INFO}"        # DEBUG|INFO|WARNING|ERROR

# Health status constants
readonly HEALTH_UNKNOWN="unknown"
readonly HEALTH_HEALTHY="healthy"
readonly HEALTH_UNHEALTHY="unhealthy"
readonly HEALTH_CRITICAL="critical"
readonly HEALTH_RECOVERING="recovering"

# Initialize health monitoring system
health_monitor_init() {
	# Check if already initialized
	if [[ "$HEALTH_MONITOR_INITIALIZED" == "true" ]]; then
		log_debug "Health monitoring system already initialized, skipping..."
		return 0
	fi

	log_debug "Initializing health monitoring system..."

	# Ensure required commands are available
	if ! command -v kill >/dev/null 2>&1; then
		log_error "Health monitor requires 'kill' command"
		return 1
	fi

	# Setup cleanup on exit
	# REMOVED: trap 'health_monitor_cleanup_all' EXIT
	# Now using unified signal_manager for proper cleanup handling

	HEALTH_MONITOR_INITIALIZED=true
	log_debug "Health monitoring system initialized successfully"
	return 0
}

# Create a new health monitor
health_monitor_create() {
	local monitor_id="$1"
	local check_interval="${2:-$HEALTH_CHECK_INTERVAL}"
	local timeout="${3:-$HEALTH_TIMEOUT}"
	local recovery_policy="${4:-restart}" # restart|notify|ignore

	if [[ -z "$monitor_id" ]]; then
		log_error "health_monitor_create: monitor_id required"
		return 1
	fi

	if [[ -n "${HEALTH_MONITORS[$monitor_id]:-}" ]]; then
		log_debug "health_monitor_create: monitor '$monitor_id' already exists"
		return 0
	fi

	log_debug "Creating health monitor '$monitor_id' (interval: ${check_interval}s, timeout: ${timeout}s, policy: $recovery_policy)"

	# Store monitor configuration
	HEALTH_MONITORS["$monitor_id"]="interval:$check_interval,timeout:$timeout,policy:$recovery_policy"
	MONITOR_STATUS["$monitor_id"]="active"

	# LAZY INITIALIZATION: Monitor will start when first process is added
	# No automatic background process spawn
	MONITOR_PIDS["$monitor_id"]="" # Empty until started

	log_debug "Health monitor '$monitor_id' created successfully (will start on demand)"
	return 0
}

# Register a process for health monitoring
health_monitor_register() {
	local process_id="$1"
	local process_pid="$2"
	local monitor_id="${3:-default}"
	local health_check_cmd="${4:-}"

	if [[ -z "$process_id" || -z "$process_pid" ]]; then
		log_error "health_monitor_register: process_id and process_pid required"
		return 1
	fi

	# Ensure monitor exists
	if [[ -z "${HEALTH_MONITORS[$monitor_id]:-}" ]]; then
		log_debug "Creating default monitor for process registration"
		health_monitor_create "$monitor_id"
	fi

	log_debug "Registering process '$process_id' (PID: $process_pid) with monitor '$monitor_id'"

	# Register process
	MONITORED_PROCESSES["$process_id"]="monitor:$monitor_id,pid:$process_pid,check_cmd:$health_check_cmd"
	PROCESS_HEALTH["$process_id"]="$HEALTH_UNKNOWN"
	PROCESS_LAST_CHECK["$process_id"]=$(date +%s)
	RECOVERY_ATTEMPTS["$process_id"]=0

	log_debug "Process '$process_id' registered successfully"
	return 0
}

# Unregister a process from health monitoring
health_monitor_unregister() {
	local process_id="$1"

	if [[ -z "$process_id" ]]; then
		log_error "health_monitor_unregister: process_id required"
		return 1
	fi

	log_debug "Unregistering process '$process_id' from health monitoring"

	# Remove from tracking
	unset MONITORED_PROCESSES["$process_id"]
	unset PROCESS_HEALTH["$process_id"]
	unset PROCESS_LAST_CHECK["$process_id"]
	unset RECOVERY_ATTEMPTS["$process_id"]

	log_debug "Process '$process_id' unregistered successfully"
	return 0
}

# Perform health check on a specific process
health_check_process() {
	local process_id="$1"

	if [[ -z "$process_id" ]]; then
		log_error "health_check_process: process_id required"
		return 1
	fi

	local process_config="${MONITORED_PROCESSES[$process_id]:-}"
	if [[ -z "$process_config" ]]; then
		log_error "health_check_process: process '$process_id' not registered"
		return 1
	fi

	# Parse process configuration
	local process_pid
	local check_cmd
	process_pid=$(echo "$process_config" | sed -n 's/.*pid:\([^,]*\).*/\1/p')
	check_cmd=$(echo "$process_config" | sed -n 's/.*check_cmd:\([^,]*\).*/\1/p')

	log_debug "Performing health check on process '$process_id' (PID: $process_pid)"

	local health_status="$HEALTH_HEALTHY"
	local check_time=$(date +%s)

	# Basic PID check
	if ! kill -0 "$process_pid" 2>/dev/null; then
		health_status="$HEALTH_CRITICAL"
		log_warn "Process '$process_id' (PID: $process_pid) is not running"
	elif [[ -n "$check_cmd" ]]; then
		# Custom health check command - SECURE: Sanitized execution
		# SECURITY: Validate command before execution to prevent injection
		if [[ "$check_cmd" =~ ^[a-zA-Z0-9_/.-]+(\s+[a-zA-Z0-9_/.-]+)*$ ]]; then
			if ! timeout 5 bash -c "$check_cmd" >/dev/null 2>&1; then
				health_status="$HEALTH_UNHEALTHY"
				log_warn "Process '$process_id' failed custom health check: $check_cmd"
			fi
		else
			health_status="$HEALTH_CRITICAL"
			log_error "Process '$process_id' has unsafe health check command: $check_cmd"
		fi
	fi

	# Update health status
	local previous_health="${PROCESS_HEALTH[$process_id]}"
	PROCESS_HEALTH["$process_id"]="$health_status"
	PROCESS_LAST_CHECK["$process_id"]="$check_time"

	# Log health status changes
	if [[ "$previous_health" != "$health_status" ]]; then
		log_debug "Process '$process_id' health changed: $previous_health -> $health_status"

		# Trigger recovery if needed
		if [[ "$health_status" == "$HEALTH_CRITICAL" || "$health_status" == "$HEALTH_UNHEALTHY" ]]; then
			health_trigger_recovery "$process_id"
		else
			# Reset recovery attempts on successful health check
			RECOVERY_ATTEMPTS["$process_id"]=0
		fi
	fi

	echo "$health_status"
	return 0
}

# Trigger recovery action for an unhealthy process
health_trigger_recovery() {
	local process_id="$1"

	if [[ -z "$process_id" ]]; then
		log_error "health_trigger_recovery: process_id required"
		return 1
	fi

	local process_config="${MONITORED_PROCESSES[$process_id]:-}"
	if [[ -z "$process_config" ]]; then
		log_error "health_trigger_recovery: process '$process_id' not registered"
		return 1
	fi

	# Parse monitor configuration
	local monitor_id
	monitor_id=$(echo "$process_config" | sed -n 's/.*monitor:\([^,]*\).*/\1/p')
	local monitor_config="${HEALTH_MONITORS[$monitor_id]:-}"
	local recovery_policy
	recovery_policy=$(echo "$monitor_config" | sed -n 's/.*policy:\([^,]*\).*/\1/p')

	local attempts="${RECOVERY_ATTEMPTS[$process_id]:-0}"

	log_warn "Triggering recovery for process '$process_id' (attempt: $((attempts + 1))/$MAX_RECOVERY_ATTEMPTS, policy: $recovery_policy)"

	# Check if we've exceeded max recovery attempts
	if [[ $attempts -ge $MAX_RECOVERY_ATTEMPTS ]]; then
		log_error "Process '$process_id' exceeded max recovery attempts ($MAX_RECOVERY_ATTEMPTS)"
		PROCESS_HEALTH["$process_id"]="$HEALTH_CRITICAL"
		return 1
	fi

	# Increment recovery attempts
	RECOVERY_ATTEMPTS["$process_id"]=$((attempts + 1))
	PROCESS_HEALTH["$process_id"]="$HEALTH_RECOVERING"

	# Apply recovery policy
	case "$recovery_policy" in
	"restart")
		health_recovery_restart "$process_id"
		;;
	"notify")
		health_recovery_notify "$process_id"
		;;
	"ignore")
		log_debug "Recovery policy 'ignore' - no action taken for process '$process_id'"
		;;
	*)
		log_error "Unknown recovery policy: $recovery_policy"
		return 1
		;;
	esac

	# Apply exponential backoff
	local backoff_time=$((RECOVERY_BACKOFF_BASE ** attempts))
	log_debug "Applying recovery backoff: ${backoff_time}s for process '$process_id'"
	sleep "$backoff_time"

	return 0
}

# Recovery action: restart process
health_recovery_restart() {
	local process_id="$1"

	log_debug "Attempting to restart process '$process_id'"

	# This is a placeholder - in real implementation, this would:
	# 1. Extract restart command from process registration
	# 2. Kill old process gracefully
	# 3. Start new process
	# 4. Update process PID in monitoring

	# For now, just log the action
	log_warn "Process restart not implemented - would restart '$process_id'"
	return 0
}

# Recovery action: notify about process failure
health_recovery_notify() {
	local process_id="$1"

	log_debug "Sending failure notification for process '$process_id'"

	# This could trigger external notifications:
	# - Send to external monitoring system
	# - Write to alerting queue
	# - Trigger webhook

	# For now, just log
	log_warn "Process notification not implemented - would notify about '$process_id'"
	return 0
}

# Get health status of a process
health_get_status() {
	local process_id="$1"
	local format="${2:-status}" # status|detailed|json

	if [[ -z "$process_id" ]]; then
		log_error "health_get_status: process_id required"
		return 1
	fi

	local health_status="${PROCESS_HEALTH[$process_id]:-$HEALTH_UNKNOWN}"
	local last_check="${PROCESS_LAST_CHECK[$process_id]:-0}"
	local recovery_attempts="${RECOVERY_ATTEMPTS[$process_id]:-0}"
	local process_config="${MONITORED_PROCESSES[$process_id]:-}"

	case "$format" in
	"status")
		echo "$health_status"
		;;
	"detailed")
		echo "Process: $process_id"
		echo "  Health: $health_status"
		echo "  Last Check: $(date -d "@$last_check" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")"
		echo "  Recovery Attempts: $recovery_attempts"
		echo "  Configuration: $process_config"
		;;
	"json")
		echo "{\"process_id\":\"$process_id\",\"health\":\"$health_status\",\"last_check\":$last_check,\"recovery_attempts\":$recovery_attempts}"
		;;
	esac
}

# List all monitored processes
health_list_processes() {
	local format="${1:-summary}" # summary|detailed|json

	if [[ ${#MONITORED_PROCESSES[@]} -eq 0 ]]; then
		echo "No monitored processes"
		return 0
	fi

	case "$format" in
	"summary")
		printf "%-20s %-15s %-15s %-10s\n" "PROCESS_ID" "HEALTH" "LAST_CHECK" "ATTEMPTS"
		printf "%-20s %-15s %-15s %-10s\n" "--------------------" "---------------" "---------------" "----------"

		for process_id in "${!MONITORED_PROCESSES[@]}"; do
			local health_status="${PROCESS_HEALTH[$process_id]}"
			local last_check="${PROCESS_LAST_CHECK[$process_id]}"
			local attempts="${RECOVERY_ATTEMPTS[$process_id]}"
			local check_time_str="$(date -d "@$last_check" '+%H:%M:%S' 2>/dev/null || echo "N/A")"

			printf "%-20s %-15s %-15s %-10s\n" "$process_id" "$health_status" "$check_time_str" "$attempts"
		done
		;;
	"detailed")
		for process_id in "${!MONITORED_PROCESSES[@]}"; do
			health_get_status "$process_id" "detailed"
			echo
		done
		;;
	"json")
		echo "["
		local first=true
		for process_id in "${!MONITORED_PROCESSES[@]}"; do
			[[ "$first" == "true" ]] && first=false || echo ","
			health_get_status "$process_id" "json"
		done
		echo "]"
		;;
	esac
}

# Get health monitoring statistics
health_get_stats() {
	local total_processes=${#MONITORED_PROCESSES[@]}
	local healthy=0
	local unhealthy=0
	local critical=0
	local recovering=0
	local unknown=0

	for process_id in "${!MONITORED_PROCESSES[@]}"; do
		local status="${PROCESS_HEALTH[$process_id]}"
		case "$status" in
		"$HEALTH_HEALTHY") ((healthy++)) ;;
		"$HEALTH_UNHEALTHY") ((unhealthy++)) ;;
		"$HEALTH_CRITICAL") ((critical++)) ;;
		"$HEALTH_RECOVERING") ((recovering++)) ;;
		*) ((unknown++)) ;;
		esac
	done

	echo "Total: $total_processes, Healthy: $healthy, Unhealthy: $unhealthy, Critical: $critical, Recovering: $recovering, Unknown: $unknown"
}

# Start background monitoring for a specific monitor
health_monitor_start_background() {
	local monitor_id="$1"

	log_debug "Starting background monitoring for '$monitor_id'"

	local monitor_config="${HEALTH_MONITORS[$monitor_id]:-}"
	local check_interval
	check_interval=$(echo "$monitor_config" | sed -n 's/.*interval:\([^,]*\).*/\1/p')

	local monitor_iterations=0
	local max_monitor_iterations=${HEALTH_MAX_MONITOR_ITERATIONS:-360} # Default 360 iterations (1 hour with 10s interval)

	while [[ "${MONITOR_STATUS[$monitor_id]}" == "active" && $monitor_iterations -lt $max_monitor_iterations ]]; do
		# Check all processes assigned to this monitor
		for process_id in "${!MONITORED_PROCESSES[@]}"; do
			local process_config="${MONITORED_PROCESSES[$process_id]}"
			local process_monitor
			process_monitor=$(echo "$process_config" | sed -n 's/.*monitor:\([^,]*\).*/\1/p')

			if [[ "$process_monitor" == "$monitor_id" ]]; then
				health_check_process "$process_id" >/dev/null
			fi
		done

		sleep "$check_interval"
		((monitor_iterations++))
	done

	if [[ $monitor_iterations -ge $max_monitor_iterations ]]; then
		log_warn "Health monitor '$monitor_id' reached max iterations ($max_monitor_iterations), stopping"
	fi

	log_debug "Background monitoring stopped for '$monitor_id'"
}

# Stop a health monitor
health_monitor_stop() {
	local monitor_id="$1"

	if [[ -z "$monitor_id" ]]; then
		log_error "health_monitor_stop: monitor_id required"
		return 1
	fi

	log_debug "Stopping health monitor '$monitor_id'"

	# Mark monitor as stopped
	MONITOR_STATUS["$monitor_id"]="stopped"

	# Kill background process
	local monitor_pid="${MONITOR_PIDS[$monitor_id]:-}"
	if [[ -n "$monitor_pid" ]]; then
		kill "$monitor_pid" 2>/dev/null || true
		unset MONITOR_PIDS["$monitor_id"]
	fi

	# Clean up monitor
	unset HEALTH_MONITORS["$monitor_id"]
	unset MONITOR_STATUS["$monitor_id"]

	log_debug "Health monitor '$monitor_id' stopped successfully"
	return 0
}

# Pause a health monitor
health_monitor_pause() {
	local monitor_id="$1"

	if [[ -z "$monitor_id" ]]; then
		log_error "health_monitor_pause: monitor_id required"
		return 1
	fi

	MONITOR_STATUS["$monitor_id"]="paused"
	log_debug "Health monitor '$monitor_id' paused"
	return 0
}

# Resume a health monitor
health_monitor_resume() {
	local monitor_id="$1"

	if [[ -z "$monitor_id" ]]; then
		log_error "health_monitor_resume: monitor_id required"
		return 1
	fi

	MONITOR_STATUS["$monitor_id"]="active"
	log_debug "Health monitor '$monitor_id' resumed"
	return 0
}

# Cleanup all health monitors
health_monitor_cleanup_all() {
	log_debug "Cleaning up all health monitors..."

	for monitor_id in "${!HEALTH_MONITORS[@]}"; do
		health_monitor_stop "$monitor_id"
	done

	# Clean up process tracking
	for process_id in "${!MONITORED_PROCESSES[@]}"; do
		health_monitor_unregister "$process_id"
	done

	log_debug "All health monitors cleaned up"
}

# Check if a monitor exists
health_monitor_exists() {
	local monitor_id="$1"
	[[ -n "${HEALTH_MONITORS[$monitor_id]:-}" ]]
}

# Force health check on all processes
health_check_all() {
	log_debug "Performing health check on all monitored processes..."

	local checked=0
	for process_id in "${!MONITORED_PROCESSES[@]}"; do
		health_check_process "$process_id" >/dev/null
		((checked++))
	done

	log_debug "Health check completed on $checked processes"
	return 0
}

# Export functions
export -f health_monitor_init health_monitor_create health_monitor_register health_monitor_unregister
export -f health_check_process health_trigger_recovery health_recovery_restart health_recovery_notify
export -f health_get_status health_list_processes health_get_stats health_monitor_start_background
export -f health_monitor_stop health_monitor_pause health_monitor_resume health_monitor_cleanup_all
export -f health_monitor_exists health_check_all
