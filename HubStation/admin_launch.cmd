@echo off
setlocal
set SCRIPT_PATH=%~dp0admin_setup.ps1

echo.
echo This will prompt for admin rights, fix URL ACLs on the configured port, and start HubStation.
echo Script: %SCRIPT_PATH%
echo.
REM Launch elevated PowerShell running admin_setup.ps1 (uses $PSScriptRoot)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process PowerShell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%SCRIPT_PATH%'"

echo.
echo After it finishes, a log may be created at: %~dp0admin_setup.log
echo Press any key after ~10 seconds to open the log if present.
pause >nul
if exist "%~dp0admin_setup.log" start notepad "%~dp0admin_setup.log"
endlocal
