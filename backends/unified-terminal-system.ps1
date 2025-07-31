# Unified AI-Safe Terminal System - Windows PowerShell Version
# Prevents AI from getting stuck while providing full command compatibility

param(
    [string]$Command = "help",
    [string]$Arguments = ""
)

# Configuration
$SafeTimeout = 8          # AI-safe timeout for quick commands (seconds)
$LongTimeout = 300        # Extended timeout for complex commands (seconds)
$OutputLimit = 5000       # Max output characters for AI display
$OutputDir = "$env:TEMP\terminal-outputs"
$MaxOutputSize = 100000   # 100KB max per command output

# Ensure output directory exists
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Cross-platform timeout function
function Invoke-WithTimeout {
    param(
        [int]$TimeoutSeconds,
        [string]$Command
    )
    
    $job = Start-Job -ScriptBlock {
        param($cmd)
        Invoke-Expression $cmd
    } -ArgumentList $Command
    
    if (Wait-Job $job -Timeout $TimeoutSeconds) {
        $result = Receive-Job $job
        Remove-Job $job
        return $result
    } else {
        Stop-Job $job
        Remove-Job $job
        throw "Command timed out after $TimeoutSeconds seconds"
    }
}

# AI-Safe execution with strict timeout and output limiting
function Invoke-AISafeExecute {
    param([string]$Command)
    
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $outputFile = "$env:TEMP\ai_cmd_$timestamp.log"
    
    "AI Command: $Command" | Out-File -FilePath $outputFile -Encoding UTF8
    "Started: $(Get-Date)" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    "---" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    
    try {
        $output = Invoke-WithTimeout -TimeoutSeconds $SafeTimeout -Command $Command
        $output | Out-String | Out-File -FilePath $outputFile -Append -Encoding UTF8
        $exitCode = 0
    }
    catch {
        $_.Exception.Message | Out-File -FilePath $outputFile -Append -Encoding UTF8
        $exitCode = 1
    }
    
    # Add completion info
    "`n---" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    "Exit Code: $exitCode" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    "Completed: $(Get-Date)" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    
    # Show results (limited output)
    $content = Get-Content $outputFile -Raw
    if ($content.Length -gt $OutputLimit) {
        $content.Substring(0, $OutputLimit) + "`n... (truncated)"
    } else {
        $content
    }
    
    if ($exitCode -eq 124 -or $_.Exception.Message -like "*timed out*") {
        Write-Host "`n⚠️  Command timed out after $SafeTimeout seconds" -ForegroundColor Yellow
        Write-Host "Alternative: Use 'background' or 'progressive' mode for longer commands" -ForegroundColor Cyan
    }
}

# Background execution
function Invoke-BackgroundExecute {
    param([string]$Command)
    
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $safeName = $Command -replace '[^\w\s]', '' -replace '\s+', '_'
    $safeName = $safeName.Substring(0, [Math]::Min($safeName.Length, 20))
    $outputFile = "$OutputDir\bg_${timestamp}_${safeName}.log"
    
    "=== Background Execution: $Command ===" | Out-File -FilePath $outputFile -Encoding UTF8
    "Started at: $(Get-Date)" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    "===========================================" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    
    # Start background job
    $job = Start-Job -ScriptBlock {
        param($cmd, $outFile)
        try {
            $result = Invoke-Expression $cmd 2>&1
            $result | Out-File -FilePath $outFile -Append -Encoding UTF8
        }
        catch {
            $_.Exception.Message | Out-File -FilePath $outFile -Append -Encoding UTF8
        }
    } -ArgumentList $Command, $outputFile
    
    $job.Id | Out-File -FilePath "$OutputDir\last_command.pid" -Encoding UTF8
    $outputFile | Out-File -FilePath "$OutputDir\last_command.log" -Encoding UTF8
    
    Write-Host "✅ Command started in background (Job ID: $($job.Id))" -ForegroundColor Green
    Write-Host "📄 Output file: $outputFile" -ForegroundColor Cyan
    
    # Wait briefly to see if command completes quickly
    Start-Sleep -Seconds 2
    if ($job.State -eq "Running") {
        Write-Host "🔄 Command still running... use 'status' to check progress" -ForegroundColor Yellow
    } else {
        Write-Host "⚡ Command completed quickly" -ForegroundColor Green
        if (Test-Path $outputFile) {
            Get-Content $outputFile -Tail 20
        }
    }
}

