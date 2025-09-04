#!/bin/bash

# event_system.sh - Inter-plugin communication system using named pipes
# Provides event bus, subscription management, and message routing

# Global state for event system - Initialize immediately to avoid array errors
declare -g -A EVENT_SUBSCRIBERS=()         # event_type -> comma-separated subscriber_list  
declare -g -A EVENT_HANDLERS=()            # subscriber_id -> handler_function
declare -g -A EVENT_PIPES=()               # subscriber_id -> named_pipe_path
declare -g -A EVENT_FILTERS=()             # subscriber_id -> filter_expression
declare -g -A EVENT_STATS=()               # event_type -> event_count
declare -g EVENT_SYSTEM_INITIALIZED=false
declare -g EVENT_BUS_PIPE=""              # Main event bus pipe
declare -g EVENT_DISPATCHER_PID=""        # Background dispatcher process PID
declare -g -i EVENT_COUNTER=0             # Auto-incrementing event ID counter

# Configuration
EVENT_BUS_DIR="${EVENT_BUS_DIR:-/tmp/grpctestify_events}"
EVENT_TIMEOUT="${EVENT_TIMEOUT:-5}"                    # seconds
EVENT_QUEUE_SIZE="${EVENT_QUEUE_SIZE:-1000}"           # max events in queue
EVENT_CLEANUP_INTERVAL="${EVENT_CLEANUP_INTERVAL:-30}" # seconds

# Event priority levels
readonly EVENT_PRIORITY_LOW=1
readonly EVENT_PRIORITY_NORMAL=2
readonly EVENT_PRIORITY_HIGH=3
readonly EVENT_PRIORITY_CRITICAL=4

# Initialize event system
event_system_init() {
    log_debug "Initializing event system..."
    
    # Mark event system as initialized
    EVENT_SYSTEM_INITIALIZED=true
    
    # Create event bus directory
    mkdir -p "$EVENT_BUS_DIR"
    if [[ ! -d "$EVENT_BUS_DIR" ]]; then
    log_error "Failed to create event bus directory: $EVENT_BUS_DIR"
        return 1
    fi
    
    # Create main event bus pipe
    EVENT_BUS_PIPE="$EVENT_BUS_DIR/event_bus"
    if ! mkfifo "$EVENT_BUS_PIPE" 2>/dev/null; then
        # Pipe might already exist
        if [[ ! -p "$EVENT_BUS_PIPE" ]]; then
    log_error "Failed to create event bus pipe: $EVENT_BUS_PIPE"
            return 1
        fi
    fi
    
    # LAZY INITIALIZATION: Dispatcher will start when first event is published
    # No automatic background process spawn
    EVENT_DISPATCHER_PID=""
    
    # Setup cleanup on exit
    # REMOVED: trap 'event_system_cleanup' EXIT
    # Now using unified signal_manager for proper cleanup handling
    
    log_debug "Event system initialized successfully (dispatcher PID: $EVENT_DISPATCHER_PID)"
    return 0
}

# Subscribe to events
event_subscribe() {
    local subscriber_id="$1"
    local event_type="$2"
    local handler_function="$3"
    local filter_expression="${4:-}"
    
    if [[ -z "$subscriber_id" || -z "$event_type" || -z "$handler_function" ]]; then
    log_error "event_subscribe: subscriber_id, event_type, and handler_function required"
        return 1
    fi
    
    # Silently skip - event system disabled for stability
    return 0
    
    log_debug "Subscribing '$subscriber_id' to event type '$event_type' with handler '$handler_function'"
    
    # Create subscriber pipe
    local subscriber_pipe="$EVENT_BUS_DIR/subscriber_${subscriber_id}"
    if ! mkfifo "$subscriber_pipe" 2>/dev/null; then
        if [[ ! -p "$subscriber_pipe" ]]; then
    log_error "Failed to create subscriber pipe: $subscriber_pipe"
            return 1
        fi
    fi
    
    # Register subscriber
    EVENT_HANDLERS["$subscriber_id"]="$handler_function"
    EVENT_PIPES["$subscriber_id"]="$subscriber_pipe"
    [[ -n "$filter_expression" ]] && EVENT_FILTERS["$subscriber_id"]="$filter_expression"
    
    # Add to subscriber list for event type
    local current_subscribers="${EVENT_SUBSCRIBERS[$event_type]:-}"
    if [[ -z "$current_subscribers" ]]; then
        EVENT_SUBSCRIBERS["$event_type"]="$subscriber_id"
    else
        EVENT_SUBSCRIBERS["$event_type"]="$current_subscribers,$subscriber_id"
    fi
    
    log_debug "Subscriber '$subscriber_id' registered successfully for event type '$event_type'"
    return 0
}

