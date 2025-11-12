# ========================================================================# ==============================================================================

# HubStation Test Script - Diagnose what's working and what's not# HubStation Test Script - Diagnose what's working and what's not

# Run this while HubStation is running# Run this while HubStation is running

# ========================================================================# ==============================================================================



param([switch]$NoSound)param([switch]$NoSound)



function Speak {function Speak {

    param([string]$Message)    param([string]$Message)

    Write-Host $Message -ForegroundColor Cyan    Write-Host $Message -ForegroundColor Cyan

    if (-not $NoSound) {    if (-not $NoSound) {

        try {        try {

            Add-Type -AssemblyName System.Speech            Add-Type -AssemblyName System.Speech

            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

            $synth.Rate = 1            $synth.Rate = 1

            $synth.Speak($Message)            $synth.Speak($Message)

            $synth.Dispose()            $synth.Dispose()

        } catch {        } catch {}

            # Ignore text-to-speech failures so the test keeps running    }

        }}

    }

}function Test-Endpoint {

    param(

function Test-Endpoint {        [string]$Name,

    param(        [string]$Url,

        [string]$Name,        [string]$Method = "GET",

        [string]$Url,        [hashtable]$Body = $null

        [string]$Method = "GET",    )

        [hashtable]$Body = $null

    )    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

    Write-Host "Testing: $Name" -ForegroundColor Yellow

    Write-Host ""    Write-Host "URL: $Url" -ForegroundColor Gray

    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

    Write-Host "Testing: $Name" -ForegroundColor Yellow

    Write-Host "URL: $Url" -ForegroundColor Gray    try {

    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow        if ($Method -eq "GET") {

            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5 -ErrorAction Stop

    try {        } else {

        if ($Method -eq "GET") {            $bodyJson = $Body | ConvertTo-Json -Depth 5

            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5 -ErrorAction Stop            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop

        } else {        }

            $bodyJson = $Body | ConvertTo-Json -Depth 5

            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop        Write-Host "✓ SUCCESS" -ForegroundColor Green

        }        Write-Host "Response:" -ForegroundColor White

        $response | ConvertTo-Json -Depth 3 | Write-Host

        Write-Host "SUCCESS" -ForegroundColor Green

        Write-Host "Response:" -ForegroundColor White        return @{ success = $true; response = $response }

        Write-Host ($response | ConvertTo-Json -Depth 3)    } catch {

        Write-Host "✗ FAILED" -ForegroundColor Red

        return @{ success = $true; response = $response }        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    } catch {

        Write-Host "FAILED" -ForegroundColor Red        if ($_.Exception.Response) {

        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red            $statusCode = $_.Exception.Response.StatusCode.value__

            Write-Host "Status Code: $statusCode" -ForegroundColor Red

        if ($_.Exception.Response) {        }

            try {

                $statusCode = $_.Exception.Response.StatusCode.value__        return @{ success = $false; error = $_.Exception.Message }

                Write-Host "Status Code: $statusCode" -ForegroundColor Red    }

            } catch {}

                # Ignore status code parsing issues

            }# ==============================================================================

        }# Main Test Suite

# ==============================================================================

        return @{ success = $false; error = $_.Exception.Message }

    }Clear-Host

}

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

# ========================================================================Write-Host "  HubStation Test Suite" -ForegroundColor Cyan

# Main Test SuiteWrite-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

# ========================================================================Write-Host ""



Clear-HostSpeak "Starting HubStation test suite"



Write-Host "============================================================" -ForegroundColor Cyan$baseUrl = "http://localhost:9199"

Write-Host "  HubStation Test Suite" -ForegroundColor Cyan$results = @{}

Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""# ==============================================================================

# Test 1: Basic Status

Speak "Starting HubStation test suite"# ==============================================================================



$baseUrl = "http://localhost:9199"$results.status = Test-Endpoint -Name "Status Endpoint" -Url "$baseUrl/status"

$results = @{}

# ==============================================================================

# Core endpoints# Test 2: Reflection - CSV Tail

$results.status = Test-Endpoint -Name "Status Endpoint" -Url "$baseUrl/status"# ==============================================================================

$results.csvTail = Test-Endpoint -Name "CSV Tail (Reflection System)" -Url "$baseUrl/logs/csv/tail?rows=5"

$results.reflectWindow = Test-Endpoint -Name "Reflection Window" -Url "$baseUrl/reflect/window?rows=10"$results.csvTail = Test-Endpoint -Name "CSV Tail (Reflection System)" -Url "$baseUrl/logs/csv/tail?rows=5"



$reflectionBody = @{# ==============================================================================

    title = "Test Reflection"# Test 3: Reflection - Window

    goal = "Test the reflection submission endpoint"# ==============================================================================

    summary = "Testing if reflection submission works"

    source_model = "test-script"$results.reflectWindow = Test-Endpoint -Name "Reflection Window" -Url "$baseUrl/reflect/window?rows=10"

    meta_tags = "test,diagnostic"

}# ==============================================================================

$results.reflectSubmit = Test-Endpoint -Name "Reflection Submit" -Url "$baseUrl/reflect/submit" -Method "POST" -Body $reflectionBody# Test 4: Reflection - Submit

# ==============================================================================

# Static files

Write-Host ""$reflectionBody = @{

Write-Host "------------------------------------------------------------" -ForegroundColor Yellow    title = "Test Reflection"

Write-Host "Testing: Static File Serving" -ForegroundColor Yellow    goal = "Test the reflection submission endpoint"

Write-Host "URL: $baseUrl/web" -ForegroundColor Gray    summary = "Testing if reflection submission works"

Write-Host "------------------------------------------------------------" -ForegroundColor Yellow    source_model = "test-script"

    meta_tags = "test,diagnostic"

try {}

    $webResponse = Invoke-WebRequest -Uri "$baseUrl/web" -TimeoutSec 5 -ErrorAction Stop

    Write-Host "SUCCESS" -ForegroundColor Green$results.reflectSubmit = Test-Endpoint -Name "Reflection Submit" -Url "$baseUrl/reflect/submit" -Method "POST" -Body $reflectionBody

    Write-Host "Status: $($webResponse.StatusCode)" -ForegroundColor White

    Write-Host "Content Length: $($webResponse.Content.Length) bytes" -ForegroundColor White# ==============================================================================

    $results.staticFiles = @{ success = $true }# Test 5: Static Files (index.html)

} catch {# ==============================================================================

    Write-Host "FAILED" -ForegroundColor Red

    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor RedWrite-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

    $results.staticFiles = @{ success = $false; error = $_.Exception.Message }Write-Host "Testing: Static File Serving" -ForegroundColor Yellow

}Write-Host "URL: $baseUrl/web" -ForegroundColor Gray

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

# Optional endpoints

$geminiBody = @{try {

    description = "Test evidence description"    $webResponse = Invoke-WebRequest -Uri "$baseUrl/web" -TimeoutSec 5 -ErrorAction Stop

    quote = "Test quote"    Write-Host "✓ SUCCESS" -ForegroundColor Green

    context = "Test context"    Write-Host "Status: $($webResponse.StatusCode)" -ForegroundColor White

}    Write-Host "Content Length: $($webResponse.Content.Length) bytes" -ForegroundColor White

$results.gemini = Test-Endpoint -Name "Gemini Analyze (Optional)" -Url "$baseUrl/api/gemini/analyze" -Method "POST" -Body $geminiBody    $results.staticFiles = @{ success = $true }

} catch {

$runnerBody = @{    Write-Host "✗ FAILED" -ForegroundColor Red

    prompt = "Test prompt"    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    context = "Test context"    $results.staticFiles = @{ success = $false; error = $_.Exception.Message }

}}

$results.runner = Test-Endpoint -Name "Runner Prompt (Optional)" -Url "$baseUrl/api/runner/prompt" -Method "POST" -Body $runnerBody

# ==============================================================================

# Logs endpoint# Test 6: Gemini Endpoint (will fail if GeminiService not loaded)

$results.logs = Test-Endpoint -Name "Logs Endpoint" -Url "$baseUrl/logs?n=10"# ==============================================================================



# Summary$geminiBody = @{

Write-Host ""    description = "Test evidence description"

Write-Host "============================================================" -ForegroundColor Cyan    quote = "Test quote"

Write-Host "  TEST SUMMARY" -ForegroundColor Cyan    context = "Test context"

Write-Host "============================================================" -ForegroundColor Cyan}

