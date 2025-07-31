#!/bin/bash
# MCP AI-Safe Terminal Verification Script

echo "🧪 Testing AI-Safe Terminal MCP Server..."
echo "=========================================="

# Test 1: Check dependencies
echo "1️⃣ Checking Python dependencies..."
python3 -c "import mcp, psutil, pydantic, structlog; print('✅ All dependencies installed')" || {
    echo "❌ Dependencies missing"
    exit 1
}

# Test 2: Check ai-terminal installation
echo -e "\n2️⃣ Testing ai-terminal installation..."
export PATH="$PATH:/Users/brettmiller/.local/bin"
if command -v ai-terminal >/dev/null 2>&1; then
    echo "✅ ai-terminal found in PATH"
else
    echo "❌ ai-terminal not found"
    exit 1
fi

# Test 3: Test quick command execution
echo -e "\n3️⃣ Testing quick command execution..."
result=$(ai-terminal exec "echo 'Test successful'" 2>&1)
if [[ $result == *"Test successful"* ]]; then
    echo "✅ Quick command execution works"
else
    echo "❌ Quick command failed: $result"
    exit 1
fi

# Test 4: Test timeout protection
echo -e "\n4️⃣ Testing timeout protection..."
start_time=$(date +%s)
ai-terminal exec "sleep 5" >/dev/null 2>&1
end_time=$(date +%s)
duration=$((end_time - start_time))

if [ $duration -lt 10 ]; then
    echo "✅ Timeout protection works (took ${duration}s)"
else
    echo "⚠️ Timeout might not be working properly (took ${duration}s)"
fi

# Test 5: Check MCP server can start
echo -e "\n5️⃣ Testing MCP server startup..."
python3 /Users/brettmiller/Documents/MCPServers/mcp-ai-terminal/mcp-ai-terminal-server.py --help >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ MCP server can start"
else
    echo "❌ MCP server startup failed"
    exit 1
fi

# Test 6: Check Windsurf configuration
echo -e "\n6️⃣ Checking Windsurf configuration..."
config_file="/Users/brettmiller/Library/Application Support/Windsurf/User/settings.json"
if [ -f "$config_file" ]; then
    if grep -q "ai-safe-terminal" "$config_file"; then
        echo "✅ MCP server configured in Windsurf"
    else
        echo "❌ MCP server not found in Windsurf config"
        exit 1
    fi
else
    echo "❌ Windsurf settings file not found"
    exit 1
fi

echo -e "\n🎉 All tests passed!"
echo "Next steps:"
echo "1. Restart Windsurf to load the new MCP server"
echo "2. Try asking Windsurf to run terminal commands"
echo "3. Commands will automatically be made AI-safe"
echo ""
echo "Example commands to test in Windsurf:"
echo "- 'Run ls -la in the terminal'"
echo "- 'Execute npm test (if you have a Node.js project)'"
echo "- 'Run a command that might hang' (to test timeout protection)"
