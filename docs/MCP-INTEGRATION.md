# MCP Integration Guide

**How to integrate the AI-Safe Terminal MCP Server with different AI clients and applications.**

## 🎯 Overview

The AI-Safe Terminal MCP Server provides a standardized interface for safe terminal command execution across different AI assistants and applications. This guide covers integration with popular AI platforms.

## 🔧 General MCP Configuration

### Server Details
- **Server Name**: `ai-safe-terminal`
- **Transport**: Standard MCP over stdio
- **Tools Provided**: `run_command_safe`, `check_command_status`, `get_terminal_context`
- **Resources**: Terminal output logs, command history

### Basic Configuration Template
```json
{
  "mcpServers": {
    "ai-safe-terminal": {
      "command": "python3",
      "args": ["/path/to/mcp-ai-terminal-server.py"],
      "env": {
        "AI_TERMINAL_TIMEOUT": "8",
        "AI_TERMINAL_OUTPUT_DIR": "/tmp/ai-terminal-outputs"
      }
    }
  }
}
```

## 🚀 Platform-Specific Integration

### 1. Claude Desktop

**Configuration Location**: `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)

```json
{
  "mcpServers": {
    "ai-safe-terminal": {
      "command": "python3",
      "args": ["/Users/you/.local/bin/mcp-ai-terminal-server.py"],
      "env": {}
    }
  }
}
```

**Usage Example**:
```
User: Run my unit tests
Claude: I'll run your unit tests using the AI-safe terminal to prevent hanging.

[Uses run_command_safe with "mvn test" - automatically routes to background]

User: How did the tests go?
Claude: Let me check the status...

[Uses check_command_status to show results]
```

### 2. VS Code with Cascade

**Configuration**: Add to VS Code settings.json

```json
{
  "cascade.mcpServers": {
    "ai-safe-terminal": {
      "command": "python3",
      "args": ["/usr/local/bin/mcp-ai-terminal-server.py"],
      "cwd": "/path/to/your/project"
    }
  }
}
```

**Workflow Integration**:
- Commands automatically classified as quick/background
- Background commands show progress in Cascade terminal
- Full context available for debugging

### 3. Cursor IDE

**Configuration**: Add to Cursor's MCP settings

```json
{
  "mcpServers": {
    "ai-safe-terminal": {
      "command": "python",
      "args": ["C:\\path\\to\\mcp-ai-terminal-server.py"],
      "env": {
        "AI_TERMINAL_OUTPUT_DIR": "C:\\temp\\ai-terminal-outputs"
      }
    }
  }
}
```

**Windows Considerations**:
- Uses PowerShell backend automatically
- Paths should use forward slashes in JSON
- Requires PowerShell execution policy: `Set-ExecutionPolicy RemoteSigned`

### 4. Open WebUI / Ollama

**Docker Compose Integration**:
```yaml
version: '3.8'
services:
  ai-terminal-mcp:
    build: ./mcp-ai-terminal
    ports:
      - "8000:8000"
    volumes:
      - /tmp/ai-terminal-outputs:/tmp/ai-terminal-outputs
    environment:
      - AI_TERMINAL_TIMEOUT=8
  
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    depends_on:
      - ai-terminal-mcp
    environment:
      - MCP_SERVERS={"ai-safe-terminal":{"url":"http://ai-terminal-mcp:8000"}}
```

### 5. Custom AI Applications

**Python Integration Example**:
```python
import asyncio
from mcp.client import Client

async def use_safe_terminal():
    client = Client()
    await client.connect("python3", ["/path/to/mcp-ai-terminal-server.py"])
    
    # Execute command safely
    result = await client.call_tool("run_command_safe", {
        "command": "npm test",
        "cwd": "/path/to/project",
        "force_background": True
    })
    
    print("Command started:", result)
    
    # Check status later
    status = await client.call_tool("check_command_status", {
        "show_output": True
    })
    
    print("Status:", status)

asyncio.run(use_safe_terminal())
```

## 🛡️ Safety Configuration

### Timeout Settings
```json
{
  "env": {
    "AI_TERMINAL_TIMEOUT": "8",      // Quick command timeout
    "AI_TERMINAL_BG_TIMEOUT": "300", // Background command timeout
    "AI_TERMINAL_MAX_OUTPUT": "10000" // Max output size (bytes)
  }
}
```

### Command Classification Rules
```json
{
  "env": {
    "AI_TERMINAL_TEST_PATTERNS": "test,spec,junit,pytest",
    "AI_TERMINAL_BUILD_PATTERNS": "build,compile,make,gradle",
    "AI_TERMINAL_LONG_PATTERNS": "install,download,clone,sync"
  }
}
```

### Security Settings
```json
{
  "env": {
    "AI_TERMINAL_ALLOWED_PATHS": "/home/user,/tmp",
    "AI_TERMINAL_BLOCKED_COMMANDS": "rm -rf,sudo,su",
    "AI_TERMINAL_REQUIRE_CONFIRMATION": "true"
  }
}
```

## 📊 Monitoring and Debugging

### Log Configuration
```json
{
  "env": {
    "AI_TERMINAL_LOG_LEVEL": "INFO",
    "AI_TERMINAL_LOG_FILE": "/var/log/ai-terminal-mcp.log",
    "AI_TERMINAL_METRICS_ENABLED": "true"
  }
}
```

### Health Check Endpoint
```bash
# Check server health
curl http://localhost:8000/health

