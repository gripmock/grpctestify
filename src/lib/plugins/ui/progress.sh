#!/bin/bash

# progress.sh - UI Progress Plugin with Enhanced Plugin API
# Moved from kernel to plugins/ui for better modularity

# Plugin metadata
readonly PLUGIN_PROGRESS_VERSION="1.0.0"
readonly PLUGIN_PROGRESS_DESCRIPTION="Progress tracking and display"
readonly PLUGIN_PROGRESS_AUTHOR="grpctestify-team"
readonly PLUGIN_PROGRESS_TYPE="ui"

# Progress state
declare -g PROGRESS_TOTAL=0
declare -g PROGRESS_CURRENT=0
declare -g PROGRESS_STATUS=""

# Plugin initialization
progress_plugin_init() {
    tlog debug "Initializing progress plugin..."
    
    # Register with enhanced plugin API
    if command -v plugin_register_enhanced >/dev/null 2>&1; then
        plugin_register_enhanced "progress" "progress_plugin_handler" "$PLUGIN_PROGRESS_DESCRIPTION" "ui" \
            "progress_tracking,ui_updates" \
            "ui.progress.update:100,test.before.suite:80,test.after.each:80,test.after.suite:80"
    else
        # Fallback to basic registration
        plugin_register "progress" "progress_plugin_handler" "$PLUGIN_PROGRESS_DESCRIPTION" "ui"
    fi
    
    tlog debug "Progress plugin initialized successfully"
    return 0
}

# Plugin handler with hook support
progress_plugin_handler() {
    local command="$1"
    shift
    
    case "$command" in
        "hook:ui.progress.update")
            progress_update_hook "$@"
            ;;
        "hook:test.before.suite")
            progress_start_suite "$@"
            ;;
        "hook:test.after.each")
            progress_increment_test "$@"
            ;;
        "hook:test.after.suite")
            progress_complete_suite "$@"
            ;;
        "init")
            progress_init "$@"
            ;;
        "update")
            progress_update "$@"
            ;;
        "show")
            progress_show "$@"
            ;;
        "metadata")
            echo "{\"name\":\"progress\",\"version\":\"$PLUGIN_PROGRESS_VERSION\",\"type\":\"$PLUGIN_PROGRESS_TYPE\"}"
            ;;
        *)
    tlog error "Unknown progress plugin command: $command"
            return 1
                ;;
        esac
}

# Hook handlers
progress_update_hook() {
    local progress_data="$1"
    
    # Parse progress data (could be JSON or simple values)
    if [[ "$progress_data" == "{"* ]]; then
        local current=$(echo "$progress_data" | jq -r '.current // 0' 2>/dev/null)
        local total=$(echo "$progress_data" | jq -r '.total // 0' 2>/dev/null)
        local status=$(echo "$progress_data" | jq -r '.status // ""' 2>/dev/null)
        progress_update "$current" "$total" "$status"
    else
        # Simple format: current/total/status
        IFS='/' read -r current total status <<< "$progress_data"
        progress_update "${current:-$PROGRESS_CURRENT}" "${total:-$PROGRESS_TOTAL}" "$status"
    fi
}

progress_start_suite() {
    local suite_data="$1"
    
    if [[ "$suite_data" == "{"* ]]; then
        local total_tests=$(echo "$suite_data" | jq -r '.total_tests // 0' 2>/dev/null)
        progress_init "$total_tests" "Starting test suite..."
    fi
}

progress_increment_test() {
    local test_data="$1"
    
    ((PROGRESS_CURRENT++))
    local test_name=""
    if [[ "$test_data" == "{"* ]]; then
        test_name=$(echo "$test_data" | jq -r '.test_name // ""' 2>/dev/null)
    fi
    
    progress_update "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "Completed: $test_name"
}

progress_complete_suite() {
    progress_update "$PROGRESS_TOTAL" "$PROGRESS_TOTAL" "Test suite completed"
    progress_show
}

# Core progress functions
progress_init() {
    local total="${1:-0}"
    local status="${2:-Ready}"
    
    PROGRESS_TOTAL="$total"
    PROGRESS_CURRENT=0
    PROGRESS_STATUS="$status"
    
    tlog debug "Progress initialized: 0/$total - $status"
}

progress_update() {
    local current="${1:-$PROGRESS_CURRENT}"
    local total="${2:-$PROGRESS_TOTAL}"
    local status="${3:-$PROGRESS_STATUS}"
    
    PROGRESS_CURRENT="$current"
    PROGRESS_TOTAL="$total"
    PROGRESS_STATUS="$status"
    
    # Trigger real-time display if not in quiet mode
    if [[ "${GRPCTESTIFY_QUIET:-false}" != "true" ]]; then
        progress_display_realtime
    fi
}

progress_show() {
    local percentage=0
    if [[ "$PROGRESS_TOTAL" -gt 0 ]]; then
        percentage=$(( (PROGRESS_CURRENT * 100) / PROGRESS_TOTAL ))
    fi
    
    # Use colors plugin if available
    local blue_color=""
    local green_color=""
    local reset_color=""
    
    if command -v get_color >/dev/null 2>&1; then
        blue_color=$(get_color "BLUE")
        green_color=$(get_color "GREEN")
        reset_color=$(get_color "RESET")
    fi
    
    echo "${blue_color}Progress: ${green_color}$PROGRESS_CURRENT/$PROGRESS_TOTAL ($percentage%)${reset_color}"
    if [[ -n "$PROGRESS_STATUS" ]]; then
        echo "${blue_color}Status: ${reset_color}$PROGRESS_STATUS"
    fi
}

progress_display_realtime() {
    local percentage=0
    if [[ "$PROGRESS_TOTAL" -gt 0 ]]; then
        percentage=$(( (PROGRESS_CURRENT * 100) / PROGRESS_TOTAL ))
    fi
    
    # Create a simple progress bar
    local bar_length=30
    local filled_length=$(( (percentage * bar_length) / 100 ))
    local bar=""
    
    for ((i=0; i<filled_length; i++)); do
        bar+="█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar+="░"
    done
    
    # Use colors if available
    local colors_available=false
    if command -v get_color >/dev/null 2>&1; then
        colors_available=true
    fi
    
    if [[ "$colors_available" == "true" ]]; then
        local blue=$(get_color "BLUE")
        local green=$(get_color "GREEN")
        local reset=$(get_color "RESET")
        printf "\r${blue}[${green}%s${blue}] ${green}%3d%%${reset} ${blue}%s${reset}" "$bar" "$percentage" "$PROGRESS_STATUS"
    else
        printf "\r[%s] %3d%% %s" "$bar" "$percentage" "$PROGRESS_STATUS"
    fi
    
    # Move to next line when complete
    if [[ "$PROGRESS_CURRENT" -eq "$PROGRESS_TOTAL" ]]; then
        echo ""
    fi
}

# Get current progress state
progress_get_state() {
    echo "{\"current\":$PROGRESS_CURRENT,\"total\":$PROGRESS_TOTAL,\"status\":\"$PROGRESS_STATUS\",\"percentage\":$(( PROGRESS_TOTAL > 0 ? (PROGRESS_CURRENT * 100) / PROGRESS_TOTAL : 0 ))}"
}

# Export functions
export -f progress_plugin_init progress_plugin_handler progress_init progress_update
export -f progress_show progress_display_realtime progress_get_state
export -f progress_update_hook progress_start_suite progress_increment_test progress_complete_suite