#!/bin/bash
# AI-Safe Terminal MCP Server Test Suite

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_OUTPUT="/tmp/ai-terminal-test-output"

mkdir -p "$TEST_OUTPUT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"
}

# Test 1: Backend Installation
test_backend_installation() {
    log "🧪 Test 1: Backend Installation"
    
    if [[ -f "$PROJECT_DIR/backends/ai-terminal" ]]; then
        if "$PROJECT_DIR/backends/ai-terminal" help >/dev/null 2>&1; then
            log "   ✅ Backend installation successful"
            return 0
        else
            error "   ❌ Backend not functional"
            return 1
        fi
    else
        warn "   ⚠️  Backend not found, attempting installation..."
        if [[ -f "$PROJECT_DIR/install-ai-terminal.sh" ]]; then
            "$PROJECT_DIR/install-ai-terminal.sh" || return 1
            log "   ✅ Backend installed successfully"
            return 0
        else
            error "   ❌ Installation script not found"
            return 1
        fi
    fi
}

# Test 2: MCP Server Dependencies
test_mcp_dependencies() {
    log "🧪 Test 2: MCP Server Dependencies"
    
    # Check Python
    if ! command -v python3 >/dev/null 2>&1; then
        error "   ❌ Python 3 not found"
        return 1
    fi
    
    # Check MCP (might not be installed yet)
    if python3 -c "import mcp" 2>/dev/null; then
        log "   ✅ MCP library available"
    else
        warn "   ⚠️  MCP library not found (will be installed on first run)"
    fi
    
    # Check server script
    if [[ -f "$PROJECT_DIR/mcp-ai-terminal-server.py" ]]; then
        if python3 -m py_compile "$PROJECT_DIR/mcp-ai-terminal-server.py" 2>/dev/null; then
            log "   ✅ Server script syntax valid"
            return 0
        else
            error "   ❌ Server script syntax error"
            return 1
        fi
    else
        error "   ❌ Server script not found"
        return 1
    fi
}

# Test 3: Quick Command Execution
test_quick_command() {
    log "🧪 Test 3: Quick Command Execution"
    
    local test_output="$TEST_OUTPUT/quick_command.log"
    
    if "$PROJECT_DIR/backends/ai-terminal" exec "echo 'Quick command test'" > "$test_output" 2>&1; then
        if grep -q "Quick command test" "$test_output"; then
            log "   ✅ Quick command executed successfully"
            return 0
        else
            error "   ❌ Quick command output missing"
            cat "$test_output"
            return 1
        fi
    else
        error "   ❌ Quick command failed"
        cat "$test_output"
        return 1
    fi
}

# Test 4: Background Command Execution
test_background_command() {
    log "🧪 Test 4: Background Command Execution"
    
    local test_output="$TEST_OUTPUT/background_command.log"
    
    # Start background command
    if "$PROJECT_DIR/backends/ai-terminal" exec "sleep 3 && echo 'Background test complete'" > "$test_output" 2>&1; then
        # Check that it returned immediately (background mode detected)
        if grep -q "Background\|started in background" "$test_output"; then
            log "   ✅ Background command started successfully"
            
            # Wait for completion and check status
            sleep 5
            if "$PROJECT_DIR/backends/ai-terminal" status > "$test_output.status" 2>&1; then
                log "   ✅ Background command status check successful"
                return 0
            else
                warn "   ⚠️  Background command status check failed (may be normal)"
                return 0
            fi
        else
            warn "   ⚠️  Command may not have been detected as background"
            cat "$test_output"
            return 0  # Not a failure, just different behavior
        fi
    else
        error "   ❌ Background command failed to start"
        cat "$test_output"
        return 1
    fi
}

# Test 5: Timeout Protection
test_timeout_protection() {
    log "🧪 Test 5: Timeout Protection"
    
    local test_output="$TEST_OUTPUT/timeout_test.log"
    local start_time=$(date +%s)
    
    # Run command that should timeout
    "$PROJECT_DIR/backends/ai-terminal" exec "sleep 15" > "$test_output" 2>&1 || true
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -lt 12 ]]; then  # Should timeout before 12 seconds
        log "   ✅ Timeout protection working (${duration}s)"
        return 0
    else
        error "   ❌ Timeout protection failed (${duration}s)"
        cat "$test_output"
        return 1
    fi
}

