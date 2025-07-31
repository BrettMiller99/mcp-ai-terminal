#!/usr/bin/env python3
"""
Test script to verify the MCP server works with stdio protocol
"""
import subprocess
import json
import time

def test_mcp_server():
    print("🧪 Testing MCP AI-Safe Terminal Server stdio protocol...")
    
    # Start the MCP server
    process = subprocess.Popen(
        ['python3', '/Users/brettmiller/Documents/MCPServers/mcp-ai-terminal/mcp-ai-terminal-server.py'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    try:
        # Send initialization request
        init_request = {
            "jsonrpc": "2.0",
            "method": "initialize",
            "id": 1,
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        }
        
        process.stdin.write(json.dumps(init_request) + '\n')
        process.stdin.flush()
        
        # Read response
        response_line = process.stdout.readline()
        if response_line:
            try:
                response = json.loads(response_line.strip())
                if 'result' in response:
                    print("✅ MCP server initialization successful")
                    print("✅ stdio protocol working correctly")
                    print("✅ Ready for Windsurf integration")
                    return True
                else:
                    print("❌ Initialization failed:", response)
                    return False
            except json.JSONDecodeError:
                print("❌ Invalid JSON response:", response_line)
                return False
        else:
            print("❌ No response from server")
            return False
            
    finally:
        process.terminate()
        process.wait(timeout=1)

if __name__ == "__main__":
    success = test_mcp_server()
    exit(0 if success else 1)
