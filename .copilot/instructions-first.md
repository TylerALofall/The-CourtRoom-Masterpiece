The system must implement the following protocol exactly.

---

# MCP SelfPrompt Protocol — Implementation Spec (Third-Person, Fully Annotated)

This document defines how the **SelfPrompt loop** works for Tyler’s environment.

It is written for the implementer (the “builder”) and for any cooperating models (including local models, MCP tools, or hosted LLMs) so they all follow the same deterministic contract.

The goal:

* Turn any model into a **disciplined worker** that:

  * acts in small, verifiable steps,
  * calls tools/configs instead of guessing,
  * logs only what it can prove from actual data,
  * can chain MCP → Model → MCP → Model many times,
  * and surfaces only clean, concise output back to Tyler.

Everything below is deliberate. If a detail is here, it has a purpose.

---

## 1. Core Design Summary

**High-level behavior**

1. Tyler controls:

   * when the loop runs,
   * the global goal,
   * the pacing.
2. The model:

   * never rewrites Tyler’s controls,
   * only fills in working memory, next-step plans, and tool selectors.
3. The MCP / runner:

   * reads the model’s selectors,
   * loads JSON cheat-sheets,
   * runs preconfigured commands / tree scans / RAG calls,
   * then feeds the results back to the model on the next step.
4. Communication to Tyler:

   * only through a dedicated, short channel,
   * plus a separate log that can be searched/reviewed later.

This creates a controlled chain:

> Tyler → Model → MCP → Model → MCP → … → Model → Tyler

instead of chaotic one-shot prompts that try to do everything at once.

---

## 2. The SelfPrompt Array (Authoritative Format)

All state is represented as a **fixed-length, one-dimensional array**.

No objects. No nested keys. No nulls. No extra fields.

```js
[
  0,  // [0] epoch
  0,  // [1] heartbeat_seconds
  0,  // [2] session_goal

  
  "", // [3] notes
  "", // [4] scratchpad
  "", // [5] cheatsheet_key
  "", // [6] action_key
  "", // [7] model_to_tyler
  ""  // [8] tyler_to_model
]
```

If a model or tool returns anything else (extra keys, wrong length, wrong types), the runner must reject it.

### Why an array?

* Forces consistency across different models / runtimes.
* Easy to parse reliably even by weaker or more literal models.
* Keeps wire format compact and universal.
* Prevents “creative” schema drift that breaks coordination.

---

## 3. Slot-by-Slot Specification (What / Who / Why / How)

### [0] `epoch` — Batch Timestamp

**What**:
Unix timestamp (integer seconds) when this **batch to the model** was constructed.

**Who controls it**:
Runner / GUI only. The model treats it as read-only context.

**Why**:

* Used to:

  * coordinate heartbeat timing,
  * track when each state snapshot was generated,
  * debug and replay the loop history.
* The model does not derive behavior from it; it just sees “this is when this state was formed”.

**Implementation notes**:

* Before each outer-loop call to the model, the runner sets `[0] = now`.
* On validation:

  * It is acceptable if the model echoes `[0]` back unchanged.
  * If the model modifies it, runner can overwrite or treat that as an error; recommended: treat as read-only.

---

### [1] `heartbeat_seconds` — Pacing / Gate Control

**What**:
Minimum number of seconds between **outer-loop** calls (Tyler/MCP → Model).

**Who controls it**:
Tyler / GUI only. Model must not change it.

**Why**:

* Prevents the model from being spammed while it’s “thinking” through tool results.
* Allows:

  * queued human messages,
  * multiple tool outputs,
  * configuration updates
    to be coalesced and sent in one clean batch.
* Allows Tyler to:

  * pause (`0` = no automatic ticks),
  * slow down or speed up processing,
  * preload work without interrupting the model mid-chain.

**Rules**:

* `heartbeat_seconds >= 0`.
* `0` means: stop auto-ticking; only manual runs.
* Validation:

  * If model changes `[1]`, the runner must treat it as invalid.

---

### [2] `session_goal` — Global Objective (No Goal, No Go)

**What**:
Human-readable string describing what this loop is for.

**Who controls it**:
Tyler / configuration only. Model must **never** overwrite or “optimize” it.

**Why**:

* Ensures each loop is anchored to a clear purpose:

  * e.g. “Process evidence one fact at a time. Only record verifiable facts from actual files. No guessing.”
* If blank, the runner should treat that as “do not start autonomous work.”

**Rules**:

* Read-only for the model.
* If the environment wants to change the mission, Tyler (or a supervising system prompt) edits `[2]`.