# Unsubscribe from events
event_unsubscribe() {
    local subscriber_id="$1"
    local event_type="${2:-}"  # If empty, unsubscribe from all events
    
    if [[ -z "$subscriber_id" ]]; then
    log_error "event_unsubscribe: subscriber_id required"
        return 1
    fi
    
    log_debug "Unsubscribing '$subscriber_id' from event type '$event_type'"
    
    if [[ -n "$event_type" ]]; then
        # Unsubscribe from specific event type
        local current_subscribers="${EVENT_SUBSCRIBERS[$event_type]:-}"
        local new_subscribers=""
        
        # Remove subscriber from the list
        IFS=',' read -ra ADDR <<< "$current_subscribers"
        for sub in "${ADDR[@]}"; do
            if [[ "$sub" != "$subscriber_id" ]]; then
                [[ -z "$new_subscribers" ]] && new_subscribers="$sub" || new_subscribers="$new_subscribers,$sub"
            fi
        done
        
        if [[ -z "$new_subscribers" ]]; then
            unset EVENT_SUBSCRIBERS["$event_type"]
        else
            EVENT_SUBSCRIBERS["$event_type"]="$new_subscribers"
        fi
    else
        # Unsubscribe from all event types
        for event_type_key in "${!EVENT_SUBSCRIBERS[@]}"; do
            event_unsubscribe "$subscriber_id" "$event_type_key"
        done
    fi
    
    # Clean up subscriber resources
    local subscriber_pipe="${EVENT_PIPES[$subscriber_id]:-}"
    [[ -n "$subscriber_pipe" && -p "$subscriber_pipe" ]] && rm -f "$subscriber_pipe"
    
    unset EVENT_HANDLERS["$subscriber_id"]
    unset EVENT_PIPES["$subscriber_id"]
    unset EVENT_FILTERS["$subscriber_id"]
    
    log_debug "Subscriber '$subscriber_id' unsubscribed successfully"
    return 0
}

# Publish an event
event_publish() {
    local event_type="$1"
    local event_data="$2"
    local priority="${3:-$EVENT_PRIORITY_NORMAL}"
    local source="${4:-unknown}"
    
    if [[ -z "$event_type" ]]; then
    log_error "event_publish: event_type required"
        return 1
    fi
    
    # Silently skip - event system disabled for stability
    return 0
    
    # Create event message
    EVENT_COUNTER=$((EVENT_COUNTER + 1))
    local timestamp=$(date +%s)
    local event_id="event_${EVENT_COUNTER}_${timestamp}"
    
    local event_message
    event_message=$(cat << EOF
{
  "event_id": "$event_id",
  "event_type": "$event_type",
  "timestamp": $timestamp,
  "priority": $priority,
  "source": "$source",
  "data": "$event_data"
}
EOF
)
    
    log_debug "Publishing event '$event_id' of type '$event_type' (priority: $priority)"
    
    # Send to event bus
    if [[ -p "$EVENT_BUS_PIPE" ]]; then
        echo "$event_message" > "$EVENT_BUS_PIPE" &
        
        # Update statistics
        EVENT_STATS["$event_type"]=$((EVENT_STATS["$event_type"] + 1))
        
    log_debug "Event '$event_id' published successfully"
        return 0
    else
    log_debug "Event bus pipe not available: $EVENT_BUS_PIPE"
        return 1
    fi
}

