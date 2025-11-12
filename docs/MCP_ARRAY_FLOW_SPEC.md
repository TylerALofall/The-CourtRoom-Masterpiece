# MCP Array Flow and Heartbeat-Orchestrated Loop (Implementation Spec)

Author: Tyler (requirements), implemented by builder/agent
Date: 2025-11-11
Status: Draft v1 (actionable)

---

## Purpose
A precise, action-oriented spec to implement a model-driven workflow that:
- Uses a flat, one-level array as the core state container (no nested objects for the top-level control fields).
- Gates execution using a heartbeat (epoch-based pacing) so messages are queued and delivered in controlled batches.
- Prioritizes evidence-first facts collection; the model records only directly observed facts before any synthesis.
- Provides top-level tool categories (cheat sheet and actions) that auto-reprompt the model with the last prompt + tool output.
- Enforces periodic reflection (every N turns) writing to a log and a long-term index.
- Returns to the human (Tyler) only concise messages + access to the evolving log, avoiding chatter overload.

This spec is written in third-person as instructions to the builder.

---

## Core Control Structure: Flat Array (Canonical)
The system’s primary control/state is a single flat array with fixed indices. There is no object form. The first three fields are read-only for the model and set only by Tyler.

Canonical block (retain exactly):

```
[Tyler
  0,  // [0] epoch time 17627382467267 << ths chronically organization everything  
  0,  // [1] heartbeat_seconds // changeable by me only
  0,  // [2] session_goal //<no goal no go> (needs a decay countdown incase runs away it stops ... for now)
 
 M- Model
 M "", // [3] notes
 M "", // [4] scratchpad
 M "", // [5] cheatsheet_key/tool_calls or files_key ..<<Lookup>> ,*** and these instant reprompt the model with the last prompt and the tool output .. to large to json fil with auto call and return.
 M "", // [6] action/.sh1/runnable_command calls, <<Lookup>> ,*** and these instant reprompt the model with the last prompt and the tool output..this is a sh1 command or runnable command. file or script or whatever, raised rag, google....
 T "", // [7] model_to tyler_msg or model "Tyler: ..." , or "GPT-5: ...",

M  ""  // [8] tyler_to modeel msg

Log = [1-8], ... >>> Tyler GUI & model searching
```

Field notes and constraints:
- [0] epoch_time (number): Unix epoch ms for the current beat; set externally each heartbeat.
- [1] heartbeat_seconds (number): Read-only pace; only Tyler changes this.
- [2] session_goal (string): Required; if empty → do not proceed.
- [3] notes (M): Brief factual notes for the current step; no monologues.
- [4] scratchpad (M): Ephemeral; can be cleared often; not auto-logged.
- [5] cheatsheet_key (M): Exactly one top-level category key; selecting it triggers tool fetch and immediate auto-reprompt with “last prompt + tool output.” Not nested.
- [6] action_key (M): Exactly one runnable category key; selecting it runs a command/script and auto-reprompts with “last prompt + command output.”
- [7] model_to_tyler_msg (T): The concise message visible to Tyler; keep short and high-signal.
- [8] tyler_to_model_msg (M): Builder injects queued inbound messages here on the beat; aggregated and compact.

Additional rules:
- Read-only for model: indices [0..2]. They are context only.
- The control structure is one layer deep; no nested maps or arrays at these indices.
- Every 7–10 turns the model opens the read-only log, writes a reflection with tags, and it is indexed for search.
- When the task is done, the model signals stop via a zero-state or explicit completion in [7], and heartbeat pacing prevents spurious further prompts.

---

## Heartbeat and Queueing
- Heartbeat controls when inbound messages (from Tyler to the model) are delivered and when outbound actions are evaluated.
- Every heartbeat tick sets [0] to current epoch and processes the queue:
  1. Aggregate new inbound messages since the last beat into a single compiled payload and set [8] with it.
  2. If Tyler sent multiple items, concatenate them in a minimal, compact form (e.g., line-separated), keeping verbosity low.
  3. Do not interrupt the model between beats. The model can keep thinking/acting between beats without blocking on messages.
  4. After N turns (e.g., 7–10), enforce a reflection cycle (details below).

Delivery rules:
- All queued messages are written to a single document (append-only or chunked) and injected en masse into [8] on the next beat.
- The builder composes a unified prompt for the model that includes: session header (goal/epoch/heartbeat), last prompt, new [8] payload (if any), and any tool/command outputs from [5]/[6] activations within this beat.
- The model does not change [0..2]. It reads them as context only.

---

