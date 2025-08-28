#!/usr/bin/env bats

# colors.bats - Tests for colors.sh module using bats-core

# Load the colors module
source "${BATS_TEST_DIRNAME}/colors.sh"

@test "setup_colors function sets color variables" {
    # Test with no_color=false (default)
    unset no_color
    setup_colors
    
    [ -n "$RED" ]
    [ -n "$GREEN" ]
    [ -n "$YELLOW" ]
    [ -n "$BLUE" ]
    [ -n "$NC" ]
    [ "$CHECK" = "✅" ]
    [ "$CROSS" = "❌" ]
    [ "$INFO" = "ℹ️" ]
    [ "$ALERT" = "⚠️" ]
}

@test "setup_colors with no_color=true disables colors" {
    no_color=true
    setup_colors
    
    [ -z "$RED" ]
    [ -z "$GREEN" ]
    [ -z "$YELLOW" ]
    [ -z "$BLUE" ]
    [ -z "$NC" ]
    [ "$CHECK" = "OK" ]
    [ "$CROSS" = "ERR" ]
    [ "$INFO" = "INF" ]
    [ "$ALERT" = "WARN" ]
}

@test "log function with different levels" {
    # Reset colors for testing
    unset no_color
    setup_colors
    
    # Test error log
    run log error "Test error message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test error message"* ]]
    [[ "$output" == *"❌"* ]]
    
    # Test success log
    run log success "Test success message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test success message"* ]]
    [[ "$output" == *"✅"* ]]
    
    # Test info log
    run log info "Test info message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test info message"* ]]
    [[ "$output" == *"ℹ️"* ]]
    
    # Test section log
    run log section "Test section message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test section message"* ]]
    [[ "$output" == *"━━"* ]]
    
    # Test warning log
    run log warn "Test warning message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test warning message"* ]]
    [[ "$output" == *"⚠️"* ]]
}

@test "log function with no_color=true" {
    no_color=true
    setup_colors
    
    # Test error log
    run log error "Test error message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test error message"* ]]
    [[ "$output" == *"ERR"* ]]
    
    # Test success log
    run log success "Test success message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test success message"* ]]
    [[ "$output" == *"OK"* ]]
}

@test "log debug with verbose=true" {
    unset no_color
    setup_colors
    verbose=true
    
    run log debug "Test debug message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test debug message"* ]]
    [[ "$output" == *"🔍"* ]]
}

@test "log debug with verbose=false" {
    unset no_color
    setup_colors
    verbose=false
    
    run log debug "Test debug message"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