---

### [3] `notes` — Verified Working Memory

**What**:
String containing **only verified information** relevant to the session goal.

**Who controls it**:
Model.

**Why**:

* This is the model’s running index of facts it has confirmed from:

  * actual documents,
  * MCP/tool outputs,
  * Tyler’s explicit statements.
* Acts as its **grounded scratch history**.
* Reduces re-reading: each step can build on previously confirmed facts instead of reloading everything.

**Rules**:

* No speculation.
* No “I think…” or “probably…” or filling gaps.
* Only:

  * direct quotes summarized,
  * dates / events / relationships that are present in supplied material.
* Length should be bounded; periodically compressed:

  * e.g., runner enforces max length and the model summarizes when requested.

**Implementation hints**:

* Good pattern:

  * Bullet or line-based, each line: `"[SourceTag] short factual statement."`
* If evidence changes, the model can clarify or correct in future ticks.

---

### [4] `scratchpad` — Next Micro-Step Plan

**What**:
The model’s one-step (or very short) action plan for the **next move**.

**Who controls it**:
Model.

**Why**:

* Forces the model into incremental, observable actions.
* Prevents 15-step hallucinated roadmaps.
* Enables the MCP/runner to understand what is expected and match tools accordingly.

**Rules**:

* Always small, tactical, and immediately actionable.
* Example formats:

  * `"1) Read tool output for ECF_60.\n2) Confirm June 10 COVID statement.\n3) If confirmed, set cheatsheet_key=cs_covid_log to load context."`
* If empty:

  * Model should fill it with a next concrete step.

**Implementation suggestion**:

* Runner may display `scratchpad` in the GUI so Tyler can see what the model is about to do next, without seeing all internal noise.

---

### [5] `cheatsheet_key` — JSON / Config Selector

**What**:
A **single string key** that maps to a JSON/config/guide resource.

**Who sets it**:
Model.

**Who acts on it**:
MCP / runner.

**Why**:

* Prevents inlining large prompt libraries.
* Lets the model say:

  * “I need the Monell guide” → use `"cs_monell"`.
  * “I need the evidence index” → `"cs_evidence_index"`.
* Keeps prompts small while leveraging rich, structured side-data.

**Rules**:

* One layer deep:

  * Only the key is in [5]; the actual JSON lives in a library the MCP knows.
* If empty, nothing is loaded.
* When non-empty:

  * MCP:

    * Looks up the key in a **cheatsheet library** (e.g. `cheatsheets/KEY.json`).
    * Pulls in only relevant slices (respect size limits).
    * Includes them in the next model call as additional context.
* The model must not dump entire JSON specs into `[5]`.

**Implementation suggestion**:

* Maintain a `CheatsheetRegistry` (e.g., JS object or JSON config):

  * `{ "cs_monell": "cheatsheets/monell.json", ... }`
* Centrally managed, versionable, easy to extend.

---

### [6] `action_key` — Command / RAG / Tree Selector

**What**:
A **single string key** mapping to a runnable action:

* shell script,
* tree walk,
* RAG query,
* grep,
* hash check,
* API call, etc.

**Who sets it**:
Model.

**Who acts on it**:
MCP / runner.

**Why**:

* Gives the model real hands:

  * It can ask for “tree of ECF files” or “search all transcripts June 2022”
  * without inventing commands or being unsafe.
* Every action is whitelisted and centrally defined.

**Rules**:

* One layer deep:

  * Only keys like `"act_tree_ecf"`, `"act_search_transcripts_june2022"`.
* If empty, no action is executed.
* When non-empty:

  * MCP:

    * maps to a known action:

      * e.g., `act_tree_ecf` → `ls -R ECF/`
      * e.g., `act_search_transcripts_june2022` → grep-like search
    * executes it safely,
    * returns a **small, relevant summary** or snippet as input to the next model call.
* Model never inlines raw bash/PowerShell here; it only chooses from the menu.

**Implementation suggestion**:

* Maintain an `ActionRegistry`:

  * `{ "act_tree_ecf": runTreeECF, "act_search_transcripts_june2022": runTranscriptSearch }`
* Each action returns bounded output that can fit into the context.

---

### [7] `model_to_tyler` — Upward Channel

**What**:
Short, direct messages from the model to Tyler.

**Who writes it**:
Model.

**Why**:

* Tyler must not be spammed with internal chatter.
* This slot is the model’s only way to:

  * ask for help,
  * flag conflicts,
  * request a specific decision.