## Tool Categories and Auto-Reprompt
Top-level tool selectors are not nested UIs; the model selects a category via a single key in [5] or [6].

- Cheatsheet ([5]):
  - A category key that maps to either:
    - a JSON file (lookup), or
    - a compact top-level menu (3–4 categories) for the model to choose from.
  - On selection, the system fetches relevant content and immediately re-prompts the model with the last prompt + the tool content. This reduces back-and-forth and avoids the model needing to “one-shot” plan everything.
- Actions ([6]):
  - A category key that maps to executable actions (scripts/commands). Examples: search, web fetch, local grep, evidence retrieval, RAG queries.
  - On selection, the system executes the action with sensible defaults pulled from the context; then immediately re-prompts the model with last prompt + the action output.

Safety and ergonomics:
- Each tool call returns small, tight outputs. Avoid dumping large bodies; if a large artifact is needed, store it and return a handle/summary.
- Tool errors are also re-prompted to the model with brief diagnostics so the model can course correct.

---

## Evidence-First Policy
- The model is required to record only directly observed facts (verbatim excerpts, file refs, timestamps) before any synthesis.
- No guessing. No gap-filling. Only “what is seen” as evidence.
- This ensures a robust chain of custody for facts. Summaries or inferences are allowed only after raw facts are captured.

Implementation:
- Provide small, reusable prompts/templates that instruct the model to extract: quote, citation/path, time, minimal context.
- Encourage short entries so chat context is not polluted with monologues.

---

## Reflection Cadence and Long-Term Memory
- Every X turns (7–10 suggested), force a reflection checkpoint:
  - Model opens the read-only log summary (or tail) and produces a reflection entry:
    - What worked?
    - What failed?
    - How to improve next?
    - Tags for indexing (topics, entities, actions).
  - The reflection entry is appended to the log and simultaneously indexed into a long-term searchable store.
- This becomes the model’s teach-back mechanism; it learns over time and can recall lessons later via the index.

---

## Compiled Message Format (Beat Payload)
To accommodate different model input limits, the system compiles a single compact message for each beat. Suggested order:

1) Session Header (read-only fields)
- goal: <session_goal>
- beat: <epoch_time>
- interval: <heartbeat_seconds>s

2) Last Prompt Recap
- Short summary of the last instruction or target.

3) New Inbound (from [8])
- Concise human instructions since last beat. One-liners preferred.

4) Tool/Action Outputs
- Any outputs triggered by [5] or [6], summarized with links/handles for larger artifacts.

5) Evidence Additions (since last beat)
- Minimal fact entries: quote/path/time.

6) Guidance
- If reflection is due: include a single-line directive to reflect and update the log.

The builder should format this as a compact block with bullet points, not verbose prose.

---

## Models and Providers
- Primary: Gemini (family) and local Ollama models (Llama-family, Kimi K2, Qwen/Qin, etc.).
- The builder provides an abstraction so the compiled beat payload can be sent to any of the configured models uniformly.
- Keep the outgoing payload small and fact-dense.

---

## UI Guidance (ollama-gui.html refactor)
- Controls:
  - Heartbeat toggle (read-only minutes display if controlled by Tyler elsewhere).
  - Session goal view (read-only); separate button to propose a goal but requires Tyler to set it.
  - Log button (read-only view of recent facts and reflections).
  - Tool selectors: two rows only (Cheat Sheet, Actions) showing top-level categories (3–4). Clicking sets [5] or [6].
  - Compose area kept short; auto-collapses; avoid long scrolls.
- Behavior:
  - On beat, queue Tyler messages and inject them into [8] wholesale.
  - Show when a reflection checkpoint is due; clicking ‘Reflect Now’ simply nudges the model to perform the reflection, but it should also trigger automatically on cadence.
  - Minimize chatter panel; default to summaries, with drill-down only when needed.

---

## Quick-Loop Library Pattern
Provide a minimal helper library (pseudo-code) for loop execution:

