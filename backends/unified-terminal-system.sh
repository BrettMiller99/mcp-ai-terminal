#!/bin/bash
# Unified AI-Safe Terminal System
# Combines all terminal execution strategies in one script
# Prevents AI from getting stuck while providing full command compatibility

# Configuration
SAFE_TIMEOUT=8          # AI-safe timeout for quick commands
LONG_TIMEOUT=300        # Extended timeout for complex commands
OUTPUT_LIMIT=5000       # Max output characters for AI display
OUTPUT_DIR="/tmp/terminal-outputs"
TERMINAL_TTY="/dev/ttys009"
MAX_OUTPUT_SIZE=100000  # 100KB max per command output

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Cross-platform timeout function
run_with_timeout() {
    local timeout_seconds="$1"
    local cmd="$2"
    
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$timeout_seconds" bash -c "$cmd"
    else
        # macOS fallback - use perl for timeout
        perl -e "alarm $timeout_seconds; exec @ARGV" bash -c "$cmd"
    fi
}

# AI-Safe execution with strict timeout and output limiting
ai_safe_execute() {
    local cmd="$1"
    local timestamp=$(date +%s)
    local output_file="/tmp/ai_cmd_${timestamp}.log"
    
    echo "AI Command: $cmd" > "$output_file"
    echo "Started: $(date)" >> "$output_file"
    echo "---" >> "$output_file"
    
    # Execute with strict timeout and output limiting
    run_with_timeout "$SAFE_TIMEOUT" "$cmd" 2>&1 | head -c "$OUTPUT_LIMIT" >> "$output_file"
    local exit_code=$?
    
    # Add completion info
    echo "" >> "$output_file"
    echo "---" >> "$output_file"
    echo "Exit Code: $exit_code" >> "$output_file"
    echo "Completed: $(date)" >> "$output_file"
    
    # Show results
    cat "$output_file"
    
    # If timed out, offer alternatives
    if [ $exit_code -eq 124 ]; then
        echo ""
        echo "⚠️  Command timed out after ${SAFE_TIMEOUT}s"
        echo "Alternative: Use 'background' or 'progressive' mode for longer commands"
    fi
    
    return $exit_code
}

# Background execution - runs command in background, no blocking
execute_background() {
    local cmd="$1"
    local output_file="$OUTPUT_DIR/bg_$(date +%s)_$(echo "$cmd" | tr ' ' '_' | tr -d '[:punct:]' | head -c 20).log"
    
    echo "=== Background Execution: $cmd ===" > "$output_file"
    echo "Started at: $(date)" >> "$output_file"
    echo "PID: $$" >> "$output_file"
    echo "===========================================" >> "$output_file"
    
    # Execute in background
    (run_with_timeout "$LONG_TIMEOUT" "$cmd" >> "$output_file" 2>&1) &
    local cmd_pid=$!
    
    echo "$cmd_pid" > "$OUTPUT_DIR/last_command.pid"
    echo "$output_file" > "$OUTPUT_DIR/last_command.log"
    
    echo "✅ Command started in background (PID: $cmd_pid)"
    echo "📄 Output file: $output_file"
    
    # Wait briefly to see if command completes quickly
    sleep 2
    if ps -p "$cmd_pid" > /dev/null 2>&1; then
        echo "🔄 Command still running... use 'status' to check progress"
    else
        echo "⚡ Command completed quickly"
        show_file_tail "$output_file" 20
    fi
}

# Immediate execution with extended timeout
execute_immediate() {
    local cmd="$1"
    local output_file="$OUTPUT_DIR/immediate_$(date +%s).log"
    
    echo "=== Immediate Execution: $cmd ===" > "$output_file"
    echo "Started: $(date)" >> "$output_file"
    echo "---" >> "$output_file"
    
    # Execute with extended timeout
    run_with_timeout "$LONG_TIMEOUT" "$cmd" >> "$output_file" 2>&1
    local exit_code=$?
    
    echo "---" >> "$output_file"
    echo "Exit code: $exit_code" >> "$output_file"
    echo "Completed: $(date)" >> "$output_file"
    
    # Show output immediately (with size limiting)
    echo "=== Command Output ==="
    show_file_content "$output_file"
    
    return $exit_code
}