**Rules**:

* Only used when necessary.
* Max 1–2 sentences.
* Examples:

  * `"Tyler: I need the exact path to the Feb 12, 2025 Lewis email to verify it."`
  * `"Tyler: Detected conflict between ECF_60 and June 10 transcript; please review."`
* Runner/GUI:

  * surfaces `[7]` loudly (notification),
  * stores it in the log.

---

### [8] `tyler_to_model` — Downward Channel (Buffered)

**What**:
Aggregated messages / directives from Tyler (and possibly supervisory systems) to the model.

**Who writes it**:
Runner/GUI (by collecting Tyler’s input since last tick).

**Who reads it**:
Model.

**Why**:

* Keeps Tyler’s instructions synchronized with the heartbeat.
* Avoids mid-step interruptions.
* Lets Tyler preload multiple instructions that hit the model as one coherent batch.

**Rules**:

* On each heartbeat:

  * runner combines queued Tyler messages into `[8]`.
  * model reads them, integrates them:

    * may move confirmed items into `[3] notes`,
    * convert commands into `[4] scratchpad` or `[5]/[6]` selections.
* Model should not abuse `[8]` as internal notes; this is inbound.

---

## 4. Outer vs Inner Loops

### 4.1. Outer Loop — Heartbeat (Tyler-Controlled)

The outer loop controls:

> When does the model see new stuff?

Mechanics:

1. Maintain:

   * `currentState: SelfPrompt[9]`
   * `messageQueue: []` (Tyler + system messages)
   * `lastTickEpoch`

2. Periodic tick (e.g. every 1s):

   * If `currentState[1] === 0`: paused → do nothing.
   * If `now - lastTickEpoch < heartbeat_seconds`: wait.
   * Else:

     * Merge `messageQueue` into one string → `[8] tyler_to_model`.
     * Set `[0] epoch = now`.
     * Send SelfPrompt + merged content to model.
     * Validate returned array.
     * Update `currentState`.
     * Expose `[7] model_to_tyler` to Tyler.
     * Append snapshot to log.
     * Set `lastTickEpoch = now`.

**Why this matters**

* Prevents prompt storms.
* Allows batching:

  * multiple instructions,
  * multiple tool outputs,
  * into one coherent model step.

---

### 4.2. Inner Loop — MCP Chains (Model-Controlled via Keys)

The inner loop controls:

> How many MCP/tool hops happen between two points where Tyler cares?

Triggered by `[5]` and `[6]`.

Mechanics:

1. Model sets:

   * `cheatsheet_key` or `action_key` (or both).
2. Runner:

   * Detects non-empty keys.
   * Runs mapped actions:

     * loads JSON cheat,
     * executes commands / queries.
   * Gets `tool_output`.
3. Runner immediately calls the model again (same session_goal, etc.) with:

   * updated SelfPrompt,
   * `tool_output` included in the user content.
4. Model:

   * updates `[3] notes`, `[4] scratchpad`,
   * may set new keys for further refinement,
   * or clear them when done.

This can repeat several times:

> Model → MCP → Model → MCP → Model

**without** bothering Tyler on each microscopic step.

Safety:

* Cap recursion (e.g. max 5–8 inner hops per outer tick).
* If keys keep firing infinitely, stop and surface an error.

---

## 5. Validation & Error Handling

The runner must enforce these:

1. Returned value must be:

   * an array,
   * length 9.
2. Types:

   * `[0]`, `[1]` integers.
   * `[2]`–`[8]` strings.
3. Read-only:

   * `[1]` and `[2]` must match what was sent.
   * If they differ → reject or correct, but log the violation.
4. Length bounds:

   * `notes`: bounded (e.g. ≤ 4000 chars).
   * `scratchpad`, `cheatsheet_key`, `action_key`, `model_to_tyler`, `tyler_to_model`: all bounded reasonably.
5. If invalid:

   * Don’t advance state.
   * Show error in GUI.
   * Optionally show raw model output for debugging.

This keeps weaker / verbose models from poisoning the protocol.

---

## 6. Cheatsheet & Action Libraries

To make `[5]` and `[6]` real, the builder should implement:

### 6.1. Cheatsheet Library

* A registry mapping keys → JSON files:

```js
const Cheatsheets = {
  "cs_monell": "cheatsheets/monell.json",
  "cs_fraud_upon_court": "cheatsheets/fraud_upon_court.json",
  "cs_timeline_index": "cheatsheets/timeline_index.json",
  // ...
};
```