# Get metrics
curl http://localhost:8000/metrics
```

### Debug Mode
```json
{
  "env": {
    "AI_TERMINAL_DEBUG": "true",
    "AI_TERMINAL_TRACE_COMMANDS": "true"
  }
}
```

## 🔄 Advanced Integration Patterns

### 1. Multi-Environment Setup
```json
{
  "mcpServers": {
    "ai-safe-terminal-dev": {
      "command": "python3",
      "args": ["/path/to/mcp-ai-terminal-server.py", "--env=dev"],
      "env": {"AI_TERMINAL_TIMEOUT": "15"}
    },
    "ai-safe-terminal-prod": {
      "command": "python3", 
      "args": ["/path/to/mcp-ai-terminal-server.py", "--env=prod"],
      "env": {"AI_TERMINAL_TIMEOUT": "5"}
    }
  }
}
```

### 2. Team Shared Configuration
```bash
# Install system-wide
sudo ./install-ai-terminal.sh --system-wide

# Team configuration file
echo '{
  "mcpServers": {
    "ai-safe-terminal": {
      "command": "/usr/local/bin/mcp-ai-terminal-server.py"
    }
  }
}' > /etc/ai-terminal-mcp.json
```

### 3. CI/CD Integration
```yaml
# GitHub Actions
- name: Setup AI Terminal MCP
  run: |
    pip install -r requirements.txt
    ./install-ai-terminal.sh
    python mcp-ai-terminal-server.py --test

- name: Run AI-Assisted Tests
  env:
    MCP_CONFIG: '{"ai-safe-terminal":{"command":"python","args":["mcp-ai-terminal-server.py"]}}'
  run: |
    ai-assistant run-tests --with-mcp
```

## 🚨 Troubleshooting

### Common Issues

#### "MCP Server Connection Failed"
```bash
# Check server binary
which python3
python3 mcp-ai-terminal-server.py --version

# Test direct execution
python3 mcp-ai-terminal-server.py --test-connection
```

#### "Commands Not Being Classified Correctly"
```json
// Add custom patterns
{
  "env": {
    "AI_TERMINAL_CUSTOM_PATTERNS": "mytest:test,mybuild:build"
  }
}
```

#### "Background Commands Not Working"
```bash
# Check backend installation
ai-terminal help
ai-terminal status

# Verify permissions
ls -la /tmp/ai-terminal-outputs
```

### Performance Tuning

#### Optimize for Speed
```json
{
  "env": {
    "AI_TERMINAL_TIMEOUT": "5",
    "AI_TERMINAL_ASYNC_BACKGROUND": "true",
    "AI_TERMINAL_CACHE_ENABLED": "true"
  }
}
```

#### Optimize for Safety
```json
{
  "env": {
    "AI_TERMINAL_TIMEOUT": "3",
    "AI_TERMINAL_FORCE_BACKGROUND": "true",
    "AI_TERMINAL_STRICT_MODE": "true"
  }
}
```

## 📚 API Reference

### Tool: `run_command_safe`
**Purpose**: Execute commands with automatic safety measures

**Parameters**:
- `command` (required): Command to execute
- `cwd` (optional): Working directory
- `force_background` (optional): Force background execution
- `timeout` (optional): Custom timeout in seconds

**Returns**: 
- Immediate response with command status
- Background job ID if applicable
- Output file location

### Tool: `check_command_status` 
**Purpose**: Monitor background command progress

**Parameters**:
- `show_output` (optional): Include recent output

**Returns**:
- Status of all recent background commands
- Progress indicators
- Output snippets

### Tool: `get_terminal_context`
**Purpose**: Retrieve terminal history for debugging

**Parameters**:
- `lines` (optional): Number of recent lines (default: 50)

**Returns**:
- Recent command history
- Output summaries
- Error messages

## 🎉 Success Stories

### Example Workflows

#### 1. Java Development with Maven
```
AI: I'll run your Maven tests safely
→ run_command_safe("mvn clean test") 
→ Auto-detected as test command → Background execution
→ Immediate response: "Tests started in background"
→ User can continue working
→ Later: check_command_status() → "Tests passed: 47/47"
```

#### 2. Node.js Development
```
AI: Let me install dependencies and run tests
→ run_command_safe("npm install") → Background (long command)
→ run_command_safe("npm test") → Background (test command)  
→ Both commands run in parallel safely
→ AI provides updates as they complete
```

#### 3. DevOps Operations
```
AI: I'll deploy to staging
→ run_command_safe("docker build -t app:staging .") → Background
→ run_command_safe("kubectl apply -f staging/") → Background
→ Both commands monitored independently
→ Full deployment logs available for debugging
```

---

**Need help with integration?** Check the troubleshooting section or create an issue on the project repository.
