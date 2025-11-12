#!/bin/bash

# 9-Channel Model Orchestration Runner
# Integrates self_prompt_schema.json with routing system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/router.config"

# Paths
SCHEMA_PATH="../scripts/self_prompt_schema.json"
TEMPLATE_PATH="../scripts/self_prompt_template.json"
STATE_DIR="${DATA_DIR}/state"
NOTES_FILE="${STATE_DIR}/persistent_notes.txt"
SCRATCHPAD_DIR="${STATE_DIR}/scratchpad"
CHEATSHEET_DIR="${STATE_DIR}/cheatsheet"
LOG_FILE="${STATE_DIR}/model_log.txt"
HEARTBEAT_FILE="${STATE_DIR}/heartbeat_state.json"

# Create directories
mkdir -p "$STATE_DIR" "$SCRATCHPAD_DIR" "$CHEATSHEET_DIR"
touch "$NOTES_FILE" "$LOG_FILE"

# Initialize heartbeat state if not exists
if [ ! -f "$HEARTBEAT_FILE" ]; then
    echo '{"enabled":false,"interval":60,"last_pulse":0}' > "$HEARTBEAT_FILE"
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Get current epoch
get_epoch() {
    date +%s
}

# Get current epoch milliseconds
get_epoch_ms() {
    date +%s%3N
}

# Parse command format: {{Model}}-{{Action}}-{{Program}}: content
parse_command() {
    local input="$1"

    # Check if matches pattern {{X}}-{{Y}}-{{Z}}:
    if [[ "$input" =~ \{\{([^}]+)\}\}-\{\{([^}]+)\}\}-\{\{([^}]+)\}\}:[[:space:]]*(.*) ]]; then
        local model_name="${BASH_REMATCH[1]}"
        local action="${BASH_REMATCH[2]}"
        local program="${BASH_REMATCH[3]}"
        local content="${BASH_REMATCH[4]}"

        echo "PARSED|$model_name|$action|$program|$content"
        return 0
    fi

    return 1
}

# Execute parsed command
execute_command() {
    local model_name="$1"
    local action="$2"
    local program="$3"
    local content="$4"

    local timestamp=$(get_epoch)
    local result=""

    case "$action" in
        "Make"|"make")
            case "$program" in
                "Notepad"|"notepad"|"TXT"|"txt")
                    local filename="${SCRATCHPAD_DIR}/${model_name}-Notes.txt"
                    echo "$content" >> "$filename"
                    result="Saved to: $filename"
                    ;;
                "CSV"|"csv")
                    local filename="${SCRATCHPAD_DIR}/${model_name}-Notes.csv"
                    echo "$timestamp,$content" >> "$filename"
                    result="Saved to: $filename"
                    ;;
                *)
                    local filename="${SCRATCHPAD_DIR}/${model_name}-${program}.txt"
                    echo "$content" > "$filename"
                    result="Created: $filename"
                    ;;
            esac
            ;;
        "Fetch"|"fetch")
            case "$program" in
                "LOG"|"log")
                    # Default: last 5000 chars
                    local lines="${content:-100}"
                    result=$(tail -n "$lines" "$LOG_FILE")
                    ;;
                "Notes"|"notes")
                    result=$(cat "$NOTES_FILE")
                    ;;
                *)
                    local fetch_file="${CHEATSHEET_DIR}/${program}.json"
                    if [ -f "$fetch_file" ]; then
                        result=$(cat "$fetch_file")
                    else
                        result="Error: $program not found in cheatsheet"
                    fi
                    ;;
            esac
            ;;
        "Run"|"run"|"Execute"|"execute")
            # Terminal execution
            result=$(eval "$content" 2>&1)
            local exit_code=$?
            result="Exit Code: $exit_code\n$result"
            ;;
        *)
            result="Unknown action: $action"
            ;;
    esac

    echo "$result"
}