Write-Host ""

$results.gemini = Test-Endpoint -Name "Gemini Analyze (Optional)" -Url "$baseUrl/api/gemini/analyze" -Method "POST" -Body $geminiBody

$totalTests = 0

$passedTests = 0# ==============================================================================

$failedTests = 0# Test 7: Runner Endpoint (will fail if OllamaRunner not loaded)

$optionalFailed = 0# ==============================================================================



foreach ($test in $results.Keys) {$runnerBody = @{

    $totalTests++    prompt = "Test prompt"

    $testName = $test    context = "Test context"

    $testResult = $results[$test]}



    if ($testResult.success) {$results.runner = Test-Endpoint -Name "Runner Prompt (Optional)" -Url "$baseUrl/api/runner/prompt" -Method "POST" -Body $runnerBody

        $passedTests++

        Write-Host "PASS  - $testName" -ForegroundColor Green# ==============================================================================

        continue# Test 8: Logs

    }# ==============================================================================



    if ($test -in @("gemini", "runner")) {$results.logs = Test-Endpoint -Name "Logs Endpoint" -Url "$baseUrl/logs?n=10"

        $optionalFailed++

        Write-Host "SKIP  - $testName (optional - module not loaded)" -ForegroundColor Yellow# ==============================================================================

    } else {# Summary

        $failedTests++# ==============================================================================

        Write-Host "FAIL  - $testName - $($testResult.error)" -ForegroundColor Red

    }Write-Host "`n`n════════════════════════════════════════════════════════" -ForegroundColor Cyan

}Write-Host "  TEST SUMMARY" -ForegroundColor Cyan

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host ""Write-Host ""

