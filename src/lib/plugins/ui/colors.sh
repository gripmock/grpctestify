#!/bin/bash

# colors.sh - UI Color Plugin with Enhanced Plugin API
# Moved from kernel to plugins/ui for better modularity

# Plugin metadata
readonly PLUGIN_COLORS_VERSION="1.0.0"
readonly PLUGIN_COLORS_DESCRIPTION="UI color management and formatting"
readonly PLUGIN_COLORS_AUTHOR="grpctestify-team"
readonly PLUGIN_COLORS_TYPE="ui"

# Color definitions with plugin-aware fallbacks
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    readonly RED=$(tput setaf 1)
    readonly GREEN=$(tput setaf 2)
    readonly YELLOW=$(tput setaf 3)
    readonly BLUE=$(tput setaf 4)
    readonly MAGENTA=$(tput setaf 5)
    readonly CYAN=$(tput setaf 6)
    readonly WHITE=$(tput setaf 7)
    readonly BOLD=$(tput bold)
    readonly RESET=$(tput sgr0)
else
    readonly RED=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly BLUE=""
    readonly MAGENTA=""
    readonly CYAN=""
    readonly WHITE=""
    readonly BOLD=""
    readonly RESET=""
fi

# Plugin initialization
colors_plugin_init() {
    tlog debug "Initializing colors plugin..."
    
    # Register with enhanced plugin API
    if command -v plugin_register_enhanced >/dev/null 2>&1; then
        plugin_register_enhanced "colors" "colors_plugin_handler" "$PLUGIN_COLORS_DESCRIPTION" "ui" \
            "color_formatting,message_styling" \
            "ui.message.format:90,ui.error.display:90"
    else
        # Fallback to basic registration
        plugin_register "colors" "colors_plugin_handler" "$PLUGIN_COLORS_DESCRIPTION" "ui"
    fi
    
    tlog debug "Colors plugin initialized successfully"
    return 0
}

# Plugin handler with hook support
colors_plugin_handler() {
    local command="$1"
    shift
    
    case "$command" in
        "hook:ui.message.format")
            colors_format_message "$@"
            ;;
        "hook:ui.error.display")
            colors_format_error "$@"
            ;;
        "colorize")
            colorize "$@"
            ;;
        "metadata")
            echo "{\"name\":\"colors\",\"version\":\"$PLUGIN_COLORS_VERSION\",\"type\":\"$PLUGIN_COLORS_TYPE\"}"
            ;;
        *)
    tlog error "Unknown colors plugin command: $command"
            return 1
            ;;
    esac
}

# Enhanced message formatting through hook
colors_format_message() {
    local message="$1"
    local level="${2:-info}"
    
    case "$level" in
        "error")
            echo "${RED}${BOLD}$message${RESET}"
            ;;
        "warning")
            echo "${YELLOW}$message${RESET}"
            ;;
        "success")
            echo "${GREEN}$message${RESET}"
            ;;
        "info")
            echo "${BLUE}$message${RESET}"
            ;;
        "debug")
            echo "${CYAN}$message${RESET}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Enhanced error formatting through hook
colors_format_error() {
    local error_data="$1"
    
    # Parse error data (could be JSON)
    local error_message
    if [[ "$error_data" == "{"* ]]; then
        error_message=$(echo "$error_data" | jq -r '.message // .' 2>/dev/null || echo "$error_data")
    else
        error_message="$error_data"
    fi
    
    echo "${RED}${BOLD}✗ ERROR:${RESET} ${RED}$error_message${RESET}"
}

# Original colorize function (maintained for compatibility)
colorize() {
    local color="$1"
    local text="$2"
    
    case "$color" in
        red) echo "${RED}$text${RESET}" ;;
        green) echo "${GREEN}$text${RESET}" ;;
        yellow) echo "${YELLOW}$text${RESET}" ;;
        blue) echo "${BLUE}$text${RESET}" ;;
        magenta) echo "${MAGENTA}$text${RESET}" ;;
        cyan) echo "${CYAN}$text${RESET}" ;;
        white) echo "${WHITE}$text${RESET}" ;;
        bold) echo "${BOLD}$text${RESET}" ;;
        *) echo "$text" ;;
    esac
}

# Provide color constants for other plugins
get_color() {
    local color_name="$1"
    case "$color_name" in
        RED|red) echo "$RED" ;;
        GREEN|green) echo "$GREEN" ;;
        YELLOW|yellow) echo "$YELLOW" ;;
        BLUE|blue) echo "$BLUE" ;;
        MAGENTA|magenta) echo "$MAGENTA" ;;
        CYAN|cyan) echo "$CYAN" ;;
        WHITE|white) echo "$WHITE" ;;
        BOLD|bold) echo "$BOLD" ;;
        RESET|reset) echo "$RESET" ;;
        *) echo "" ;;
    esac
}

# Legacy compatibility for tests
setup_colors() {
    # Call the new init function
    colors_plugin_init
}

log() {
    local level="$1"
    shift
    local message="$*"
    
    # Use safe printf to avoid conflicts
    case "$level" in
        error) printf "❌ %s\n" "$message" ;;
        success) printf "✅ %s\n" "$message" ;;
        info) printf "ℹ️ %s\n" "$message" ;;
        warning) printf "⚠️ %s\n" "$message" ;;
        debug) [[ "${verbose:-}" == "true" ]] && printf "🔍 %s\n" "$message" ;;
        section) printf "───[ %s ]───\n" "$message" ;;
        *) printf "%s\n" "$message" ;;
    esac
}

# Export functions
export -f colors_plugin_init colors_plugin_handler colors_format_message colors_format_error
export -f colorize get_color setup_colors log

# Export color constants
export RED GREEN YELLOW BLUE MAGENTA CYAN WHITE BOLD RESET