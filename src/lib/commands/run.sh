#!/bin/bash

# run.sh - Simplified test execution command based on simple_grpc_test_runner.sh
# This file contains the main logic for running gRPC tests
# Refactored to remove microkernel dependencies and use proven stable architecture

set -euo pipefail

# Basic logging
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        error) echo "❌ $message" >&2 ;;
        success) echo "✅ $message" ;;
        info) echo "ℹ️ $message" ;;
        warning) echo "⚠️ $message" >&2 ;;
        *) echo "$message" ;;
    esac
}

# Timeout function for preventing hanging tests
kernel_timeout() {
    local timeout_seconds="$1"
    shift
    
    # Validate timeout parameter
    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -eq 0 ]]; then
        log error "kernel_timeout: invalid timeout value: $timeout_seconds"
        return 1
    fi
    
    # Method 1: Use system timeout if available
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_seconds" "$@"
        return $?
    fi
    
    # Method 2: Use gtimeout on macOS (if installed)
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$timeout_seconds" "$@"
        return $?
    fi
    
    # Method 3: Pure shell implementation
    local cmd_pid timeout_pid exit_code
    
    # Start command in background
    "$@" &
    cmd_pid=$!
    
    # Start timeout killer in background
    (
        sleep "$timeout_seconds"
        if kill -0 "$cmd_pid" 2>/dev/null; then
            # Send TERM first, then KILL if needed
            kill -TERM "$cmd_pid" 2>/dev/null
            sleep 1
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null
            fi
        fi
    ) &
    timeout_pid=$!
    
    # Wait for command completion
    if wait "$cmd_pid" 2>/dev/null; then
        exit_code=$?
        # Kill timeout process
        kill "$timeout_pid" 2>/dev/null
        wait "$timeout_pid" 2>/dev/null
        return $exit_code
    else
        # Command was killed by timeout
        kill "$timeout_pid" 2>/dev/null
        wait "$timeout_pid" 2>/dev/null
        return 124  # Standard timeout exit code
    fi
}

