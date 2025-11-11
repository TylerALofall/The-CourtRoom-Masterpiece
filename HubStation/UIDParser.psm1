# UIDParser.psm1 - Evidence Card UID parsing and file organization
# Handles Gemini multi-card responses with UID-based splitting and storage

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Parse-UID {
    <#
    .SYNOPSIS
    Parses a UID string into its components.

    .DESCRIPTION
    UID format: [Claim][Element][Defendant][Letter]
    Examples:
    - 111 → Claim 1, Element 1, Defendant 1
    - 245B → Claim 2, Element 4, Defendant 5, Evidence B
    - 1234A → Claim 1, Element 2, Sub-element 3, Defendant 4, Evidence A

    .PARAMETER UID
    The UID string (e.g., '111', '245B', '1234').

    .OUTPUTS
    Hashtable with keys: claim, element, defendant, sub_element, evidence_letter, is_valid
    #>
    param(
        [Parameter(Mandatory)]
        [string]$UID
    )

    # Match pattern: 3-4 digits optionally followed by a letter
    if ($UID -notmatch '^(\d{3,4})([A-Z]?)$') {
        return @{ is_valid = $false; raw = $UID }
    }

    $digits = $Matches[1]
    $letter = $Matches[2]

    $claim = [int]($digits[0].ToString())
    $element = [int]($digits[1].ToString())

    $defendant = 0
    $subElement = 0

    if ($digits.Length -eq 3) {
        $defendant = [int]($digits[2].ToString())
    } elseif ($digits.Length -eq 4) {
        $subElement = [int]($digits[2].ToString())
        $defendant = [int]($digits[3].ToString())
    }

    return @{
        is_valid = $true
        raw = $UID
        claim = $claim
        element = $element
        sub_element = $subElement
        defendant = $defendant
        evidence_letter = $letter
        is_evidence_variant = ($letter -ne '')
    }
}

function Split-GeminiResponse {
    <#
    .SYNOPSIS
    Splits a Gemini response containing multiple Evidence Cards.

    .DESCRIPTION
    Detects card boundaries by scanning for UID patterns: [XXX] or [XXXX][A-Z]?
    Returns an array of hashtables, each with: uid, raw_text, parsed_uid

    .PARAMETER ResponseText
    The full text response from Gemini.

    .OUTPUTS
    Array of hashtables: @{ uid, raw_text, parsed_uid }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ResponseText
    )

    # Pattern to detect UID at start of line or after blank line
    # Match [XXX] or [XXXX] optionally followed by letter
    $pattern = '(?m)^\s*\[(\d{3,4})([A-Z]?)\]'

    $matches = [regex]::Matches($ResponseText, $pattern)

    if ($matches.Count -eq 0) {
        # No UIDs found, treat entire response as one card with unknown UID
        return @(
            @{
                uid = 'UNKNOWN'
                raw_text = $ResponseText
                parsed_uid = @{ is_valid = $false; raw = 'UNKNOWN' }
            }
        )
    }

    $cards = @()
    for ($i = 0; $i -lt $matches.Count; $i++) {
        $m = $matches[$i]
        $uid = $m.Groups[1].Value + $m.Groups[2].Value
        $startIdx = $m.Index

        # Find end: either next UID or end of string
        $endIdx = if ($i -lt $matches.Count - 1) {
            $matches[$i + 1].Index
        } else {
            $ResponseText.Length
        }

        $cardText = $ResponseText.Substring($startIdx, $endIdx - $startIdx).Trim()

        $parsed = Parse-UID -UID $uid

        $cards += @{
            uid = $uid
            raw_text = $cardText
            parsed_uid = $parsed
        }
    }

    return $cards
}

