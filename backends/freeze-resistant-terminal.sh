#!/bin/bash
# Freeze-Resistant Terminal System
# Advanced detection and recovery for frozen commands

# Configuration
SAFE_TIMEOUT=8
FREEZE_DETECTION_INTERVAL=3
MAX_NO_OUTPUT_TIME=30
OUTPUT_DIR="/tmp/terminal-outputs"
FREEZE_LOG="$OUTPUT_DIR/freeze-detection.log"

mkdir -p "$OUTPUT_DIR"

# Enhanced timeout with freeze detection
run_with_freeze_detection() {
    local timeout_seconds="$1"
    local cmd="$2"
    local output_file="$3"
    
    echo "=== Freeze-Resistant Execution: $cmd ===" > "$output_file"
    echo "Started: $(date)" >> "$output_file"
    echo "Timeout: ${timeout_seconds}s" >> "$output_file"
    echo "Freeze Detection: Active" >> "$output_file"
    echo "===========================================" >> "$output_file"
    
    # Start command in background
    bash -c "$cmd" >> "$output_file" 2>&1 &
    local cmd_pid=$!
    
    # Initialize monitoring variables
    local last_output_size=0
    local no_output_time=0
    local elapsed_time=0
    local freeze_detected=false
    
    echo "Monitoring PID $cmd_pid for freeze detection..." | tee -a "$FREEZE_LOG"
    
    while ps -p "$cmd_pid" > /dev/null 2>&1 && [ $elapsed_time -lt $timeout_seconds ]; do
        # Check if output file size has changed (indicates progress)
        local current_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo 0)
        
        if [ "$current_size" -eq "$last_output_size" ]; then
            ((no_output_time += FREEZE_DETECTION_INTERVAL))
            echo "No output for ${no_output_time}s (PID: $cmd_pid)" >> "$FREEZE_LOG"
        else
            no_output_time=0
            echo "Progress detected: ${current_size} bytes (PID: $cmd_pid)" >> "$FREEZE_LOG"
        fi
        
        last_output_size=$current_size
        
        # Check for freeze condition
        if [ $no_output_time -gt $MAX_NO_OUTPUT_TIME ]; then
            echo "🚨 FREEZE DETECTED: No output for ${no_output_time}s" | tee -a "$output_file" "$FREEZE_LOG"
            freeze_detected=true
            break
        fi
        
        # Check CPU usage to detect spinning processes
        local cpu_usage=$(ps -p "$cmd_pid" -o %cpu= 2>/dev/null | tr -d ' ')
        if [ -n "$cpu_usage" ] && (( $(echo "$cpu_usage > 90" | bc -l 2>/dev/null || echo 0) )); then
            if [ $no_output_time -gt 10 ]; then
                echo "🚨 HIGH CPU + NO OUTPUT: Possible infinite loop detected" | tee -a "$output_file" "$FREEZE_LOG"
                freeze_detected=true
                break
            fi
        fi
        
        sleep $FREEZE_DETECTION_INTERVAL
        ((elapsed_time += FREEZE_DETECTION_INTERVAL))
    done
    
    # Handle different termination scenarios
    if ps -p "$cmd_pid" > /dev/null 2>&1; then
        if [ "$freeze_detected" = true ]; then
            echo "🔥 FORCE TERMINATING frozen process (PID: $cmd_pid)" | tee -a "$output_file" "$FREEZE_LOG"
            force_kill_process_tree "$cmd_pid"
            echo "Process terminated due to freeze detection" >> "$output_file"
            return 124  # Timeout exit code
        elif [ $elapsed_time -ge $timeout_seconds ]; then
            echo "⏰ TIMEOUT: Gracefully terminating (PID: $cmd_pid)" | tee -a "$output_file" "$FREEZE_LOG"
            graceful_kill_process_tree "$cmd_pid"
            return 124  # Timeout exit code
        fi
    fi
    
    # Process completed normally
    wait "$cmd_pid" 2>/dev/null
    local exit_code=$?
    echo "✅ Command completed normally (Exit: $exit_code)" | tee -a "$FREEZE_LOG"
    return $exit_code
}

