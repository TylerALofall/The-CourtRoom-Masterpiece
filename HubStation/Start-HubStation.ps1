# ==============================================================================
# Start HubStation - Simple Startup with Audio Feedback
# Just double-click this file!
# ==============================================================================

# Parameters must be declared before any non-comment statements
param(
    [switch]$NoSound
)

# Set the Gemini API Key automatically (for this session only)
$env:GEMINI_API_KEY = "AIzaSyDq9_og3lYjSVZtwWhq3MaO2XvuFMAyR3M"

# Function to speak and write
function Write-Status {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )

    Write-Host $Message -ForegroundColor $Color

    if (-not $NoSound) {
        try {
            Add-Type -AssemblyName System.Speech
            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $synth.SelectVoiceByHints('Male') # or 'Female'
            $synth.Speak($Message)
            $synth.Dispose()
        } catch {
            # Silent fail if TTS not available
        }
    }
}

# ==============================================================================
# STEP 1: Check if we're in the right directory
# ==============================================================================

Write-Status "Starting HubStation setup" "Cyan"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path (Join-Path $scriptDir "HubStation.ps1"))) {
    Write-Status "ERROR: Cannot find HubStation.ps1. Please run this script from the HubStation directory." "Red"
    Read-Host "Press Enter to exit"
    exit 1
}

Set-Location $scriptDir
Write-Status "Directory check passed" "Green"

# ==============================================================================
# STEP 2: Check for Ollama
# ==============================================================================

Write-Status "Checking for Ollama" "Cyan"

try {
    $ollamaCheck = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
    Write-Status "Ollama is running" "Green"
} catch {
    Write-Status "WARNING: Ollama is not running. Please start Ollama first." "Yellow"
    Write-Status "You can start Ollama by running: ollama serve" "Yellow"

    $response = Read-Host "Do you want to continue anyway? (y/n)"
    if ($response -ne 'y') {
        Write-Status "Exiting. Please start Ollama and try again." "Red"
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# ==============================================================================
# STEP 3: Check for Gemini API Key
# ==============================================================================

Write-Status "Checking for Gemini API key" "Cyan"

if (-not $env:GEMINI_API_KEY) {
    Write-Status "WARNING: GEMINI_API_KEY environment variable is not set." "Yellow"
    Write-Status "Gemini evidence card generation will not work without it." "Yellow"

    $key = Read-Host "Enter your Gemini API key (or press Enter to skip)"
    if ($key) {
        $env:GEMINI_API_KEY = $key
        Write-Status "Gemini API key set for this session" "Green"
    } else {
        Write-Status "Skipping Gemini API key. You can set it later." "Yellow"
    }
} else {
    Write-Status "Gemini API key found" "Green"
}

# ==============================================================================
# STEP 4: Check port availability
# ==============================================================================

Write-Status "Checking if port 9099 is available" "Cyan"

try {
    $portCheck = Test-NetConnection -ComputerName localhost -Port 9099 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($portCheck) {
    Write-Status "WARNING: Port 9099 is already in use. HubStation may fail to start." "Yellow"

        $response = Read-Host "Do you want to continue anyway? (y/n)"
        if ($response -ne 'y') {
            Write-Status "Exiting. Please close the application using port 9099." "Red"
            Read-Host "Press Enter to exit"
            exit 1
        }
    } else {
    Write-Status "Port 9099 is available" "Green"
    }
} catch {
    # Port is available (Test-NetConnection fails when nothing is listening)
    Write-Status "Port 9099 is available" "Green"
}

# ==============================================================================
# STEP 5: Start HubStation
# ==============================================================================

Write-Status "All checks passed. Starting HubStation now." "Green"
Write-Status "You should hear module loading messages in a moment." "Cyan"

Start-Sleep -Seconds 2

# Start HubStation.ps1
& (Join-Path $scriptDir "HubStation.ps1")
