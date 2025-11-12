#!/bin/bash

# Visual test of auto-echo loop
# Shows how commands chain back automatically

echo "═══════════════════════════════════════════════════════"
echo "  Testing Auto-Echo Network Loop"
echo "═══════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Setup test environment
mkdir -p data/state/{scratchpad,cheatsheet}

# Create test cheat sheet
cat > data/state/cheatsheet/test_tool.json << 'EOF'
{
  "name": "Test Tool",
  "purpose": "Demonstrates RAG fetch",
  "data": "This is test reference data"
}
EOF

echo -e "\n${YELLOW}Setup complete. Testing echo loop...${NC}\n"

# Simulate model response with multiple channels
echo -e "${CYAN}Simulating Model Response:${NC}"
cat << 'SIMJSON'
{
  "d_self_note": "Tested the echo loop system",
  "e_scratchpad": "{{Qwen3}}-Make-Notepad: Echo loop test note",
  "f_cheat_sheet": "test_tool",
  "g_terminal_call": "echo 'Terminal echo test' && pwd",
  "h_chat_message": "",
  "i_message_tyler": "",
  "response": "Testing all channels for auto-echo",
  "chain_next": "false"
}
SIMJSON

echo -e "\n${YELLOW}Processing channels...${NC}\n"

# Test (D) - Self note
echo -e "${GREEN}[D] Self Note:${NC} Saving to persistent notes..."
echo "[TEST] Tested the echo loop system" >> data/state/persistent_notes.txt
echo "  ✓ Saved"

# Test (E) - Scratchpad command
echo -e "\n${GREEN}[E] Scratchpad:${NC} {{Qwen3}}-Make-Notepad: Echo loop test note"
echo "Echo loop test note" >> data/state/scratchpad/Qwen3-Notes.txt
echo "  ✓ Executed: Saved to scratchpad/Qwen3-Notes.txt"

# Test (F) - Fetch cheat sheet
echo -e "\n${GREEN}[F] Cheat Sheet:${NC} Fetching test_tool..."
if [ -f data/state/cheatsheet/test_tool.json ]; then
    cat data/state/cheatsheet/test_tool.json
    echo -e "\n  ✓ Fetched and would return to model"
fi

# Test (G) - Terminal
echo -e "\n${GREEN}[G] Terminal:${NC} echo 'Terminal echo test' && pwd"
result=$(echo 'Terminal echo test' && pwd)
echo "$result"
echo "  ✓ Executed, output would return to model"

# Show what would chain back
echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Auto-Echo Result (goes back to model):${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

cat << 'ECHO'

PREVIOUS COMMAND RESULTS:
[D] Saved to persistent notes
[E] Scratchpad result:
Saved to data/state/scratchpad/Qwen3-Notes.txt

[F] Cheat sheet 'test_tool':
{
  "name": "Test Tool",
  "purpose": "Demonstrates RAG fetch",
  "data": "This is test reference data"
}

[G] Terminal command: echo 'Terminal echo test' && pwd
Exit code: 0
Output:
Terminal echo test
/home/user/The-CourtRoom-Masterpiece/runner_setup_skelleton

═══════════════════════════════════════════════════════
ECHO

echo -e "\n${GREEN}✓ Echo loop test complete!${NC}"
echo ""
echo "The model would receive all these results automatically"
echo "and can use them in the next response."
echo ""
echo -e "${YELLOW}Run actual test:${NC} ./auto_chain.sh \"Test the echo system\""
echo ""