```
class BeatLoop {
  constructor(io, tools, store, cadence=8) {
    this.io = io;         // send/receive with model(s)
    this.tools = tools;   // cheatsheet/actions resolvers
    this.store = store;   // log + long-term
    this.cadence = cadence;
    this.turn = 0;
    this.state = [ Date.now(), 60, '', '', '', '', '', '', '' ];
  }

  setGoal(s) { this.state[2] = s; }
  setHeartbeatSeconds(sec) { this.state[1] = sec; }

  async tick() {
    this.state[0] = Date.now();
    const inbound = await this.store.dequeueInbound();
    if (inbound) this.state[8] = inbound; else this.state[8] = '';

    const compiled = await this.compileBeatPayload();
    const reply = await this.io.prompt(compiled);

    // Persist minimal evidence facts out of reply
    await this.store.appendFacts(reply.facts || []);

    // Tool triggers
    if (this.state[5]) {
      const out = await this.tools.cheatsheet(this.state[5]);
      const reprompt = await this.io.reprompt(this.lastPrompt, out);
      await this.store.appendFacts(reprompt.facts || []);
      this.state[5] = '';
    }
    if (this.state[6]) {
      const out = await this.tools.action(this.state[6]);
      const reprompt = await this.io.reprompt(this.lastPrompt, out);
      await this.store.appendFacts(reprompt.facts || []);
      this.state[6] = '';
    }

    // Reflection
    this.turn++;
    if (this.turn % this.cadence === 0) {
      const logTail = await this.store.tail();
      const reflection = await this.io.prompt({ task:'reflect', logTail });
      await this.store.appendReflection(reflection);
      await this.store.indexReflection(reflection);
    }

    // Deliver concise message to Tyler
    if (reply.toTyler) await this.store.deliverToTyler(reply.toTyler);
  }

  async compileBeatPayload() {
    return {
      header: { goal: this.state[2], beat: this.state[0], interval: this.state[1] },
      lastPrompt: this.lastPrompt || '',
      inbound: this.state[8] || '',
      tools: await this.store.pendingToolSummaries(),
      evidence: await this.store.pendingFacts(),
      guidance: (this.turn % this.cadence === 0) ? 'reflect' : ''
    };
  }
}
```

Notes:
- The actual implementation can be in PowerShell/JS/Python; the pattern is what matters.
- Keep tool outputs summarized; store bulky artifacts separately.

---

## Logging and Long-Term Memory
- Log focuses on: facts (quotes, citations, timestamps), decisions taken, and reflections.
- Tyler sees: the messages to him ([7]) and the read-only log. Intermediate chatter is not surfaced to him.
- Every N turns: reflection bulk-writes into both the log and a searchable index.

---

## Acceptance Criteria
- The top-level state is a 1-deep array with indices 0–8 exactly as defined, with [0..2] read-only to the model.
- Heartbeat gating exists: inbound messages are queued and injected into [8] only on beat; the model is not interrupted between beats.
- Selecting a cheatsheet/action category key auto-fetches and auto-reprompts with last prompt + tool output.
- Evidence-first logging exists; facts precede synthesis.
- Reflection cadence implemented (every 7–10 turns) and stored to long-term memory.
- Tyler’s view is limited to concise messages + the log; chatter isn’t shown.
- UI (ollama-gui.html) exposes only top-level controls and small compose area with minimal friction.

---

## Implementation Notes and Tips
- Keep everything small and short—avoid long blocks in the chat context.
- Do not leak internal chatter to Tyler; keep [7] crisp.
- Provide a micro “cheat sheet” file mapping 3–4 categories max; deeper trees are resolved by file lookups, not by array nesting.
- The model can operate many turns without Tyler’s input; Tyler’s messages are batched per beat and compiled into the prompt.
- If no goal in [2], do nothing—fail fast and notify via [7].
- For evidence review (1,500+ artifacts), favor batch indexing and selective retrieval (handles + snippets).
- Periodically rewrite/compact the log (e.g., every 10 cycles) and re-ask: “How could this have been better?” Include result in reflections.

---

## Example Minimal Cheat Sheet Mapping (JSON)
```
{
  "legal_elements": "cheatsheets/legal_elements.json",
  "procedures": "cheatsheets/procedures.json",
  "commands": "cheatsheets/commands.json",
  "evidence": "cheatsheets/evidence.json"
}
```

The model sets [5] = "legal_elements" to fetch that sheet; the builder reprompts with the last prompt + that JSON content.

---

## Example Action Mapping (JSON)
```
{
  "search_case": "scripts/search_case.sh",
  "grep_repo": "scripts/grep_repo.ps1",
  "fetch_web": "scripts/fetch_web.py",
  "rag_query": "scripts/rag_query.py"
}
```

The model sets [6] = "grep_repo"; the builder runs it with sensible defaults, returns a summarized output, and immediately reprompts.

---

## Final Notes
- This spec is intentionally prescriptive so the builder can implement it without further clarification.
- Where details are missing, prefer small, composable parts and short summaries.
- The system’s strength is in paced, tool-assisted, evidence-first iteration—not one-shot prompting.
