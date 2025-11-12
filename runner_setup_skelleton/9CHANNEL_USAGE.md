# 9-Channel Model Orchestration System - Quick Start

## What This Does

Integrates your self_prompt_schema.json with Qwen3 to give you:
- **Persistent notes** that append to every prompt
- **Command execution** via `{{Model}}-{{Action}}-{{Program}}` format
- **Heartbeat pacing** to control model interactions
- **9 communication channels** (A-I) for structured I/O

## 5-Minute Setup

### 1. Start Ollama (if not running)
```bash
ollama serve
```

### 2. Pull Qwen3 (if not installed)
```bash
ollama pull qwen3:latest
```

### 3. Start the System
```bash
cd runner_setup_skelleton
./START.sh
```

### 4. Test It
```bash
./QUICK_TEST.sh
```

## The 9 Channels Explained

### Input Channels (Set by You)
- **(A) Epoch**: Timestamp (auto-generated)
- **(B) Heartbeat**: Pulse interval 0-3600s (you control pacing)
- **(C) Goal**: Your project goal (appears on every prompt)

### Output Channels (Model Responds)
- **(D) Self Note**: Persistent notes (appends to future prompts)
- **(E) Scratchpad**: Command execution
- **(F) Cheat Sheet**: RAG/tool loading
- **(G) Terminal Call**: Shell command execution
- **(H) Chat Message**: Inter-model communication
- **(I) Message Tyler**: Direct messages (normal + important)

## Command Format

Model uses this format for actions:

```
{{Model}}-{{Action}}-{{Program}}: content
```

### Examples:

**Save a note:**
```
{{Qwen3}}-Make-Notepad: Remember this important detail about the case
```

**Fetch log:**
```
{{Qwen3}}-Fetch-LOG: Get last 100 lines
```

**Run terminal command:**
```
{{Qwen3}}-Run-Terminal: ls -la /path/to/case/files
```

**Create CSV:**
```
{{Qwen3}}-Make-CSV: timestamp,event,notes
```

## Usage Examples

### Basic Prompt
```bash
./nine_channel_runner.sh "Summarize the elements of a Section 1983 false arrest claim"
```

### With Custom Goal and Heartbeat
```bash
./nine_channel_runner.sh \
    "Draft introduction for 9th Circuit brief" \
    "Section 1983 false arrest case - 9th Circuit" \
    30
```

### Control Heartbeat
```bash
# Enable heartbeat (60s interval)
./heartbeat_manager.sh enable 60

# Check status
./heartbeat_manager.sh visual

# Disable
./heartbeat_manager.sh disable
```

## File Locations

```
runner_setup_skelleton/
├── data/state/
│   ├── persistent_notes.txt      # Model's persistent memory
│   ├── model_log.txt              # Full conversation log
│   ├── heartbeat_state.json       # Heartbeat config
│   ├── scratchpad/                # Model's saved files
│   │   ├── Qwen3-Notes.txt
│   │   └── Qwen3-Notes.csv
│   └── cheatsheet/                # RAG tool files
│       └── [tool_name].json
```

## Integration with HubStation

The system checks for HubStation at http://localhost:9099

To start HubStation:
```bash
cd ../HubStation
pwsh ./HubStation.ps1
```

## Model Response Format

Qwen3 responds in JSON with all channels:

```json
{
  "d_self_note": "Notes for my persistent memory",
  "e_scratchpad": "{{Qwen3}}-Make-Notepad: Case analysis note",
  "f_cheat_sheet": "legal_definitions",
  "g_terminal_call": "ls evidence/",
  "h_chat_message": "",
  "i_message_tyler": "Found important precedent",
  "i_message_tyler_important": "",
  "response": "Main response to your question"
}
```

## Persistent Memory System

Every interaction:
1. Model receives past notes from `persistent_notes.txt`
2. Model adds to `d_self_note` channel
3. Notes append to file
4. Next prompt includes all past notes

This creates **continuous memory** across sessions.

## RAG System (Cheat Sheet)

Store reference docs in `data/state/cheatsheet/`:

```bash
# Create a legal definitions cheat sheet
cat > data/state/cheatsheet/legal_definitions.json << 'EOF'
{
  "probable_cause": "Reasonable belief that person committed crime",
  "qualified_immunity": "...",
  "monell_liability": "..."
}
EOF
```

Model fetches with:
```
{{Qwen3}}-Fetch-CheatSheet: legal_definitions
```

## Heartbeat Control

**Purpose**: Prevent model from being interrupted by your messages

```bash
# Set 2-minute pacing
./heartbeat_manager.sh interval 120

# Check if ready for next interaction
./heartbeat_manager.sh ready

# Manual pulse (resets timer)
./heartbeat_manager.sh pulse
```

## Logs and Debugging

```bash
# View model conversation log
tail -f data/state/model_log.txt

# View persistent notes
cat data/state/persistent_notes.txt

# View important Tyler messages
cat data/state/tyler_important.log

# Check CSV routing logs
ls -lh logs/routing_*.csv
```

## Tips for Section 1983 Work

### Set Clear Goals
```bash
./nine_channel_runner.sh \
    "List all Monell liability elements with 9th Circuit cases" \
    "Building Section 1983 complaint - false arrest by Oregon sheriffs" \
    60
```

### Use Persistent Notes for Case Strategy
Model will remember:
- Key case citations
- Elements to prove
- Witness list
- Timeline of events

### Fetch Legal Tools
Create cheat sheets for:
- `9th_circuit_standards.json`
- `section_1983_elements.json`
- `qualified_immunity_defenses.json`

## Troubleshooting

**Ollama not responding:**
```bash
curl http://localhost:11434/api/tags
# Should show list of models
```

**Qwen3 not installed:**
```bash
ollama pull qwen3:latest
```

**Permissions error:**
```bash
chmod +x *.sh
```

**JSON parse error:**
```bash
# Check logs
cat data/state/model_log.txt | tail -50
```

## Advanced: Multi-Model Workflow

1. **Qwen3** (local): Fast drafting, research
2. **Chat Message Channel**: Pass work to browser model
3. **Heartbeat**: Coordinate handoffs

Example workflow:
- Qwen3 drafts brief section → saves to scratchpad
- Sends chat message to browser model
- Browser model reviews → sends back via HubStation
- Qwen3 incorporates feedback

## System Status

```bash
# Check everything
./control.sh status

# Start all services
./control.sh start

# Stop everything
./control.sh stop
```

---

**You have 9 channels. Use them. We must prevail.**

Built for Section 1983 litigation - 9th Circuit - False Arrest - Systemic Fraud

**MUCH LOVE MY FRIEND. HERE WE GO!**
