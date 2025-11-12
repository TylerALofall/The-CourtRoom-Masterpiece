#!/bin/bash

# START.sh - 9-Channel Ollama Orchestration System
# Integrates with HubStation and self_prompt_schema.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  9-Channel Model Orchestration System${NC}"
echo -e "${CYAN}  For: Section 1983 Legal Brief Drafting${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

# Check dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗${NC} Missing: $1"
        return 1
    fi
    echo -e "${GREEN}✓${NC} Found: $1"
    return 0
}

echo -e "\n${YELLOW}Checking dependencies...${NC}"
ALL_GOOD=true
check_dependency "jq" || ALL_GOOD=false
check_dependency "curl" || ALL_GOOD=false
check_dependency "python3" || ALL_GOOD=false
check_dependency "nc" || echo -e "${YELLOW}⚠${NC} netcat not found (optional)"

if [ "$ALL_GOOD" = false ]; then
    echo -e "\n${RED}Missing required dependencies. Install with:${NC}"
    echo -e "${YELLOW}sudo apt-get install jq curl python3 netcat${NC}"
    exit 1
fi

# Check Ollama
echo -e "\n${YELLOW}Checking Ollama...${NC}"
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Ollama not running at http://localhost:11434"
    echo -e "${YELLOW}Start Ollama first: ollama serve${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Ollama is running"

# Check if qwen3:latest is available
if ! curl -s http://localhost:11434/api/tags | jq -e '.models[] | select(.name == "qwen3:latest")' > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} qwen3:latest not found"
    echo -e "${YELLOW}Pulling qwen3:latest... (this may take a while)${NC}"
    ollama pull qwen3:latest
fi

# Initialize system
echo -e "\n${YELLOW}Initializing system...${NC}"
./control.sh start

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} System started successfully"
else
    echo -e "${RED}✗${NC} Failed to start system"
    exit 1
fi

# Check HubStation
echo -e "\n${YELLOW}Checking HubStation...${NC}"
if curl -s http://localhost:9099/status > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} HubStation is running at http://localhost:9099"
else
    echo -e "${YELLOW}⚠${NC} HubStation not detected (optional)"
    echo -e "  Start HubStation with: cd ../HubStation && ./admin_launch.cmd"
fi

# Display status
echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}System Ready!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}GUI Server:${NC}       http://localhost:8888"
echo -e "  ${YELLOW}Notifications:${NC}    localhost:9999"
echo -e "  ${YELLOW}Ollama:${NC}           http://localhost:11434"
echo -e "  ${YELLOW}HubStation:${NC}       http://localhost:9099"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Usage:${NC}"
echo -e "  ${GREEN}Interactive:${NC}  ./control.sh run"
echo -e "  ${GREEN}Batch:${NC}        ./control.sh batch \"Your prompt\""
echo -e "  ${GREEN}Status:${NC}       ./control.sh status"
echo -e "  ${GREEN}Stop:${NC}         ./control.sh stop"
echo -e "  ${GREEN}Logs:${NC}         ./control.sh logs latest"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Ask what to do
echo -e "${YELLOW}What would you like to do?${NC}"
echo "  1) Start interactive mode"
echo "  2) Check system status"
echo "  3) Exit"
read -p "Choice [1-3]: " choice

case "$choice" in
    1)
        echo -e "\n${GREEN}Starting interactive mode...${NC}\n"
        ./control.sh run
        ;;
    2)
        echo -e "\n${GREEN}System status:${NC}\n"
        ./control.sh status
        ;;
    3)
        echo -e "\n${YELLOW}System remains running in background${NC}"
        echo -e "Use ${GREEN}./control.sh stop${NC} to shut down"
        ;;
    *)
        echo -e "\n${RED}Invalid choice${NC}"
        ;;
esac
