# HubStation

What it is
- Local HTTP server (PowerShell) exposing endpoints and serving the UI.

Serve static site
- StaticRoot resolved from hub_config.json (default: ..\\scripts)
- GET /web → index.html from StaticRoot

Key endpoints
- GET /status, GET /logs
- POST /queue/push, GET /queue/list, POST /queue/pop
- POST /heartbeat/enable, /heartbeat/tick, GET /heartbeat/state
- GET /models, /ollama/list, /ollama/ps; POST /ollama/pull, /ollama/stop
- POST /chat (to Ollama)
- POST /stt (to whisper.cpp)

Admin startup
- Run admin_launch.cmd → adds URLACL and starts HubStation.ps1.

Notes
- CORS enabled ('*').
- Logs buffer up to ~2000 lines, /logs?n=200 tails.
