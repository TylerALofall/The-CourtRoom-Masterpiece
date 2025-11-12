<#
GeminiService.ps1
Implements Handle-GeminiAnalyzeRequest consumed by HubStation.ps1 /api/gemini/analyze route.
Rules:
- GEMINI names the UID; we do not. We only left-pad the numeric portion for filenames.
- tdate comes with UID and is used in filenames: UID-####-{tdate}.json
- The submission timestamp is identical across: stored request file, raw response, and E-card schema files.
- Returns ok + summary + file paths; on error returns ok=false with error.
#>

function New-SubmitTimestamp {
    return (Get-Date -Format o)
}

function Get-GeminiDropFolder {
    param(
        [string]$Root
    )
    if (-not $Root) { $Root = Join-Path $PSScriptRoot 'shared_bus' }
    $dir = Join-Path $Root 'gemini'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    return $dir
}

function Write-JsonFileSameTimestamp {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)]$Object,
        [Parameter(Mandatory=$true)][string]$Timestamp
    )
    $json = $Object | ConvertTo-Json -Depth 10
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
    try {
        $dt = [DateTimeOffset]::Parse($Timestamp)
        [System.IO.File]::SetCreationTimeUtc($Path, $dt.UtcDateTime)
        [System.IO.File]::SetLastWriteTimeUtc($Path, $dt.UtcDateTime)
    } catch {
        # Fallback: leave FS timestamps if parsing fails
    }
    return $Path
}

function Format-UidForFilename {
    param([string]$uid)
    if (-not $uid) { return $null }
    # Expect something like ABC-7 or ABC-123; pad numeric segment to 4 digits for ordering.
    if ($uid -match '^(.*?)-(\d+)$') {
        $prefix = $matches[1]
        $num = [int]$matches[2]
        $numPad = ('{0:D4}' -f $num)
        return "$prefix-$numPad"
    }
    return $uid
}

function Invoke-Gemini-API {
    param(
        [Parameter(Mandatory=$true)][string]$ApiKey,
        [Parameter(Mandatory=$true)]$Payload
    )
    # Placeholder external call. Replace with real Google Gemini endpoint when ready.
    # For now, simulate a structured response with UID/tdate and up to 3 cards.
    $nowDate = (Get-Date -Format 'yyyyMMdd')
    $sim = @{
        ok = $true
        uid = "GEM-$([System.Random]::new().Next(1,9999))"
        tdate = $nowDate
        messages = @(
            @{ role='assistant'; text='Card 1 content'; schemaType='E'; index=1 },
            @{ role='assistant'; text='Card 2 content'; schemaType='E'; index=2 }
        )
        summary = 'Simulated Gemini output'
        source = 'simulated'
    }
    return $sim
}

function Handle-GeminiAnalyzeRequest {
    param(
        [Parameter(Mandatory=$true)]$RequestBody
    )
    try {
        $apiKey = $env:GEMINI_API_KEY
        if (-not $apiKey) {
            return @{ ok=$false; error='GEMINI_API_KEY not set'; hint='Set GEMINI_API_KEY and retry' }
        }

        $tsSubmit = New-SubmitTimestamp
        $drop = Get-GeminiDropFolder

        # Persist the exact request materials
        $reqFile = Join-Path $drop ("request-" + ([System.Guid]::NewGuid().ToString('N')) + ".json")
        Write-JsonFileSameTimestamp -Path $reqFile -Object $RequestBody -Timestamp $tsSubmit | Out-Null

        # Call Gemini API (simulated for now)
        $gem = Invoke-Gemini-API -ApiKey $apiKey -Payload $RequestBody
        if (-not ($gem.ok)) { return @{ ok=$false; error=($gem.error ?? 'Gemini call failed') } }

        $uid = $gem.uid
        $tdate = $gem.tdate
        if (-not $uid) { return @{ ok=$false; error='Gemini response missing UID' } }
        if (-not $tdate) { $tdate = (Get-Date -Format 'yyyyMMdd') }

        $uidFileSafe = Format-UidForFilename -uid $uid

        # Persist raw response
        $rawFile = Join-Path $drop ("response-" + $uidFileSafe + "-$tdate.json")
        Write-JsonFileSameTimestamp -Path $rawFile -Object $gem -Timestamp $tsSubmit | Out-Null

        # Split into E1..E3 schemas
        $schemas = @()
        $idx = 0
        foreach ($m in ($gem.messages | Where-Object { $_.schemaType -eq 'E' })) {
            $idx++
            if ($idx -gt 3) { break }
            $e = @{
                uid = $uid
                tdate = $tdate
                index = $idx
                content = $m.text
                kind = 'VI-CARD'
                source = 'gemini'
                ts_submit = $tsSubmit
            }
            $eFile = Join-Path $drop ("$uidFileSafe-$tdate-E$idx.json")
            Write-JsonFileSameTimestamp -Path $eFile -Object $e -Timestamp $tsSubmit | Out-Null
            $schemas += $eFile
        }

        return @{
            ok = $true
            uid = $uid
            tdate = $tdate
            ts_submit = $tsSubmit
            request_file = $reqFile
            response_file = $rawFile
            schema_files = $schemas
            summary = $gem.summary
        }
    } catch {
        return @{ ok=$false; error=$_.Exception.Message }
    }
}

Export-ModuleMember -Function Handle-GeminiAnalyzeRequest