function Save-EvidenceCard {
    <#
    .SYNOPSIS
    Saves an Evidence Card to the appropriate directory and updates the index.

    .DESCRIPTION
    Organizes cards into: evidence_cards/<claim>/<element>/<defendant>/<UID>.json
    Updates evidence_cards/index.json with metadata.

    .PARAMETER Card
    Hashtable from Split-GeminiResponse output.

    .PARAMETER BaseDir
    Root directory for evidence_cards (default: ./shared_bus/evidence_cards).

    .PARAMETER SourceModel
    Name of the model that produced this card (e.g., 'gemini').

    .OUTPUTS
    Hashtable: @{ ok, path, uid, error }
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Card,

        [string]$BaseDir = './shared_bus/evidence_cards',

        [string]$SourceModel = 'gemini'
    )

    try {
        $parsed = $Card.parsed_uid

        if (-not $parsed.is_valid) {
            # Save to root with UNKNOWN prefix
            $fileName = "UNKNOWN_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            $fullPath = Join-Path $BaseDir $fileName
        } else {
            # Build directory path: <claim>/<element>/<defendant>/
            $claimDir = "claim_$($parsed.claim)"
            $elemDir = "element_$($parsed.element)"
            $defDir = "defendant_$($parsed.defendant)"

            $cardDir = Join-Path $BaseDir (Join-Path $claimDir (Join-Path $elemDir $defDir))

            if (-not (Test-Path $cardDir)) {
                New-Item -ItemType Directory -Path $cardDir -Force | Out-Null
            }

            $fileName = "$($Card.uid).json"
            $fullPath = Join-Path $cardDir $fileName
        }

        # Build JSON object
        $cardObj = @{
            uid = $Card.uid
            claim = $parsed.claim
            element = $parsed.element
            defendant = $parsed.defendant
            sub_element = $parsed.sub_element
            evidence_letter = $parsed.evidence_letter
            source_model = $SourceModel
            timestamp = (Get-Date).ToString('o')
            raw_text = $Card.raw_text
        }

        $json = $cardObj | ConvertTo-Json -Depth 4 -Compress:$false
        Set-Content -Path $fullPath -Value $json -Encoding UTF8

        # Update index
        Update-EvidenceIndex -UID $Card.uid -FilePath $fullPath -BaseDir $BaseDir -SourceModel $SourceModel

        Write-Host "[UID] Saved card: $($Card.uid) → $fullPath"

        return @{ ok = $true; path = $fullPath; uid = $Card.uid }

    } catch {
        Write-Warning "[UID] Failed to save card $($Card.uid): $($_.Exception.Message)"
        return @{ ok = $false; error = $_.Exception.Message; uid = $Card.uid }
    }
}

function Update-EvidenceIndex {
    <#
    .SYNOPSIS
    Updates the master index.json with a new or updated card reference.

    .PARAMETER UID
    The card UID.

    .PARAMETER FilePath
    Full path to the saved JSON file.

    .PARAMETER BaseDir
    Root directory for evidence_cards.

    .PARAMETER SourceModel
    Name of the source model.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$UID,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [string]$BaseDir = './shared_bus/evidence_cards',

        [string]$SourceModel = 'gemini'
    )

    $indexPath = Join-Path $BaseDir 'index.json'

    $index = @{}
    if (Test-Path $indexPath) {
        try {
            $indexContent = Get-Content -Path $indexPath -Raw | ConvertFrom-Json
            # Convert PSCustomObject to hashtable
            foreach ($prop in $indexContent.PSObject.Properties) {
                $index[$prop.Name] = $prop.Value
            }
        } catch {
            Write-Warning "[UID] Failed to read index, starting fresh: $($_.Exception.Message)"
        }
    }

    $index[$UID] = @{
        file_path = $FilePath
        source_model = $SourceModel
        last_updated = (Get-Date).ToString('o')
    }

    $indexJson = $index | ConvertTo-Json -Depth 4 -Compress:$false
    Set-Content -Path $indexPath -Value $indexJson -Encoding UTF8

    Write-Host "[UID] Updated index: $UID"
}

function Process-GeminiResponse {
    <#
    .SYNOPSIS
    Full pipeline: split response, parse UIDs, save cards, update index.

    .PARAMETER ResponseText
    The full Gemini response.

    .PARAMETER BaseDir
    Root directory for evidence_cards.

    .PARAMETER SourceModel
    Name of the model (default: 'gemini').

    .OUTPUTS
    Array of save results: @{ ok, path, uid, error }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ResponseText,

        [string]$BaseDir = './shared_bus/evidence_cards',

        [string]$SourceModel = 'gemini'
    )

    $cards = Split-GeminiResponse -ResponseText $ResponseText

    $results = @()
    foreach ($card in $cards) {
        $saveResult = Save-EvidenceCard -Card $card -BaseDir $BaseDir -SourceModel $SourceModel
        $results += $saveResult
    }

    return $results
}

Export-ModuleMember -Function @(
    'Parse-UID',
    'Split-GeminiResponse',
    'Save-EvidenceCard',
    'Update-EvidenceIndex',
    'Process-GeminiResponse'
)
