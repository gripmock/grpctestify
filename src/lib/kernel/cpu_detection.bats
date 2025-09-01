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
    # Mock unavailable commands
    nproc() { return 127; }
    sysctl() { return 127; }
    export -f nproc sysctl
    
    # Create mock /proc/cpuinfo
    local mock_cpuinfo="$BATS_TMPDIR/cpuinfo"
    cat > "$mock_cpuinfo" << 'EOF'
processor	: 0
processor	: 1
processor	: 2
processor	: 3
processor	: 4
processor	: 5
processor	: 6
processor	: 7
EOF
    
    # Mock test for file existence
    test() {
        if [[ "$1" == "-f" && "$2" == "/proc/cpuinfo" ]]; then
            return 0
        fi
        command test "$@"
    }
    export -f test
    
    # Mock grep to use our mock file
    grep() {
        if [[ "$1" == "-c" && "$2" == "^processor" && "$3" == "/proc/cpuinfo" ]]; then
            command grep -c "^processor" "$mock_cpuinfo"
        else
            command grep "$@"
        fi
    }
    export -f grep
    
    run auto_detect_parallel_jobs
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]
}

@test "auto_detect_parallel_jobs: falls back to default when all methods fail" {
    # Mock all commands to fail
    nproc() { return 127; }
    sysctl() { return 127; }
    native_cpu_count() { return 127; }
    portable_cpu_count() { return 127; }
    export -f nproc sysctl native_cpu_count portable_cpu_count
    
    # Mock test to fail for /proc/cpuinfo
    test() {
        if [[ "$1" == "-f" && "$2" == "/proc/cpuinfo" ]]; then
            return 1
        fi
        command test "$@"
    }
    export -f test
    
    run auto_detect_parallel_jobs
    [ "$status" -eq 0 ]
    [ "$output" = "4" ]
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