Write-Host "------------------------------------------------------------" -ForegroundColor White

Write-Host "Total Tests: $totalTests" -ForegroundColor White$totalTests = 0

Write-Host "Passed: $passedTests" -ForegroundColor Green$passedTests = 0

Write-Host "Failed: $failedTests" -ForegroundColor Red$failedTests = 0

Write-Host "Optional failures: $optionalFailed" -ForegroundColor Yellow$optionalFailed = 0

Write-Host "------------------------------------------------------------" -ForegroundColor White

Write-Host ""foreach ($test in $results.Keys) {

    $totalTests++

# Recommendations    $testName = $test

Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan    $testResult = $results[$test]

Write-Host ""

    if ($testResult.success) {

if ($failedTests -eq 0 -and $passedTests -gt 0) {        $passedTests++

    Speak "All core tests passed"        Write-Host "✓ $testName" -ForegroundColor Green

    Write-Host "PASS  - Core functionality is working" -ForegroundColor Green        continue

    Write-Host ""    }

}

    if ($test -in @("gemini", "runner")) {

if ($results.gemini.success -eq $false) {        $optionalFailed++

    Write-Host "WARN - GeminiService.ps1 is not loaded" -ForegroundColor Yellow        Write-Host "○ $testName (optional - module not loaded)" -ForegroundColor Yellow

    Write-Host "       Evidence card generation via Gemini will be unavailable" -ForegroundColor Gray    } else {

    Write-Host "       This component is optional" -ForegroundColor Gray        $failedTests++

    Write-Host ""        Write-Host "✗ $testName - $($testResult.error)" -ForegroundColor Red

}    }

}

