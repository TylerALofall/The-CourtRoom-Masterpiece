# Evidence Management System (Clean Structure)

Directories
- scripts/: Frontend UI (index.html remains root entry point)
- HubStation/: Local server (PowerShell) + config + README
- services/:
  - gemini-api/ (stub docs only)
  - ollama/ (LLM runbook)
  - whisper/ (STT runbook)
- docs/: Architecture & flow docs

Next wiring
- Implement /api/gemini/analyze (HubStation or Node).
- Install Ollama & Whisper assets.

Non-included
- No prompt texts stored in service stubs.
- Secrets expected via environment.

Refer to docs/ for deeper flow details.
