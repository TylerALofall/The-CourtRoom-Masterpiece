# Ninth Circuit Brief Evidence System Upgrade Plan

## Objectives
- Keep existing cyberpunk visual style, colors, and layout unchanged while expanding functionality.
- Centralize all evidentiary materials in PDF-only workflows with reliable storage and retrieval.
- Wire Gemini 2.5 Pro interactions to a locked "Revised_Prompt" so every call is consistent.
- Restore or add voice-to-text capture across every claim element editor.
- Enforce the UID scheme (`CC-E-D`) across evidence cards, JSON exports, timeline entries, and future filings.
- Populate drafting templates (JSON → PDF) without altering the provided schema/strings.
- Link evidence seamlessly into litigation documents with stable, shareable references.
- Persist timeline metadata locally in JSON files and render chronologically at startup.

## Work Streams
1. **Codebase Recon**
   - Map existing IndexedDB schema, Gemini hooks, microphone handlers, and export utilities in `index.html`.
   - Inventory assets/templates: locate response template PDF/JSON, UID reference, and timeline resources.

2. **Evidence Repository**
   - Design local storage structure for PDFs (folder plus manifest JSON) while keeping originals in `ECF_FILES`.
   - Extend UI upload widgets to save PDFs locally, index metadata (UID, claim, element, defendants, date), and optionally sync with Drive.

3. **Gemini Integration**
   - Author `Revised_Prompt` text file; load at runtime; inject into every Gemini request.
   - Ensure selectable context per element (note, transcript, PDF excerpt) before dispatch.

4. **Voice-to-Text (STT)**
   - Audit current microphone pipeline; refactor into reusable module that attaches to each element row.
   - Pick STT backend (Gemini audio, local WASM, or future processor hook) and document configuration knobs.

5. **UID Engine**
   - Implement generator/validator for UID pattern (claim + element + defendant digits + optional suffix ABC).
   - Surface UID counter UI (suggest next ID, allow overrides, prevent duplicate collisions in IndexedDB + manifest).

6. **Template + Merge**
   - Parse provided PDF/JSON template; map evidence card fields to schema.
   - Build export routine that feeds completed records into template (or mail-merge-ready CSV/JSON) with no truncation.

7. **Evidence ↔ Document Linking**
   - Assign shareable URLs for each stored PDF (local schema with relative paths).
   - Generate citation strings and embed clickable anchors inside draft exports (HTML/PDF) for compilation.

8. **Timeline Persistence**
   - Store events as individual JSON files (one per UID or consolidated) inside dedicated directory.
   - Auto-load, sort chronologically, and render timeline with toggle filters (claim/defendant/UID suffix).

9. **Accessibility & Reliability**
   - Provide keyboard shortcuts and ARIA labels to support screen reader workflows.
   - Document recovery steps and backup strategy (manifest snapshots, Drive sync hooks).

10. **Testing & Validation**
    - Create checklist for UI smoke tests (upload, STT, Gemini call, UID generation, timeline render).
    - Verify JSON exports match schema and confirm PDF compilation path.

## Recon Notes (Initial Pass)
- `scripts/index.html` already contains:
   - IndexedDB store `EvidenceDB` with object stores `evidence_cards` and `files`.
   - Timeline and circular-menu data hard-coded in JS arrays waiting to be replaced by persisted JSON.
   - Voice capture pipeline that posts base64 audio to `http://127.0.0.1:9099/stt` (matches HubStation endpoint).
   - Hub messaging helpers hitting `/queue/push`, `/run`, `/chat`, `/heartbeat`, etc., confirming the UI was meant to talk to HubStation.
- `HubStation/HubStation.ps1` exposes rich REST endpoints (chat, STT, TTS, queueing, Ollama control, static hosting). Static root currently points to `../personal-website`; we need to retarget that to the `scripts/` directory or host separately.
- Whisper + Polly configuration already lives in `hub_config.json`; no Python dependencies are required.

## Next Actions
1. Finish cataloguing UI touchpoints (Gemini usage, evidence upload, timeline rendering) and record required extension hooks.
2. Decide static hosting approach (retarget HubStation static root or introduce minimal Node/PowerShell server) so the cyberpunk UI runs without `file://` restrictions.
3. Design storage layout for canonical prompt, Whisper transcript append, and PDF evidence bundles (folders, manifest schema, UID linkages).
4. Outline modular MCP-style helper scripts (fact citation logger, screenshot capture, transcript saver, evidence dispatcher) and how they wire into HubStation endpoints.
5. Review "REF UNIQUE ELEMENT OUTLINE" + response template PDFs to ensure UID mapping and export schema stay untouched before coding changes.