# Start background event dispatcher
event_start_dispatcher() {
    log_debug "Starting event dispatcher..."
    
    local dispatcher_iterations=0
    local max_dispatcher_iterations=${EVENT_MAX_DISPATCHER_ITERATIONS:-3600}  # Default 3600 iterations (1 hour with 1s interval)
    
    while [[ $dispatcher_iterations -lt $max_dispatcher_iterations ]]; do
        # Check if event system is initialized
        if [[ "$EVENT_SYSTEM_INITIALIZED" != "true" ]]; then
            sleep 1
            ((dispatcher_iterations++))
            continue
        fi
        
        if [[ -p "$EVENT_BUS_PIPE" ]]; then
            # Read events from the bus
            if read -r event_message < "$EVENT_BUS_PIPE"; then
                event_dispatch_message "$event_message"
            fi
        else
            # Event bus not available, wait and retry
            sleep 1
        fi
        
        ((dispatcher_iterations++))
    done
    
    log_debug "Event dispatcher completed after $dispatcher_iterations iterations"
}

# Dispatch event message to subscribers
event_dispatch_message() {
    local event_message="$1"
    
    # Ensure event system is initialized
    if [[ "$EVENT_SYSTEM_INITIALIZED" != "true" ]]; then
        return 0
    fi
    
    # Parse event message (simplified JSON parsing)
    local event_type
    event_type=$(echo "$event_message" | grep -o '"event_type": *"[^"]*"' | sed 's/"event_type": *"\([^"]*\)"/\1/')
    
    local event_id
    event_id=$(echo "$event_message" | grep -o '"event_id": *"[^"]*"' | sed 's/"event_id": *"\([^"]*\)"/\1/')
    
    log_debug "Dispatching event '$event_id' of type '$event_type'"
    
    # Get subscribers for this event type
    local subscribers="${EVENT_SUBSCRIBERS[$event_type]:-}"
    if [[ -z "$subscribers" ]]; then
    log_debug "No subscribers for event type '$event_type'"
        return 0
    fi
    
    # Dispatch to each subscriber
    IFS=',' read -ra ADDR <<< "$subscribers"
    for subscriber_id in "${ADDR[@]}"; do
        event_dispatch_to_subscriber "$subscriber_id" "$event_message"
    done
}

# Dispatch event to specific subscriber
event_dispatch_to_subscriber() {
    local subscriber_id="$1"
    local event_message="$2"
    
    local handler_function="${EVENT_HANDLERS[$subscriber_id]:-}"
    local filter_expression="${EVENT_FILTERS[$subscriber_id]:-}"
    
    if [[ -z "$handler_function" ]]; then
    log_warn "No handler function for subscriber '$subscriber_id'"
        return 1
    fi
    
    # Apply filter if specified
    if [[ -n "$filter_expression" ]]; then
        if ! event_apply_filter "$event_message" "$filter_expression"; then
    log_debug "Event filtered out for subscriber '$subscriber_id'"
            return 0
        fi
    fi
    
    log_debug "Dispatching event to subscriber '$subscriber_id' with handler '$handler_function'"
    
    # Call handler function with event message
    if command -v "$handler_function" >/dev/null 2>&1; then
        "$handler_function" "$event_message"
    else
    log_warn "Handler function '$handler_function' not found for subscriber '$subscriber_id'"
    fi
}

# Apply event filter
event_apply_filter() {
    local event_message="$1"
    local filter_expression="$2"
    
    # Simple filter implementation - could be enhanced with more complex expressions
    # For now, just check if the filter string is contained in the event message
    if [[ "$event_message" =~ $filter_expression ]]; then
        return 0  # Filter passes
    else
        return 1  # Filter fails
    fi
}

