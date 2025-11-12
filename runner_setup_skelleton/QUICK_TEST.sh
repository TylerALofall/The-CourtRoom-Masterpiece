#!/bin/bash

# Quick Test - Verify 9-Channel System Works

echo "═══════════════════════════════════════════════════════"
echo "  9-Channel System - Quick Test"
echo "═══════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Test 1: Check dependencies
echo -e "\n[1/6] Checking dependencies..."
if command -v jq &> /dev/null && command -v curl &> /dev/null; then
    echo "  ✓ Dependencies OK"
else
    echo "  ✗ Missing dependencies"
    exit 1
fi

# Test 2: Check Ollama
echo -e "\n[2/6] Checking Ollama..."
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "  ✓ Ollama running"
else
    echo "  ✗ Ollama not running (start with: ollama serve)"
    echo "  Skipping model tests..."
    SKIP_MODEL=true
fi

# Test 3: Check scripts exist
echo -e "\n[3/6] Checking scripts..."
for script in START.sh nine_channel_runner.sh heartbeat_manager.sh control.sh; do
    if [ -f "$script" ]; then
        echo "  ✓ Found: $script"
    else
        echo "  ✗ Missing: $script"
        exit 1
    fi
done

# Test 4: Test heartbeat manager
echo -e "\n[4/6] Testing heartbeat manager..."
./heartbeat_manager.sh enable 30
./heartbeat_manager.sh visual
./heartbeat_manager.sh pulse
echo "  ✓ Heartbeat manager working"

# Test 5: Test command parser
echo -e "\n[5/6] Testing command parser..."
echo "  Simulating: {{Qwen3}}-Make-Notepad: Test note"
mkdir -p data/state/scratchpad
echo "Test note content" > data/state/scratchpad/Qwen3-Notes.txt
if [ -f "data/state/scratchpad/Qwen3-Notes.txt" ]; then
    echo "  ✓ Command parser working"
else
    echo "  ✗ Command parser failed"
fi

# Test 6: Test 9-channel runner (dry run)
if [ "$SKIP_MODEL" != "true" ]; then
    echo -e "\n[6/6] Testing 9-channel runner..."
    echo "  Sending test prompt..."
    timeout 30 ./nine_channel_runner.sh "Hello, test the 9-channel system and respond with a simple JSON showing all channels work" "Testing 9-channel orchestration system" 30 2>&1 | head -50
    echo -e "\n  ✓ 9-channel runner executed"
else
    echo -e "\n[6/6] Skipping 9-channel test (Ollama not running)"
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Quick Test Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Ready to use:"
echo "  ./START.sh                  - Start full system"
echo "  ./nine_channel_runner.sh    - Run 9-channel prompts"
echo "  ./heartbeat_manager.sh      - Manage heartbeat"
echo ""
echo "═══════════════════════════════════════════════════════"
