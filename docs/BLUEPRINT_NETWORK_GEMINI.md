# Blueprint: Network Flow + Gemini Toggle (UID/File Contract)

Date: 2025-11-12
Scope: Describe the end-to-end flowchart and steps to get the network running, when to switch to Gemini, and how UID/file pairing must behave. This is a plan-only doc. No code changes are performed here.

## High-Level Flow (Mermaid)

```mermaid
flowchart TD
    A[User Input] -->|Mic| B[STT]
    A -->|Chat Send| C[Queue Push]
    B --> D[Insert Transcript into Composer]
    D --> E{Gemini Toggle?}
    C --> F{Gemini Toggle?}

    E -- On --> G[Gemini Analyze Request]
    F -- On --> G
    E -- Off --> H[Heartbeat Aggregator]
    F -- Off --> H

    H --> I[Model Calls (Ollama, tools)]
    I --> J[Consolidated Response]

    G --> K[Gemini Response]
    subgraph UID/File Contract
      K --> L[Collect UID + tdate + timestamp]
      L --> M[(Store File: raw prompt & revised prompt)]
      M --> N[PAIR with Gemini Response]
      N --> O[Emit E1..E3 VI Card Schemas]
      O --> P[Each schema has filename: UID-####-{tdate}]
    end

    J --> Q[UI: display status/output]
    P --> Q
```

## Operational Modes
- Gemini Toggle OFF: Mic and Chat enqueue work (release=heartbeat). Heartbeat aggregator runs models/tools and posts consolidated results. No Gemini call.
- Gemini Toggle ON: Mic and Chat route to Gemini analyze instead of heartbeat. Everything else stays the same.

## Network Bring-up Checklist
1) Start HubStation on port 9099.
2) Confirm endpoints:
   - GET /status
   - POST /heartbeat/tick
   - POST /queue/push
   - GET /logs, GET /logs/csv/tail
   - POST /chat
   - POST /stt
   - POST /api/gemini/analyze (optional; requires module)
3) Verify UI loads (scripts/index.html) and side controller buttons respond.
4) Verify mic → STT → composer path works.
5) Verify logs and recent/stop modals fetch.

## Gemini Hookup Status (Current)
- Front-end: runGeminiAnalyze wired to /api/gemini/analyze. Toggle ON will redirect Mic/Chat to Gemini path.
- Server: GeminiService.ps1 exists but is a placeholder. HubStation.ps1 checks for Handle-GeminiAnalyzeRequest and returns error if not loaded.
- API Key: Start-HubStation.ps1 prompts/sets GEMINI_API_KEY env. Must be present for real calls.

## UID and File Pairing Contract
- Incoming Gemini response is a single payload with multiple text messages (1–3). Each message has a UID and tdate provided by Gemini.
- Rules:
  - GEMINI names the UID, not us. Preserve UID and its tdate.
  - If UID numeric part has <4 digits, left-pad to 4 (e.g., 7 => 0007) for sorting.
  - Timestamp captured at submission must equal the timestamp stored on disk for the paired file(s).
  - Store:
    - FILE: persisted copy of input materials used in the request
      - FILE + TEXT PROMPT + PROMPT_REVISED forms the exact Gemini request content recorded on disk.
    - RESPONSE: the raw Gemini response payload.
  - Output: E1..E3 VI Card schemas (1–3), each with a filename using UID-####-{tdate}.
  - Pairing: File record and schema files share the same UID and tdate so they always compile together.

## Minimal Implementation Notes (deferred)
- Add a simple front-end toggle (Gemini: ON/OFF) bound to localStorage; when ON, send mic/chat content to /api/gemini/analyze.
- On server, implement Handle-GeminiAnalyzeRequest:
  - Parse request (description, quote, context, optional prompt revisions).
  - Generate submission timestamp (ts_submit). Persist the exact request materials to disk.
  - Forward to Gemini API using GEMINI_API_KEY.
  - Receive response with UID + tdate + 1–3 text parts. Persist raw response to disk.
  - Split into E1..E3 schemas. Name each schema file UID-####-{tdate}.json (or .yaml). Ensure timestamp on these files equals ts_submit.
  - Return ok + summary + file paths.

## What needs to happen next (no code yet)
- Confirm HubStation is running and endpoints OK.
- Decide placement for Gemini file drops (e.g., HubStation/shared_bus/reflections or a new folder HubStation/shared_bus/gemini).
- Implement the Gemini service handler and file write logic.
- Add a tiny UI toggle to switch Mic/Chat routing between heartbeat and Gemini.

```text
Acceptance:
- Network endpoints reachable; UI buttons functional.
- With toggle OFF, heartbeat mode works as-is.
- With toggle ON, mic/chat requests go to Gemini; handler returns 1–3 schemas; disk has paired files using UID/tdate with identical submit timestamp.
```