# Graceful process termination
graceful_kill_process_tree() {
    local parent_pid="$1"
    echo "Gracefully terminating process tree for PID $parent_pid" >> "$FREEZE_LOG"
    
    # Get all child processes
    local child_pids=$(pgrep -P "$parent_pid" 2>/dev/null)
    
    # Send TERM signal first (graceful)
    kill -TERM "$parent_pid" 2>/dev/null
    for child in $child_pids; do
        kill -TERM "$child" 2>/dev/null
    done
    
    # Wait a bit for graceful shutdown
    sleep 3
    
    # If still running, force kill
    if ps -p "$parent_pid" > /dev/null 2>&1; then
        echo "Graceful termination failed, forcing kill..." >> "$FREEZE_LOG"
        force_kill_process_tree "$parent_pid"
    fi
}

# Force process termination
force_kill_process_tree() {
    local parent_pid="$1"
    echo "Force terminating process tree for PID $parent_pid" >> "$FREEZE_LOG"
    
    # Get all child processes (recursive)
    local all_pids=$(pstree -p "$parent_pid" 2>/dev/null | grep -o '([0-9]*)' | tr -d '()' || echo "$parent_pid")
    
    # Force kill everything
    for pid in $all_pids; do
        if ps -p "$pid" > /dev/null 2>&1; then
            kill -KILL "$pid" 2>/dev/null
            echo "Force killed PID $pid" >> "$FREEZE_LOG"
        fi
    done
    
    # Clean up any remaining zombie processes
    wait 2>/dev/null || true
}

# Test freeze scenarios
test_freeze_scenarios() {
    echo "🧪 Testing Freeze Detection Mechanisms..."
    
    # Test 1: Infinite loop
    echo "Test 1: Infinite loop detection"
    run_with_freeze_detection 15 "while true; do :; done" "/tmp/test1.log" &
    local test1_pid=$!
    
    # Test 2: Network hang simulation
    echo "Test 2: Network hang simulation"  
    run_with_freeze_detection 15 "sleep 100" "/tmp/test2.log" &
    local test2_pid=$!
    
    # Test 3: Disk I/O hang simulation
    echo "Test 3: Disk I/O hang simulation"
    run_with_freeze_detection 15 "dd if=/dev/zero of=/tmp/large_file bs=1M count=10000 2>/dev/null" "/tmp/test3.log" &
    local test3_pid=$!
    
    echo "Running tests... Check $FREEZE_LOG for results"
    
    # Monitor tests
    sleep 20
    
    # Force cleanup any remaining test processes
    pkill -f "while true" 2>/dev/null || true
    pkill -f "sleep 100" 2>/dev/null || true
    pkill -f "dd if=/dev/zero" 2>/dev/null || true
    
    echo "Test results:"
    echo "Test 1 (infinite loop):" && tail -5 "/tmp/test1.log" 2>/dev/null || echo "Test completed"
    echo "Test 2 (network hang):" && tail -5 "/tmp/test2.log" 2>/dev/null || echo "Test completed" 
    echo "Test 3 (disk I/O hang):" && tail -5 "/tmp/test3.log" 2>/dev/null || echo "Test completed"
}

# Enhanced AI-safe execution with freeze protection
ai_safe_execute_enhanced() {
    local cmd="$1"
    local timestamp=$(date +%s)
    local output_file="/tmp/ai_cmd_enhanced_${timestamp}.log"
    
    echo "🛡️  Enhanced AI-Safe Execution: $cmd"
    
    # Run with freeze detection
    run_with_freeze_detection "$SAFE_TIMEOUT" "$cmd" "$output_file"
    local exit_code=$?
    
    # Add completion info
    echo "===========================================" >> "$output_file"
    echo "Exit Code: $exit_code" >> "$output_file"
    echo "Completed: $(date)" >> "$output_file"
    
    # Show results with safety limits
    if [ -f "$output_file" ]; then
        local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 10000 ]; then
            echo "=== Output (truncated) ==="
            head -30 "$output_file"
            echo "... (truncated due to size) ..."
            tail -10 "$output_file"
        else
            cat "$output_file"
        fi
    fi
    
    # Provide recovery suggestions if frozen
    if [ $exit_code -eq 124 ]; then
        echo ""
        echo "🚨 Command was terminated (timeout/freeze detected)"
        echo "💡 Recovery suggestions:"
        echo "   - Try background execution: bg '$cmd'"
        echo "   - Check system resources: df -h && free -h"
        echo "   - Review freeze log: tail $FREEZE_LOG"
        echo "   - Test with simpler version of command"
    fi
    
    return $exit_code
}

