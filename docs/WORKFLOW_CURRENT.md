# Current Workflow (As Implemented Today)

This document captures the actual behavior of the hub, UI, and modules today—so you can correct it. No changes are proposed in this file.

- Startup
  - User launches `HubStation/Start-HubStation.ps1` → starts `HubStation.ps1` on port 9099; opens `/web`.
  - Config loaded/saved in `HubStation/hub_config.json` (Port, OllamaBaseUrl, voices, context/predict limits, StaticRoot).

- Core Endpoints (HubStation.ps1)
  - Status: `GET /status` → ok, port, model, voices, heartbeat state, limits.
  - Static site: `GET /web`, `/web/*` → serves `scripts/` by default.
  - Heartbeat: `POST /heartbeat/enable`, `GET /heartbeat/state`, `POST /heartbeat/tick` (server stores enabled/last/count).
  - Queue: `POST /queue/push`, `GET /queue/list`, `POST /queue/pop` (in-memory array; not auto-aggregated on heartbeat yet).
  - Notifications: `POST /notify/push`, `GET /notify/list`, `POST /notify/pop` (in-memory).
  - Chat: `POST /chat` → calls Ollama `/api/chat` non-stream; clamps num_ctx/num_predict.
  - STT: `POST /stt` → Whisper.cpp (writes temp WAV if base64 provided; path-based also supported).
  - TTS: `POST /tts` → System.Speech synth; optional save WAV.
  - Models: `GET /models` (tags), `GET /ollama/list`, `GET /ollama/ps`, `POST /ollama/pull`, `POST /ollama/stop`.
  - Reflections & Logs: `GET /logs` (in-memory buffer tail), `GET /logs/csv/tail`, `GET /reflect/window`, `POST /reflect/submit`.
  - Process: `POST /process/terminate` with pid (+ safety blocklist and self-protect).
  - Tools bridge: `POST /tool` → invokes external ToolBridge script if configured.

- Reflections Store (Reflections.psm1)
  - Initializes `shared_bus/{inbox,outbox,reflections,logs}`; CSV at `shared_bus/logs/hub_events.csv`.
  - CSV tail/window endpoints feed UI; submission writes JSON + logs a CSV row with meta tags.

- UI: `scripts/index.html` (floating side controller)
  - Compose: queues message (`/queue/push`) and concurrently calls `/chat` to show immediate reply under composer.
  - Mic → STT → Gemini: records audio, posts to `/stt`; inserts transcript into composer; auto-calls `/api/gemini/analyze`; shows results under composer.
  - Heartbeat modal: enables client-side interval → calls `/heartbeat/tick` every N minutes; server tracks `enabled/last/count`.
  - Logs: shows `/logs/csv/tail` (fallback `/logs`).
  - Recent processes: `/run { action: 'recent-processes' }`.
  - Stop: model stop via `/ollama/stop` or PID terminate via `/process/terminate`.
  - Notes: `/run { action: 'save-note' }`.

- ollama-gui.html (utilities)
  - Models list, pull, stop; simple prompt that calls `/chat`; TTS speak; optional schema insert for testing.

- Security / Safety
  - CORS `*` for GET/POST/OPTIONS.
  - Static path containment; process termination blocklist + self-protection.
  - Listener bound to 127.0.0.1/localhost only.

- Known Differences vs Target
  - No server-side compiled beat payload that auto-injects queued items into a flat array and re-prompts.
  - Reflection cadence not enforced server-side; client must trigger.
  - Gemini analyze path is wired; GeminiService is placeholder.
  - Cheatsheet/actions as top-level category keys not yet implemented as 1-deep array with auto-reprompt.
