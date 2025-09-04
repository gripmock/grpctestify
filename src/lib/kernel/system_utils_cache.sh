#!/bin/bash
# shellcheck shell=bash

# System Utils Cache - Early detection for critical utilities only
# Kept minimal: timeout/gtimeout and CPU detection helpers

SYSTEM_UTILS_CACHE_INITIALIZED=false

cache_log() {
    local level="$1"
    shift
    case "$level" in
        debug) [[ "${GRPCTESTIFY_LOG_LEVEL:-}" == "debug" ]] && echo "🐛 DEBUG: $*" >&2 ;;
        info)  echo "ℹ️  INFO: $*" ;;
        warn)  echo "⚠️  WARN: $*" >&2 ;;
        error) echo "❌ ERROR: $*" >&2 ;;
    esac
}

#######################################
# Initialize system utilities cache (minimal)
#######################################
init_system_utils_cache() {
    if [[ "$SYSTEM_UTILS_CACHE_INITIALIZED" == "true" ]]; then
        return 0
    fi

    cache_log debug "Initializing minimal system utils cache..."

    # Detect timeout variants
    local timeout_path="" gtimeout_path=""
    if command -v timeout >/dev/null 2>&1; then
        timeout_path=$(command -v timeout)
    fi
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout_path=$(command -v gtimeout)
    fi

    if [[ -n "$timeout_path" ]]; then
        SYSTEM_UTILS_CACHE_TIMEOUT_AVAILABLE="true"
        SYSTEM_UTILS_CACHE_TIMEOUT_CMD_PATH="$timeout_path"
    elif [[ -n "$gtimeout_path" ]]; then
        SYSTEM_UTILS_CACHE_TIMEOUT_AVAILABLE="true"
        SYSTEM_UTILS_CACHE_TIMEOUT_CMD_PATH="$gtimeout_path"
    else
        SYSTEM_UTILS_CACHE_TIMEOUT_AVAILABLE="false"
        SYSTEM_UTILS_CACHE_TIMEOUT_CMD_PATH=""
    fi

    # CPU detection method (nproc/sysctl/psrinfo/fallback)
    if command -v nproc >/dev/null 2>&1; then
        SYSTEM_UTILS_CACHE_CPU_DETECTION_METHOD="nproc"
    elif command -v sysctl >/dev/null 2>&1; then
        SYSTEM_UTILS_CACHE_CPU_DETECTION_METHOD="sysctl"
    elif command -v psrinfo >/dev/null 2>&1; then
        SYSTEM_UTILS_CACHE_CPU_DETECTION_METHOD="psrinfo"
    else
        SYSTEM_UTILS_CACHE_CPU_DETECTION_METHOD="fallback"
    fi

    SYSTEM_UTILS_CACHE_INITIALIZED=true
    cache_log debug "Minimal system utils cache initialized"
}

#######################################
# Get timeout command path or empty
#######################################
get_timeout_command() {
    [[ "$SYSTEM_UTILS_CACHE_INITIALIZED" == "true" ]] || init_system_utils_cache
    echo "$SYSTEM_UTILS_CACHE_TIMEOUT_CMD_PATH"
}

#######################################
# Execute a command with timeout (uses timeout/gtimeout or pure shell)
#######################################
cached_timeout_exec() {
    local timeout_seconds="$1"
    shift

    if [[ ! "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -le 0 ]]; then
        cache_log error "cached_timeout_exec: invalid timeout value: $timeout_seconds"
        return 1
    fi

    [[ "$SYSTEM_UTILS_CACHE_INITIALIZED" == "true" ]] || init_system_utils_cache

    local timeout_cmd
    timeout_cmd=$(get_timeout_command)
    if [[ -n "$timeout_cmd" ]]; then
        "$timeout_cmd" "$timeout_seconds" "$@"
        return $?
    fi

    # Fallback to pure shell implementation
    local cmd_pid timeout_pid exit_code
    "$@" &
    cmd_pid=$!
    (
        sleep "$timeout_seconds"
        if kill -0 "$cmd_pid" 2>/dev/null; then
            kill -TERM "$cmd_pid" 2>/dev/null
            sleep 1
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null
            fi
        fi
    ) &
    timeout_pid=$!

    if wait "$cmd_pid" 2>/dev/null; then
        exit_code=$?
        kill "$timeout_pid" 2>/dev/null
        wait "$timeout_pid" 2>/dev/null
        return $exit_code
    else
        kill "$timeout_pid" 2>/dev/null
        wait "$timeout_pid" 2>/dev/null
        return 124
    fi
}

#######################################
# CPU detection (nproc/sysctl/psrinfo/fallback)
#######################################
get_cpu_detection_method() {
    [[ "$SYSTEM_UTILS_CACHE_INITIALIZED" == "true" ]] || init_system_utils_cache
    echo "$SYSTEM_UTILS_CACHE_CPU_DETECTION_METHOD"
}

cached_cpu_count() {
    [[ "$SYSTEM_UTILS_CACHE_INITIALIZED" == "true" ]] || init_system_utils_cache
    case "$SYSTEM_UTILS_CACHE_CPU_DETECTION_METHOD" in
        nproc) nproc 2>/dev/null || echo "1" ;;
        sysctl)
            case "$(uname -s)" in
                Darwin|FreeBSD|OpenBSD|NetBSD) sysctl -n hw.ncpu 2>/dev/null || echo "1" ;;
                *) echo "1" ;;
            esac
            ;;
        psrinfo) psrinfo | wc -l 2>/dev/null || echo "1" ;;
        *) echo "1" ;;
    esac
}

#######################################
# Debug print
#######################################
debug_print_cache() {
    [[ "${GRPCTESTIFY_LOG_LEVEL:-}" == "debug" ]] || return 0
    cache_log debug "System Utils Cache Contents:"
    cache_log debug "  timeout_cmd_path: ${SYSTEM_UTILS_CACHE_TIMEOUT_CMD_PATH:-<none>}"
    cache_log debug "  cpu_detection_method: ${SYSTEM_UTILS_CACHE_CPU_DETECTION_METHOD:-fallback}"
}