# Background execution with freeze monitoring
execute_background_enhanced() {
    local cmd="$1"
    local timestamp=$(date +%s)
    local safe_name=$(echo "$cmd" | tr ' ' '_' | tr -d '[:punct:]' | head -c 20)
    local output_file="$OUTPUT_DIR/enhanced_bg_${timestamp}_${safe_name}.log"
    
    echo "🛡️  Enhanced Background Execution: $cmd"
    
    # Start with freeze detection in background
    (run_with_freeze_detection 300 "$cmd" "$output_file") &
    local monitor_pid=$!
    
    echo "$monitor_pid" > "$OUTPUT_DIR/last_enhanced_command.pid"
    echo "$output_file" > "$OUTPUT_DIR/last_enhanced_command.log"
    
    echo "✅ Enhanced command started (Monitor PID: $monitor_pid)"
    echo "📄 Output file: $output_file"
    echo "🔍 Freeze detection active - check status with 'enhanced-status'"
    
    # Brief status check
    sleep 3
    if ps -p "$monitor_pid" > /dev/null 2>&1; then
        echo "🔄 Command running with freeze protection..."
    else
        echo "⚡ Command completed quickly"
        if [ -f "$output_file" ]; then
            tail -10 "$output_file"
        fi
    fi
}

# Enhanced status checking
check_enhanced_status() {
    if [ -f "$OUTPUT_DIR/last_enhanced_command.pid" ]; then
        local monitor_pid=$(cat "$OUTPUT_DIR/last_enhanced_command.pid")
        local log_file=$(cat "$OUTPUT_DIR/last_enhanced_command.log" 2>/dev/null || echo "")
        
        if ps -p "$monitor_pid" > /dev/null 2>&1; then
            echo "🔄 Enhanced command still running (Monitor PID: $monitor_pid)"
            echo "🔍 Freeze detection status:"
            tail -5 "$FREEZE_LOG"
            
            if [ -n "$log_file" ] && [ -f "$log_file" ]; then
                echo "=== Recent Output ==="
                tail -15 "$log_file"
            fi
        else
            echo "✅ Enhanced command completed (Monitor PID: $monitor_pid)"
            if [ -n "$log_file" ] && [ -f "$log_file" ]; then
                echo "=== Final Output ==="
                tail -30 "$log_file"
            fi
        fi
    else
        echo "ℹ️  No enhanced background command found"
    fi
}

# Main command dispatcher
case "${1:-help}" in
    "safe-enhanced")
        shift
        ai_safe_execute_enhanced "$*"
        ;;
    "bg-enhanced")
        shift
        execute_background_enhanced "$*"
        ;;
    "enhanced-status")
        check_enhanced_status
        ;;
    "test-freeze")
        test_freeze_scenarios
        ;;
    "freeze-log")
        if [ -f "$FREEZE_LOG" ]; then
            echo "=== Freeze Detection Log ==="
            tail -50 "$FREEZE_LOG"
        else
            echo "No freeze detection log found"
        fi
        ;;
    "cleanup-frozen")
        echo "🧹 Cleaning up any frozen processes..."
        pkill -f "freeze-resistant-terminal" 2>/dev/null || true
        pkill -f "while true" 2>/dev/null || true
        echo "✅ Cleanup completed"
        ;;
    "help"|*)
        echo "🛡️  Freeze-Resistant Terminal System"
        echo "   Advanced freeze detection and recovery mechanisms"
        echo ""
        echo "ENHANCED COMMANDS:"
        echo "  safe-enhanced <cmd>     - AI-safe with freeze detection"
        echo "  bg-enhanced <cmd>       - Background with freeze monitoring"
        echo "  enhanced-status         - Check enhanced command status"
        echo ""
        echo "TESTING & MONITORING:"
        echo "  test-freeze             - Test freeze detection scenarios"
        echo "  freeze-log              - Show freeze detection log"
        echo "  cleanup-frozen          - Force cleanup frozen processes"
        echo ""
        echo "FREEZE DETECTION FEATURES:"
        echo "  • Output monitoring (${MAX_NO_OUTPUT_TIME}s threshold)"
        echo "  • CPU usage analysis"
        echo "  • Process tree termination"
        echo "  • Graceful -> Force kill escalation"
        echo "  • Comprehensive logging"
        echo ""
        echo "FILES:"
        echo "  Freeze Log: $FREEZE_LOG"
        echo "  Output Dir: $OUTPUT_DIR"
        ;;
esac
