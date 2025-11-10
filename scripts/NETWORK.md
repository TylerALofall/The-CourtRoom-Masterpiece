# Network and Service Map

- **Purpose**: Single reference for how the local stack fits together so you can run, test, and debug fast.
- **Scope**: HubStation (9099), Ollama (11434), Chrome DevTools MCP (9222), and personal-website static UI.

## Overview
- **HubStation (PowerShell HttpListener)**
  - Listens on: http://127.0.0.1:9099
  - Proxies to Ollama at: http://127.0.0.1:11434
  - Serves static site: /web → d:\THE_ESCAPE\personal-website
  - API endpoints: /status, /models, /chat, /tts, /voices, /ollama/pull, /ollama/stop, /ollama/ps, /queue/*, /heartbeat/*
- **Ollama**
  - Listens on: http://127.0.0.1:11434
  - Endpoints used by HubStation: /api/version, /api/tags, /api/chat
- **Chrome DevTools MCP (optional)**
  - Connects to Chrome at: http://127.0.0.1:9222
  - Configured in: d:\THE_ESCAPE\MCP\mcp.json (server: chrome-devtools-mcp@latest)

## Ports and URLs
- 9099 → HubStation base (local): http://127.0.0.1:9099
- 11434 → Ollama API: http://127.0.0.1:11434
- 9222 → Chrome remote debugging (MCP): http://127.0.0.1:9222

## HubStation API (quick reference)
- GET /status → health + defaults
- GET /models → list of available models (maps to Ollama /api/tags)
- POST /chat → { model, messages:[{role,content}], temperature }
- POST /tts → { text, voice?, rate?, volume? }
- GET /voices → { default, voices:[...] }
- POST /ollama/pull → { model }
- POST /ollama/stop → { model }
- GET /ollama/ps → running models/process info
- GET /queue/list → hub queue counts (optional)
- POST /queue/pop → { release: 'immediate'|'heartbeat'|'end', max? }
- GET /heartbeat/state → { enabled, last }
- GET /web → serves d:\THE_ESCAPE\personal-website

### Example calls (PowerShell)
- Status
  - irm http://127.0.0.1:9099/status | ConvertTo-Json -Depth 6
- Pull a model
  - irm -Method Post http://127.0.0.1:9099/ollama/pull -ContentType application/json -Body '{"model":"qwen3:latest"}'
- Chat
  - $b=@{model='qwen3:latest';temperature=0.7;messages=@(@{role='user';content='Say hello'})}|ConvertTo-Json -Depth 6; irm -Method Post http://127.0.0.1:9099/chat -ContentType application/json -Body $b
- TTS
  - irm -Method Post http://127.0.0.1:9099/tts -ContentType application/json -Body '{"text":"Hello Tyler","voice":"Microsoft Brian","rate":0,"volume":100}'

## Ollama API (used indirectly)
- GET /api/version → check Ollama is running
- GET /api/tags → list models
- POST /api/chat → chat completions (HubStation calls this for you)

## Static UI
- Base: http://127.0.0.1:9099/web
- Ollama GUI: http://127.0.0.1:9099/web/ollama-gui.html
  - Model list, Pull/Stop model, Chat, Speak (Windows TTS)
  - Self-prompt schema helpers: Insert Template, Send w/ Schema

## Configuration
- File: d:\THE_ESCAPE\HubStation\hub_config.json
  - Keys (typical):
    - Port: 9099
    - OllamaBaseUrl: "http://127.0.0.1:11434"
    - DefaultModel: "qwen3:latest"
    - DefaultVoice: "Microsoft Brian"

## Launch & Health
- HubStation (adds URL ACLs & starts):
  - d:\THE_ESCAPE\HubStation\admin_launch.cmd
- Ollama:
  - Start: Start-Process -WindowStyle Minimized -FilePath "ollama" -ArgumentList "serve"
- Health checks:
  - HubStation: GET /status
  - Ollama: curl http://127.0.0.1:11434/api/version

## Troubleshooting
- /models returns error → Start Ollama, then pull a model (qwen3 or qwen2.5)
- TTS voice missing → Use default (no voice), or choose Brian/Mark
- Port/permission issues → Re-run admin_launch.cmd to refresh URL ACLs
- Static site not loading → Confirm path d:\THE_ESCAPE\personal-website exists and index.html loads

---
Last updated: (local)
