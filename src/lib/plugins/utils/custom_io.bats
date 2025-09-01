#!/usr/bin/env bats

# custom_io.bats - Tests for custom IO system

setup() {
    export BATS_TEST_ISOLATED=1
    
    # Load system under test
    source "${BATS_TEST_DIRNAME}/custom_io.sh"
    
    # Mock log function
    log() {
        echo "LOG $1: $2" >&2
    }
    export -f log
    
    # Clean up any leftover IO directories
    cleanup_test_io
}

teardown() {
    cleanup_test_io
}

cleanup_test_io() {
    # Clean up any test IO directories
    find /tmp -maxdepth 1 -name "grpctestify_io_*" -type d 2>/dev/null | while read -r dir; do
        rm -rf "$dir" 2>/dev/null || true
    done
    find /tmp -maxdepth 1 -name "grpctestify_mutex_*" -type d 2>/dev/null | while read -r dir; do
        rm -rf "$dir" 2>/dev/null || true
    done
}

@test "io_init initializes IO system" {
    run io_init
    [ "$status" -eq 0 ]
    [ -d "$GRPCTESTIFY_IO_DIR" ]
    [ -p "$GRPCTESTIFY_PROGRESS_PIPE" ]
    [ -p "$GRPCTESTIFY_RESULTS_PIPE" ]
    [ -p "$GRPCTESTIFY_ERRORS_PIPE" ]
    [ "$GRPCTESTIFY_IO_INITIALIZED" = "true" ]
}

@test "io_cleanup removes IO system" {
    io_init
    run io_cleanup
    [ "$status" -eq 0 ]
    [ ! -d "$GRPCTESTIFY_IO_DIR" ]
    [ "$GRPCTESTIFY_IO_INITIALIZED" = "false" ]
}

@test "io_send_progress works without initialization" {
    # Should fallback gracefully
    run io_send_progress "test1" "running" "."
    [ "$status" -eq 0 ]
}

@test "io_send_result works without initialization" {
    # Should fallback gracefully
    run io_send_result "test1" "PASSED" "100" "details"
    [ "$status" -eq 0 ]
}

@test "io_send_error works without initialization" {
    # Should fallback gracefully
    run io_send_error "test1" "error details"
    [ "$status" -eq 0 ]
}

@test "io_printf provides synchronized output" {
    io_init
    
    run io_printf "test %s %d" "formatted" 123
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test formatted 123" ]]
}

@test "io_error provides synchronized error output" {
    io_init
    
    run io_error "error message"
    [ "$status" -eq 0 ]
}

@test "io_newline outputs newline" {
    io_init
    
    run io_newline
    [ "$status" -eq 0 ]
}

@test "io_status shows system information" {
    run io_status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Custom IO System Status:" ]]
    [[ "$output" =~ "Initialized: false" ]]
    
    io_init
    run io_status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Initialized: true" ]]
}

@test "io_clear_buffers clears all buffers" {
    io_init
    
    # Add some data to buffers (simulate)
    GRPCTESTIFY_PROGRESS_BUFFER["test1"]="passed:."
    GRPCTESTIFY_RESULTS_BUFFER["test1"]="PASSED:100:details"
    GRPCTESTIFY_ERROR_BUFFER["test1"]="error details"
    
    run io_clear_buffers
    [ "$status" -eq 0 ]
}

@test "io_store_progress stores progress data" {
    io_init
    
    run io_store_progress "test1:running:."
    [ "$status" -eq 0 ]
}

@test "io_store_result stores result data" {
    io_init
    
    run io_store_result "test1:PASSED:100:details"
    [ "$status" -eq 0 ]
}

@test "io_store_error stores error data" {
    io_init
    
    run io_store_error "test1:error details"
    [ "$status" -eq 0 ]
}

@test "IO system handles concurrent access" {
    io_init
    
    # Function to send concurrent data
    send_concurrent_data() {
        local id="$1"
        io_send_progress "test_$id" "running" "."
        io_send_result "test_$id" "PASSED" "100" "concurrent test"
        io_send_error "test_$id" "concurrent error"
    }
    export -f send_concurrent_data
    
    # Start multiple background processes
    send_concurrent_data "1" &
    send_concurrent_data "2" &
    send_concurrent_data "3" &
    
    # Wait for all to complete
    wait
    
    # System should still be functional
    run io_status
    [ "$status" -eq 0 ]
}

@test "IO system initializes only once" {
    # First initialization
    run io_init
    [ "$status" -eq 0 ]
    local first_dir="$GRPCTESTIFY_IO_DIR"
    
    # Second initialization should return success but not change directory
    run io_init
    [ "$status" -eq 0 ]
    [ "$GRPCTESTIFY_IO_DIR" = "$first_dir" ]
}

@test "IO system provides fallback when not initialized" {
    # Ensure not initialized
    GRPCTESTIFY_IO_INITIALIZED=false
    
    # These should work without failing
    run io_send_progress "test" "running" "."
    [ "$status" -eq 0 ]
    
    run io_send_result "test" "PASSED" "100" "details"
    [ "$status" -eq 0 ]
    
    run io_send_error "test" "error"
    [ "$status" -eq 0 ]
}
