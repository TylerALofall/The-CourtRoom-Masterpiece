# HubStation File Mapping and Syntax Check Script
# Lists all files, checks for key components, and scans for syntax errors

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Scanning HubStation directory: $basePath" -ForegroundColor Cyan

# List all files and folders
Write-Host "\nAll files and folders:" -ForegroundColor Yellow
Get-ChildItem -Path $basePath -Recurse | Select-Object FullName | ForEach-Object { Write-Host $_.FullName }

# Check for key files
$keyFiles = @(
    "index.html",
    "GeminiService.ps1",
    "Reflections.psm1",
    "HubStation.ps1",
    "hub_config.json",
    "shared_bus",
    "START.bat",
    "Start-HubStation.ps1"
)
Write-Host "\nChecking for required files/components:" -ForegroundColor Yellow
foreach ($file in $keyFiles) {
    $found = Get-ChildItem -Path $basePath -Recurse -Force | Where-Object { $_.Name -ieq $file }
    if ($found) {
        Write-Host "Found: $file" -ForegroundColor Green
    } else {
        Write-Host "Missing: $file" -ForegroundColor Red
    }
}

# Scan .ps1 and .psm1 files for syntax errors
Write-Host "\nScanning PowerShell scripts for syntax errors:" -ForegroundColor Yellow
$scriptFiles = Get-ChildItem -Path $basePath -Recurse -Include *.ps1,*.psm1
foreach ($script in $scriptFiles) {
    Write-Host "Checking: $($script.FullName)" -ForegroundColor Gray
    try {
        $content = Get-Content $script.FullName -Raw
        [void][System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Host "Syntax OK" -ForegroundColor Green
    }
    catch { Write-Host "Syntax Error: $($_.Exception.Message)" -ForegroundColor Red }
}

Write-Host "\nMapping and syntax check complete." -ForegroundColor Cyan