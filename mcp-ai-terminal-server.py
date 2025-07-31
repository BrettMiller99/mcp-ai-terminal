#!/usr/bin/env python3
"""
MCP AI-Safe Terminal Server

This MCP server intercepts run_command tool calls and automatically applies
hang-prevention logic, making it transparent to both AI and users.

Key Benefits:
- Automatic hang prevention for ALL AI assistants
- Zero configuration required
- Works with existing workflows
- Completely transparent to users
- Cross-platform support
- Centralized safety logic
"""

import asyncio
import json
import os
import platform
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

# MCP imports (would need to install: pip install mcp)
try:
    from mcp.server import Server
    from mcp.server.models import InitializationOptions
    from mcp.types import Resource, Tool, TextContent
except ImportError:
    print("MCP not installed. Install with: pip install mcp")
    sys.exit(1)

class AISafeTerminalServer:
    def __init__(self):
        self.server = Server("ai-safe-terminal")
        self.platform = platform.system().lower()
        self.setup_handlers()
        
        # Configuration
        self.safe_timeout = 8  # seconds for AI-safe commands
        self.background_timeout = 300  # seconds for background commands
        self.output_dir = Path(tempfile.gettempdir()) / "ai-terminal-outputs"
        self.output_dir.mkdir(exist_ok=True)
        
        # Command classification patterns
        self.test_patterns = ["test", "junit", "pytest", "jest", "mocha", "rspec"]
        self.build_patterns = ["build", "compile", "make", "gradle", "maven", "npm run build"]
        self.long_patterns = ["install", "download", "sync", "clone", "pull", "push"]
    
    def setup_handlers(self):
        @self.server.list_tools()
        async def handle_list_tools() -> List[Tool]:
            return [
                Tool(
                    name="run_command_safe",
                    description="Execute terminal commands with automatic hang prevention and smart timeout handling",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "The command to execute"
                            },
                            "cwd": {
                                "type": "string", 
                                "description": "Working directory (optional)"
                            },
                            "force_background": {
                                "type": "boolean",
                                "description": "Force background execution (optional)"
                            },
                            "timeout": {
                                "type": "integer",
                                "description": "Custom timeout in seconds (optional)"
                            }
                        },
                        "required": ["command"]
                    }
                ),
                Tool(
                    name="check_command_status",
                    description="Check the status of background commands",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "show_output": {
                                "type": "boolean",
                                "description": "Whether to include recent output"
                            }
                        }
                    }
                ),
                Tool(
                    name="get_terminal_context",
                    description="Get recent terminal activity for debugging context",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "lines": {
                                "type": "integer",
                                "description": "Number of recent lines to retrieve (default 50)"
                            }
                        }
                    }
                )
            ]
    
        @self.server.call_tool()
        async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
            if name == "run_command_safe":
                return await self.execute_safe_command(arguments)
            elif name == "check_command_status":
                return await self.check_status(arguments)
            elif name == "get_terminal_context":
                return await self.get_context(arguments)
            else:
                raise ValueError(f"Unknown tool: {name}")
    
    def classify_command(self, command: str) -> str:
        """Classify command type for execution strategy"""
        cmd_lower = command.lower()
        
        # Check for test commands
        if any(pattern in cmd_lower for pattern in self.test_patterns):
            return "test"
        
        # Check for build commands  
        if any(pattern in cmd_lower for pattern in self.build_patterns):
            return "build"
            
        # Check for long-running commands
        if any(pattern in cmd_lower for pattern in self.long_patterns):
            return "long"
            
        # Check command length as heuristic
        if len(command.split()) > 5:
            return "complex"
            
        return "quick"
    
    async def execute_safe_command(self, args: Dict[str, Any]) -> List[TextContent]:
        command = args["command"]
        cwd = args.get("cwd", os.getcwd())
        force_background = args.get("force_background", False)
        custom_timeout = args.get("timeout")
        
        # Classify command
        cmd_type = self.classify_command(command)
        
        # Determine execution strategy
        if force_background or cmd_type in ["test", "build", "long"]:
            return await self.execute_background(command, cwd)
        else:
            timeout = custom_timeout or self.safe_timeout
            return await self.execute_with_timeout(command, cwd, timeout)
    
    async def execute_with_timeout(self, command: str, cwd: str, timeout: int) -> List[TextContent]:
        """Execute command with strict timeout"""
        try:
            # Create output file
            timestamp = int(time.time())
            output_file = self.output_dir / f"safe_{timestamp}.log"
            
            with output_file.open("w") as f:
                f.write(f"=== AI-Safe Execution ===\n")
                f.write(f"Command: {command}\n")
                f.write(f"CWD: {cwd}\n")
                f.write(f"Timeout: {timeout}s\n")
                f.write(f"Started: {time.ctime()}\n")
                f.write("=" * 40 + "\n")
            
            # Execute with timeout
            process = await asyncio.create_subprocess_shell(
                command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                cwd=cwd
            )
            
            try:
                stdout, _ = await asyncio.wait_for(
                    process.communicate(), 
                    timeout=timeout
                )
                
                output = stdout.decode('utf-8', errors='replace')
                
                # Save to file
                with output_file.open("a") as f:
                    f.write(output)
                    f.write(f"\n{'=' * 40}\n")
                    f.write(f"Exit Code: {process.returncode}\n")
                    f.write(f"Completed: {time.ctime()}\n")
                
                # Return formatted result
                result = f"✅ Command completed successfully\n"
                result += f"Exit Code: {process.returncode}\n"
                result += f"Output:\n{output[:2000]}"  # Limit output size
                
                if len(output) > 2000:
                    result += f"\n... (truncated, full output in {output_file})"
                
                return [TextContent(type="text", text=result)]
                
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()
                
                with output_file.open("a") as f:
                    f.write("\n⏰ TIMEOUT: Command terminated\n")
                    f.write(f"Timeout: {timeout}s\n")
                    f.write(f"Terminated: {time.ctime()}\n")
                
                return [TextContent(
                    type="text",
                    text=f"⏰ Command timed out after {timeout}s and was terminated\n"
                         f"This prevents AI from hanging on slow commands.\n"
                         f"For long-running commands, use force_background=true\n"
                         f"Log: {output_file}"
                )]
                
        except Exception as e:
            return [TextContent(
                type="text",
                text=f"❌ Error executing command: {str(e)}"
            )]
    
    async def execute_background(self, command: str, cwd: str) -> List[TextContent]:
        """Execute command in background"""
        timestamp = int(time.time())
        safe_name = "".join(c for c in command[:20] if c.isalnum() or c in "_-")
        output_file = self.output_dir / f"bg_{timestamp}_{safe_name}.log"
        pid_file = self.output_dir / f"bg_{timestamp}_{safe_name}.pid"
        
        try:
            # Start background process
            process = await asyncio.create_subprocess_shell(
                f"{command} > {output_file} 2>&1 & echo $!",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=cwd,
                shell=True
            )
            
            stdout, _ = await process.communicate()
            pid = stdout.decode().strip()
            
            # Save PID
            with pid_file.open("w") as f:
                f.write(pid)
            
            # Initial status check
            await asyncio.sleep(1)
            
            result = f"✅ Command started in background\n"
            result += f"PID: {pid}\n"
            result += f"Output file: {output_file}\n"
            result += f"Use check_command_status to monitor progress\n"
            
            # Try to show initial output
            if output_file.exists():
                with output_file.open("r") as f:
                    initial = f.read(500)
                    if initial.strip():
                        result += f"\n=== Initial Output ===\n{initial}"
            
            return [TextContent(type="text", text=result)]
            
        except Exception as e:
            return [TextContent(
                type="text",
                text=f"❌ Error starting background command: {str(e)}"
            )]
    
    async def check_status(self, args: Dict[str, Any]) -> List[TextContent]:
        """Check status of background commands"""
        show_output = args.get("show_output", True)
        
        # Find recent background commands
        bg_files = sorted(self.output_dir.glob("bg_*.log"), key=os.path.getmtime, reverse=True)
        
        if not bg_files:
            return [TextContent(type="text", text="No background commands found")]
        
        result = "=== Background Command Status ===\n"
        
        for log_file in bg_files[:5]:  # Show last 5 commands
            timestamp = log_file.stem.split('_')[1]
            pid_file = log_file.parent / f"{log_file.stem.replace('bg_', 'bg_')}.pid"
            
            if pid_file.exists():
                with pid_file.open("r") as f:
                    pid = f.read().strip()
                
                # Check if process is still running
                try:
                    os.kill(int(pid), 0)
                    status = "🔄 Running"
                except (OSError, ValueError):
                    status = "✅ Completed"
            else:
                status = "❓ Unknown"
            
            result += f"\nCommand: {log_file.stem}\n"
            result += f"Status: {status}\n"
            result += f"Log: {log_file}\n"
            
            if show_output and log_file.exists():
                with log_file.open("r") as f:
                    recent_output = f.read()[-1000:]  # Last 1000 chars
                    if recent_output.strip():
                        result += f"Recent output:\n{recent_output}\n"
            
            result += "-" * 40 + "\n"
        
        return [TextContent(type="text", text=result)]
    
    async def get_context(self, args: Dict[str, Any]) -> List[TextContent]:
        """Get terminal context for AI debugging"""
        lines = args.get("lines", 50)
        
        # Collect recent outputs
        all_files = sorted(
            list(self.output_dir.glob("*.log")), 
            key=os.path.getmtime, 
            reverse=True
        )
        
        context = "=== Recent Terminal Activity ===\n"
        
        for log_file in all_files[:3]:  # Last 3 commands
            if log_file.exists():
                with log_file.open("r") as f:
                    content = f.read()
                    
                context += f"\n📄 {log_file.name}\n"
                context += "-" * 40 + "\n"
                
                # Get last N lines
                content_lines = content.splitlines()
                if len(content_lines) > lines:
                    context += f"... (showing last {lines} lines)\n"
                    context += "\n".join(content_lines[-lines:])
                else:
                    context += content
                
                context += "\n" + "=" * 40 + "\n"
        
        return [TextContent(type="text", text=context)]

def main():
    """Run the MCP server"""
    import argparse
    import sys
    
    # Parse arguments - argparse already handles --help automatically
    parser = argparse.ArgumentParser(description="AI-Safe Terminal MCP Server")
    
    # If --help is requested, argparse will handle it and exit
    try:
        args = parser.parse_args()
    except SystemExit:
        # This happens when --help is called
        return
    
    # Run the actual server
    asyncio.run(run_server())

async def run_server():
    """Run the actual MCP server with stdio transport"""
    from mcp.server.stdio import stdio_server
    
    server_instance = AISafeTerminalServer()
    
    # Run the server using stdio transport (required for Windsurf)
    async with stdio_server() as (read_stream, write_stream):
        await server_instance.server.run(
            read_stream,
            write_stream,
            server_instance.server.create_initialization_options()
        )

if __name__ == "__main__":
    main()
