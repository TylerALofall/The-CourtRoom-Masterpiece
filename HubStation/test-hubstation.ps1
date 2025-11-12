# ==============================================================================Write-Host "Hello"# ========================================================================# ========================================================================# ========================================================================# ==============================================================================

# HubStation Test Script - Diagnose what's working and what's not

# Run this while HubStation is running# HubStation Test Script - Diagnose what's working and what's not

# ==============================================================================

# Run this while HubStation is running# HubStation Test Script - Diagnose what's working and what's not

param([switch]$NoSound)

# ========================================================================

function Speak {

    param([string]$Message)# Run this while HubStation is running# HubStation Test Script - Diagnose what's working and what's not# HubStation Test Script - Diagnose what's working and what's not

    Write-Host $Message -ForegroundColor Cyan

    if (-not $NoSound) {param([switch]$NoSound)

        try {

            Add-Type -AssemblyName System.Speech# ========================================================================

            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

            $synth.Rate = 1function Speak {

            $synth.Speak($Message)

            $synth.Dispose()    param([string]$Message)# Run this while HubStation is running# Run this while HubStation is running

        } catch {}

    }

}

    Write-Host $Message -ForegroundColor Cyanparam([switch]$NoSound)

function Test-Endpoint {

    param(    if (-not $NoSound) {

        [string]$Name,

        [string]$Url,        try {# ========================================================================# ==============================================================================

        [string]$Method = "GET",

        [hashtable]$Body = $null            Add-Type -AssemblyName System.Speech

    )

            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizerfunction Speak {

    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

    Write-Host "Testing: $Name" -ForegroundColor Yellow            $synth.Rate = 1

    Write-Host "URL: $Url" -ForegroundColor Gray

    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow            $synth.Speak($Message)    param([string]$Message)



    try {            $synth.Dispose()

        if ($Method -eq "GET") {

            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5 -ErrorAction Stop        } catch {

        } else {

            $bodyJson = $Body | ConvertTo-Json -Depth 5            # Ignore text-to-speech failures so the test keeps running

            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop

        }        }    Write-Host $Message -ForegroundColor Cyanparam([switch]$NoSound)param([switch]$NoSound)



        Write-Host "✓ SUCCESS" -ForegroundColor Green    }

        Write-Host "Response:" -ForegroundColor White

        $response | ConvertTo-Json -Depth 3 | Write-Host}    if (-not $NoSound) {



        return @{ success = $true; response = $response }

    } catch {

        Write-Host "✗ FAILED" -ForegroundColor Redfunction Test-Endpoint {        try {

        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    param(

        if ($_.Exception.Response) {

            $statusCode = $_.Exception.Response.StatusCode.value__        [string]$Name,            Add-Type -AssemblyName System.Speech

            Write-Host "Status Code: $statusCode" -ForegroundColor Red

        }        [string]$Url,



        return @{ success = $false; error = $_.Exception.Message }        [string]$Method = "GET",            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizerfunction Speak {function Speak {

    }

}        [hashtable]$Body = $null



# ==============================================================================    )            $synth.Rate = 1

# Main Test Suite

# ==============================================================================



Clear-Host    Write-Host ""            $synth.Speak($Message)    param([string]$Message)    param([string]$Message)



Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow

Write-Host "  HubStation Test Suite" -ForegroundColor Cyan

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan    Write-Host "Testing: $Name" -ForegroundColor Yellow            $synth.Dispose()

Write-Host ""

    Write-Host "URL: $Url" -ForegroundColor Gray

Speak "Starting HubStation test suite"

    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow        } catch {    Write-Host $Message -ForegroundColor Cyan    Write-Host $Message -ForegroundColor Cyan

$baseUrl = "http://localhost:9099"

$results = @{}



# ==============================================================================    try {            # Ignore text-to-speech failures so the test keeps running

# Test 1: Basic Status

# ==============================================================================        if ($Method -eq "GET") {



$results.status = Test-Endpoint -Name "Status Endpoint" -Url "$baseUrl/status"            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5 -ErrorAction Stop        }    if (-not $NoSound) {    if (-not $NoSound) {



# ==============================================================================        } else {

# Test 2: Reflection - CSV Tail

# ==============================================================================            $bodyJson = $Body | ConvertTo-Json -Depth 5    }



$results.csvTail = Test-Endpoint -Name "CSV Tail (Reflection System)" -Url "$baseUrl/logs/csv/tail?rows=5"            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop



# ==============================================================================        }}        try {        try {

# Test 3: Reflection - Window

# ==============================================================================



$results.reflectWindow = Test-Endpoint -Name "Reflection Window" -Url "$baseUrl/reflect/window?rows=10"        Write-Host "SUCCESS" -ForegroundColor Green



# ==============================================================================        Write-Host "Response:" -ForegroundColor White

# Test 4: Reflection - Submit

# ==============================================================================        Write-Host ($response | ConvertTo-Json -Depth 3)function Test-Endpoint {            Add-Type -AssemblyName System.Speech            Add-Type -AssemblyName System.Speech



$reflectionBody = @{

    title = "Test Reflection"

    goal = "Test the reflection submission endpoint"        return @{ success = $true; response = $response }    param(

    summary = "Testing if reflection submission works"

    source_model = "test-script"    } catch {

    meta_tags = "test,diagnostic"

}        Write-Host "FAILED" -ForegroundColor Red        [string]$Name,            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer            $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer



$results.reflectSubmit = Test-Endpoint -Name "Reflection Submit" -Url "$baseUrl/reflect/submit" -Method "POST" -Body $reflectionBody        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red



# ==============================================================================        [string]$Url,

# Test 5: Static Files (index.html)

# ==============================================================================        if ($_.Exception.Response) {



Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow            try {        [string]$Method = "GET",            $synth.Rate = 1            $synth.Rate = 1

Write-Host "Testing: Static File Serving" -ForegroundColor Yellow

Write-Host "URL: $baseUrl/web" -ForegroundColor Gray                $statusCode = $_.Exception.Response.StatusCode.value__

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

                Write-Host "Status Code: $statusCode" -ForegroundColor Red        [hashtable]$Body = $null

try {

    $webResponse = Invoke-WebRequest -Uri "$baseUrl/web" -TimeoutSec 5 -ErrorAction Stop            } catch {

    Write-Host "✓ SUCCESS" -ForegroundColor Green

    Write-Host "Status: $($webResponse.StatusCode)" -ForegroundColor White                # Ignore status code parsing issues    )            $synth.Speak($Message)            $synth.Speak($Message)

    Write-Host "Content Length: $($webResponse.Content.Length) bytes" -ForegroundColor White

    $results.staticFiles = @{ success = $true }            }

} catch {

    Write-Host "✗ FAILED" -ForegroundColor Red        }

    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    $results.staticFiles = @{ success = $false; error = $_.Exception.Message }

}

        return @{ success = $false; error = $_.Exception.Message }    Write-Host ""            $synth.Dispose()            $synth.Dispose()

# ==============================================================================

# Test 6: Gemini Endpoint (will fail if GeminiService not loaded)    }

# ==============================================================================

}    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow

$geminiBody = @{

    description = "Test evidence description"

    quote = "Test quote"

    context = "Test context"# ========================================================================    Write-Host "Testing: $Name" -ForegroundColor Yellow        } catch {        } catch {}

}

# Main Test Suite

$results.gemini = Test-Endpoint -Name "Gemini Analyze (Optional)" -Url "$baseUrl/api/gemini/analyze" -Method "POST" -Body $geminiBody

# ========================================================================    Write-Host "URL: $Url" -ForegroundColor Gray

# ==============================================================================

# Test 7: Runner Endpoint (will fail if OllamaRunner not loaded)

# ==============================================================================

Clear-Host    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow            # Ignore text-to-speech failures so the test keeps running    }

$runnerBody = @{

    prompt = "Test prompt"

    context = "Test context"

}Write-Host "============================================================" -ForegroundColor Cyan



$results.runner = Test-Endpoint -Name "Runner Prompt (Optional)" -Url "$baseUrl/api/runner/prompt" -Method "POST" -Body $runnerBodyWrite-Host "  HubStation Test Suite" -ForegroundColor Cyan



# ==============================================================================Write-Host "============================================================" -ForegroundColor Cyan    try {        }}

# Test 8: Logs

# ==============================================================================Write-Host ""



$results.logs = Test-Endpoint -Name "Logs Endpoint" -Url "$baseUrl/logs?n=10"        if ($Method -eq "GET") {



# ==============================================================================Speak "Starting HubStation test suite"

# Summary

# ==============================================================================            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5 -ErrorAction Stop    }



Write-Host "`n`n════════════════════════════════════════════════════════" -ForegroundColor Cyan$baseUrl = "http://localhost:9099"

Write-Host "  TEST SUMMARY" -ForegroundColor Cyan

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan$results = @{}        } else {

Write-Host ""



$totalTests = 0

$passedTests = 0# Core endpoints            $bodyJson = $Body | ConvertTo-Json -Depth 5}function Test-Endpoint {

$failedTests = 0

$optionalFailed = 0$results.status = Test-Endpoint -Name "Status Endpoint" -Url "$baseUrl/status"



foreach ($test in $results.Keys) {$results.csvTail = Test-Endpoint -Name "CSV Tail (Reflection System)" -Url "$baseUrl/logs/csv/tail?rows=5"            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop

    $totalTests++

    $testName = $test$results.reflectWindow = Test-Endpoint -Name "Reflection Window" -Url "$baseUrl/reflect/window?rows=10"

    $testResult = $results[$test]

        }    param(

    if ($testResult.success) {

        $passedTests++$reflectionBody = @{

        Write-Host "✓ $testName" -ForegroundColor Green

        continue    title = "Test Reflection"

    }

    goal = "Test the reflection submission endpoint"

    if ($test -in @("gemini", "runner")) {

        $optionalFailed++    summary = "Testing if reflection submission works"        Write-Host "SUCCESS" -ForegroundColor Greenfunction Test-Endpoint {        [string]$Name,

        Write-Host "○ $testName (optional - module not loaded)" -ForegroundColor Yellow

    } else {    source_model = "test-script"

        $failedTests++

        Write-Host "✗ $testName - $($testResult.error)" -ForegroundColor Red    meta_tags = "test,diagnostic"        Write-Host "Response:" -ForegroundColor White

    }

}}



Write-Host ""$results.reflectSubmit = Test-Endpoint -Name "Reflection Submit" -Url "$baseUrl/reflect/submit" -Method "POST" -Body $reflectionBody        Write-Host ($response | ConvertTo-Json -Depth 3)    param(        [string]$Url,

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White

Write-Host "Total Tests: $totalTests" -ForegroundColor White

Write-Host "Passed: $passedTests" -ForegroundColor Green

Write-Host "Failed: $failedTests" -ForegroundColor Red# Static files

Write-Host "Optional (not loaded): $optionalFailed" -ForegroundColor Yellow

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor WhiteWrite-Host ""

Write-Host ""

Write-Host "------------------------------------------------------------" -ForegroundColor Yellow        return @{ success = $true; response = $response }        [string]$Name,        [string]$Method = "GET",

# ==============================================================================

# RecommendationsWrite-Host "Testing: Static File Serving" -ForegroundColor Yellow

# ==============================================================================

Write-Host "URL: $baseUrl/web" -ForegroundColor Gray    } catch {

Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan

Write-Host ""Write-Host "------------------------------------------------------------" -ForegroundColor Yellow



if ($failedTests -eq 0 -and $passedTests -gt 0) {        Write-Host "FAILED" -ForegroundColor Red        [string]$Url,        [hashtable]$Body = $null

    Speak "All core tests passed"

    Write-Host "✓ Core functionality is working!" -ForegroundColor Greentry {

    Write-Host ""

}    $webResponse = Invoke-WebRequest -Uri "$baseUrl/web" -TimeoutSec 5 -ErrorAction Stop        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red



if ($results.gemini.success -eq $false) {    Write-Host "SUCCESS" -ForegroundColor Green

    Write-Host "• GeminiService.ps1 is not loaded" -ForegroundColor Yellow

    Write-Host "  → Evidence card generation via Gemini won't work" -ForegroundColor Gray    Write-Host "Status: $($webResponse.StatusCode)" -ForegroundColor White        [string]$Method = "GET",    )

    Write-Host "  → This is optional" -ForegroundColor Gray

    Write-Host ""    Write-Host "Content Length: $($webResponse.Content.Length) bytes" -ForegroundColor White

}

    $results.staticFiles = @{ success = $true }        if ($_.Exception.Response) {

if ($results.runner.success -eq $false) {

    Write-Host "• OllamaRunner is not loaded" -ForegroundColor Yellow} catch {

    Write-Host "  → AI model routing (6 routes) won't work" -ForegroundColor Gray

    Write-Host "  → This is optional" -ForegroundColor Gray    Write-Host "FAILED" -ForegroundColor Red            try {        [hashtable]$Body = $null

    Write-Host ""

}    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red



if ($results.status.success) {    $results.staticFiles = @{ success = $false; error = $_.Exception.Message }                $statusCode = $_.Exception.Response.StatusCode.value__

    Write-Host "✓ You can access the web interface at:" -ForegroundColor Green

    Write-Host "  http://localhost:9099/web" -ForegroundColor Cyan}

    Write-Host ""

}                Write-Host "Status Code: $statusCode" -ForegroundColor Red    )    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow



if ($results.reflectSubmit.success) {# Optional endpoints

    Write-Host "✓ Check your reflection was saved:" -ForegroundColor Green

    Write-Host "  Get-Content HubStation\shared_bus\logs\hub_events.csv" -ForegroundColor Cyan$geminiBody = @{            } catch {

    Write-Host ("  Get-ChildItem {0}" -f 'HubStation\shared_bus\reflections\') -ForegroundColor Cyan

    Write-Host ""    description = "Test evidence description"

}

    quote = "Test quote"                # Ignore status code parsing issues    Write-Host "Testing: $Name" -ForegroundColor Yellow

# ==============================================================================

# Browser Test    context = "Test context"

# ==============================================================================

}            }

Write-Host "BROWSER TEST:" -ForegroundColor Cyan

Write-Host "Open your browser and go to:" -ForegroundColor White$results.gemini = Test-Endpoint -Name "Gemini Analyze (Optional)" -Url "$baseUrl/api/gemini/analyze" -Method "POST" -Body $geminiBody

Write-Host "  http://localhost:9099/web" -ForegroundColor Yellow

Write-Host ""        }    Write-Host ""    Write-Host "URL: $Url" -ForegroundColor Gray

Write-Host "If you see your index.html page, static files are working!" -ForegroundColor White

Write-Host ""$runnerBody = @{



$openBrowser = Read-Host "Open browser now? (y/n)"    prompt = "Test prompt"

if ($openBrowser -eq 'y') {

    Start-Process "http://localhost:9099/web"    context = "Test context"

    Speak "Opening browser"

}}        return @{ success = $false; error = $_.Exception.Message }    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow



Write-Host ""$results.runner = Test-Endpoint -Name "Runner Prompt (Optional)" -Url "$baseUrl/api/runner/prompt" -Method "POST" -Body $runnerBody

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "  Test Complete" -ForegroundColor Cyan    }

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Logs endpoint

Speak "Test complete"

$results.logs = Test-Endpoint -Name "Logs Endpoint" -Url "$baseUrl/logs?n=10"}    Write-Host "Testing: $Name" -ForegroundColor Yellow



# Summary

Write-Host ""

Write-Host "============================================================" -ForegroundColor Cyan# ========================================================================    Write-Host "URL: $Url" -ForegroundColor Gray    try {

Write-Host "  TEST SUMMARY" -ForegroundColor Cyan

Write-Host "============================================================" -ForegroundColor Cyan# Main Test Suite

Write-Host ""

# ========================================================================    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow        if ($Method -eq "GET") {

$totalTests = 0

$passedTests = 0

$failedTests = 0

$optionalFailed = 0Clear-Host            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5 -ErrorAction Stop



foreach ($testName in $results.Keys) {

    $totalTests++

    $testResult = $results[$testName]Write-Host "============================================================" -ForegroundColor Cyan    try {        } else {



    if ($testResult.success) {Write-Host "  HubStation Test Suite" -ForegroundColor Cyan

        $passedTests++

        Write-Host "PASS  - $testName" -ForegroundColor GreenWrite-Host "============================================================" -ForegroundColor Cyan        if ($Method -eq "GET") {            $bodyJson = $Body | ConvertTo-Json -Depth 5

        continue

    }Write-Host ""



    if ($testName -in @("gemini", "runner")) {            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5 -ErrorAction Stop            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop

        $optionalFailed++

        Write-Host "SKIP  - $testName (optional - module not loaded)" -ForegroundColor YellowSpeak "Starting HubStation test suite"

    } else {

        $failedTests++        } else {        }

        Write-Host "FAIL  - $testName - $($testResult.error)" -ForegroundColor Red

    }$baseUrl = "http://localhost:9099"

}

$results = @{}            $bodyJson = $Body | ConvertTo-Json -Depth 5

Write-Host ""

Write-Host "------------------------------------------------------------" -ForegroundColor White

Write-Host "Total Tests: $totalTests" -ForegroundColor White

Write-Host "Passed: $passedTests" -ForegroundColor Green# Core endpoints            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop        Write-Host "✓ SUCCESS" -ForegroundColor Green

Write-Host "Failed: $failedTests" -ForegroundColor Red

Write-Host "Optional failures: $optionalFailed" -ForegroundColor Yellow$results.status = Test-Endpoint -Name "Status Endpoint" -Url "$baseUrl/status"

Write-Host "------------------------------------------------------------" -ForegroundColor White

Write-Host ""$results.csvTail = Test-Endpoint -Name "CSV Tail (Reflection System)" -Url "$baseUrl/logs/csv/tail?rows=5"        }        Write-Host "Response:" -ForegroundColor White



# Recommendations$results.reflectWindow = Test-Endpoint -Name "Reflection Window" -Url "$baseUrl/reflect/window?rows=10"

Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan

Write-Host ""        $response | ConvertTo-Json -Depth 3 | Write-Host



if ($failedTests -eq 0 -and $passedTests -gt 0) {$reflectionBody = @{

    Speak "All core tests passed"

    Write-Host "PASS  - Core functionality is working" -ForegroundColor Green    title = "Test Reflection"        Write-Host "SUCCESS" -ForegroundColor Green

    Write-Host ""

}    goal = "Test the reflection submission endpoint"



if (-not $results.gemini.success) {    summary = "Testing if reflection submission works"        Write-Host "Response:" -ForegroundColor White        return @{ success = $true; response = $response }

    Write-Host "WARN - GeminiService.ps1 is not loaded" -ForegroundColor Yellow

    Write-Host "       Evidence card generation via Gemini will be unavailable" -ForegroundColor Gray    source_model = "test-script"

    Write-Host "       This component is optional" -ForegroundColor Gray

    Write-Host ""    meta_tags = "test,diagnostic"        Write-Host ($response | ConvertTo-Json -Depth 3)    } catch {

}

}

if (-not $results.runner.success) {

    Write-Host "WARN - OllamaRunner is not loaded" -ForegroundColor Yellow$results.reflectSubmit = Test-Endpoint -Name "Reflection Submit" -Url "$baseUrl/reflect/submit" -Method "POST" -Body $reflectionBody        Write-Host "✗ FAILED" -ForegroundColor Red

    Write-Host "       AI model routing (6 routes) will be unavailable" -ForegroundColor Gray

    Write-Host "       This component is optional" -ForegroundColor Gray

    Write-Host ""

}# Static files        return @{ success = $true; response = $response }        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red



if ($results.status.success) {Write-Host ""

    Write-Host "PASS  - Web interface available at http://localhost:9099/web" -ForegroundColor Green

    Write-Host ""Write-Host "------------------------------------------------------------" -ForegroundColor Yellow    } catch {

}

Write-Host "Testing: Static File Serving" -ForegroundColor Yellow

if ($results.reflectSubmit.success) {

    Write-Host "PASS  - Reflection submitted successfully" -ForegroundColor GreenWrite-Host "URL: $baseUrl/web" -ForegroundColor Gray        Write-Host "FAILED" -ForegroundColor Red        if ($_.Exception.Response) {

    Write-Host "       Check logs with:  Get-Content HubStation\shared_bus\logs\hub_events.csv" -ForegroundColor Cyan

    Write-Host "       Check files with: Get-ChildItem HubStation\shared_bus\reflections\*" -ForegroundColor CyanWrite-Host "------------------------------------------------------------" -ForegroundColor Yellow

    Write-Host ""

}        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red            $statusCode = $_.Exception.Response.StatusCode.value__



# Browser test prompttry {

Write-Host "BROWSER TEST:" -ForegroundColor Cyan

Write-Host "Open your browser and visit http://localhost:9099/web" -ForegroundColor White    $webResponse = Invoke-WebRequest -Uri "$baseUrl/web" -TimeoutSec 5 -ErrorAction Stop            Write-Host "Status Code: $statusCode" -ForegroundColor Red

Write-Host "If index.html loads, static files are working." -ForegroundColor White

Write-Host ""    Write-Host "SUCCESS" -ForegroundColor Green



$openBrowser = Read-Host "Open browser now? (y/n)"    Write-Host "Status: $($webResponse.StatusCode)" -ForegroundColor White        if ($_.Exception.Response) {        }

if ($openBrowser -eq 'y') {

    Start-Process "http://localhost:9099/web"    Write-Host "Content Length: $($webResponse.Content.Length) bytes" -ForegroundColor White

    Speak "Opening browser"

}    $results.staticFiles = @{ success = $true }            try {



Write-Host ""} catch {

Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "  Test Complete" -ForegroundColor Cyan    Write-Host "FAILED" -ForegroundColor Red                $statusCode = $_.Exception.Response.StatusCode.value__        return @{ success = $false; error = $_.Exception.Message }

Write-Host "============================================================" -ForegroundColor Cyan

    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

Speak "Test complete"

    $results.staticFiles = @{ success = $false; error = $_.Exception.Message }                Write-Host "Status Code: $statusCode" -ForegroundColor Red    }

}

            } catch {}

# Optional endpoints

$geminiBody = @{                # Ignore status code parsing issues

    description = "Test evidence description"

    quote = "Test quote"            }# ==============================================================================

    context = "Test context"

}        }# Main Test Suite

$results.gemini = Test-Endpoint -Name "Gemini Analyze (Optional)" -Url "$baseUrl/api/gemini/analyze" -Method "POST" -Body $geminiBody

# ==============================================================================

$runnerBody = @{

    prompt = "Test prompt"        return @{ success = $false; error = $_.Exception.Message }

    context = "Test context"

}    }Clear-Host

$results.runner = Test-Endpoint -Name "Runner Prompt (Optional)" -Url "$baseUrl/api/runner/prompt" -Method "POST" -Body $runnerBody

}

# Logs endpoint

$results.logs = Test-Endpoint -Name "Logs Endpoint" -Url "$baseUrl/logs?n=10"Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan



# Summary# ========================================================================Write-Host "  HubStation Test Suite" -ForegroundColor Cyan

Write-Host ""

Write-Host "============================================================" -ForegroundColor Cyan# Main Test SuiteWrite-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "  TEST SUMMARY" -ForegroundColor Cyan

Write-Host "============================================================" -ForegroundColor Cyan# ========================================================================Write-Host ""

Write-Host ""



$totalTests = 0

$passedTests = 0Clear-HostSpeak "Starting HubStation test suite"

$failedTests = 0

$optionalFailed = 0



foreach ($testName in $results.Keys) {Write-Host "============================================================" -ForegroundColor Cyan$baseUrl = "http://localhost:9099"

    $totalTests++

    $testResult = $results[$testName]Write-Host "  HubStation Test Suite" -ForegroundColor Cyan$results = @{}



    if ($testResult.success) {Write-Host "============================================================" -ForegroundColor Cyan

        $passedTests++

        Write-Host "PASS  - $testName" -ForegroundColor GreenWrite-Host ""# ==============================================================================

        continue

    }# Test 1: Basic Status



    if ($testName -in @("gemini", "runner")) {Speak "Starting HubStation test suite"# ==============================================================================

        $optionalFailed++

        Write-Host "SKIP  - $testName (optional - module not loaded)" -ForegroundColor Yellow

    } else {

    $failedTests++$baseUrl = "http://localhost:9099"$results.status = Test-Endpoint -Name "Status Endpoint" -Url "$baseUrl/status"

        Write-Host "FAIL  - $testName - $($testResult.error)" -ForegroundColor Red

    }$results = @{}

}

# ==============================================================================

Write-Host ""

Write-Host "------------------------------------------------------------" -ForegroundColor White# Core endpoints# Test 2: Reflection - CSV Tail

Write-Host "Total Tests: $totalTests" -ForegroundColor White

Write-Host "Passed: $passedTests" -ForegroundColor Green$results.status = Test-Endpoint -Name "Status Endpoint" -Url "$baseUrl/status"# ==============================================================================

Write-Host "Failed: $failedTests" -ForegroundColor Red

Write-Host "Optional failures: $optionalFailed" -ForegroundColor Yellow$results.csvTail = Test-Endpoint -Name "CSV Tail (Reflection System)" -Url "$baseUrl/logs/csv/tail?rows=5"

Write-Host "------------------------------------------------------------" -ForegroundColor White

Write-Host ""$results.reflectWindow = Test-Endpoint -Name "Reflection Window" -Url "$baseUrl/reflect/window?rows=10"$results.csvTail = Test-Endpoint -Name "CSV Tail (Reflection System)" -Url "$baseUrl/logs/csv/tail?rows=5"



# Recommendations

Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan

Write-Host ""$reflectionBody = @{# ==============================================================================



if ($failedTests -eq 0 -and $passedTests -gt 0) {    title = "Test Reflection"# Test 3: Reflection - Window

    Speak "All core tests passed"

    Write-Host "PASS  - Core functionality is working" -ForegroundColor Green    goal = "Test the reflection submission endpoint"# ==============================================================================

    Write-Host ""

}    summary = "Testing if reflection submission works"



if (-not $results.gemini.success) {    source_model = "test-script"$results.reflectWindow = Test-Endpoint -Name "Reflection Window" -Url "$baseUrl/reflect/window?rows=10"

    Write-Host "WARN - GeminiService.ps1 is not loaded" -ForegroundColor Yellow

    Write-Host "       Evidence card generation via Gemini will be unavailable" -ForegroundColor Gray    meta_tags = "test,diagnostic"

    Write-Host "       This component is optional" -ForegroundColor Gray

    Write-Host ""}# ==============================================================================

}

$results.reflectSubmit = Test-Endpoint -Name "Reflection Submit" -Url "$baseUrl/reflect/submit" -Method "POST" -Body $reflectionBody# Test 4: Reflection - Submit

if (-not $results.runner.success) {

    Write-Host "WARN - OllamaRunner is not loaded" -ForegroundColor Yellow# ==============================================================================

    Write-Host "       AI model routing (6 routes) will be unavailable" -ForegroundColor Gray

    Write-Host "       This component is optional" -ForegroundColor Gray# Static files

    Write-Host ""

}Write-Host ""$reflectionBody = @{



if ($results.status.success) {Write-Host "------------------------------------------------------------" -ForegroundColor Yellow    title = "Test Reflection"

    Write-Host "PASS  - Web interface available at http://localhost:9099/web" -ForegroundColor Green

    Write-Host ""Write-Host "Testing: Static File Serving" -ForegroundColor Yellow    goal = "Test the reflection submission endpoint"

}

Write-Host "URL: $baseUrl/web" -ForegroundColor Gray    summary = "Testing if reflection submission works"

if ($results.reflectSubmit.success) {

    Write-Host "PASS  - Reflection submitted successfully" -ForegroundColor GreenWrite-Host "------------------------------------------------------------" -ForegroundColor Yellow    source_model = "test-script"

    Write-Host "       Check logs with:  Get-Content HubStation\shared_bus\logs\hub_events.csv" -ForegroundColor Cyan

    Write-Host "       Check files with: Get-ChildItem HubStation\shared_bus\reflections\*" -ForegroundColor Cyan    meta_tags = "test,diagnostic"

    Write-Host ""

}try {}



# Browser test prompt    $webResponse = Invoke-WebRequest -Uri "$baseUrl/web" -TimeoutSec 5 -ErrorAction Stop

Write-Host "BROWSER TEST:" -ForegroundColor Cyan

Write-Host "Open your browser and visit http://localhost:9099/web" -ForegroundColor White    Write-Host "SUCCESS" -ForegroundColor Green$results.reflectSubmit = Test-Endpoint -Name "Reflection Submit" -Url "$baseUrl/reflect/submit" -Method "POST" -Body $reflectionBody

Write-Host "If index.html loads, static files are working." -ForegroundColor White

Write-Host ""    Write-Host "Status: $($webResponse.StatusCode)" -ForegroundColor White



$openBrowser = Read-Host "Open browser now? (y/n)"    Write-Host "Content Length: $($webResponse.Content.Length) bytes" -ForegroundColor White# ==============================================================================

if ($openBrowser -eq 'y') {

    Start-Process "http://localhost:9099/web"    $results.staticFiles = @{ success = $true }# Test 5: Static Files (index.html)

    Speak "Opening browser"

}} catch {# ==============================================================================



Write-Host ""    Write-Host "FAILED" -ForegroundColor Red

Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "  Test Complete" -ForegroundColor Cyan    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor RedWrite-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

Write-Host "============================================================" -ForegroundColor Cyan

    $results.staticFiles = @{ success = $false; error = $_.Exception.Message }Write-Host "Testing: Static File Serving" -ForegroundColor Yellow

Speak "Test complete"

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

    Write-Host "PASS  - Web interface available at http://localhost:9099/web" -ForegroundColor GreenWrite-Host ""

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

Write-Host "Open your browser and visit http://localhost:9099/web" -ForegroundColor White}

Write-Host "If index.html loads, static files are working." -ForegroundColor White

Write-Host ""if ($results.gemini.success -eq $false) {

    Write-Host "• GeminiService.ps1 is not loaded" -ForegroundColor Yellow

$openBrowser = Read-Host "Open browser now? (y/n)"    Write-Host "  → Evidence card generation via Gemini won't work" -ForegroundColor Gray

if ($openBrowser -eq 'y') {    Write-Host "  → This is optional" -ForegroundColor Gray

    Start-Process "http://localhost:9099/web"    Write-Host ""

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
    Write-Host "  http://localhost:9099/web" -ForegroundColor Cyan
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
Write-Host "  http://localhost:9099/web" -ForegroundColor Yellow
Write-Host ""
Write-Host "If you see your index.html page, static files are working!" -ForegroundColor White
Write-Host ""

$openBrowser = Read-Host "Open browser now? (y/n)"
if ($openBrowser -eq 'y') {
    Start-Process "http://localhost:9099/web"
    Speak "Opening browser"
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Complete" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

Speak "Test complete"