# Progressive monitoring - shows output as it happens
execute_progressive() {
    local cmd="$1"
    local output_file="$OUTPUT_DIR/progressive_$(date +%s).log"
    
    echo "=== Progressive Execution: $cmd ==="
    echo "📊 Monitoring output in real-time..."
    
    # Start command in background
    bash -c "$cmd" > "$output_file" 2>&1 &
    local cmd_pid=$!
    
    # Monitor output progressively
    local count=0
    local last_size=0
    
    while ps -p "$cmd_pid" > /dev/null 2>&1 && [ $count -lt "$LONG_TIMEOUT" ]; do
        if [ -f "$output_file" ]; then
            local current_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo 0)
            
            if [ "$current_size" -gt "$last_size" ]; then
                echo "--- Update (${count}s) ---"
                tail -c +$((last_size + 1)) "$output_file" | head -c 500
                last_size=$current_size
            fi
        fi
        sleep 3
        ((count += 3))
    done
    
    # Kill if still running
    if ps -p "$cmd_pid" > /dev/null 2>&1; then
        kill "$cmd_pid" 2>/dev/null
        echo "⏰ Command timed out after ${LONG_TIMEOUT}s"
    else
        echo "✅ Command completed"
    fi
    
    # Show final output
    if [ -f "$output_file" ]; then
        echo "=== Final Output ==="
        show_file_tail "$output_file" 30
    fi
}

# Terminal injection - send command directly to IntelliJ terminal
inject_terminal() {
    local cmd="$1"
    local monitor_file="$OUTPUT_DIR/injection_$(date +%s).log"
    
    echo "=== Injecting into IntelliJ Terminal: $cmd ===" > "$monitor_file"
    echo "Timestamp: $(date)" >> "$monitor_file"
    echo "TTY: $TERMINAL_TTY" >> "$monitor_file"
    
    # Inject command into IntelliJ terminal
    if echo "$cmd" > "$TERMINAL_TTY" 2>/dev/null; then
        echo "✅ Command injected successfully into IntelliJ terminal"
        echo "📄 Check your IntelliJ terminal for results"
        echo "📋 Monitor log: $monitor_file"
    else
        echo "❌ Failed to inject command into terminal"
        echo "💡 Make sure IntelliJ terminal is active on $TERMINAL_TTY"
    fi
}

# Check status of background commands
check_status() {
    if [ -f "$OUTPUT_DIR/last_command.pid" ]; then
        local cmd_pid=$(cat "$OUTPUT_DIR/last_command.pid")
        local log_file=$(cat "$OUTPUT_DIR/last_command.log" 2>/dev/null || echo "")
        
        if ps -p "$cmd_pid" > /dev/null 2>&1; then
            echo "🔄 Background command still running (PID: $cmd_pid)"
            if [ -n "$log_file" ] && [ -f "$log_file" ]; then
                echo "=== Recent Output ==="
                show_file_tail "$log_file" 15
            fi
        else
            echo "✅ Background command completed (PID: $cmd_pid)"
            if [ -n "$log_file" ] && [ -f "$log_file" ]; then
                echo "=== Final Output ==="
                show_file_tail "$log_file" 30
            fi
        fi
    else
        echo "ℹ️  No background command found"
    fi
}

