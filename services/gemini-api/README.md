# Gemini API (stub)

Purpose
- Provide a single POST /api/gemini/analyze endpoint the UI calls for auto-fill.
- No prompts stored here; route forwards model+contents to Gemini and returns response.

Minimal contract
- In: { model: string, contents: array }
- Out: Raw Gemini response. UI extracts candidates[0].content.parts[0].text.

Implementation options
- A) Add this route to HubStation (PowerShell) using Invoke-RestMethod and an env GEMINI_API_KEY.
- B) Tiny Node/Express service listening on localhost:3000, CORS allow from the UI.

Notes
- Keep API key in environment (not committed).
- Do not embed prompt text in code; load from file or pass from UI.
