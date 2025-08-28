#!/bin/bash

# utils.sh - Shared utility functions
# Common functions used across multiple modules

# Process line with comment and quote handling
process_line() {
    local line="$1"
    local in_str=0
    local escaped=0
    local res=""
    
    for ((i=1; i<=${#line}; i++)); do
        local c="${line:$((i-1)):1}"
        if ((escaped)); then
            res+="$c"
            escaped=0
        elif [[ "$c" == "\\" ]]; then
            res+="$c"
            escaped=1
        elif [[ "$c" == "\"" ]]; then
            res+="$c"
            in_str=$((!in_str))
        elif [[ "$c" == "#" && $in_str -eq 0 ]]; then
            break
        else
            res+="$c"
        fi
    done
    
    echo "$res"
}

# Extract section from test file using awk
# This is a complex parser that:
# 1. Finds sections delimited by "--- SECTION_NAME ---"
# 2. Handles comments (# characters) properly inside and outside quoted strings
# 3. Processes escape sequences and quoted strings correctly
# 4. Strips comments while preserving quoted content
extract_section_awk() {
    local test_file="$1"
    local section="$2"
    
    awk -v sec="$section" '
    # Smart comment removal: processes line character-by-character to handle quotes correctly
    function process_line(line) {
        in_str = 0
        escaped = 0
        res = ""
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (escaped) {
                res = res c
                escaped = 0
            } else if (c == "\\") {
                res = res c
                escaped = 1
            } else if (c == "\"") {
                res = res c
                in_str = !in_str
            } else if (c == "#" && !in_str) {
                break
            } else {
                res = res c
            }
        }
        return res
    }
    $0 ~ /^[[:space:]]*#/ { next }
    $0 ~ "^[[:space:]]*---[[:space:]]*" sec "([[:space:]]+.*)?[[:space:]]*---" { 
        found=1
        # Capture the full line for modifier detection
        modifier_line = $0
        next 
    } 
    /^[[:space:]]*---/ { 
        found=0 
    } 
    found {
        processed = process_line($0)
        gsub(/^[[:space:]]*/, "", processed)
        gsub(/[[:space:]]*$/, "", processed)
        if (processed != "") {
            printf "%s\n", processed
        }
    }' "$test_file"
}

# Extract section header (the --- SECTION_NAME ... --- line itself)
extract_section_header() {
    local test_file="$1"
    local section="$2"
    
    grep -n "^[[:space:]]*---[[:space:]]*${section}" "$test_file" | head -1 | cut -d: -f2-
}

# JSON validation is handled by validation.sh module

# Sanitize string for safe usage
sanitize_string() {
    local input="$1"
    # Remove control characters and normalize whitespace
    echo "$input" | tr -d '\000-\037' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Check if command exists
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || return 1
    fi
    return 0
}

# Get file extension
get_file_extension() {
    local file="$1"
    echo "${file##*.}"
}

# Trim leading and trailing whitespace
trim_whitespace() {
    local str="$1"
    echo "$str" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Expand tilde in path to home directory
expand_tilde() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

# Unused error functions removed

# Unused utility functions removed