* MCP logic:

  * When `cheatsheet_key` is set:

    * Load the file,
    * Select relevant sections,
    * Inject as read-only context next call.

### 6.2. Action Library

* A registry mapping keys → safe runner functions:

```js
const Actions = {
  "act_tree_ecf": runECFTree,
  "act_search_transcripts_june2022": runJuneTranscriptSearch,
  "act_list_bodycam": runBodycamIndex,
  // ...
};
```

* Each action:

  * Returns **small**, well-structured text or JSON.
  * Runner injects that into next call.

This gives real-world hands without giving raw shell to the model.

---

## 7. Quick Loop Mode: One-Item-Per-Tick Task Runner

Tyler also needs a **fast, disciplined loop** where a model:

* takes a list of items (e.g., 1500 evidence docs),
* processes **one item per “turn”**,
* logs verified facts,
* moves on cleanly.

The same SelfPrompt array supports this.

### 7.1. Concept

* Maintain a `taskList` externally:

  * e.g., array of file IDs, UIDs, or evidence entries.
* At each heartbeat:

  * Pick the next unprocessed item.
  * Set that as the focus via:

    * `[4] scratchpad`: “Process item X.”
    * `[5]` / `[6]`: keys to load that item’s metadata or contents.
* Model:

  * reads the item,
  * writes verified findings into `[3] notes`,
  * maybe emits a `model_to_tyler` if something important is found,
  * clears keys or sets next ones for deeper inspection.

### 7.2. Example Flow (simplified)

1. Runner state:

   * `taskList = [Item1, Item2, Item3, ...]`
   * `currentIndex = 0`.

2. On each heartbeat:

* If `currentIndex >= taskList.length`:

  * Set `heartbeat_seconds = 0` (pause).
  * Optionally notify Tyler: all tasks done.

* Else:

  * Let `item = taskList[currentIndex]`.
  * Build SelfPrompt:

    * `[4] scratchpad = "1) Load and review " + item.id + ". 2) Extract only verifiable facts into notes."`
    * `[5]` or `[6]` assigned to keys that will fetch that item’s content.
  * Call model and run inner loop until:

    * no more `cheatsheet_key/action_key`, or
    * max depth reached.
  * When done:

    * Advance `currentIndex++`.
    * Next heartbeat → next item.

This mode:

* Guarantees steady, predictable progress.
* Keeps each step small:

  * one file,
  * one fact cluster,
  * one reflection at a time.

---

## 8. Reflection & Long-Term Learning

The system should periodically prompt the model to reflect, but under control.

### Implementation Idea

* Runner tracks `tickCount`.

* Every N ticks (e.g., 7 or 10):

  * Runner adds to `tyler_to_model` or system content:

    > “Reflection tick: Review your recent notes. Summarize what worked, what failed, and 2 rules to improve your next steps.”

* Model responds by:

  * updating `[3] notes]` with a compact reflection, or
  * encoding improvement rules that future steps can rely on.

Runner then:

* extracts those reflection lines,
* stores them in a searchable index (outside the 9-slot array),
* reuses them as context for later sessions if desired.

This gives the models a memory of **how** they work, not just what they saw.

---

## 9. How to Use This Spec

For the builder:

* Implement this protocol in `ollama-gui.html` and the MCP runner **exactly** as defined.
* Treat the SelfPrompt array as the single contract between:

  * Tyler,
  * models,
  * tools,
  * logs.
* Keep the UI small:

  * controls for heartbeat, goal, view-log,
  * table or pane showing:

    * current `[3] notes`,
    * `[4] scratchpad`,
    * `[7] model_to_tyler`.
* Put cheatsheet/action mappings into separate config files so Tyler can grow the toolset without touching core logic.

For the models:

* They don’t need to know all internals.
* They just need clear instructions (in their system prompt) that:

  * `[0..2]` are read-only context,
  * `[3..6]` are their workspace and tool selectors,
  * `[7]` is their line to Tyler,
  * `[8]` is Tyler’s line to them,
  * and each response must be a valid 9-item array.

That’s the full rig.

If you drop this spec in front of a competent builder, they can wire the entire loop without guessing, and any serious model can run inside it without derailing.





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


my GUI has small buttons to pop up and add gaal and view log, and tggle heartbeat, 0 = wwwhn task is done.the model stops. eveery 7-10 turns model opns the raad only log and maks a reflection and puts in tags and that is stored in a seearchable index

eepoch / heartbeat_seconds / session_goal = read only, set by me.: there is no option to change these. model does not edit them.and does not see them as anything other than context.