# Build 9-channel prompt
build_prompt() {
    local user_input="$1"
    local goal="$2"
    local heartbeat_interval="$3"

    local epoch=$(get_epoch)
    local heartbeat_state=$(cat "$HEARTBEAT_FILE" | jq -r '.enabled')
    local notes=$(cat "$NOTES_FILE")

    # Construct prompt with 9 channels
    local prompt="═══════════════════════════════════════════════════════
9-CHANNEL SCHEMA PROMPT
═══════════════════════════════════════════════════════

(A) EPOCH: $epoch
(B) HEARTBEAT: ${heartbeat_interval}s (Status: $heartbeat_state)
(C) GOAL: $goal

═══════════════════════════════════════════════════════
PAST NOTES (Persistent):
$(tail -c 2000 "$NOTES_FILE")
═══════════════════════════════════════════════════════

USER INPUT: $user_input

═══════════════════════════════════════════════════════
RESPONSE CHANNELS:

You MUST respond using these channels:

(D) SELF_NOTE: Your persistent notes (appends to future prompts)
(E) SCRATCHPAD: Commands in format {{Model}}-{{Action}}-{{Program}}: content
    Examples:
    - {{Qwen3}}-Make-Notepad: Save this observation
    - {{Qwen3}}-Fetch-LOG: Get last 100 lines
    - {{Qwen3}}-Run-Terminal: ls -la

(F) CHEAT_SHEET: Tool/RAG calls (fetches reference docs)
(G) TERMINAL_CALL: Shell commands to execute
(H) CHAT_MESSAGE: Message to other models
(I) MESSAGE_TYLER: Direct message to Tyler
    - MESSAGE_TYLER: Normal message
    - MESSAGE_TYLER_IMPORTANT: Urgent (with popup)

═══════════════════════════════════════════════════════
RESPOND IN JSON FORMAT:
{
  \"d_self_note\": \"your persistent notes\",
  \"e_scratchpad\": \"{{Model}}-{{Action}}-{{Program}}: content\",
  \"f_cheat_sheet\": \"tool to fetch (or empty)\",
  \"g_terminal_call\": \"command to run (or empty)\",
  \"h_chat_message\": \"message to other models (or empty)\",
  \"i_message_tyler\": \"message for Tyler (or empty)\",
  \"i_message_tyler_important\": \"urgent message (or empty)\",
  \"response\": \"your main response to user\"
}
═══════════════════════════════════════════════════════"

    echo "$prompt"
}

# Call Qwen3 with 9-channel schema
call_qwen3() {
    local prompt="$1"

    # Log the prompt
    echo -e "\n═══ PROMPT $(get_epoch) ═══" >> "$LOG_FILE"
    echo "$prompt" >> "$LOG_FILE"

    # Call Ollama
    local response=$(curl -s http://localhost:11434/api/generate -d "{
        \"model\": \"qwen3:latest\",
        \"prompt\": $(echo "$prompt" | jq -Rs .),
        \"stream\": false,
        \"format\": \"json\",
        \"options\": {
            \"temperature\": 0.7,
            \"top_p\": 0.9
        }
    }" | jq -r '.response')

    # Log the response
    echo -e "\n═══ RESPONSE $(get_epoch) ═══" >> "$LOG_FILE"
    echo "$response" >> "$LOG_FILE"

    echo "$response"
}

