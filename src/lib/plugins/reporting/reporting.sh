#!/usr/bin/env bash

# Reporting plugin: JUnit and JSON generators
# These functions were migrated from run.sh to reduce duplication and centralize reporting.

# Generate JUnit XML report
reporting_generate_junit_report() {
    local output_file="$1"
    local total="$2"
    local passed="$3"
    local failed="$4"
    local skipped="$5"
    local duration_ms="$6"
    local start_time="$7"
    # New parameters for test details
    local passed_tests_ref="$8"
    local failed_tests_ref="$9"
    local skipped_tests_ref="${10}"

    local duration_seconds=$(echo "scale=3; $duration_ms / 1000" | bc 2>/dev/null || echo "0")
    local timestamp=$(date -Iseconds 2>/dev/null || date)

    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" || return 1

    # Generate JUnit XML
    cat > "$output_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="grpctestify" tests="$total" failures="$failed" skipped="$skipped" time="$duration_seconds">
  <properties>
    <property name="grpctestify.version" value="v1.0.0"/>
    <property name="grpctestify.timestamp" value="$timestamp"/>
    <property name="system.hostname" value="$(hostname 2>/dev/null || echo 'unknown')"/>
    <property name="system.username" value="$(whoami 2>/dev/null || echo 'unknown')"/>
    <property name="system.os" value="${OSTYPE:-unknown}"/>
  </properties>
  <testsuite name="grpctestify" tests="$total" failures="$failed" skipped="$skipped" time="$duration_seconds" timestamp="$timestamp">
EOF

    # Add passed test cases with actual test information
    if [[ -n "$passed_tests_ref" ]]; then
        eval "local passed_tests=(\"\${${passed_tests_ref}[@]}\")"
        for test_info in "${passed_tests[@]}"; do
            IFS='|' read -r test_file test_duration <<< "$test_info"
            local classname=$(dirname "$test_file")
            local name=$(basename "$test_file" .gctf)
            local time_seconds=$(echo "scale=3; $test_duration / 1000" | bc 2>/dev/null || echo "0.001")
            cat >> "$output_file" << EOF
    <testcase classname="$classname" name="$name" time="$time_seconds"/>
EOF
        done
    fi

    # Add failed test cases with actual test information
    if [[ -n "$failed_tests_ref" ]]; then
        eval "local failed_tests=(\"\${${failed_tests_ref}[@]}\")"
        for test_info in "${failed_tests[@]}"; do
            IFS='|' read -r test_file test_duration error_msg <<< "$test_info"
            local classname=$(dirname "$test_file")
            local name=$(basename "$test_file" .gctf)
            local time_seconds=$(echo "scale=3; $test_duration / 1000" | bc 2>/dev/null || echo "0.001")
            cat >> "$output_file" << EOF
    <testcase classname="$classname" name="$name" time="$time_seconds">
      <failure message="Test failed" type="failure">$error_msg</failure>
    </testcase>
EOF
        done
    fi

    # Add skipped test cases with actual test information
    if [[ -n "$skipped_tests_ref" ]]; then
        eval "local skipped_tests=(\"\${${skipped_tests_ref}[@]}\")"
        for test_info in "${skipped_tests[@]}"; do
            IFS='|' read -r test_file test_duration <<< "$test_info"
            local classname=$(dirname "$test_file")
            local name=$(basename "$test_file" .gctf)
            local time_seconds=$(echo "scale=3; $test_duration / 1000" | bc 2>/dev/null || echo "0.001")
            cat >> "$output_file" << EOF
    <testcase classname="$classname" name="$name" time="$time_seconds">
      <skipped message="Test skipped"/>
    </testcase>
EOF
        done
    fi

    cat >> "$output_file" << EOF
  </testsuite>
</testsuites>
EOF

    return 0
}