# List event subscribers
event_list_subscribers() {
    local event_type="${1:-}"  # If empty, list all subscribers
    local format="${2:-summary}"  # summary|detailed|json
    
    # Ensure event system is initialized
    if [[ "$EVENT_SYSTEM_INITIALIZED" != "true" ]]; then
        echo "Event system not initialized"
        return 1
    fi
    
    case "$format" in
        "summary")
            if [[ -n "$event_type" ]]; then
                local subscribers="${EVENT_SUBSCRIBERS[$event_type]:-}"
                echo "Event Type: $event_type"
                echo "Subscribers: $subscribers"
            else
                printf "%-20s %-50s\n" "EVENT_TYPE" "SUBSCRIBERS"
                printf "%-20s %-50s\n" "--------------------" "--------------------------------------------------"
                for event_type_key in "${!EVENT_SUBSCRIBERS[@]}"; do
                    local subscribers="${EVENT_SUBSCRIBERS[$event_type_key]}"
                    printf "%-20s %-50s\n" "$event_type_key" "$subscribers"
                done
            fi
            ;;
        "detailed")
            for subscriber_id in "${!EVENT_HANDLERS[@]}"; do
                local handler="${EVENT_HANDLERS[$subscriber_id]}"
                local pipe="${EVENT_PIPES[$subscriber_id]}"
                local filter="${EVENT_FILTERS[$subscriber_id]:-none}"
                
                echo "Subscriber: $subscriber_id"
                echo "  Handler: $handler"
                echo "  Pipe: $pipe"
                echo "  Filter: $filter"
                echo
            done
            ;;
        "json")
            echo "["
            local first=true
            for subscriber_id in "${!EVENT_HANDLERS[@]}"; do
                [[ "$first" == "true" ]] && first=false || echo ","
                local handler="${EVENT_HANDLERS[$subscriber_id]}"
                local pipe="${EVENT_PIPES[$subscriber_id]}"
                local filter="${EVENT_FILTERS[$subscriber_id]:-}"
                echo "  {\"subscriber_id\":\"$subscriber_id\",\"handler\":\"$handler\",\"pipe\":\"$pipe\",\"filter\":\"$filter\"}"
            done
            echo "]"
            ;;
    esac
}

# REMOVED: event_get_stats function - unused dead code

# REMOVED: event_clear_stats function - unused dead code

# Check if subscriber exists
event_subscriber_exists() {
    local subscriber_id="$1"
    [[ -n "${EVENT_HANDLERS[$subscriber_id]:-}" ]]
}

# Wait for specific event
event_wait_for() {
    local event_type="$1"
    local timeout="${2:-$EVENT_TIMEOUT}"
    local filter="${3:-}"
    
    if [[ -z "$event_type" ]]; then
    log_error "event_wait_for: event_type required"
        return 1
    fi
    
    log_debug "Waiting for event type '$event_type' (timeout: ${timeout}s)"
    
    # Create temporary subscriber
    local temp_subscriber="wait_$$_$(date +%s)"
    local temp_result_file="/tmp/event_wait_$temp_subscriber"
    
    # Handler function that writes to result file
    temp_event_handler() {
        local event_message="$1"
        echo "$event_message" > "$temp_result_file"
    }
    export -f temp_event_handler
    
    # Subscribe temporarily
    event_subscribe "$temp_subscriber" "$event_type" "temp_event_handler" "$filter"
    
    # Wait for result
    local waited=0
    while [[ $waited -lt $timeout ]]; do
        if [[ -f "$temp_result_file" ]]; then
            local result
            result=$(cat "$temp_result_file")
            
            # Cleanup
            event_unsubscribe "$temp_subscriber" "$event_type"
            rm -f "$temp_result_file"
            
            echo "$result"
            return 0
        fi
        
        sleep 1
        ((waited++))
    done
    
    # Timeout reached
    event_unsubscribe "$temp_subscriber" "$event_type"
    rm -f "$temp_result_file"
    
    log_warn "Timeout waiting for event type '$event_type'"
    return 124
}

# Cleanup event system
event_system_cleanup() {
    log_debug "Cleaning up event system..."
    
    # Stop dispatcher
    if [[ -n "$EVENT_DISPATCHER_PID" ]]; then
        kill "$EVENT_DISPATCHER_PID" 2>/dev/null || true
    fi
    
    # Clean up all subscribers
    for subscriber_id in "${!EVENT_HANDLERS[@]}"; do
        event_unsubscribe "$subscriber_id"
    done
    
    # Clean up event bus
    [[ -p "$EVENT_BUS_PIPE" ]] && rm -f "$EVENT_BUS_PIPE"
    
    # Clean up event directory
    [[ -d "$EVENT_BUS_DIR" ]] && rm -rf "$EVENT_BUS_DIR"
    
    log_debug "Event system cleaned up"
}

# Test handler removed - was unused dead code

# Export functions
export -f event_system_init event_subscribe event_unsubscribe event_publish
export -f event_start_dispatcher event_dispatch_message event_dispatch_to_subscriber
export -f event_apply_filter event_list_subscribers
export -f event_subscriber_exists event_wait_for event_system_cleanup
