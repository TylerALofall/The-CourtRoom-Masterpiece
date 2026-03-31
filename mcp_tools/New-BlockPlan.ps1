<#
.SYNOPSIS
    create_block_plan — Creates a structured block plan (outline) for a set of documents.

.DESCRIPTION
    Accepts a list of document_nos for a case and generates an XML block plan
    artifact that outlines how the documents relate to the block's argument or
    motion. The block plan XML is written to a 'block_plans/' subdirectory
    relative to the repository root.

    XML is the master format. The block plan is an XML file; a CSV index row
    is also appended for searchability.

    Heartbeat / loop logic is NOT implemented here. This tool is a single
    synchronous call that creates the plan and returns the artifact path.

.PARAMETER InputJson
    JSON string. Accepted fields:
        case_no       (string, required)
        case_name     (string, optional)
        block_title   (string, required)
        document_nos  (array of strings, required)
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$InputJson = '{}'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Result {
    param([hashtable]$Result)
    $Result | ConvertTo-Json -Depth 10 -Compress | Write-Output
}

# ---------------------------------------------------------------------------
# Parse input
# ---------------------------------------------------------------------------
try {
    $in = $InputJson | ConvertFrom-Json
} catch {
    Write-Result @{ ok = $false; error = "Invalid JSON input: $($_.Exception.Message)" }
    exit 1
}

if (-not $in.PSObject.Properties['case_no'] -or [string]::IsNullOrWhiteSpace($in.case_no)) {
    Write-Result @{ ok = $false; error = "Required field 'case_no' is missing or empty." }
    exit 1
}
if (-not $in.PSObject.Properties['block_title'] -or [string]::IsNullOrWhiteSpace($in.block_title)) {
    Write-Result @{ ok = $false; error = "Required field 'block_title' is missing or empty." }
    exit 1
}
if (-not $in.PSObject.Properties['document_nos'] -or $in.document_nos.Count -eq 0) {
    Write-Result @{ ok = $false; error = "Required field 'document_nos' is missing or empty." }
    exit 1
}

$caseNo       = [string]$in.case_no
$caseName     = if ($in.PSObject.Properties['case_name']) { [string]$in.case_name } else { '' }
$blockTitle   = [string]$in.block_title
$documentNos  = @($in.document_nos | ForEach-Object { [string]$_ })

# ---------------------------------------------------------------------------
# Setup output directory
# ---------------------------------------------------------------------------
$RepoRoot      = Split-Path $PSScriptRoot -Parent
$BlockPlansDir = Join-Path $RepoRoot 'block_plans'

if (-not (Test-Path $BlockPlansDir)) {
    New-Item -ItemType Directory -Path $BlockPlansDir -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Resolve document metadata from ECF_FILES
# ---------------------------------------------------------------------------
$EcfDir = Join-Path $RepoRoot 'ECF_FILES'

$docEntries = @()
foreach ($docNo in $documentNos) {
    $filePattern  = if ($caseNo) { "Case_$($caseNo)_$($docNo)*" } else { "Case_*_$($docNo)*" }
    $matchedFiles = @()
    if (Test-Path $EcfDir) {
        $matchedFiles = @(Get-ChildItem -Path $EcfDir -Filter $filePattern -File |
                          Where-Object { $_.Extension.ToLower() -ne '.xml' })
    }

    $fileName  = if ($matchedFiles.Count -gt 0) { ($matchedFiles | Sort-Object Name | Select-Object -First 1).Name } else { "unknown" }
    $descLabel = ''
    if ($fileName -match '^Case_\d+_[\d-]+[_-](.+)\.\w+$') {
        $descLabel = ($Matches[1] -replace '_', ' ').Trim()
    }

    $docEntries += @{
        document_no = $docNo
        file_name   = $fileName
        description = $descLabel
    }
}

# ---------------------------------------------------------------------------
# Build XML
# ---------------------------------------------------------------------------
$epochMs   = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$createdAt = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

$xmlEscape = { param($s) if ($null -eq $s) { return '' }; [string]$s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' }

$docXmlLines = @($docEntries | ForEach-Object {
    "    <document_ref>`n      <document_no>$($_.document_no)</document_no>`n      <file_name>$(& $xmlEscape $_.file_name)</file_name>`n      <description>$(& $xmlEscape $_.description)</description>`n    </document_ref>"
})

$xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<block_plan>
  <block_title>$(& $xmlEscape $blockTitle)</block_title>
  <case_no>$caseNo</case_no>
  <case_name>$(& $xmlEscape $caseName)</case_name>
  <created_at>$createdAt</created_at>
  <epoch_ms>$epochMs</epoch_ms>
  <document_count>$($docEntries.Count)</document_count>
  <documents>
$($docXmlLines -join "`n")
  </documents>
  <notes></notes>
</block_plan>
"@

# ---------------------------------------------------------------------------
# Write XML artifact
# ---------------------------------------------------------------------------
$safeTitle    = $blockTitle -replace '[^a-zA-Z0-9_-]', '_'
$xmlFileName  = "block_plan_case$($caseNo)_$($epochMs)_$($safeTitle).xml"
$xmlFilePath  = Join-Path $BlockPlansDir $xmlFileName

try {
    $xmlContent | Out-File -FilePath $xmlFilePath -Encoding UTF8
} catch {
    Write-Result @{ ok = $false; error = "Failed to write block plan XML: $($_.Exception.Message)" }
    exit 1
}

# ---------------------------------------------------------------------------
# Append a CSV index row for searchability
# ---------------------------------------------------------------------------
$csvPath = Join-Path $BlockPlansDir 'block_plans_index.csv'
if (-not (Test-Path $csvPath)) {
    'epoch_ms,case_no,case_name,block_title,document_count,xml_path' | Out-File -FilePath $csvPath -Encoding UTF8
}

$csvRow = "$epochMs,$caseNo,`"$(($caseName -replace '"','""'))`",`"$(($blockTitle -replace '"','""'))`",$($docEntries.Count),`"$xmlFileName`""
Add-Content -Path $csvPath -Value $csvRow -Encoding UTF8

Write-Result @{
    ok               = $true
    block_title      = $blockTitle
    case_no          = $caseNo
    case_name        = $caseName
    document_count   = $docEntries.Count
    block_plan_path  = $xmlFilePath
    created_at_epoch = $epochMs
}
