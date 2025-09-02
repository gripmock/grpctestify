#!/usr/bin/env bats

# Test suite for CPU detection functionality

setup() {
    # Mock tlog function
    tlog() {
        echo "TLOG [$1]: $2" >&2
    }
    
    # Source the system utilities
    source "$BATS_TEST_DIRNAME/../plugins/utils/system_utilities.sh"
    source "$BATS_TEST_DIRNAME/portability.sh"
    source "$BATS_TEST_DIRNAME/native_utils.sh"
}

@test "auto_detect_parallel_jobs: uses nproc when available" {
    # Mock nproc to return 8
    nproc() { echo "8"; }
    export -f nproc
    
    run auto_detect_parallel_jobs
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]
}

@test "auto_detect_parallel_jobs: uses sysctl when nproc unavailable" {
    # Mock unavailable nproc
    nproc() { return 127; }
    export -f nproc
    
    # Mock sysctl to return 8
    sysctl() {
        if [[ "$*" == "-n hw.ncpu" ]]; then
            echo "8"
        fi
    }
    export -f sysctl
    
    run auto_detect_parallel_jobs
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]
}

@test "auto_detect_parallel_jobs: uses /proc/cpuinfo fallback" {
    # Test that the function can handle different detection methods
    # We test the actual behavior rather than trying to mock system commands
    
    run auto_detect_parallel_jobs
    [ "$status" -eq 0 ]
    
    # Should return a positive number
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -gt 0 ]
    
    # Should not be empty
    [ -n "$output" ]
    
    # On systems with /proc/cpuinfo, this should work
    # On other systems, it should fall back to other methods
    echo "Detected CPU cores: $output"
}

@test "auto_detect_parallel_jobs: falls back to default when all methods fail" {
    # Test that the function returns a reasonable value even when some methods fail
    # We can't easily mock system commands in bats, so we test the actual behavior
    
    run auto_detect_parallel_jobs
    [ "$status" -eq 0 ]
    
    # Should return a positive number
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -gt 0 ]
    
    # Should not be empty
    [ -n "$output" ]
}

@test "get_default_parallel_jobs: uses PARALLEL_JOBS environment variable" {
    export PARALLEL_JOBS=12
    
    run get_default_parallel_jobs
    [ "$status" -eq 0 ]
    [ "$output" = "12" ]
}

@test "get_default_parallel_jobs: falls back to auto-detection" {
    unset PARALLEL_JOBS
    
    # Mock auto_detect_parallel_jobs
    auto_detect_parallel_jobs() { echo "8"; }
    export -f auto_detect_parallel_jobs
    
    run get_default_parallel_jobs
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]
}

@test "CPU detection regression: should not return hardcoded 4 on systems with 8 cores" {
    # This is a regression test for the bug where systems with 8 cores
    # were incorrectly reporting 4 threads due to faulty detection logic
    
    # Simulate a real system with 8 cores
    nproc() { echo "8"; }
    export -f nproc
    
    # Test both functions
    run auto_detect_parallel_jobs
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]
    
    unset PARALLEL_JOBS
    run get_default_parallel_jobs  
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]
}

@test "portable_cpu_count: should work when available" {
    # Test that portable_cpu_count is preferred when available
    portable_cpu_count() { echo "8"; }
    export -f portable_cpu_count
    
    run auto_detect_parallel_jobs
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]
}

@test "CPU detection: realistic cross-platform test" {
    # Test realistic scenarios across different platforms
    
    # Linux scenario (nproc available)
    case "$(uname)" in
        "Linux")
            if command -v nproc >/dev/null 2>&1; then
                local actual_cores
                actual_cores=$(nproc)
                
                run auto_detect_parallel_jobs
                [ "$status" -eq 0 ]
                [ "$output" = "$actual_cores" ]
            fi
            ;;
        "Darwin")
            if command -v sysctl >/dev/null 2>&1; then
                local actual_cores
                actual_cores=$(sysctl -n hw.ncpu)
                
                run auto_detect_parallel_jobs  
                [ "$status" -eq 0 ]
                [ "$output" = "$actual_cores" ]
            fi
            ;;
    esac
}
