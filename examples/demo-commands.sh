#!/bin/bash
# AI-Safe Terminal MCP Server Demo Commands
# Demonstrates different command types and execution strategies

echo "🎭 AI-Safe Terminal MCP Server Demo"
echo "   This script shows how different commands are handled"
echo ""

# Assuming the server is running and ai-terminal is available
if ! command -v ai-terminal >/dev/null 2>&1; then
    echo "❌ ai-terminal not found. Please run ./install-ai-terminal.sh first"
    exit 1
fi

echo "1. 🚀 Quick Command (immediate execution with timeout)"
echo "   Command: echo 'Hello, AI-Safe World!'"
ai-terminal exec "echo 'Hello, AI-Safe World!'"
echo ""

echo "2. ⏱️  Timeout Protection (command killed after timeout)"
echo "   Command: sleep 10 (should be killed after ~8 seconds)"
ai-terminal exec "sleep 10"
echo ""

echo "3. 🧪 Test Command (automatic background execution)"
echo "   Command: echo 'Running tests...' && sleep 3 && echo 'Tests completed: 15 passed, 0 failed'"
ai-terminal exec "echo 'Running tests...' && sleep 3 && echo 'Tests completed: 15 passed, 0 failed'"
echo ""

echo "4. 🔨 Build Command (automatic background execution)"
echo "   Command: echo 'Building project...' && sleep 5 && echo 'Build successful'"
ai-terminal exec "echo 'Building project...' && sleep 5 && echo 'Build successful'"
echo ""

echo "5. 📊 Status Check (monitor background commands)"
echo "   Checking status of background commands..."
ai-terminal status
echo ""

echo "6. 📖 Context Retrieval (get recent terminal activity)"
echo "   Getting recent terminal context..."
ai-terminal context
echo ""

echo "7. 🔍 File Operations (quick commands)"
echo "   Command: ls -la /tmp"
ai-terminal exec "ls -la /tmp"
echo ""

echo "8. 🌐 Network Command (background execution due to potential hang)"
echo "   Command: ping -c 3 google.com"
ai-terminal exec "ping -c 3 google.com"
echo ""

echo "9. 📝 Complex Command Chain"
echo "   Command: echo 'Step 1' && sleep 1 && echo 'Step 2' && sleep 1 && echo 'Step 3'"
ai-terminal exec "echo 'Step 1' && sleep 1 && echo 'Step 2' && sleep 1 && echo 'Step 3'"
echo ""

echo "10. 🚨 Infinite Loop Protection"
echo "    Command: bash -c 'for i in {1..5}; do echo \"Loop $i\"; sleep 1; done'"
echo "    (This simulates a potentially long-running process)"
ai-terminal exec "bash -c 'for i in {1..5}; do echo \"Loop \$i\"; sleep 1; done'"
echo ""

echo "🎉 Demo completed!"
echo ""
echo "Key Observations:"
echo "• Quick commands executed immediately with timeout protection"
echo "• Test/build commands automatically routed to background"
echo "• Long-running commands don't block the AI"
echo "• All commands logged for later analysis"
echo "• Status and context commands provide monitoring capabilities"
echo ""
echo "Check /tmp/ai-terminal-outputs/ for detailed logs!"
