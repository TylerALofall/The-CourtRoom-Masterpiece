# Functional Flow Overview

1. Page Load
Browser requests /web → HubStation serves scripts/index.html.

2. User Actions → UI Logic
- Evidence form: writes to IndexedDB only.
- Upload files: Google OAuth then POST to Drive API.
- Mic record: capture audio → POST /stt → transcript returned.
- Compose/send queue message: POST /queue/push.
- Heartbeat enable: POST /heartbeat/enable; ticks POST /heartbeat/tick.
- Mini chat: POST /chat → Ollama response.
- Logs modal: GET /logs.

3. External Services
- Ollama: provides model responses for /chat.
- Whisper.cpp: executable invoked by /stt pipeline.
- Gemini API: NOT YET WIRED. Will serve auto-fill functionality.

4. Data Persistence
- Evidence cards: IndexedDB object store 'evidence_cards'.
- Uploaded files: Google Drive.
- Transcripts: ephemeral (user can save via note → /run save-note).
- Queue/log buffers: in-memory HubStation arrays.

5. Error Handling Patterns
- HubStation endpoints return { ok:false, error } with HTTP 4xx/5xx.
- UI uses showStatus(type) for short-lived notifications.
- Missing service (Ollama/Whisper) surfaces as error toast; UI still functional.

6. Extension Points
- /api/gemini/analyze route
- Consumer agent that polls /queue/pop to process 9-path objects.

7. Security / Isolation
- Localhost only (127.0.0.1). CORS '*' currently; can tighten later.
- Secrets (API keys) expected via environment, not repo.

8. Performance Considerations
- IndexedDB operations small; no server DB yet.
- Whisper.cpp invoked per STT request; consider queueing if frequent.
- Ollama chat synchronous; potential future streaming not used.
