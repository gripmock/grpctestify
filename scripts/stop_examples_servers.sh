#!/bin/bash
# Stop all grpctestify example servers
# This script stops all running example servers started by start_examples_servers.sh

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SERVERS_LOG_DIR="$PROJECT_ROOT/logs/servers"

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $*"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" >&2
}

# Stop server by PID file
stop_server_by_pid() {
    local pid_file="$1"
    local server_name=$(basename "$pid_file" .pid)
    
    if [[ ! -f "$pid_file" ]]; then
        warn "PID file not found: $pid_file"
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        error "Invalid PID in $pid_file: $pid"
        rm -f "$pid_file"
        return 1
    fi
    
    if kill -0 "$pid" 2>/dev/null; then
        log "🛑 Stopping $server_name (PID: $pid)..."
        
        # Try graceful shutdown first
        if kill -TERM "$pid" 2>/dev/null; then
            # Wait for graceful shutdown
            local attempts=10
            for ((i=1; i<=attempts; i++)); do
                if ! kill -0 "$pid" 2>/dev/null; then
                    log "✅ $server_name stopped gracefully"
                    rm -f "$pid_file"
                    return 0
                fi
                sleep 1
            done
            
            # Force kill if graceful shutdown failed
            warn "Force killing $server_name..."
            kill -KILL "$pid" 2>/dev/null || true
            sleep 1
        fi
        
        # Verify process is stopped
        if ! kill -0 "$pid" 2>/dev/null; then
            log "✅ $server_name stopped"
            rm -f "$pid_file"
            return 0
        else
            error "Failed to stop $server_name"
            return 1
        fi
    else
        warn "$server_name was not running (PID: $pid)"
        rm -f "$pid_file"
        return 0
    fi
}

# Stop all servers by name pattern
stop_servers_by_pattern() {
    local pattern="$1"
    local stopped=0
    
    log "🔍 Looking for processes matching: $pattern"
    
    # Find PIDs of matching processes
    local pids=$(pgrep -f "$pattern" 2>/dev/null || true)
    
    if [[ -z "$pids" ]]; then
        warn "No processes found matching: $pattern"
        return 0
    fi
    
    # Stop each matching process
    for pid in $pids; do
        local cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        log "🛑 Stopping process: $cmd (PID: $pid)"
        
        if kill -TERM "$pid" 2>/dev/null; then
            ((stopped++))
            sleep 1
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                warn "Force killing PID: $pid"
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
    done
    
    log "✅ Stopped $stopped processes"
    return 0
}

# Main function
main() {
    log "🛑 Stopping all grpctestify example servers..."
    
    local servers_stopped=0
    local servers_failed=0
    
    # Method 1: Stop by PID files
    if [[ -d "$SERVERS_LOG_DIR" ]]; then
        for pid_file in "$SERVERS_LOG_DIR"/*.pid; do
            if [[ -f "$pid_file" ]]; then
                if stop_server_by_pid "$pid_file"; then
                    ((servers_stopped++))
                else
                    ((servers_failed++))
                fi
            fi
        done
    fi
    
    # Method 2: Stop any remaining servers by process name
    log "🔍 Checking for remaining example server processes..."
    
    # Common server binary names
    local server_patterns=(
        "examples/.*server"
        "user-management.*server"
        "real-time-chat.*server"
        "iot-monitoring.*server"
        "ai-chat.*server"
        "media-streaming.*server"
        "shopflow-ecommerce.*server"
        "file-storage.*server"
        "fintech-payment.*server"
    )
    
    for pattern in "${server_patterns[@]}"; do
        stop_servers_by_pattern "$pattern"
    done
    
    # Method 3: Cleanup by port (if needed)
    log "🔍 Checking for processes on example server ports..."
    local ports=(50051 50052 50053 50054 50055 50056 50057 50058 50059)
    
    for port in "${ports[@]}"; do
        local pid=$(lsof -ti ":$port" 2>/dev/null || true)
        if [[ -n "$pid" ]]; then
            log "🛑 Stopping process on port $port (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
    done
    
    # Cleanup log directory
    if [[ -d "$SERVERS_LOG_DIR" ]]; then
        log "🧹 Cleaning up PID files..."
        rm -f "$SERVERS_LOG_DIR"/*.pid
    fi
    
    # Summary
    echo
    log "📊 Server shutdown summary:"
    log "  ✅ Stopped: $servers_stopped"
    if [[ $servers_failed -gt 0 ]]; then
        error "  ❌ Failed: $servers_failed"
    fi
    
    log "🎉 All example servers stopped!"
    return 0
}

main "$@"
