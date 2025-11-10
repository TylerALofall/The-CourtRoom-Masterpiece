# Ollama Service

HubStation integration
- HubStation /chat, /ollama/list, /ollama/ps, /ollama/pull, /ollama/stop map to Ollama CLI or REST.

Prerequisites
- Ollama installed locally.
- Model (e.g., qwen3:latest) pulled.

Runbook
1. Start Ollama daemon (default listens at 127.0.0.1:11434).
2. Pull required model: `ollama pull qwen3:latest`.
3. Verify: GET http://127.0.0.1:11434/api/tags returns models.
4. Use UI mini chat → POST /chat to test.

Failure modes
- 404 /api/chat: daemon not running.
- Empty response: model not pulled.

Performance
- num_ctx & num_predict clamped by HubStation.