# Check status of background commands
function Get-CommandStatus {
    if (Test-Path "$OutputDir\last_command.pid") {
        $jobId = Get-Content "$OutputDir\last_command.pid"
        $logFile = ""
        if (Test-Path "$OutputDir\last_command.log") {
            $logFile = Get-Content "$OutputDir\last_command.log"
        }
        
        $job = Get-Job -Id $jobId -ErrorAction SilentlyContinue
        if ($job -and $job.State -eq "Running") {
            Write-Host "🔄 Background command still running (Job ID: $jobId)" -ForegroundColor Yellow
            if ($logFile -and (Test-Path $logFile)) {
                Write-Host "=== Recent Output ===" -ForegroundColor Cyan
                Get-Content $logFile -Tail 15
            }
        } else {
            Write-Host "✅ Background command completed (Job ID: $jobId)" -ForegroundColor Green
            if ($logFile -and (Test-Path $logFile)) {
                Write-Host "=== Final Output ===" -ForegroundColor Cyan
                Get-Content $logFile -Tail 30
            }
        }
    } else {
        Write-Host "ℹ️  No background command found" -ForegroundColor Blue
    }
}

# Get recent context for AI
function Get-TerminalContext {
    Write-Host "=== Recent Terminal Context ===" -ForegroundColor Cyan
    
    # Show recent AI commands
    $recentFiles = Get-ChildItem "$env:TEMP\ai_cmd_*.log" -ErrorAction SilentlyContinue | 
                   Sort-Object LastWriteTime -Descending | Select-Object -First 3
    
    foreach ($file in $recentFiles) {
        Write-Host "--- $($file.Name) ---" -ForegroundColor Yellow
        Get-Content $file.FullName -Tail 10
        Write-Host ""
    }
    
    # Show background command status
    if (Test-Path "$OutputDir\last_command.pid") {
        Write-Host "--- Background Command Status ---" -ForegroundColor Yellow
        Get-CommandStatus
    }
    
    # Show recent outputs
    Write-Host "--- Recent Command Files ---" -ForegroundColor Yellow
    Get-ChildItem "$OutputDir\*.log" -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending | Select-Object -First 5 |
        ForEach-Object { "$($_.Name) $($_.Length)bytes $($_.LastWriteTime.ToString('MM/dd HH:mm'))" }
}

# Smart command execution
function Invoke-SmartExecute {
    param([string]$Command)
    
    Write-Host "🤖 Analyzing command: $Command" -ForegroundColor Magenta
    
    switch -Regex ($Command) {
        'mvn.*test|gradle.*test|npm.*test|yarn.*test|pytest|jest|dotnet.*test' {
            Write-Host "🧪 Test command detected → Background execution" -ForegroundColor Green
            Invoke-BackgroundExecute $Command
        }
        'mvn.*install|gradle.*build|npm.*install|yarn.*install|pip.*install|docker.*build|dotnet.*build|msbuild' {
            Write-Host "🔨 Build command detected → Background execution" -ForegroundColor Green
            Invoke-BackgroundExecute $Command
        }
        'git.*(push|pull|clone)|curl|wget|Invoke-WebRequest|Invoke-RestMethod' {
            Write-Host "🌐 Network command detected → Extended timeout execution" -ForegroundColor Green
            Invoke-AISafeExecute $Command
        }
        '^(ls|dir|pwd|whoami|date|Get-Date|echo|type|cat|Get-Content|findstr|Select-String|git.*status)' {
            Write-Host "⚡ Quick command detected → AI-safe execution" -ForegroundColor Green
            Invoke-AISafeExecute $Command
        }
        default {
            Write-Host "📋 General command → AI-safe execution" -ForegroundColor Green
            Invoke-AISafeExecute $Command
        }
    }
}

# Show outputs
function Show-Outputs {
    Write-Host "=== Recent Command Outputs ===" -ForegroundColor Cyan
    
    Write-Host "--- Output Files ---" -ForegroundColor Yellow
    Get-ChildItem "$OutputDir\*.log", "$env:TEMP\ai_cmd_*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 10 |
        Format-Table Name, Length, LastWriteTime -AutoSize
    
    Write-Host "`n--- Recent Content ---" -ForegroundColor Yellow
    $recentFiles = Get-ChildItem "$OutputDir\*.log", "$env:TEMP\ai_cmd_*.log" -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 3
    
    foreach ($file in $recentFiles) {
        Write-Host "=== $($file.Name) ===" -ForegroundColor Cyan
        Get-Content $file.FullName -Tail 8
        Write-Host ""
    }
}

