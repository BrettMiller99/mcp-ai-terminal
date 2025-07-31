#!/bin/bash
# AI-Safe Terminal MCP Server Launcher

set -e

# Configuration
DEFAULT_PORT=8000
LOG_DIR="/tmp/ai-terminal-outputs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create log directory
mkdir -p "$LOG_DIR"

# Parse arguments
PORT=${1:-$DEFAULT_PORT}
DAEMON=${2:-false}

echo "🚀 Starting AI-Safe Terminal MCP Server..."
echo "   Port: $PORT"
echo "   Script Dir: $SCRIPT_DIR"
echo "   Log Dir: $LOG_DIR"

# Check dependencies
if ! python3 -c "import mcp" 2>/dev/null; then
    echo "❌ MCP not installed. Installing dependencies..."
    pip3 install -r "$SCRIPT_DIR/requirements.txt"
fi

# Verify backend installation
if [[ ! -f "$SCRIPT_DIR/backends/ai-terminal" ]]; then
    echo "🔧 Installing backend systems..."
    if [[ -f "$SCRIPT_DIR/install-ai-terminal.sh" ]]; then
        "$SCRIPT_DIR/install-ai-terminal.sh"
    fi
fi

# Start server
if [[ "$DAEMON" == "true" ]]; then
    echo "🔄 Starting server as daemon..."
    nohup python3 "$SCRIPT_DIR/mcp-ai-terminal-server.py" --port "$PORT" > "$LOG_DIR/mcp-server.log" 2>&1 &
    echo $! > "$LOG_DIR/mcp-server.pid"
    echo "✅ Server started as daemon (PID: $(cat "$LOG_DIR/mcp-server.pid"))"
    echo "   Log: tail -f $LOG_DIR/mcp-server.log"
    echo "   Stop: kill $(cat "$LOG_DIR/mcp-server.pid")"
else
    echo "▶️  Starting server in foreground..."
    echo "   Press Ctrl+C to stop"
    python3 "$SCRIPT_DIR/mcp-ai-terminal-server.py" --port "$PORT"
fi