# Get recent context for AI
get_context() {
    echo "=== Recent Terminal Context ==="
    
    # Show recent AI commands
    local recent_ai_files=$(ls -t /tmp/ai_cmd_*.log 2>/dev/null | head -3)
    for file in $recent_ai_files; do
        if [ -f "$file" ]; then
            echo "--- $(basename "$file") ---"
            show_file_tail "$file" 10
            echo ""
        fi
    done
    
    # Show background command status
    if [ -f "$OUTPUT_DIR/last_command.pid" ]; then
        echo "--- Background Command Status ---"
        check_status
    fi
    
    # Show recent outputs
    echo "--- Recent Command Files ---"
    ls -la "$OUTPUT_DIR"/*.log 2>/dev/null | tail -5 | awk '{print $9, $5 "bytes", $6" "$7" "$8}'
}

# Show file content with size limiting
show_file_content() {
    local file="$1"
    local max_lines="${2:-50}"
    
    if [ -f "$file" ]; then
        local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
        
        if [ "$file_size" -gt "$MAX_OUTPUT_SIZE" ]; then
            echo "📄 Output too large (${file_size} bytes), showing truncated:"
            echo "--- First 25 lines ---"
            head -25 "$file"
            echo "..."
            echo "--- Last 25 lines ---"
            tail -25 "$file"
        else
            cat "$file"
        fi
    fi
}

# Show file tail with line limiting
show_file_tail() {
    local file="$1"
    local lines="${2:-20}"
    
    if [ -f "$file" ]; then
        tail -"$lines" "$file"
    fi
}

# Smart command execution - chooses best strategy
smart_execute() {
    local cmd="$1"
    
    echo "🤖 Analyzing command: $cmd"
    
    # Analyze command to choose best strategy
    case "$cmd" in
        *"mvn"*"test"*|*"maven"*"test"*|*"gradle test"*|*"npm test"*|*"yarn test"*|*"pytest"*|*"jest"*|*"go test"*)
            echo "🧪 Test command detected → Background execution"
            execute_background "$cmd"
            ;;
        *"mvn install"*|*"mvn clean install"*|*"gradle build"*|*"npm install"*|*"yarn install"*|*"pip install"*|*"docker build"*|*"cargo build"*)
            echo "🔨 Build command detected → Background execution"
            execute_background "$cmd"
            ;;
        *"git push"*|*"git pull"*|*"git clone"*|*"curl"*|*"wget"*|*"ssh"*|*"scp"*|*"rsync"*)
            echo "🌐 Network command detected → Immediate with extended timeout"
            execute_immediate "$cmd"
            ;;
        "ls"*|"pwd"|"whoami"|"date"|"history"*|"echo"*|"cat"*|"head"*|"tail"*|"grep"*|"find"*|"git status"*|"git log"*)
            echo "⚡ Quick command detected → AI-safe execution"
            ai_safe_execute "$cmd"
            ;;
        *)
            echo "📋 General command → AI-safe execution"
            ai_safe_execute "$cmd"
            ;;
    esac
}

# Cleanup old files
cleanup() {
    local days_old="${1:-1}"
    echo "🧹 Cleaning up files older than $days_old day(s)..."
    
    local count=0
    # Clean up AI command logs
    find /tmp -name "ai_cmd_*.log" -mtime +$days_old -delete 2>/dev/null && ((count++))
    
    # Clean up output directory
    find "$OUTPUT_DIR" -name "*.log" -mtime +$days_old -delete 2>/dev/null && ((count++))
    find "$OUTPUT_DIR" -name "*.pid" -mtime +$days_old -delete 2>/dev/null && ((count++))
    
    echo "✅ Cleanup completed"
}

# Show recent outputs
show_outputs() {
    echo "=== Recent Command Outputs ==="
    
    # Show file listing
    echo "--- Output Files ---"
    ls -lat "$OUTPUT_DIR"/*.log /tmp/ai_cmd_*.log 2>/dev/null | head -10
    
    echo ""
    echo "--- Recent Content ---"
    # Show content of 3 most recent files
    local recent_files=$(ls -t "$OUTPUT_DIR"/*.log /tmp/ai_cmd_*.log 2>/dev/null | head -3)
    for file in $recent_files; do
        if [ -f "$file" ]; then
            echo "=== $(basename "$file") ==="
            show_file_tail "$file" 8
            echo ""
        fi
    done
}

# Main command dispatcher
case "${1:-help}" in
    "exec"|"run")
        shift
        smart_execute "$*"
        ;;
    "safe")
        shift
        ai_safe_execute "$*"
        ;;
    "bg"|"background")
        shift
        execute_background "$*"
        ;;
    "immediate"|"now")
        shift
        execute_immediate "$*"
        ;;
    "progressive"|"monitor")
        shift
        execute_progressive "$*"
        ;;
    "inject")
        shift
        inject_terminal "$*"
        ;;
    "status"|"check")
        check_status
        ;;
    "context"|"recent")
        get_context
        ;;
    "outputs"|"results")
        show_outputs
        ;;
    "cleanup")
        cleanup "$2"
        ;;
    "timeout")
        if [ -n "$2" ]; then
            SAFE_TIMEOUT="$2"
            echo "⏱️  AI timeout set to $SAFE_TIMEOUT seconds"
        else
            echo "Current AI timeout: $SAFE_TIMEOUT seconds"
            echo "Current long timeout: $LONG_TIMEOUT seconds"
        fi
        ;;
    "help"|*)
        echo "🚀 Unified AI-Safe Terminal System"
        echo "   Prevents AI hanging while providing full command compatibility"
        echo ""
        echo "📋 EXECUTION MODES:"
        echo "   exec <command>     - Smart execution (AI-recommended)"
        echo "   safe <command>     - Quick execution with ${SAFE_TIMEOUT}s timeout"
        echo "   bg <command>       - Background execution (unlimited time)"
        echo "   immediate <command> - Extended timeout execution"
        echo "   progressive <command> - Real-time monitoring"
        echo "   inject <command>   - Send to IntelliJ terminal directly"
        echo ""
        echo "📊 MONITORING:"
        echo "   status            - Check background command status"
        echo "   context           - Show recent terminal activity"
        echo "   outputs           - Show recent command outputs"
        echo ""
        echo "🔧 MANAGEMENT:"
        echo "   cleanup [days]    - Clean up old files (default: 1 day)"
        echo "   timeout [seconds] - Set/view timeout settings"
        echo ""
        echo "💡 EXAMPLES:"
        echo "   $0 exec 'mvn clean test'     # Auto: background execution"
        echo "   $0 exec 'git status'         # Auto: quick execution"
        echo "   $0 bg 'gradle build'         # Force: background"
        echo "   $0 inject 'ls -la'           # Send to IntelliJ"
        echo "   $0 context                   # Get recent activity"
        echo ""
        echo "🗂️  FILES:"
        echo "   Output Directory: $OUTPUT_DIR"
        echo "   IntelliJ TTY: $TERMINAL_TTY"
        echo "   AI Timeout: ${SAFE_TIMEOUT}s | Long Timeout: ${LONG_TIMEOUT}s"
        ;;
esac
