#!/bin/bash

# fast_parser.sh - Optimized section extraction
# Replaces complex AWK parser with simpler, faster bash implementation

# Configuration is loaded automatically by bashly

# Fast section extraction using pure bash
extract_section_fast() {
    local test_file="$1"
    local section="$2"
    
    # Quick validation
    if [[ ! -f "$test_file" || ! -r "$test_file" ]]; then
        return 1
    fi
    
    local in_section=false
    local section_pattern="^[[:space:]]*---[[:space:]]*${section}([[:space:]]+.*)?[[:space:]]*---"
    local end_pattern="^[[:space:]]*---"
    
    while IFS= read -r line; do
        # Skip empty lines and comments at start
        if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            [[ "$in_section" == "true" ]] || continue
        fi
        
        # Check for section start
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=true
            continue
        fi
        
        # Check for section end
        if [[ "$in_section" == "true" && "$line" =~ $end_pattern ]]; then
            break
        fi
        
        # Output section content
        if [[ "$in_section" == "true" ]]; then
            # Remove inline comments (but preserve quoted strings)
            local processed_line="$line"
            
            # Simple comment removal (not quote-aware for performance)
            if [[ "$processed_line" =~ ^([^#]*)(#.*)?$ ]]; then
                processed_line="${BASH_REMATCH[1]}"
            fi
            
            # Trim whitespace
            processed_line="${processed_line#"${processed_line%%[![:space:]]*}"}"
            processed_line="${processed_line%"${processed_line##*[![:space:]]}"}"
            
            # Output non-empty lines
            [[ -n "$processed_line" ]] && echo "$processed_line"
        fi
    done < "$test_file"
}

# Quote-aware comment removal (for when precision is needed)
extract_section_precise() {
    local test_file="$1"
    local section="$2"
    
    # Fall back to AWK for complex cases requiring quote awareness
    awk -v sec="$section" '
    function strip_comments(line) {
        in_quote = 0
        escaped = 0
        result = ""
        
        for (i = 1; i <= length(line); i++) {
            char = substr(line, i, 1)
            
            if (escaped) {
                result = result char
                escaped = 0
            } else if (char == "\\") {
                result = result char
                escaped = 1
            } else if (char == "\"") {
                result = result char
                in_quote = !in_quote
            } else if (char == "#" && !in_quote) {
                break
            } else {
                result = result char
            }
        }
        
        # Trim whitespace
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", result)
        return result
    }
    
    /^[[:space:]]*#/ { next }
    $0 ~ "^[[:space:]]*---[[:space:]]*" sec "([[:space:]]+.*)?[[:space:]]*---" { 
        found = 1
        next 
    }
    /^[[:space:]]*---/ { found = 0 }
    found {
        processed = strip_comments($0)
        if (processed != "") print processed
    }' "$test_file"
}

# Smart section extraction (chooses appropriate method)
extract_section_smart() {
    local test_file="$1"
    local section="$2"
    local precision="${3:-auto}"
    
    case "$precision" in
        "fast")
            extract_section_fast "$test_file" "$section"
            ;;
        "precise")
            extract_section_precise "$test_file" "$section"
            ;;
        "auto"|*)
            # Use fast method for most cases, precise for complex content
            local content=$(extract_section_fast "$test_file" "$section")
            
            # Check if content contains complex quoting that might need precise parsing
            if echo "$content" | grep -q '".*#.*"'; then
                extract_section_precise "$test_file" "$section"
            else
                echo "$content"
            fi
            ;;
    esac
}

# Batch section extraction (for performance)
extract_multiple_sections() {
    local test_file="$1"
    shift
    local sections=("$@")
    
    # Single file pass for multiple sections
    declare -A section_content
    declare -A section_found
    local current_section=""
    local in_section=false
    
    # Initialize arrays
    for section in "${sections[@]}"; do
        section_found["$section"]=false
        section_content["$section"]=""
    done
    
    while IFS= read -r line; do
        # Skip empty lines and comments outside sections
        if [[ ! "$in_section" && ( "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ) ]]; then
            continue
        fi
        
        # Check for any section start
        for section in "${sections[@]}"; do
            if [[ "$line" =~ ^[[:space:]]*---[[:space:]]*${section}([[:space:]]+.*)?[[:space:]]*--- ]]; then
                current_section="$section"
                in_section=true
                section_found["$section"]=true
                break
            fi
        done
        
        # Check for section end
        if [[ "$in_section" && "$line" =~ ^[[:space:]]*--- ]]; then
            in_section=false
            current_section=""
            continue
        fi
        
        # Collect section content
        if [[ "$in_section" && -n "$current_section" ]]; then
            # Simple processing
            local processed_line="$line"
            if [[ "$processed_line" =~ ^([^#]*)(#.*)?$ ]]; then
                processed_line="${BASH_REMATCH[1]}"
            fi
            processed_line="${processed_line#"${processed_line%%[![:space:]]*}"}"
            processed_line="${processed_line%"${processed_line##*[![:space:]]}"}"
            
            if [[ -n "$processed_line" ]]; then
                if [[ -n "${section_content[$current_section]}" ]]; then
                    section_content["$current_section"]+=$'\n'"$processed_line"
                else
                    section_content["$current_section"]="$processed_line"
                fi
            fi
        fi
    done < "$test_file"
    
    # Output results as JSON for easy parsing
    local json_output="{"
    local first=true
    
    for section in "${sections[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            json_output+=","
        fi
        
        local content="${section_content[$section]}"
        # Escape JSON special characters
        content=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g; s/'"'"'/\\'"'"'/g')
        json_output+="\"$section\":\"$content\""
    done
    
    json_output+="}"
    echo "$json_output"
}

# Performance test for different extraction methods
benchmark_extraction() {
    local test_file="$1"
    local section="${2:-ENDPOINT}"
    local iterations="${3:-100}"
    
    if [[ ! -f "$test_file" ]]; then
        echo "Test file not found: $test_file"
        return 1
    fi
    
    echo "Benchmarking extraction methods on $test_file (${iterations} iterations):"
    
    # Benchmark fast method
    local start_time=$(date +%s.%N 2>/dev/null || date +%s)
    for ((i=1; i<=iterations; i++)); do
        extract_section_fast "$test_file" "$section" >/dev/null
    done
    local end_time=$(date +%s.%N 2>/dev/null || date +%s)
    local fast_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "N/A")
    
    # Benchmark precise method  
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    for ((i=1; i<=iterations; i++)); do
        extract_section_precise "$test_file" "$section" >/dev/null
    done
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    local precise_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "N/A")
    
    echo "Fast method:    ${fast_time}s"
    echo "Precise method: ${precise_time}s"
    
    if command -v bc >/dev/null 2>&1; then
        local speedup=$(echo "scale=2; $precise_time / $fast_time" | bc -l 2>/dev/null || echo "N/A")
        echo "Speedup:        ${speedup}x"
    fi
}

# Export functions
export -f extract_section_fast
export -f extract_section_precise  
export -f extract_section_smart
export -f extract_multiple_sections
export -f benchmark_extraction
