# FIELD NOTES (Acceptance & Ops)

Date: 2025-11-12

## Acceptance Criteria (This Cycle)
- Gemini Toggle exists in UI as a button labelled Gem:OFF / Gem:ON.
- Toggle state persisted in localStorage (key GEMINI_ON) and reflected at startup.
- Mic flow:
  - OFF: Mic → STT → Composer → (optional queue/heartbeat) unchanged.
  - ON: Mic → STT → Composer + immediate /api/gemini/analyze on transcript.
- Chat (mini composer) flow:
  - OFF: Queue to hub (release=heartbeat) + immediate local chat call for UI feedback.
  - ON: Direct call /api/gemini/analyze; do not queue.
- Gemini handler is still a stub on server; calls may return a friendly error message until implemented.

## UID & File Pairing (From Blueprint)
- UID is provided by Gemini; we do not generate it.
- tdate is attached to UID; filenames use UID-####-{tdate}.json with left-padded 4-digit numeric portion.
- Submission timestamp is applied identically to stored request file, raw response file, and all emitted VI card schemas (E1..E3).

## Quick Check Steps
1) Start HubStation (Start-HubStation.ps1) and open the UI.
2) Confirm button Gem:OFF appears; click to toggle Gem:ON; refresh page and verify it stays ON.
3) Mic test: speak, stop; ensure composer fills; if Gem:ON, see a Gemini request attempt status.
4) Chat test: type a short message; if Gem:ON, see Gemini request attempt; if OFF, queue + chat.
5) Logs modal loads; Recent/Stop modals list processes; HB modal works as before.

## Notes
- No runner skeleton files modified.
- Next: implement server-side Gemini handler with UID/tdate and file pairing.
