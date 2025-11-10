# Frontend (scripts/)

Entry: index.html (inlined styles & scripts currently).

Asset folders (future organization)
- assets/css: place extracted CSS from index.html if refactored.
- assets/js: modular JS (e.g., evidence.js, chat.js, stt.js).
- assets/img: static images.

Current data mechanisms
- IndexedDB: evidence_cards, files store.
- Calls HubStation endpoints for dynamic features.

Refactor suggestions (deferred)
- Split large inline script into modules under assets/js.
- Move <style> content into assets/css/main.css.
