@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
if not exist "%SCRIPT_DIR%test-hubstation.ps1" (
    echo test-hubstation.ps1 not found next to TEST.bat
    exit /b 1
)
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%test-hubstation.ps1" %*