# Process 9-channel response
process_response() {
    local json_response="$1"

    # Extract each channel
    local d_note=$(echo "$json_response" | jq -r '.d_self_note // empty')
    local e_scratch=$(echo "$json_response" | jq -r '.e_scratchpad // empty')
    local f_cheat=$(echo "$json_response" | jq -r '.f_cheat_sheet // empty')
    local g_terminal=$(echo "$json_response" | jq -r '.g_terminal_call // empty')
    local h_chat=$(echo "$json_response" | jq -r '.h_chat_message // empty')
    local i_tyler=$(echo "$json_response" | jq -r '.i_message_tyler // empty')
    local i_tyler_imp=$(echo "$json_response" | jq -r '.i_message_tyler_important // empty')
    local response=$(echo "$json_response" | jq -r '.response // empty')

    echo -e "\n${CYAN}═══ Processing 9-Channel Response ═══${NC}"

    # (D) Self Note - Append to persistent notes
    if [ -n "$d_note" ] && [ "$d_note" != "null" ]; then
        echo -e "${YELLOW}[D] SELF NOTE:${NC} Saving to persistent memory..."
        echo -e "\n[$(get_epoch)] $d_note" >> "$NOTES_FILE"
    fi

    # (E) Scratchpad - Parse and execute command
    if [ -n "$e_scratch" ] && [ "$e_scratch" != "null" ]; then
        echo -e "${YELLOW}[E] SCRATCHPAD:${NC} $e_scratch"
        local parsed=$(parse_command "$e_scratch")
        if [ $? -eq 0 ]; then
            IFS='|' read -r status model action program content <<< "$parsed"
            echo -e "  Executing: $model → $action → $program"
            local cmd_result=$(execute_command "$model" "$action" "$program" "$content")
            echo -e "  Result: $cmd_result"
        fi
    fi

    # (F) Cheat Sheet - Fetch RAG tool
    if [ -n "$f_cheat" ] && [ "$f_cheat" != "null" ]; then
        echo -e "${YELLOW}[F] CHEAT SHEET:${NC} Fetching: $f_cheat"
        local tool_file="${CHEATSHEET_DIR}/${f_cheat}.json"
        if [ -f "$tool_file" ]; then
            echo -e "  Found: $tool_file"
            cat "$tool_file" | head -c 500
        else
            echo -e "  ${RED}Not found:${NC} $f_cheat"
        fi
    fi

    # (G) Terminal Call
    if [ -n "$g_terminal" ] && [ "$g_terminal" != "null" ]; then
        echo -e "${YELLOW}[G] TERMINAL:${NC} Executing: $g_terminal"
        local term_result=$(eval "$g_terminal" 2>&1)
        echo -e "${GREEN}Output:${NC}\n$term_result"
        # Log terminal output
        echo -e "\n[TERMINAL $(get_epoch)] $g_terminal\n$term_result" >> "$LOG_FILE"
    fi

    # (H) Chat Message
    if [ -n "$h_chat" ] && [ "$h_chat" != "null" ]; then
        echo -e "${YELLOW}[H] CHAT MESSAGE:${NC} $h_chat"
        echo "$h_chat" > "${STATE_DIR}/chat_message_$(get_epoch).txt"
    fi

    # (I) Message Tyler
    if [ -n "$i_tyler" ] && [ "$i_tyler" != "null" ]; then
        echo -e "${YELLOW}[I] MESSAGE TYLER:${NC} $i_tyler"
        ./notify.sh "Model Message" "$i_tyler"
    fi

    if [ -n "$i_tyler_imp" ] && [ "$i_tyler_imp" != "null" ]; then
        echo -e "${RED}[I] IMPORTANT FOR TYLER:${NC} $i_tyler_imp"
        ./notify.sh "⚠️ IMPORTANT" "$i_tyler_imp"
        # Also save to important log
        echo "[$(get_epoch)] IMPORTANT: $i_tyler_imp" >> "${STATE_DIR}/tyler_important.log"
    fi

    # Main response
    echo -e "\n${GREEN}═══ Model Response ═══${NC}"
    echo "$response"
    echo -e "${CYAN}══════════════════════${NC}\n"
}

# Main execution
main() {
    local user_input="$1"
    local goal="${2:-Building 9th Circuit Section 1983 legal brief for false arrest case}"
    local heartbeat="${3:-60}"

    # Build prompt
    local full_prompt=$(build_prompt "$user_input" "$goal" "$heartbeat")

    # Call model
    echo -e "${CYAN}Calling Qwen3...${NC}"
    local model_response=$(call_qwen3 "$full_prompt")

    # Process response
    process_response "$model_response"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ $# -eq 0 ]; then
        echo "Usage: $0 \"your prompt\" [goal] [heartbeat_interval]"
        exit 1
    fi
    main "$@"
fi
