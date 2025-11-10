# Whisper.cpp (STT)

HubStation uses /stt to call whisper.cpp with a model.

Configure in HubStation/hub_config.json:
- WhisperCppExe: path to main.exe
- WhisperModelPath: path to ggml-base.en.bin (or other)

Runbook
1. Place executable at D:\tools\whisper.cpp\main.exe (or update config).
2. Place model at D:\models\ggml-base.en.bin (or update config).
3. UI: Mic → Stop → UI posts audioBase64 to /stt → transcript returned.

Failure modes
- NO_EXE or NO_MODEL codes in response.
- Large audio may be slow—consider shorter clips.