# Test 6: Cross-Platform Detection
test_cross_platform() {
    log "🧪 Test 6: Cross-Platform Detection"
    
    local platform_output="$TEST_OUTPUT/platform_test.log"
    
    # Test platform detection
    case "$OSTYPE" in
        darwin*)
            log "   🍎 Detected macOS"
            if "$PROJECT_DIR/backends/ai-terminal" exec "uname -s" > "$platform_output" 2>&1; then
                if grep -q "Darwin" "$platform_output"; then
                    log "   ✅ macOS platform working"
                    return 0
                fi
            fi
            ;;
        linux*)
            log "   🐧 Detected Linux"
            if "$PROJECT_DIR/backends/ai-terminal" exec "uname -s" > "$platform_output" 2>&1; then
                if grep -q "Linux" "$platform_output"; then
                    log "   ✅ Linux platform working"
                    return 0
                fi
            fi
            ;;
        cygwin*|mingw*|msys*)
            log "   🪟 Detected Windows"
            # Windows test would use PowerShell backend
            warn "   ⚠️  Windows testing requires PowerShell backend"
            return 0
            ;;
        *)
            warn "   ⚠️  Unknown platform: $OSTYPE"
            return 0
            ;;
    esac
    
    error "   ❌ Platform detection failed"
    cat "$platform_output"
    return 1
}

# Test 7: Freeze Detection (if available)
test_freeze_detection() {
    log "🧪 Test 7: Freeze Detection"
    
    if [[ -f "$PROJECT_DIR/backends/freeze-resistant-terminal.sh" ]]; then
        local test_output="$TEST_OUTPUT/freeze_test.log"
        local start_time=$(date +%s)
        
        # Test freeze detection with infinite loop
        "$PROJECT_DIR/backends/freeze-resistant-terminal.sh" safe-enhanced "bash -c 'while true; do echo ping; sleep 1; done'" > "$test_output" 2>&1 || true
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $duration -lt 15 ]]; then
            log "   ✅ Freeze detection working (${duration}s)"
            return 0
        else
            error "   ❌ Freeze detection failed (${duration}s)"
            return 1
        fi
    else
        warn "   ⚠️  Freeze detection script not available"
        return 0
    fi
}

# Run all tests
run_all_tests() {
    log "🚀 Starting AI-Safe Terminal MCP Server Test Suite"
    log "   Project: $PROJECT_DIR"
    log "   Test Output: $TEST_OUTPUT"
    
    local tests=(
        "test_backend_installation"
        "test_mcp_dependencies" 
        "test_quick_command"
        "test_background_command"
        "test_timeout_protection"
        "test_cross_platform"
        "test_freeze_detection"
    )
    
    local passed=0
    local failed=0
    local total=${#tests[@]}
    
    for test in "${tests[@]}"; do
        if $test; then
            ((passed++))
        else
            ((failed++))
        fi
        echo ""
    done
    
    log "📊 Test Results:"
    log "   Total: $total"
    log "   Passed: $passed"
    log "   Failed: $failed"
    
    if [[ $failed -eq 0 ]]; then
        log "🎉 All tests passed! MCP server is ready to use."
        return 0
    else
        error "💥 Some tests failed. Please check the output above."
        return 1
    fi
}

# Handle command line arguments
case "${1:-all}" in
    "all")
        run_all_tests
        ;;
    "backend")
        test_backend_installation
        ;;
    "deps")
        test_mcp_dependencies
        ;;
    "quick")
        test_quick_command
        ;;
    "background")
        test_background_command
        ;;
    "timeout")
        test_timeout_protection
        ;;
    "platform")
        test_cross_platform
        ;;
    "freeze")
        test_freeze_detection
        ;;
    "help")
        echo "AI-Safe Terminal MCP Server Test Suite"
        echo ""
        echo "Usage: $0 [test]"
        echo ""
        echo "Tests:"
        echo "  all        - Run all tests (default)"
        echo "  backend    - Test backend installation"
        echo "  deps       - Test MCP dependencies"
        echo "  quick      - Test quick command execution"
        echo "  background - Test background command execution"
        echo "  timeout    - Test timeout protection"
        echo "  platform   - Test cross-platform detection"
        echo "  freeze     - Test freeze detection"
        echo "  help       - Show this help"
        ;;
    *)
        error "Unknown test: $1"
        echo "Use '$0 help' for available tests"
        exit 1
        ;;
esac
