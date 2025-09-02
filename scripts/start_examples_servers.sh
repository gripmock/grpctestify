#!/bin/bash
# Start all grpctestify example servers
# This script builds and starts servers for all examples in the background

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly EXAMPLES_DIR="$PROJECT_ROOT/examples"
readonly SERVERS_LOG_DIR="$PROJECT_ROOT/logs/servers"
readonly TIMEOUT_SECONDS=30

# Create logs directory
mkdir -p "$SERVERS_LOG_DIR"

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $*"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" >&2
}

# Find all servers with Makefile
find_servers() {
    find "$EXAMPLES_DIR" -name "Makefile" -path "*/server/*" | while read -r makefile; do
        dirname "$makefile"
    done
}

# Extract port from server main.go or default
get_server_port() {
    local server_dir="$1"
    local main_file="$server_dir/main.go"
    
    if [[ -f "$main_file" ]]; then
        # Try to extract port from main.go
        local port=$(grep -oE ':([0-9]{4,5})' "$main_file" | head -1 | cut -c2-)
        if [[ -n "$port" ]]; then
            echo "$port"
            return 0
        fi
    fi
    
    # Default port based on server type
    local server_name=$(basename "$(dirname "$server_dir")")
    case "$server_name" in
        "user-management") echo "50051" ;;
        "iot-monitoring") echo "50052" ;;
        "fintech-payment") echo "50053" ;;
        "ai-chat") echo "50054" ;;
        "media-streaming") echo "50055" ;;
        "shopflow-ecommerce") echo "50056" ;;
        "real-time-chat") echo "50057" ;;
        "file-storage") echo "50058" ;;
        *) echo "50059" ;;
    esac
}

# Check if port is available
is_port_available() {
    local port="$1"
    ! nc -z localhost "$port" 2>/dev/null
}

# Wait for server to start
wait_for_server() {
    local port="$1"
    local server_name="$2"
    local max_attempts=30
    
    log "Waiting for $server_name on port $port..."
    
    for ((i=1; i<=max_attempts; i++)); do
        if nc -z localhost "$port" 2>/dev/null; then
            log "✅ $server_name is ready on port $port"
            return 0
        fi
        sleep 1
    done
    
    error "❌ $server_name failed to start on port $port after ${max_attempts}s"
    return 1
}

# Build and start a server
start_server() {
    local server_dir="$1"
    local server_name=$(basename "$(dirname "$server_dir")")
    local port=$(get_server_port "$server_dir")
    local log_file="$SERVERS_LOG_DIR/${server_name}.log"
    
    log "🚀 Starting $server_name server..."
    
    # Check if port is available
    if ! is_port_available "$port"; then
        warn "Port $port is already in use, server might already be running"
        return 0
    fi
    
    # Build server
    log "🔨 Building $server_name..."
    if ! (cd "$server_dir/server" && make build >/dev/null 2>&1); then
        error "Failed to build $server_name"
        return 1
    fi
    
    # Start server in background
    log "▶️  Starting $server_name on port $port..."
    (
        cd "$server_dir/server"
        ./server 2>&1 | tee "$log_file"
    ) &
    
    local server_pid=$!
    echo "$server_pid" > "$SERVERS_LOG_DIR/${server_name}.pid"
    
    # Wait for server to be ready
    if wait_for_server "$port" "$server_name"; then
        log "✅ $server_name started successfully (PID: $server_pid)"
        return 0
    else
        # Kill the process if it failed to start properly
        kill "$server_pid" 2>/dev/null || true
        rm -f "$SERVERS_LOG_DIR/${server_name}.pid"
        return 1
    fi
}

# Main function
main() {
    log "🎯 Starting all grpctestify example servers..."
    
    cd "$PROJECT_ROOT"
    
    local servers_started=0
    local servers_failed=0
    
    # Find and start all servers
    while IFS= read -r server_dir; do
        local server_name=$(basename "$(dirname "$server_dir")")
        
        if start_server "$server_dir"; then
            ((servers_started++))
        else
            ((servers_failed++))
            warn "Failed to start $server_name"
        fi
        
        # Small delay between server starts
        sleep 2
    done < <(find_servers)
    
    # Summary
    echo
    log "📊 Server startup summary:"
    log "  ✅ Started: $servers_started"
    if [[ $servers_failed -gt 0 ]]; then
        error "  ❌ Failed: $servers_failed"
    fi
    
    if [[ $servers_started -gt 0 ]]; then
        log "🎉 Example servers are ready for testing!"
        log "📁 Server logs: $SERVERS_LOG_DIR"
        log "🛑 To stop servers: ./scripts/stop_examples_servers.sh"
        return 0
    else
        error "💥 No servers started successfully"
        return 1
    fi
}

# Cleanup on exit
cleanup() {
    log "🧹 Cleaning up..."
}

trap cleanup EXIT

main "$@"