if ($results.runner.success -eq $false) {

    Write-Host "WARN - OllamaRunner is not loaded" -ForegroundColor YellowWrite-Host ""

    Write-Host "       AI model routing (6 routes) will be unavailable" -ForegroundColor GrayWrite-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White

    Write-Host "       This component is optional" -ForegroundColor GrayWrite-Host "Total Tests: $totalTests" -ForegroundColor White

    Write-Host ""Write-Host "Passed: $passedTests" -ForegroundColor Green

}Write-Host "Failed: $failedTests" -ForegroundColor Red

Write-Host "Optional (not loaded): $optionalFailed" -ForegroundColor Yellow

if ($results.status.success) {Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White

    Write-Host "PASS  - Web interface available at http://localhost:9199/web" -ForegroundColor GreenWrite-Host ""

    Write-Host ""

}# ==============================================================================

# Recommendations

if ($results.reflectSubmit.success) {# ==============================================================================

    Write-Host "PASS  - Reflection submitted successfully" -ForegroundColor Green

    Write-Host "       Check logs with:  Get-Content HubStation\shared_bus\logs\hub_events.csv" -ForegroundColor CyanWrite-Host "RECOMMENDATIONS:" -ForegroundColor Cyan

    Write-Host "       Check files with: Get-ChildItem HubStation\shared_bus\reflections\*" -ForegroundColor CyanWrite-Host ""

    Write-Host ""

}if ($failedTests -eq 0 -and $passedTests -gt 0) {

    Speak "All core tests passed"

# Browser test prompt    Write-Host "✓ Core functionality is working!" -ForegroundColor Green

Write-Host "BROWSER TEST:" -ForegroundColor Cyan    Write-Host ""

Write-Host "Open your browser and visit http://localhost:9199/web" -ForegroundColor White}

Write-Host "If index.html loads, static files are working." -ForegroundColor White

Write-Host ""if ($results.gemini.success -eq $false) {

    Write-Host "• GeminiService.ps1 is not loaded" -ForegroundColor Yellow

$openBrowser = Read-Host "Open browser now? (y/n)"    Write-Host "  → Evidence card generation via Gemini won't work" -ForegroundColor Gray

if ($openBrowser -eq 'y') {    Write-Host "  → This is optional" -ForegroundColor Gray

    Start-Process "http://localhost:9199/web"    Write-Host ""

    Speak "Opening browser"}

}

if ($results.runner.success -eq $false) {

Write-Host ""    Write-Host "• OllamaRunner is not loaded" -ForegroundColor Yellow

Write-Host "============================================================" -ForegroundColor Cyan    Write-Host "  → AI model routing (6 routes) won't work" -ForegroundColor Gray

Write-Host "  Test Complete" -ForegroundColor Cyan    Write-Host "  → This is optional" -ForegroundColor Gray

Write-Host "============================================================" -ForegroundColor Cyan    Write-Host ""

}

Speak "Test complete"

if ($results.status.success) {
    Write-Host "✓ You can access the web interface at:" -ForegroundColor Green
    Write-Host "  http://localhost:9199/web" -ForegroundColor Cyan
    Write-Host ""
}

if ($results.reflectSubmit.success) {
    Write-Host "✓ Check your reflection was saved:" -ForegroundColor Green
    Write-Host "  Get-Content HubStation\shared_bus\logs\hub_events.csv" -ForegroundColor Cyan
    Write-Host ("  Get-ChildItem {0}" -f 'HubStation\shared_bus\reflections\') -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================================================
# Browser Test
# ==============================================================================

Write-Host "BROWSER TEST:" -ForegroundColor Cyan
Write-Host "Open your browser and go to:" -ForegroundColor White
Write-Host "  http://localhost:9199/web" -ForegroundColor Yellow
Write-Host ""
Write-Host "If you see your index.html page, static files are working!" -ForegroundColor White
Write-Host ""

$openBrowser = Read-Host "Open browser now? (y/n)"
if ($openBrowser -eq 'y') {
    Start-Process "http://localhost:9199/web"
    Speak "Opening browser"
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Complete" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

Speak "Test complete"