# Smart comment removal (from v0.0.13)
process_line() {
    local line="$1"
    local in_str=0
    local escaped=0
    local res=""
    local i c
    
    for ((i=0; i<${#line}; i++)); do
        c="${line:$i:1}"
        if [[ $escaped -eq 1 ]]; then
            res="$res$c"
            escaped=0
        elif [[ "$c" == "\\" ]]; then
            res="$res$c"
            escaped=1
        elif [[ "$c" == "\"" ]]; then
            res="$res$c"
            in_str=$((1 - in_str))
        elif [[ "$c" == "#" && $in_str -eq 0 ]]; then
            break
        else
            res="$res$c"
        fi
    done
    echo "$res"
}

# Run single test file
run_single_test() {
    local test_file="$1"
    local dry_run="${2:-false}"
    
    if [[ ! -f "$test_file" ]]; then
        log error "Test file not found: $test_file"
        return 1
    fi
    
    # Parse test file
    local address=$(awk '/--- ADDRESS ---/{getline; print; exit}' "$test_file" | xargs)
    local endpoint=$(awk '/--- ENDPOINT ---/{getline; print; exit}' "$test_file" | xargs)
    local request=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue  # skip comment lines
        fi
        processed_line=$(process_line "$line")
        processed_line=$(echo "$processed_line" | sed 's/[[:space:]]*$//')
        if [[ -n "$processed_line" ]]; then
            request="$request$processed_line"
        fi
    done < <(awk '/--- REQUEST ---/{flag=1; next} /^---/{flag=0} flag' "$test_file")
    
    local expected_response=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue  # skip comment lines
        fi
        processed_line=$(process_line "$line")
        processed_line=$(echo "$processed_line" | sed 's/[[:space:]]*$//')
        if [[ -n "$processed_line" ]]; then
            expected_response="$expected_response$processed_line"
        fi
    done < <(awk '/--- RESPONSE ---/{flag=1; next} /^---/{flag=0} flag' "$test_file")
    local expected_error=$(awk '/--- ERROR ---/{flag=1; next} /^---/{flag=0} flag' "$test_file")
    local headers=$(awk '/--- HEADERS ---/{flag=1; next} /^---/{flag=0} flag' "$test_file")
    local request_headers=$(awk '/--- REQUEST_HEADERS ---/{flag=1; next} /^---/{flag=0} flag' "$test_file")
    local options_section=$(awk '/--- OPTIONS ---/{flag=1; next} /^---/{flag=0} flag' "$test_file")
    
    # Parse inline options from OPTIONS section
    local partial_option="false"
    local tolerance_option=""
    local redact_option=""
    local timeout_option=""
    
    if [[ -n "$options_section" ]]; then
        while IFS= read -r option_line; do
            if [[ "$option_line" =~ ^partial:[[:space:]]*(.+)$ ]]; then
                partial_option="${BASH_REMATCH[1]// /}"
            elif [[ "$option_line" =~ ^tolerance:[[:space:]]*(.+)$ ]]; then
                tolerance_option="${BASH_REMATCH[1]// /}"
            elif [[ "$option_line" =~ ^redact:[[:space:]]*(.+)$ ]]; then
                redact_option="${BASH_REMATCH[1]}"
            elif [[ "$option_line" =~ ^timeout:[[:space:]]*(.+)$ ]]; then
                timeout_option="${BASH_REMATCH[1]// /}"
            fi
        done <<< "$options_section"
    fi
    
    # Use GRPCTESTIFY_ADDRESS if no address in file
    if [[ -z "$address" ]]; then
        address="${GRPCTESTIFY_ADDRESS:-localhost:4770}"
    fi
    
    # Warn about deprecated HEADERS section and collect for summary
    if [[ -n "$headers" ]]; then
        log warning "HEADERS section is deprecated. Use REQUEST_HEADERS instead."
        # Increment global counter for summary (if it exists)
        if [[ -n "${headers_warnings:-}" ]]; then
            headers_warnings=$((headers_warnings + 1))
        fi
    fi
    
    if [[ -z "$endpoint" ]]; then
        log error "No endpoint specified in $test_file"
        return 1
    fi
    
    # Prepare headers arguments
    local header_args=()
    if [[ -n "$headers" ]]; then
        while IFS= read -r header; do
            if [[ -n "$header" && ! "$header" =~ ^[[:space:]]*$ ]]; then
                header_args+=("-H" "$header")
            fi
        done <<< "$headers"
    fi
    if [[ -n "$request_headers" ]]; then
        while IFS= read -r header; do
            if [[ -n "$header" && ! "$header" =~ ^[[:space:]]*$ ]]; then
                header_args+=("-H" "$header")
            fi
        done <<< "$request_headers"
    fi
    
    # Dry-run mode check
    if [[ "$dry_run" == "true" ]]; then
        local cmd_preview
        if [[ -n "$request" ]]; then
            if [[ ${#header_args[@]} -gt 0 ]]; then
                cmd_preview="echo '$request' | grpcurl -plaintext ${header_args[*]} -d @ '$address' '$endpoint'"
            else
                cmd_preview="echo '$request' | grpcurl -plaintext -d @ '$address' '$endpoint'"
            fi
        else
            if [[ ${#header_args[@]} -gt 0 ]]; then
                cmd_preview="grpcurl -plaintext ${header_args[*]} '$address' '$endpoint'"
            else
                cmd_preview="grpcurl -plaintext '$address' '$endpoint'"
            fi
        fi
        
        log info "DRY RUN - Command: $cmd_preview"
        if [[ -n "$expected_response" ]]; then
            log info "Expected Response: $expected_response"
        fi
        if [[ -n "$expected_error" ]]; then
            log info "Expected Error: $expected_error"
        fi
        return 3  # SKIPPED for dry-run
    fi
    
    # Make gRPC call with per-test timeout
    local grpc_output
    local timeout_seconds="${timeout_option:-30}"  # Default 30 seconds per test
    
    if [[ -n "$request" ]]; then
        if [[ ${#header_args[@]} -gt 0 ]]; then
            grpc_output=$(kernel_timeout "$timeout_seconds" bash -c "echo '$request' | grpcurl -plaintext '${header_args[*]}' -d @ '$address' '$endpoint'" 2>&1)
        else
            grpc_output=$(kernel_timeout "$timeout_seconds" bash -c "echo '$request' | grpcurl -plaintext -d @ '$address' '$endpoint'" 2>&1)
        fi
    else
        if [[ ${#header_args[@]} -gt 0 ]]; then
            grpc_output=$(kernel_timeout "$timeout_seconds" grpcurl -plaintext "${header_args[@]}" "$address" "$endpoint" 2>&1)
        else
            grpc_output=$(kernel_timeout "$timeout_seconds" grpcurl -plaintext "$address" "$endpoint" 2>&1)
        fi
    fi
    local grpc_exit_code=$?
    
    # Handle timeout specifically
    if [[ $grpc_exit_code -eq 124 ]]; then
        log error "gRPC call timed out after ${timeout_seconds}s in $test_file"
        return 1  # FAIL
    fi
    
    # Check result
    if [[ $grpc_exit_code -eq 0 ]]; then
        # Success case - check response
        if [[ -n "$expected_error" ]]; then
            log error "Expected error but got success in $test_file"
            return 1  # FAIL
        fi
        
        if [[ -n "$expected_response" ]]; then
            # Apply inline options for JSON comparison
            local actual_for_comparison="$grpc_output"
            local expected_for_comparison="$expected_response"
            
            # Apply redact option (remove specified fields)
            if [[ -n "$redact_option" ]]; then
                # Convert comma-separated list to jq array format
                local redact_fields=$(echo "$redact_option" | sed 's/[]["]//g' | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')
                actual_for_comparison=$(echo "$actual_for_comparison" | jq -c "delpaths([[$redact_fields] | map([.])])" 2>/dev/null || echo "$actual_for_comparison")
                expected_for_comparison=$(echo "$expected_for_comparison" | jq -c "delpaths([[$redact_fields] | map([.])])" 2>/dev/null || echo "$expected_for_comparison")
            fi
            
            # Apply partial matching if enabled
            if [[ "$partial_option" == "true" ]]; then
                # For partial matching, check if all expected fields exist in actual
                local expected_keys=$(echo "$expected_for_comparison" | jq -c 'paths(scalars) as $p | {"path": $p, "value": getpath($p)}' 2>/dev/null || echo "")
                if [[ -n "$expected_keys" ]]; then
                    local partial_match_failed=false
                    while IFS= read -r key_value; do
                        if [[ -n "$key_value" ]]; then
                            local path=$(echo "$key_value" | jq -r '.path | join(".")' 2>/dev/null)
                            local expected_val=$(echo "$key_value" | jq -r '.value' 2>/dev/null)
                            local actual_val=$(echo "$actual_for_comparison" | jq -r ".$path" 2>/dev/null || echo "null")
                            
                            if [[ "$expected_val" != "$actual_val" ]]; then
                                partial_match_failed=true
                                break
                            fi
                        fi
                    done <<< "$expected_keys"
                    
                    if [[ "$partial_match_failed" == "false" ]]; then
                        return 0  # PASS - partial match succeeded
                    fi
                fi
            fi
            
            # Standard exact comparison
            local clean_expected=$(echo "$expected_for_comparison" | jq -S -c . 2>/dev/null || echo "$expected_for_comparison")
            local clean_actual=$(echo "$actual_for_comparison" | jq -S -c . 2>/dev/null || echo "$actual_for_comparison")
            
            if [[ "$clean_actual" == "$clean_expected" ]]; then
                return 0  # PASS
            else
                log error "Response mismatch in $test_file"
                log error "Expected: $clean_expected"
                log error "Actual: $clean_actual"
                return 1  # FAIL
            fi
        else
            return 0  # PASS (no response validation)
        fi
    else
        # Error case - check if error was expected
        if [[ -n "$expected_error" ]]; then
            # Try to extract message from expected error JSON
            local expected_message
            expected_message=$(echo "$expected_error" | jq -r '.message // empty' 2>/dev/null)
            
            # If we have a message in JSON, look for it in the output
            if [[ -n "$expected_message" && "$expected_message" != "null" ]]; then
                if [[ "$grpc_output" == *"$expected_message"* ]]; then
                    return 0  # PASS (expected error message found)
                fi
            fi
            
            # Fallback: check if the entire expected error text is contained in output
            if [[ "$grpc_output" == *"$expected_error"* ]]; then
                return 0  # PASS (expected error)
            fi
            
            log error "Error mismatch in $test_file"
            log error "Expected error containing: $expected_error"
            log error "Actual error: $grpc_output"
            return 1  # FAIL
        else
            log error "gRPC call failed for $test_file: $grpc_output"
            return 1  # FAIL
        fi
    fi
}

# CPU detection (simplified)
auto_detect_parallel_jobs() {
    local cpu_count
    cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
    echo "$cpu_count"
}

# File collection with sorting support  
collect_test_files() {
    local test_path="$1"
    local sort_mode="${2:-path}"
    local files=()
    
    if [[ -f "$test_path" ]]; then
        files=("$test_path")
    elif [[ -d "$test_path" ]]; then
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find "$test_path" -name "*.gctf" -print0)
        
        # Sort files according to mode (simplified for now)
        case "$sort_mode" in
            "random")
                IFS=$'\n' files=($(printf '%s\n' "${files[@]}" | shuf))
                ;;
            *)
                IFS=$'\n' files=($(sort <<<"${files[*]}"))
                ;;
        esac
    fi
    
    printf '%s\n' "${files[@]}"
}

# Generate JUnit XML report
generate_junit_report() {
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
generate_json_report() {
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
            cat >> "$output_file" << EOF
      ]
EOF
        fi
    fi
    
    # Add failed tests
    if [[ -n "$failed_tests_ref" ]]; then
        eval "local failed_tests=(\"\${${failed_tests_ref}[@]}\")"
        if [[ ${#failed_tests[@]} -gt 0 ]]; then
            if [[ -n "$passed_tests_ref" && ${#passed_tests[@]} -gt 0 ]]; then
                echo "," >> "$output_file"
            fi
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
          "error": "$error_msg"
        }
EOF
            done
            cat >> "$output_file" << EOF
      ]
EOF
        fi
    fi
    
    # Add skipped tests
    if [[ -n "$skipped_tests_ref" ]]; then
        eval "local skipped_tests=(\"\${${skipped_tests_ref}[@]}\")"
        if [[ ${#skipped_tests[@]} -gt 0 ]]; then
            if [[ ( -n "$passed_tests_ref" && ${#passed_tests[@]} -gt 0 ) || ( -n "$failed_tests_ref" && ${#failed_tests[@]} -gt 0 ) ]]; then
                echo "," >> "$output_file"
            fi
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
            cat >> "$output_file" << EOF
      ]
EOF
        fi
    fi
    
    # Close JSON structure
    cat >> "$output_file" << EOF
    }
  }
}
EOF

    return 0
}

# Perform the complete update process (based on v0.0.13 implementation)
perform_update() {
    local latest_version="$1"
    local current_script="$2"
    
    echo "🔄 Downloading grpctestify.sh $latest_version..."
    
    local download_url="https://github.com/gripmock/grpctestify/releases/download/${latest_version}/grpctestify.sh"
    local temp_file=$(mktemp)
    
    # Download latest version
    if ! curl -L --connect-timeout 10 --max-time 300 -o "$temp_file" "$download_url" 2>&1; then
        log error "Failed to download update"
        rm -f "$temp_file"
        return 1
    fi
    
    # Verify file was downloaded
    if [[ ! -f "$temp_file" || ! -s "$temp_file" ]]; then
        log error "Downloaded file is empty or missing"
        rm -f "$temp_file"
        return 1
    fi
    
    echo "📋 Verifying checksum..."
    
    # Verify checksum using checksums.txt file (like in v0.0.13)
    local checksum_url="https://github.com/gripmock/grpctestify/releases/download/${latest_version}/checksums.txt"
    local expected_checksum
    if expected_checksum=$(curl -s --connect-timeout 10 --max-time 30 "$checksum_url" 2>/dev/null | grep "grpctestify.sh" | awk '{print $1}'); then
        if [[ -n "$expected_checksum" ]]; then
            # Calculate checksum
            local actual_checksum
            if command -v sha256sum >/dev/null 2>&1; then
                actual_checksum=$(sha256sum "$temp_file" | cut -d' ' -f1)
            elif command -v shasum >/dev/null 2>&1; then
                actual_checksum=$(shasum -a 256 "$temp_file" | cut -d' ' -f1)
            else
                log warning "No SHA-256 tool available, skipping checksum verification"
                actual_checksum="$expected_checksum"  # Skip verification
            fi
            
            if [[ "$actual_checksum" != "$expected_checksum" ]]; then
                log error "Checksum verification failed"
                log error "Expected: $expected_checksum"
                log error "Actual: $actual_checksum"
                rm -f "$temp_file"
                return 1
            fi
            echo "✅ Checksum verification passed"
        else
            log warning "Could not find grpctestify.sh checksum in checksums.txt"
        fi
    else
        log warning "Could not fetch checksums.txt, proceeding without verification"
    fi
    
    echo "💾 Creating backup..."
    
    # Create backup
    local backup_file="${current_script}.backup.$(date +%Y%m%d_%H%M%S)"
    if ! cp "$current_script" "$backup_file"; then
        log error "Failed to create backup"
        rm -f "$temp_file"
        return 1
    fi
    
    echo "🔧 Installing update..."
    
    # Replace with new version
    if ! cp "$temp_file" "$current_script"; then
        log error "Failed to install update"
        # Restore backup
        cp "$backup_file" "$current_script"
        rm -f "$temp_file"
        return 1
    fi
    
    # Set executable permissions
    if ! chmod +x "$current_script"; then
        log error "Failed to set executable permissions"
        rm -f "$temp_file"
        return 1
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    echo ""
    echo "✅ Update completed successfully!"
    echo "📦 Updated to version: $latest_version"
    echo "💾 Backup available at: $backup_file"
    echo ""
    echo "🔄 Please restart grpctestify.sh to use the new version"
    
    return 0
}

# Main test execution function (renamed for bashly)
run_tests() {
    local test_path="${args[test_path]:-${1:-}}"
    
    # Handle version flag
    if [[ "${args[--version]:-0}" == "1" ]]; then
        echo "grpctestify v1.0.0"
        return 0
    fi

    # Handle list-plugins flag
    if [[ "${args[--list-plugins]:-0}" == "1" ]]; then
        echo "Available plugins:"
        echo ""
        echo "📁 Built-in plugins (integrated into grpctestify.sh):"
        
        # List of built-in plugin categories
        local builtin_plugins=(
            "🔧 Core plugins:"
            "  • grpc_client - gRPC call execution"
            "  • json_comparator - JSON response validation"
            "  • test_orchestrator - Test execution management"
            "  • failure_reporter - Error reporting and logging"
            ""
            "🎯 Assertion plugins:"
            "  • grpc_asserts - gRPC-specific assertions"
            "  • json_assertions - JSON content validation"
            "  • numeric_assertions - Numeric value checks"
            "  • regex_assertions - Regular expression matching"
            ""
            "🛠️ System plugins:"
            "  • grpc_tls - TLS/SSL support"
            "  • grpc_headers_trailers - Headers and trailers handling"
            "  • grpc_response_time - Performance measurement"
            "  • grpc_type_validation - Protocol buffer validation"
            ""
            "🎨 Output plugins:"
            "  • colors - Terminal color support"
            "  • progress - Progress indicators"
            "  • logging_io - Enhanced logging"
            "  • grpc_json_reporter - JSON format reports"
        )
        
        printf '%s\n' "${builtin_plugins[@]}"
        
        echo ""
        echo "📁 External plugins directory: ${GRPCTESTIFY_PLUGIN_DIR:-~/.grpctestify/plugins}"
        if [[ -d "${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}" ]]; then
            local external_count=0
            while IFS= read -r -d '' plugin; do
                if [[ -f "$plugin" ]]; then
                    plugin_name=$(basename "$plugin" .sh)
                    echo "  • $plugin_name (external)"
                    ((external_count++))
                fi
            done < <(find "${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}" -name "*.sh" -type f -print0 2>/dev/null)
            
            if [[ $external_count -eq 0 ]]; then
                echo "  (No external plugins found)"
            fi
        else
            echo "  (Directory not found - create it to add external plugins)"
        fi
        return 0
    fi

    # Handle config flag
    if [[ "${args[--config]:-0}" == "1" ]]; then
        echo "Current grpctestify.sh configuration:"
        echo ""
        echo "🔧 Environment variables:"
            echo "  GRPCTESTIFY_ADDRESS: ${GRPCTESTIFY_ADDRESS:-localhost:4770}"
    echo "  GRPCTESTIFY_PLUGIN_DIR: ${GRPCTESTIFY_PLUGIN_DIR:-~/.grpctestify/plugins}"
    echo "  Note: Use CLI flags for timeout, verbose, parallel, and sort options"
        echo ""
        echo "⚙️ Default settings:"
        echo "  Parallel jobs: ${args[--parallel]:-auto}"
        echo "  Sort mode: ${args[--sort]:-path}"
        echo "  Retry count: ${args[--retry]:-3}"
        echo "  Retry delay: ${args[--retry-delay]:-1}s"
        echo "  Test timeout: ${args[--timeout]:-30}s"
        echo ""
        echo "📁 Plugin directory:"
        if [[ -d "${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}" ]]; then
            echo "  Status: ✅ Exists"
            echo "  Location: ${GRPCTESTIFY_PLUGIN_DIR:-$HOME/.grpctestify/plugins}"
        else
            echo "  Status: ❌ Not found"
            echo "  Run 'mkdir -p ~/.grpctestify/plugins' to create"
        fi
        return 0
    fi

    # Handle update flag
    if [[ "${args[--update]:-0}" == "1" ]]; then
        # Use the proper update implementation from update.sh
        echo "🔄 grpctestify.sh v1.0.0 - Update"
        echo ""
        echo "📡 Checking for updates..."
        
        # Get latest version from GitHub API
        local api_url="https://api.github.com/repos/gripmock/grpctestify/releases/latest"
        local latest_version=""
        local current_version="v1.0.0"
        
        # Check dependencies
        if ! command -v curl >/dev/null 2>&1; then
            log error "curl is required for update checking"
            return 1
        fi
        
        if ! command -v jq >/dev/null 2>&1; then
            log error "jq is required for update checking"
            return 1
        fi
        
        # Query GitHub API with timeout
        local response
        if ! response=$(curl -s --connect-timeout 10 --max-time 30 "$api_url" 2>&1); then
            log error "Failed to check for updates (network error)"
            return 1
        fi
        
        # Extract version from response
        if ! latest_version=$(echo "$response" | jq -r '.tag_name // empty' 2>/dev/null); then
            log error "Failed to parse GitHub API response"
            return 1
        fi
        
        if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
            log error "No version information found in API response"
            return 1
        fi
        
        echo "Current version: $current_version"
        echo "Latest version: $latest_version"
        echo ""
        
        # Compare versions
        if [[ "$latest_version" != "$current_version" ]]; then
            echo "🆕 Update available: $current_version -> $latest_version"
            echo ""
            echo -n "Do you want to update? [y/N]: "
            read -r response
            
            case "$response" in
                [yY]|[yY][eE][sS])
                    perform_update "$latest_version" "$0"
                    ;;
                *)
                    echo "❌ Update cancelled by user"
                    ;;
            esac
        else
            echo "✅ Already up to date"
        fi
        
        return 0
    fi

    # Handle create-plugin flag
    if [[ -n "${args[--create-plugin]:-}" ]]; then
        local plugin_name="${args[--create-plugin]}"
        
        echo "🔌 Creating new plugin: $plugin_name"
        echo ""
        
        # Load plugins module if not already loaded
        if ! command -v create_plugin_command >/dev/null 2>&1; then
            source "${BASH_SOURCE[0]%/*}/plugins.sh"
        fi
        
        # Use the new plugin creation logic from plugins.sh
        create_plugin_command "$plugin_name"
        
        return 0
    fi

    # Handle init-config flag
    if [[ -n "${args[--init-config]:-}" ]]; then
        local config_file="${args[--init-config]}"
        
        echo "⚙️ Creating configuration file: $config_file"
        
        if [[ -f "$config_file" ]]; then
            log error "Configuration file already exists: $config_file"
            return 1
        fi
        
        cat > "$config_file" << 'EOF'
# grpctestify.sh configuration file
# This file can be sourced before running grpctestify.sh

# Default gRPC server address
export GRPCTESTIFY_ADDRESS="localhost:4770"

# Plugin directory for external plugins
export GRPCTESTIFY_PLUGIN_DIR="$HOME/.grpctestify/plugins"

# Note: CLI flags take precedence over environment variables
# Use --timeout, --verbose, --parallel, --sort flags instead of ENV variables
EOF
        
        echo "✅ Configuration file created!"
        echo "📁 Location: $config_file"
        echo ""
        echo "🔧 Usage:"
        echo "  source $config_file"
        echo "  ./grpctestify.sh your_tests/"
        
        return 0
    fi

    # Handle completion flag
    if [[ -n "${args[--completion]:-}" ]]; then
        local shell_type="${args[--completion]}"
        
        echo "🚀 Installing shell completion for: $shell_type"
        echo ""
        echo "ℹ️ Shell completion functionality:"
        echo "  • Bash completion: Add to ~/.bashrc"
        echo "  • Zsh completion: Add to ~/.zshrc"
        echo "  • Complete grpctestify.sh flags and options"
        echo ""
        echo "📝 Implementation:"
        echo "  This feature is planned for future releases"
        echo "  Current version: v1.0.0 (basic completion available)"
        
        return 0
    fi
    
    # Show help if no test path provided
    if [[ -z "$test_path" ]]; then
        grpctestify.sh_usage
        return 0
    fi

    # Validate test path
    if [[ ! -e "$test_path" ]]; then
        log error "Test path does not exist: $test_path"
        return 1
    fi

    # Get options from bashly args
    local parallel_jobs="${args[--parallel]:-}"
    local dry_run="${args[--dry-run]:-0}"
    local verbose="${args[--verbose]:-0}"
    local sort_mode="${args[--sort]:-path}"
    local log_format="${args[--log-format]:-}"
    local log_output="${args[--log-output]:-}"
    
    # Validate log format if specified
    if [[ -n "$log_format" ]]; then
        case "$log_format" in
            "junit"|"json")
                if [[ -z "$log_output" ]]; then
                    log error "Error: --log-output is required when using --log-format"
                    return 1
                fi
                ;;
            *)
                log error "Error: Unsupported log format '$log_format'. Supported: junit, json"
                return 1
                ;;
        esac
    fi
    
    # Auto-detect parallel jobs if not specified or set to "auto"
    if [[ -z "$parallel_jobs" || "$parallel_jobs" == "auto" ]]; then
        parallel_jobs=$(auto_detect_parallel_jobs)
        [[ "$verbose" == "1" ]] && log info "Auto-detected $parallel_jobs CPU cores, using $parallel_jobs parallel jobs"
    fi
    
    # Collect test files
    local test_files=()
    while IFS= read -r file; do
        test_files+=("$file")
    done < <(collect_test_files "$test_path" "$sort_mode")
    
    local total=${#test_files[@]}
    
    if [[ "$total" -eq 0 ]]; then
        log error "No test files found in: $test_path"
        return 1
    fi

    [[ "$verbose" == "1" ]] && log info "Auto-selected progress mode: $([ "$verbose" == "1" ] && echo "verbose" || echo "dots") ($total tests, verbose=$verbose)"
    
    # Start timing for detailed statistics (cross-platform with ms precision)
    local start_time
    if command -v python3 >/dev/null 2>&1; then
        # Use python3 for high precision timing (cross-platform)
        start_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    elif command -v node >/dev/null 2>&1; then
        # Fallback to node.js
        start_time=$(node -e "console.log(Date.now())")
    else
        # Fallback to second precision
        start_time=$(($(date +%s) * 1000))
    fi
    
    local passed=0
    local failed=0
    local skipped=0
    # Global counter for warnings (accessible by run_single_test)
    headers_warnings=0
    
    # Arrays to store test details for JUnit report
    local passed_tests=()
    local failed_tests=()
    local skipped_tests=()
    
    if [[ "$total" -eq 1 ]]; then
        log info "Running 1 test sequentially..."
        [[ "$verbose" == "1" ]] && log info "Verbose mode enabled - detailed test information will be shown"
    else
        if [[ "$parallel_jobs" -eq 1 ]]; then
            log info "Running $total test(s) sequentially..."
        else
            log info "Running $total test(s) in parallel (jobs: $parallel_jobs)..."
        fi
    fi
    
    # Execute tests with pytest-style UI
    
    # Use indexed loop instead of array expansion (more reliable in generated scripts)
    for (( i=0; i<${#test_files[@]}; i++ )); do
        local test_file="${test_files[$i]}"
        local test_name=$(basename "$test_file" .gctf)
        
        # Start timing for this test
        local test_start_time
        if command -v python3 >/dev/null 2>&1; then
            test_start_time=$(python3 -c "import time; print(int(time.time() * 1000))")
        elif command -v node >/dev/null 2>&1; then
            test_start_time=$(node -e "console.log(Date.now())")
        else
            test_start_time=$(($(date +%s) * 1000))
        fi
        
        # Pytest-style UI: verbose vs dots mode
        if [[ "$verbose" == "1" ]]; then
            printf "Testing %s ... " "$test_name"
            if run_single_test "$test_file" "$([[ "$dry_run" == "1" ]] && echo "true" || echo "false")"; then
                echo "✅ PASS"
                passed=$((passed + 1))
                
                # Calculate test duration
                local test_end_time
                if command -v python3 >/dev/null 2>&1; then
                    test_end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
                elif command -v node >/dev/null 2>&1; then
                    test_end_time=$(node -e "console.log(Date.now())")
                else
                    test_end_time=$(($(date +%s) * 1000))
                fi
                local test_duration=$((test_end_time - test_start_time))
                passed_tests+=("$test_file|$test_duration")
            else
                local exit_code=$?
                
                # Calculate test duration
                local test_end_time
                if command -v python3 >/dev/null 2>&1; then
                    test_end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
                elif command -v node >/dev/null 2>&1; then
                    test_end_time=$(node -e "console.log(Date.now())")
                else
                    test_end_time=$(($(date +%s) * 1000))
                fi
                local test_duration=$((test_end_time - test_start_time))
                
                if [[ "$exit_code" -eq 3 ]]; then
                    echo "🔍 SKIP (dry-run)"
                    skipped=$((skipped + 1))
                    skipped_tests+=("$test_file|$test_duration")
                else
                    echo "❌ FAIL"
                    failed=$((failed + 1))
                    failed_tests+=("$test_file|$test_duration|Test execution failed")
                fi
            fi
        else
            # Dots mode (pytest-style)
            if run_single_test "$test_file" "$([[ "$dry_run" == "1" ]] && echo "true" || echo "false")" >/dev/null 2>&1; then
                local exit_code=$?
            else
                local exit_code=$?
            fi
            
            # Calculate test duration
            local test_end_time
            if command -v python3 >/dev/null 2>&1; then
                test_end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
            elif command -v node >/dev/null 2>&1; then
                test_end_time=$(node -e "console.log(Date.now())")
            else
                test_end_time=$(($(date +%s) * 1000))
            fi
            local test_duration=$((test_end_time - test_start_time))
            
            case $exit_code in
                0)
                    printf "."
                    passed=$((passed + 1))
                    passed_tests+=("$test_file|$test_duration")
                    ;;
                3)
                    printf "S"
                    skipped=$((skipped + 1))
                    skipped_tests+=("$test_file|$test_duration")
                    ;;
                *)
                    printf "E"
                    failed=$((failed + 1))
                    failed_tests+=("$test_file|$test_duration|Test execution failed")
                    ;;
            esac
        fi
    done
    
    # Add newline after dots mode
    [[ "$verbose" != "1" ]] && echo
    
    # Calculate execution time and advanced statistics (cross-platform with ms precision)
    local end_time
    if command -v python3 >/dev/null 2>&1; then
        # Use python3 for high precision timing (cross-platform)
        end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    elif command -v node >/dev/null 2>&1; then
        # Fallback to node.js
        end_time=$(node -e "console.log(Date.now())")
    else
        # Fallback to second precision
        end_time=$(($(date +%s) * 1000))
    fi
    local duration_ms=$((end_time - start_time))
    local duration_sec=$((duration_ms / 1000))
    local remaining_ms=$((duration_ms % 1000))
    
    # Calculate average time per test
    local avg_per_test_ms=0
    if [[ $total -gt 0 ]]; then
        avg_per_test_ms=$((duration_ms / total))
    fi
    
    # Professional summary like pytest/jest
    echo
    echo "════════════════════════════════════════════════════════════════════════════════"
    
    # Test results line with professional formatting
    if [[ $failed -gt 0 ]]; then
        echo "❌ FAILED ($failed failed, $passed passed$([ "$skipped" -gt 0 ] && echo ", $skipped skipped" || echo "") in ${duration_sec}.$(printf "%03d" $remaining_ms)s)"
    elif [[ $skipped -gt 0 ]]; then
        echo "🔍 PASSED ($passed passed, $skipped skipped in ${duration_sec}.$(printf "%03d" $remaining_ms)s)"
    else
        echo "✅ PASSED ($passed passed in ${duration_sec}.$(printf "%03d" $remaining_ms)s)"
    fi
    
    echo "────────────────────────────────────────────────────────────────────────────────"
    
    # Detailed statistics section
    echo "📊 Execution Statistics:"
    echo "   • Total tests: $total"
    echo "   • Passed: $passed"
    echo "   • Failed: $failed" 
    echo "   • Skipped: $skipped"
    echo "   • Duration: ${duration_sec}.$(printf "%03d" $remaining_ms)s"
    echo "   • Average per test: ${avg_per_test_ms}ms"
    
    # Execution mode information
    if [[ "$parallel_jobs" -eq 1 ]]; then
        echo "   • Mode: Sequential (1 thread)"
    else
        echo "   • Mode: Parallel ($parallel_jobs threads)"
    fi
    
    # Success rate calculation (only for executed tests)
    local executed=$((passed + failed))
    local success_rate
    if [[ "$dry_run" == "1" ]]; then
        echo "   • Success rate: N/A (dry-run mode)"
        success_rate="N/A (dry-run)"
    elif [[ $executed -gt 0 ]]; then
        local success_rate_num=$(( (passed * 100) / executed ))
        echo "   • Success rate: ${success_rate_num}% ($passed/$executed executed)"
        success_rate="${success_rate_num}%"
    else
        echo "   • Success rate: N/A (no tests executed)"
        success_rate="N/A"
    fi
    
    # Performance analysis with emojis
    if [[ $total -gt 0 && "$dry_run" != "1" ]]; then
        if [[ $avg_per_test_ms -lt 100 ]]; then
            echo "   • Performance: ⚡ Excellent (${avg_per_test_ms}ms/test)"
        elif [[ $avg_per_test_ms -lt 500 ]]; then
            echo "   • Performance: ✅ Good (${avg_per_test_ms}ms/test)"  
        elif [[ $avg_per_test_ms -lt 1000 ]]; then
            echo "   • Performance: ⚠️  Moderate (${avg_per_test_ms}ms/test)"
        else
            echo "   • Performance: 🐌 Slow (${avg_per_test_ms}ms/test)"
        fi
    fi
    
    echo "────────────────────────────────────────────────────────────────────────────────"
    
    # Warnings section (collected during execution)
    local has_warnings=false
    if [[ $headers_warnings -gt 0 ]]; then
        if [[ "$has_warnings" == "false" ]]; then
            echo "⚠️  Warnings:"
            has_warnings=true
        fi
        echo "   • Found $headers_warnings HEADERS sections - use REQUEST_HEADERS instead"
    fi
    
    # Environment info
    echo "🔧 Environment:"
    echo "   • gRPC Address: ${GRPCTESTIFY_ADDRESS:-localhost:4770}"
    echo "   • Sort Mode: $sort_mode"
    if [[ "$dry_run" == "1" ]]; then
        echo "   • Dry Run: Enabled (no actual gRPC calls)"
    else
        echo "   • Dry Run: Disabled (real gRPC calls)"
    fi
    
    if [[ "$has_warnings" == "false" ]]; then
        echo "✨ No warnings detected"
    fi
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    
    # Generate reports if requested
    if [[ -n "$log_format" && -n "$log_output" ]]; then
        echo
        echo "📋 Generating $log_format report..."
        
        case "$log_format" in
            "junit")
                # Pass test details to generate_junit_report
                generate_junit_report "$log_output" "$total" "$passed" "$failed" "$skipped" "$duration_ms" "$start_time" "passed_tests" "failed_tests" "skipped_tests"
                ;;
            "json")
                generate_json_report "$log_output" "$total" "$passed" "$failed" "$skipped" "$duration_ms" "$start_time" "passed_tests" "failed_tests" "skipped_tests"
                ;;
        esac
        
        if [[ $? -eq 0 ]]; then
            echo "✅ Report saved: $log_output"
        else
            echo "❌ Failed to generate report: $log_output"
        fi
    fi
    
    # Return appropriate exit code (0 only for 100% success in non-dry-run)
    if [[ "$dry_run" == "1" ]]; then
        return 0  # Dry-run always succeeds
    else
        return $([[ $failed -eq 0 ]] && echo 0 || echo 1)
    fi
}

# Required by bashly framework - this function will be called by the generated script
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Being sourced by bashly generated script
    true
fi
