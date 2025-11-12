#!/bin/bash

# Auto-Chain Network Loop
# Automatically echoes command responses back to model for chaining

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/router.config"

STATE_DIR="${DATA_DIR}/state"
NOTES_FILE="${STATE_DIR}/persistent_notes.txt"
LOG_FILE="${STATE_DIR}/model_log.txt"
CHAIN_FILE="${STATE_DIR}/chain_history.txt"

mkdir -p "$STATE_DIR"
touch "$NOTES_FILE" "$LOG_FILE" "$CHAIN_FILE"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

get_epoch() {
    date +%s
}

# Build prompt with A, B, C headers (cosmetic only)
build_prompt_header() {
    local user_input="$1"
    local goal="$2"
    local heartbeat="$3"
    local chain_context="$4"

    local epoch=$(get_epoch)

    cat << EOF
═══════════════════════════════════════════════════════
(A) EPOCH: $epoch
(B) HEARTBEAT: ${heartbeat}s (you'll be woken up every ${heartbeat}s)
(C) GOAL: $goal
═══════════════════════════════════════════════════════

PERSISTENT NOTES:
$(tail -c 1500 "$NOTES_FILE" 2>/dev/null || echo "No notes yet")

═══════════════════════════════════════════════════════
EOF

    # Add chain context if this is a follow-up
    if [ -n "$chain_context" ]; then
        cat << EOF
PREVIOUS COMMAND RESULT:
$chain_context
═══════════════════════════════════════════════════════
EOF
    fi

    cat << EOF
USER INPUT: $user_input

═══════════════════════════════════════════════════════
RESPOND IN JSON:
{
  "d_self_note": "your persistent notes (appends to memory)",
  "e_scratchpad": "{{Model}}-{{Action}}-{{Program}}: content",
  "f_cheat_sheet": "tool name to fetch",
  "g_terminal_call": "command to execute",
  "h_chat_message": "message to other models",
  "i_message_tyler": "normal message",
  "i_message_tyler_important": "urgent message",
  "response": "your main response",
  "chain_next": "true|false - do you need another turn with results?"
}

CHANNEL EXAMPLES:
- {{Qwen3}}-Make-Notepad: case notes here
- {{Qwen3}}-Fetch-LOG: 100
- {{Qwen3}}-Run-Terminal: ls -la
═══════════════════════════════════════════════════════
EOF
}

# Call model
call_model() {
    local prompt="$1"

    echo -e "${CYAN}→ Calling Qwen3...${NC}"

    # Log prompt
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
            \"top_p\": 0.9,
            \"num_ctx\": 8192
        }
    }" | jq -r '.response')

    # Log response
    echo -e "\n═══ RESPONSE $(get_epoch) ═══" >> "$LOG_FILE"
    echo "$response" >> "$LOG_FILE"

    echo "$response"
}

# Execute commands and collect results
execute_channels() {
    local json_response="$1"

    local results=""

    # (D) Self Note
    local d_note=$(echo "$json_response" | jq -r '.d_self_note // empty')
    if [ -n "$d_note" ] && [ "$d_note" != "null" ]; then
        echo -e "${YELLOW}[D] SELF NOTE:${NC} Saving..."
        echo -e "\n[$(get_epoch)] $d_note" >> "$NOTES_FILE"
        results+="[D] Saved to persistent notes\n"
    fi

    # (E) Scratchpad command
    local e_scratch=$(echo "$json_response" | jq -r '.e_scratchpad // empty')
    if [ -n "$e_scratch" ] && [ "$e_scratch" != "null" ]; then
        echo -e "${YELLOW}[E] SCRATCHPAD:${NC} $e_scratch"

        # Parse {{Model}}-{{Action}}-{{Program}}: content
        if [[ "$e_scratch" =~ \{\{([^}]+)\}\}-\{\{([^}]+)\}\}-\{\{([^}]+)\}\}:[[:space:]]*(.*) ]]; then
            local model="${BASH_REMATCH[1]}"
            local action="${BASH_REMATCH[2]}"
            local program="${BASH_REMATCH[3]}"
            local content="${BASH_REMATCH[4]}"

            local cmd_result=$(execute_scratchpad_command "$model" "$action" "$program" "$content")
            results+="[E] Scratchpad result:\n$cmd_result\n\n"
            echo -e "  ${GREEN}Result:${NC} $cmd_result"
        fi
    fi

    # (F) Cheat Sheet
    local f_cheat=$(echo "$json_response" | jq -r '.f_cheat_sheet // empty')
    if [ -n "$f_cheat" ] && [ "$f_cheat" != "null" ]; then
        echo -e "${YELLOW}[F] CHEAT SHEET:${NC} Fetching: $f_cheat"
        local cheat_file="${STATE_DIR}/cheatsheet/${f_cheat}.json"
        if [ -f "$cheat_file" ]; then
            local cheat_content=$(cat "$cheat_file")
            results+="[F] Cheat sheet '$f_cheat':\n$cheat_content\n\n"
            echo -e "  ${GREEN}Loaded${NC}"
        else
            results+="[F] Cheat sheet '$f_cheat' not found\n\n"
            echo -e "  ${RED}Not found${NC}"
        fi
    fi

    # (G) Terminal
    local g_terminal=$(echo "$json_response" | jq -r '.g_terminal_call // empty')
    if [ -n "$g_terminal" ] && [ "$g_terminal" != "null" ]; then
        echo -e "${YELLOW}[G] TERMINAL:${NC} $g_terminal"
        local term_output=$(eval "$g_terminal" 2>&1)
        local exit_code=$?
        results+="[G] Terminal command: $g_terminal\nExit code: $exit_code\nOutput:\n$term_output\n\n"
        echo -e "  ${GREEN}Exit code: $exit_code${NC}"
    fi

    # (H) Chat message
    local h_chat=$(echo "$json_response" | jq -r '.h_chat_message // empty')
    if [ -n "$h_chat" ] && [ "$h_chat" != "null" ]; then
        echo -e "${YELLOW}[H] CHAT MESSAGE:${NC} $h_chat"
        echo "$h_chat" > "${STATE_DIR}/chat_out_$(get_epoch).txt"
        results+="[H] Chat message sent\n\n"
    fi

    # (I) Message Tyler
    local i_tyler=$(echo "$json_response" | jq -r '.i_message_tyler // empty')
    if [ -n "$i_tyler" ] && [ "$i_tyler" != "null" ]; then
        echo -e "${YELLOW}[I] TYLER:${NC} $i_tyler"
        ./notify.sh "Qwen3" "$i_tyler" 2>/dev/null || echo "  (notification skipped)"
    fi

    local i_tyler_imp=$(echo "$json_response" | jq -r '.i_message_tyler_important // empty')
    if [ -n "$i_tyler_imp" ] && [ "$i_tyler_imp" != "null" ]; then
        echo -e "${RED}[I] TYLER IMPORTANT:${NC} $i_tyler_imp"
        ./notify.sh "⚠️ IMPORTANT" "$i_tyler_imp" 2>/dev/null || echo "  (notification skipped)"
        echo "[$(get_epoch)] IMPORTANT: $i_tyler_imp" >> "${STATE_DIR}/tyler_important.log"
    fi

    # Return all results for chaining
    echo "$results"
}

