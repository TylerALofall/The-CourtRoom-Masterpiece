# Delta to Spec & Migration Plan

This document lists the gaps between current implementation (see WORKFLOW_CURRENT.md) and the canonical flat array + heartbeat aggregation spec (see MCP_ARRAY_FLOW_SPEC.md), then provides an ordered migration plan. No code is changed by this file.

## 1. Flat Array Session State (Indices 0..8)
Current: No unified array in hub; state scattered (heartbeat object, queues, logs).
Target: Single array: [0] epoch, [1] heartbeat_seconds, [2] session_goal, [3] notes, [4] scratchpad, [5] cheatsheet_key, [6] action_key, [7] model_to_tyler_msg, [8] tyler_to_model_msg.
Gap: Need server component to hold and serialize this canonical array, enforce read-only [0..2], mutate others per cycle.

Action: Introduce `SessionState.psm1` with Get/Set operations, validation, and export `/session/state` endpoint.

## 2. Heartbeat Aggregation → Compiled Beat
Current: Heartbeat tick increments counters only; queue separate.
Target: On each heartbeat, aggregate queue items (release=heartbeat) → join → set array[8]; compile beat payload; drive model cycle.
Gap: Missing aggregator + compiled beat builder.

Action: Add `HeartbeatLoop.psm1` that:
- On POST /heartbeat/tick: builds aggregated inbound message, updates epoch, triggers model cycle if session_goal present.
- Writes concise log row per cycle.

## 3. Auto-Reprompt Tool & Action Keys
Current: /tool endpoint exists; /run executes actions; no automatic reprompt sequenced with last prompt.
Target: Setting [5] or [6] causes: run tool/action → capture output summary → immediate reprompt with (previous prompt + output) → refresh notes/scratchpad.
Gap: Need watcher of array state changes or explicit POST to `/session/set` to queue tool/action execution.

Action: Implement `/session/set` that accepts a partial update (only indices 3–8). When [5] or [6] change from empty → non-empty, schedule execution in next heartbeat cycle.

## 4. Reflection Cadence Enforcement (Every 7–10 Turns)
Current: Manual reflection via endpoints; no cadence.
Target: Count cycles; when cycle % cadence == 0, open log window → produce reflection → store CSV + JSON + tag index.
Gap: Need cycle counter and reflection trigger logic.

Action: HeartbeatLoop increments turn count; if due, call Reflections module to generate reflection stub and offer model a reflection prompt.

## 5. Evidence-First Logging Pipeline
Current: Logs show server internal messages; reflections store CSV events; no structured fact capture pre-synthesis.
Target: Each cycle extracts direct evidence facts first (quotes, paths) before summary/inference.
Gap: Need schema + extraction step.

Action: Add `FactCapture.psm1` with `Add-Fact` and integrate into compiled beat builder; UI can view raw facts separately.

## 6. Unified Return to Tyler (Array[7])
Current: UI surfaces various responses (chat reply, logs, Gemini output) independently.
Target: The only textual conversational output to Tyler per cycle is array[7], aggregated and trimmed.
Gap: Need a consolidation layer to take model output + tool summaries + reflection notice and produce a single short message.

Action: After model cycle completion, derive model_to_tyler_msg and store at index 7; UI polls `/session/state` rather than multiple raw endpoints.

## 7. Gemini Service Implementation
Current: Placeholder.
Target: Real analyze logic returning structured summary + optional evidence extraction to facts.
Gap: Missing API client/integration.

Action: Implement `Invoke-GeminiAnalyze` with configurable API key, error handling, fact extraction pass.

## 8. Cheatsheet & Action Category Maps (One-Level)
Current: Not centralized; scattered template logic.
Target: JSON maps for cheatsheet categories and action categories with 3–4 top-level entries.
Gap: Need consistent mapping + loader.

Action: Create `config/cheatsheet.map.json`, `config/action.map.json` and loader functions. When array[5]/[6] set, validate key exists.

## 9. Persistent Session Goal & Decay
Current: Goal not enforced.
Target: If no goal or expired goal (decay timer) → halt cycles.
Gap: Need goal timestamp + optional decay seconds.

Action: Extend array[2] semantics with a metadata object stored separately: { goal, set_epoch, decay_seconds }. On each heartbeat, verify still valid.

## 10. UI Refactor
Current: Direct calls to many endpoints.
Target: Poll `/session/state` + minimal actions (`/session/set`, heartbeat tick). Tool/action selection sets keys only; heartbeat processes them.
Gap: Need new JS state adapter; deprecate direct chat/STT immediate Gemini calls (those become heartbeat-driven actions).

Action: Implement phased approach: initial adapter layer while preserving existing endpoints; then shrink UI calls down.

## Ordered Migration Plan
1. Add SessionState and `/session/state` (read) + `/session/set` (write partial indices 3–8).
2. Integrate HeartbeatLoop to compile beat payload and aggregate queue items into index 8.
3. Implement tool/action auto-reprompt flow (watch [5]/[6]) inside HeartbeatLoop.
4. Add cycle counter + reflection cadence trigger.
5. Implement FactCapture and modify compiled beat builder to collect evidence first.
6. Consolidate model_to_tyler_msg at index 7; UI polls this value.
7. Provide real Gemini analyze function, hooking into FactCapture.
8. Add cheatsheet/action mapping JSON config loaders.
9. Introduce goal decay metadata; enforce <no goal no go> rule.
10. Refactor UI (incremental) to rely on session endpoints and heartbeat rather than direct multi-endpoint sprawl.
11. Remove deprecated direct endpoints (optional cleanup phase).

## Non-Goals (For Now)
- Authentication / multi-user separation.
- Streaming responses.
- Cross-session persistence of entire array history (only reflections/facts for now).

## Validation Checklist
- `/session/state` returns 9 indices exactly; [0..2] unchanged by model.
- Heartbeat tick leads to tool/action execution if keys present and queue items aggregated into [8].
- Reflection appears every configured cadence cycles; JSON + CSV row appended.
- Facts recorded before any summary; accessible via new facts endpoint or log tail.
- Tyler sees only array[7] as conversational output.

## Rollback Strategy
- All new modules added without deleting existing endpoints.
- UI toggled by feature flag (e.g., `?v2=1`) to test new heartbeat/session flow.
- If instability detected, revert to existing endpoints while troubleshooting modules.
