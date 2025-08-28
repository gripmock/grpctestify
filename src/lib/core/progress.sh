#!/bin/bash

# progress.sh - Progress tracking utilities
# Simple progress tracking for test execution

# Progress tracking variables
PROGRESS_COUNT=0
PROGRESS_CURRENT_LINE_LENGTH=0
# Use PROGRESS_LINE_LENGTH from config.sh as max line length
PROGRESS_SUCCESS_COUNT=0
PROGRESS_FAILURE_COUNT=0
START_TIME="$(date +%s.%N)"

# Performance metrics
declare -a TEST_TIMES=()
TOTAL_RESPONSE_TIME=0
MAX_RESPONSE_TIME=0
MIN_RESPONSE_TIME=999999

# Record test performance
record_test_performance() {
    local test_time="$1"
    TEST_TIMES+=("$test_time")
    TOTAL_RESPONSE_TIME=$((TOTAL_RESPONSE_TIME + test_time))
    
    if (( test_time > MAX_RESPONSE_TIME )); then
        MAX_RESPONSE_TIME=$test_time
    fi
    
    if (( test_time < MIN_RESPONSE_TIME )); then
        MIN_RESPONSE_TIME=$test_time
    fi
}

print_progress() {
    local char="$1"
    local progress_mode="${2:-none}"
    
    if [[ "$progress_mode" == "dots" ]]; then
        printf "%s" "$char" >&2
        PROGRESS_COUNT=$((PROGRESS_COUNT + 1))
        PROGRESS_CURRENT_LINE_LENGTH=$((PROGRESS_CURRENT_LINE_LENGTH + 1))
        
        # Track success/failure counts
        if [[ "$char" == "." ]]; then
            PROGRESS_SUCCESS_COUNT=$((PROGRESS_SUCCESS_COUNT + 1))
        elif [[ "$char" == "F" ]]; then
            PROGRESS_FAILURE_COUNT=$((PROGRESS_FAILURE_COUNT + 1))
            printf "\n" >&2
            PROGRESS_CURRENT_LINE_LENGTH=0
        fi
        
        # Wrap at ~80 chars (but not for failures, they get their own line)
        if [[ $PROGRESS_CURRENT_LINE_LENGTH -ge $PROGRESS_LINE_LENGTH && "$char" != "F" ]]; then
            printf "\n" >&2
            PROGRESS_CURRENT_LINE_LENGTH=0
        fi
    fi
}

print_progress_summary() {
    local progress_mode="${1:-none}"
    
    if [[ "$progress_mode" == "dots" ]]; then
        printf "\n" >&2
        
        # Calculate elapsed time
        local end_time=$(date +%s.%N)
        local elapsed_time=$(echo "$end_time - $START_TIME" | bc -l 2>/dev/null || echo "0.00")
        
        # Print summary like Jest/pytest
        printf "Test Suites: " >&2
        if [[ $PROGRESS_FAILURE_COUNT -eq 0 ]]; then
            printf "${GREEN}1 passed${NC}" >&2
        else
            printf "${RED}1 failed${NC}" >&2
        fi
        printf ", 1 total\n" >&2
        
        printf "Tests:       " >&2
        if [[ $PROGRESS_FAILURE_COUNT -eq 0 ]]; then
            printf "${GREEN}%d passed${NC}" "$PROGRESS_SUCCESS_COUNT" >&2
        else
            printf "${RED}%d failed${NC}, ${GREEN}%d passed${NC}" "$PROGRESS_FAILURE_COUNT" "$PROGRESS_SUCCESS_COUNT" >&2
        fi
        printf ", %d total\n" "$PROGRESS_COUNT" >&2
        
        printf "Time:        %.2fs\n" "$elapsed_time" >&2
        
        # Show performance metrics if available
        if [[ $PROGRESS_COUNT -gt 0 && ${#TEST_TIMES[@]} -gt 0 ]]; then
            local avg_response_time=$((TOTAL_RESPONSE_TIME / PROGRESS_COUNT))
            printf "Performance: Avg: %dms, Min: %dms, Max: %dms\n" \
                "$avg_response_time" "$MIN_RESPONSE_TIME" "$MAX_RESPONSE_TIME" >&2
        fi
        
        # Add final status
        if [[ $PROGRESS_FAILURE_COUNT -eq 0 ]]; then
            printf "${GREEN}✓ All tests passed${NC}\n" >&2
        else
            printf "${RED}✗ %d test(s) failed${NC}\n" "$PROGRESS_FAILURE_COUNT" >&2
        fi
    fi
}