# Cleanup function
function Clear-OldOutputs {
    param([int]$DaysOld = 1)
    
    Write-Host "🧹 Cleaning up files older than $DaysOld day(s)..." -ForegroundColor Yellow
    
    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    
    # Clean up AI command logs
    Get-ChildItem "$env:TEMP\ai_cmd_*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force
    
    # Clean up output directory
    Get-ChildItem "$OutputDir\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force
    
    Write-Host "✅ Cleanup completed" -ForegroundColor Green
}

# Main command dispatcher
switch ($Command.ToLower()) {
    { $_ -in @("exec", "run") } {
        Invoke-SmartExecute $Arguments
    }
    "safe" {
        Invoke-AISafeExecute $Arguments
    }
    { $_ -in @("bg", "background") } {
        Invoke-BackgroundExecute $Arguments
    }
    { $_ -in @("status", "check") } {
        Get-CommandStatus
    }
    { $_ -in @("context", "recent") } {
        Get-TerminalContext
    }
    { $_ -in @("outputs", "results") } {
        Show-Outputs
    }
    "cleanup" {
        $days = if ($Arguments) { [int]$Arguments } else { 1 }
        Clear-OldOutputs $days
    }
    "timeout" {
        if ($Arguments) {
            $global:SafeTimeout = [int]$Arguments
            Write-Host "⏱️  AI timeout set to $SafeTimeout seconds" -ForegroundColor Green
        } else {
            Write-Host "Current AI timeout: $SafeTimeout seconds" -ForegroundColor Cyan
            Write-Host "Current long timeout: $LongTimeout seconds" -ForegroundColor Cyan
        }
    }
    default {
        Write-Host "🚀 Unified AI-Safe Terminal System - Windows PowerShell Version" -ForegroundColor Magenta
        Write-Host "   Prevents AI hanging while providing full command compatibility`n" -ForegroundColor White
        
        Write-Host "📋 EXECUTION MODES:" -ForegroundColor Cyan
        Write-Host "   .\unified-terminal-system.ps1 exec '<command>'     - Smart execution (AI-recommended)" -ForegroundColor White
        Write-Host "   .\unified-terminal-system.ps1 safe '<command>'     - Quick execution with ${SafeTimeout}s timeout" -ForegroundColor White
        Write-Host "   .\unified-terminal-system.ps1 bg '<command>'       - Background execution (unlimited time)" -ForegroundColor White
        
        Write-Host "`n📊 MONITORING:" -ForegroundColor Cyan
        Write-Host "   .\unified-terminal-system.ps1 status            - Check background command status" -ForegroundColor White
        Write-Host "   .\unified-terminal-system.ps1 context           - Show recent terminal activity" -ForegroundColor White
        Write-Host "   .\unified-terminal-system.ps1 outputs           - Show recent command outputs" -ForegroundColor White
        
        Write-Host "`n🔧 MANAGEMENT:" -ForegroundColor Cyan
        Write-Host "   .\unified-terminal-system.ps1 cleanup [days]    - Clean up old files (default: 1 day)" -ForegroundColor White
        Write-Host "   .\unified-terminal-system.ps1 timeout [seconds] - Set/view timeout settings" -ForegroundColor White
        
        Write-Host "`n💡 EXAMPLES:" -ForegroundColor Cyan
        Write-Host "   .\unified-terminal-system.ps1 exec 'dotnet test'      # Auto: background execution" -ForegroundColor Gray
        Write-Host "   .\unified-terminal-system.ps1 exec 'git status'       # Auto: quick execution" -ForegroundColor Gray
        Write-Host "   .\unified-terminal-system.ps1 bg 'msbuild solution'   # Force: background" -ForegroundColor Gray
        Write-Host "   .\unified-terminal-system.ps1 context                 # Get recent activity" -ForegroundColor Gray
        
        Write-Host "`n🗂️  FILES:" -ForegroundColor Cyan
        Write-Host "   Output Directory: $OutputDir" -ForegroundColor White
        Write-Host "   AI Timeout: ${SafeTimeout}s | Long Timeout: ${LongTimeout}s" -ForegroundColor White
    }
}
