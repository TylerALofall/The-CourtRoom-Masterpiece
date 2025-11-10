# Project Architecture (concise)

Components
- Frontend UI: scripts/index.html (served via HubStation /web)
- Hub server: HubStation/HubStation.ps1 (+ hub_config.json)
- Services: Ollama (LLM), Whisper.cpp (STT), optional Gemini API
- Data: IndexedDB in-browser for Evidence Cards; external Google Drive uploads

Flow (request paths)
- Browser → GET http://127.0.0.1:9099/web → static files from scripts/
- UI → HubStation JSON:
  - POST /chat → Ollama
  - POST /stt → Whisper.cpp
  - POST /heartbeat/*, GET /logs, /queue/* → local state/queues
- UI → Google: OAuth + multipart uploads
- UI → Gemini: POST /api/gemini/analyze (to be implemented)

Responsibilities
- scripts/: UI, components, and client logic
- HubStation/: local HTTP, static host, tool bridges, CORS, logging
- services/gemini-api/: minimal HTTP endpoint to forward Gemini requests (no prompt text stored here)
- services/ollama/: runbook and config for Ollama
- services/whisper/: runbook and config for Whisper.cpp

Contracts
- /chat: {model, messages[], options?} → {ok, response}
- /stt: {audioBase64|audioPath, extension, language?} → {ok, text}
- /queue: push/list/pop JSON objects (can carry 9-path prompt objects)
- /api/gemini/analyze: {model, contents[]} → passthrough to Gemini → UI parses text → fills fields

Non-goals here
- No prompt content committed
- No model weights in repo