# Execute scratchpad command
execute_scratchpad_command() {
    local model="$1"
    local action="$2"
    local program="$3"
    local content="$4"

    case "$action" in
        Make|make)
            case "$program" in
                Notepad|notepad|txt|TXT)
                    local file="${STATE_DIR}/scratchpad/${model}-Notes.txt"
                    echo "$content" >> "$file"
                    echo "Saved to $file"
                    ;;
                CSV|csv)
                    local file="${STATE_DIR}/scratchpad/${model}-Notes.csv"
                    echo "$(get_epoch),$content" >> "$file"
                    echo "Appended to $file"
                    ;;
                *)
                    local file="${STATE_DIR}/scratchpad/${model}-${program}.txt"
                    echo "$content" > "$file"
                    echo "Created $file"
                    ;;
            esac
            ;;
        Fetch|fetch)
            case "$program" in
                LOG|log|Log)
                    local lines="${content:-100}"
                    tail -n "$lines" "$LOG_FILE"
                    ;;
                Notes|notes)
                    cat "$NOTES_FILE"
                    ;;
                *)
                    local file="${STATE_DIR}/cheatsheet/${program}.json"
                    if [ -f "$file" ]; then
                        cat "$file"
                    else
                        echo "Error: $program not found"
                    fi
                    ;;
            esac
            ;;
        Run|run|Execute|execute)
            eval "$content" 2>&1
            ;;
        *)
            echo "Unknown action: $action"
            ;;
    esac
}

# Main auto-chain loop
auto_chain() {
    local user_input="$1"
    local goal="$2"
    local heartbeat="${3:-60}"
    local max_chains="${4:-5}"

    local chain_context=""
    local chain_count=0

    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Auto-Chain Network Loop - Starting${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

    while [ $chain_count -lt $max_chains ]; do
        echo -e "\n${YELLOW}═══ Chain #$((chain_count + 1)) ═══${NC}"

        # Build prompt
        local prompt=$(build_prompt_header "$user_input" "$goal" "$heartbeat" "$chain_context")

        # Call model
        local response=$(call_model "$prompt")

        # Parse response
        local main_response=$(echo "$response" | jq -r '.response // empty')
        local chain_next=$(echo "$response" | jq -r '.chain_next // "false"')

        echo -e "\n${GREEN}═══ Model Says ═══${NC}"
        echo "$main_response"
        echo -e "${GREEN}══════════════════${NC}"

        # Execute channels and get results
        echo -e "\n${CYAN}→ Executing channels...${NC}"
        local execution_results=$(execute_channels "$response")

        # Save to chain history
        echo -e "\n═══ CHAIN #$((chain_count + 1)) $(get_epoch) ═══" >> "$CHAIN_FILE"
        echo "USER: $user_input" >> "$CHAIN_FILE"
        echo "RESPONSE: $main_response" >> "$CHAIN_FILE"
        echo "RESULTS: $execution_results" >> "$CHAIN_FILE"

        # Check if model wants to chain
        if [ "$chain_next" != "true" ]; then
            echo -e "\n${GREEN}✓ Chain complete - model doesn't need another turn${NC}"
            break
        fi

        # Prepare context for next chain
        chain_context="$execution_results"
        user_input="Continue based on the results above"
        chain_count=$((chain_count + 1))

        if [ $chain_count -lt $max_chains ]; then
            echo -e "\n${YELLOW}→ Model requested another turn, auto-chaining...${NC}"
            sleep 1
        else
            echo -e "\n${RED}⚠ Max chains ($max_chains) reached${NC}"
        fi
    done

    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Auto-Chain Complete - $chain_count iteration(s)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ $# -eq 0 ]; then
        echo "Usage: $0 \"prompt\" [goal] [heartbeat] [max_chains]"
        echo ""
        echo "Examples:"
        echo "  $0 \"List files in evidence dir\""
        echo "  $0 \"Analyze Section 1983 elements\" \"False arrest brief\" 30 3"
        exit 1
    fi

    auto_chain "$@"
fi
