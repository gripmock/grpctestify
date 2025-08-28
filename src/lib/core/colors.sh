#!/bin/bash

# colors.sh - Color and logging utilities
# This module provides color output and logging functionality

# Color configuration
setup_colors() {
    if [[ "${no_color:-false}" == "true" ]]; then
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        NC=""
        CHECK="OK"
        CROSS="ERR"
        INFO="INF"
        ALERT="WARN"
    else
        RED="\033[0;31m"
        GREEN="\033[0;32m"
        YELLOW="\033[0;33m"
        BLUE="\033[0;34m"
        NC="\033[0m"
        CHECK="✅"
        CROSS="❌"
        INFO="ℹ️"
        ALERT="⚠️"
    fi
}

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "error")
            printf "${RED}${CROSS} %s${NC}\n" "$message" >&2
            ;;
        "success")
            printf "${GREEN}${CHECK} %s${NC}\n" "$message"
            ;;
        "info")
            printf "${BLUE}${INFO} %s${NC}\n" "$message"
            ;;
        "section")
            printf "\n${YELLOW}───[ %s ]───${NC}\n" "$message"
            ;;
        "debug")
            if [[ "${verbose:-false}" == "true" ]]; then
                printf "${YELLOW}🔍 %s${NC}\n" "$message" >&2
            fi
            ;;
        "warning")
            printf "${YELLOW}${ALERT} %s${NC}\n" "$message" >&2
            ;;
    esac
}

# Dependencies are now handled by bashly configuration
# See src/bashly.yml for dependency definitions

# Initialize colors on module load
setup_colors