# Generate JSON report
reporting_generate_json_report() {
    local output_file="$1"
    local total="$2"
    local passed="$3"
    local failed="$4"
    local skipped="$5"
    local duration_ms="$6"
    local start_time="$7"
    # New parameters for test details
    local passed_tests_ref="$8"
    local failed_tests_ref="$9"
    local skipped_tests_ref="${10}"

    local timestamp=$(date -Iseconds 2>/dev/null || date)

    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" || return 1

    # Start JSON report
    cat > "$output_file" << EOF
{
  "grpctestify": {
    "version": "v1.0.0",
    "timestamp": "$timestamp",
    "duration_ms": $duration_ms,
    "summary": {
      "total": $total,
      "passed": $passed,
      "failed": $failed,
      "skipped": $skipped,
      "success_rate": $(echo "scale=2; $passed * 100 / $total" | bc 2>/dev/null || echo "0")
    },
    "environment": {
      "hostname": "$(hostname 2>/dev/null || echo 'unknown')",
      "username": "$(whoami 2>/dev/null || echo 'unknown')",
      "os": "${OSTYPE:-unknown}",
      "shell": "${SHELL:-unknown}"
    },
    "tests": {
EOF

    # Add passed tests
    if [[ -n "$passed_tests_ref" ]]; then
        eval "local passed_tests=(\"\${${passed_tests_ref}[@]}\")"
        if [[ ${#passed_tests[@]} -gt 0 ]]; then
            cat >> "$output_file" << EOF
      "passed": [
EOF
            local first=true
            for test_info in "${passed_tests[@]}"; do
                IFS='|' read -r test_file test_duration <<< "$test_info"
                local classname=$(dirname "$test_file")
                local name=$(basename "$test_file" .gctf)
                local time_seconds=$(echo "scale=3; $test_duration / 1000" | bc 2>/dev/null || echo "0.001")

                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo "," >> "$output_file"
                fi

                cat >> "$output_file" << EOF
        {
          "file": "$test_file",
          "classname": "$classname",
          "name": "$name",
          "duration_ms": $test_duration,
          "duration_s": $time_seconds,
          "status": "passed"
        }
EOF
            done
            echo -e "\n      ]," >> "$output_file"
        fi
    fi

    # Add failed tests
    if [[ -n "$failed_tests_ref" ]]; then
        eval "local failed_tests=(\"\${${failed_tests_ref}[@]}\")"
        if [[ ${#failed_tests[@]} -gt 0 ]]; then
            cat >> "$output_file" << EOF
      "failed": [
EOF
            local first=true
            for test_info in "${failed_tests[@]}"; do
                IFS='|' read -r test_file test_duration error_msg <<< "$test_info"
                local classname=$(dirname "$test_file")
                local name=$(basename "$test_file" .gctf)
                local time_seconds=$(echo "scale=3; $test_duration / 1000" | bc 2>/dev/null || echo "0.001")

                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo "," >> "$output_file"
                fi

                cat >> "$output_file" << EOF
        {
          "file": "$test_file",
          "classname": "$classname",
          "name": "$name",
          "duration_ms": $test_duration,
          "duration_s": $time_seconds,
          "status": "failed",
          "error": $(jq -Rs . <<< "$error_msg" 2>/dev/null || echo "$error_msg")
        }
EOF
            done
            echo -e "\n      ]," >> "$output_file"
        fi
    fi

    # Add skipped tests
    if [[ -n "$skipped_tests_ref" ]]; then
        eval "local skipped_tests=(\"\${${skipped_tests_ref}[@]}\")"
        if [[ ${#skipped_tests[@]} -gt 0 ]]; then
            cat >> "$output_file" << EOF
      "skipped": [
EOF
            local first=true
            for test_info in "${skipped_tests[@]}"; do
                IFS='|' read -r test_file test_duration <<< "$test_info"
                local classname=$(dirname "$test_file")
                local name=$(basename "$test_file" .gctf)
                local time_seconds=$(echo "scale=3; $test_duration / 1000" | bc 2>/dev/null || echo "0.001")

                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo "," >> "$output_file"
                fi

                cat >> "$output_file" << EOF
        {
          "file": "$test_file",
          "classname": "$classname",
          "name": "$name",
          "duration_ms": $test_duration,
          "duration_s": $time_seconds,
          "status": "skipped"
        }
EOF
            done
            echo -e "\n      ]" >> "$output_file"
        fi
    fi

    # Close JSON
    cat >> "$output_file" << EOF
    }
  }
}
EOF

    return 0
}
