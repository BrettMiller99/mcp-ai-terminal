# Cross-Platform Terminal System Guide

This guide shows how to use the unified terminal system across different operating systems.

## 📋 Platform Support

| Platform | Script | Shell | Status |
|----------|---------|-------|---------|
| **macOS** | `unified-terminal-system.sh` | bash/zsh | ✅ **Fully Tested** |
| **Linux** | `unified-terminal-system.sh` | bash/zsh | ✅ **Compatible** |
| **Windows** | `unified-terminal-system.ps1` | PowerShell | ✅ **Available** |

## 🍎 macOS/Linux Usage

### Setup
```bash
chmod +x unified-terminal-system.sh
```

### Examples
```bash
# Smart execution (recommended for AI)
./unified-terminal-system.sh exec "mvn clean test"

# Quick commands
./unified-terminal-system.sh exec "git status"

# Background execution
./unified-terminal-system.sh bg "gradle build"

# Get context
./unified-terminal-system.sh context
```

## 🪟 Windows Usage

### Setup
```powershell
# Enable script execution (run as Administrator once)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or for single session
PowerShell -ExecutionPolicy Bypass -File unified-terminal-system.ps1
```

### Examples
```powershell
# Smart execution (recommended for AI)
.\unified-terminal-system.ps1 exec "dotnet test"

# Quick commands
.\unified-terminal-system.ps1 exec "git status"

# Background execution
.\unified-terminal-system.ps1 bg "msbuild MySolution.sln"

# Get context
.\unified-terminal-system.ps1 context
```

## 🔄 Command Mapping

### Test Commands
| Platform | Command | Auto-Detection |
|----------|---------|---------------|
| **Java** | `mvn test`, `gradle test` | ✅ Background |
| **.NET** | `dotnet test`, `msbuild` | ✅ Background |
| **Node** | `npm test`, `yarn test` | ✅ Background |
| **Python** | `pytest`, `python -m pytest` | ✅ Background |

### Build Commands  
| Platform | Command | Auto-Detection |
|----------|---------|---------------|
| **Java** | `mvn install`, `gradle build` | ✅ Background |
| **.NET** | `dotnet build`, `msbuild` | ✅ Background |
| **Node** | `npm install`, `yarn install` | ✅ Background |
| **Docker** | `docker build` | ✅ Background |

### Quick Commands
| Platform | Command | Auto-Detection |
|----------|---------|---------------|
| **All** | `git status`, `ls`/`dir`, `pwd` | ✅ Immediate |
| **All** | `echo`, `cat`/`type` | ✅ Immediate |

## 🛠️ IDE Integration

### IntelliJ IDEA
**macOS/Linux:**
- Terminal TTY: Auto-detected via `tty` command
- Injection: Direct to `/dev/ttys009` (or detected TTY)

**Windows:**
- Terminal: Uses PowerShell jobs (no direct injection)
- Alternative: Copy commands to IDE terminal manually

### VS Code
**All Platforms:**
- Use integrated terminal
- Commands work in any terminal within VS Code

### Command Prompt/PowerShell
**Windows:**
- Native PowerShell support
- Background jobs for long-running commands

## 🔧 Configuration

### macOS/Linux
```bash
# Set custom timeouts
./unified-terminal-system.sh timeout 15

# Custom output directory
export OUTPUT_DIR="/custom/path/outputs"
```

### Windows
```powershell
# Set custom timeouts
.\unified-terminal-system.ps1 timeout 15

# Custom output directory via environment variable
$env:TEMP = "C:\custom\temp\path"
```

## 📁 File Locations

### macOS/Linux
```
/tmp/terminal-outputs/          # Main output directory
/tmp/ai_cmd_*.log              # AI command logs
~/.zsh_history or ~/.bash_history  # Shell history
```

### Windows
```
%TEMP%\terminal-outputs\        # Main output directory
%TEMP%\ai_cmd_*.log            # AI command logs
PowerShell command history      # Get-History
```

## 🚀 Advanced Features

### Background Job Management

**macOS/Linux:**
```bash
# Check all background processes
./unified-terminal-system.sh status

# Kill stuck processes
pkill -f "long-running-command"
```

**Windows:**
```powershell
# Check all background jobs
Get-Job

# Stop specific job
Stop-Job -Id 1

# Remove completed jobs
Remove-Job -State Completed
```

### Output Management

**All Platforms:**
```bash
# Show recent outputs
./unified-terminal-system.sh outputs      # macOS/Linux
.\unified-terminal-system.ps1 outputs     # Windows

# Cleanup old files
./unified-terminal-system.sh cleanup 3    # Keep 3 days
.\unified-terminal-system.ps1 cleanup 3   # Keep 3 days
```

## 🔍 Troubleshooting

### Common Issues

**macOS/Linux:**
- **Permission denied**: `chmod +x unified-terminal-system.sh`
- **Command not found**: Ensure you're in the correct directory
- **TTY issues**: Check `tty` command output

**Windows:**
- **Execution Policy**: Run `Set-ExecutionPolicy RemoteSigned`
- **Path issues**: Use `.\` prefix for local scripts
- **Job errors**: Check `Get-Job` for background command status

### Debug Mode

**macOS/Linux:**
```bash
# Run with debug output
bash -x unified-terminal-system.sh exec "command"
```

**Windows:**
```powershell
# Run with verbose output
.\unified-terminal-system.ps1 exec "command" -Verbose
```

## 📝 Migration Guide

### From macOS to Windows
1. Copy command patterns from bash to PowerShell
2. Update file paths (`/tmp/` → `%TEMP%`)
3. Replace Unix commands with PowerShell equivalents
4. Test background job functionality

### From Windows to macOS/Linux  
1. Convert PowerShell commands to bash equivalents
2. Update file paths (`%TEMP%` → `/tmp/`)
3. Replace PowerShell cmdlets with Unix commands
4. Test TTY injection functionality

---

**Note**: Both systems provide the same core functionality - AI-safe execution, background processing, and context sharing. Choose the appropriate script for your platform and enjoy seamless AI terminal integration!
