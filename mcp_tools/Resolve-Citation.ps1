<#
.SYNOPSIS
    resolve_citation — Resolves a citation string to a document and page.

.DESCRIPTION
    Parses a citation in the canonical format and maps it back to a file in
    ECF_FILES. Supported citation formats:

        ecf[<document_no>]page[<page_no>]
        [<filing_source>][<document_no>]page[<page_no>]

    The document_no in the citation is matched against filenames in ECF_FILES
    using the Case_<case_no>_<document_no> prefix pattern.

    filing_path is NOT returned because this tool works with already-filed
    ECF documents, not supporting attachments.

.PARAMETER InputJson
    JSON string. Accepted fields:
        citation  (string, required)
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

if (-not $in.PSObject.Properties['citation'] -or [string]::IsNullOrWhiteSpace($in.citation)) {
    Write-Result @{ ok = $false; error = "Required field 'citation' is missing or empty." }
    exit 1
}

$citation = [string]$in.citation

# ---------------------------------------------------------------------------
# Parse citation string
# ---------------------------------------------------------------------------
# Primary format: ecf[23]page[5]  or  [ecf][23]page[5]
# Normalized format: filing_source document_no page_no

$filingSource = ''
$docNo        = ''
$pageNo       = 0

# Try: <source>[<docno>]page[<pageno>]
$m1 = [regex]::Match($citation, '^(?<src>[a-zA-Z_]+)\[(?<doc>[^\]]+)\]page\[(?<pg>\d+)\]$')
if ($m1.Success) {
    $filingSource = $m1.Groups['src'].Value.ToLower()
    $docNo        = $m1.Groups['doc'].Value
    $pageNo       = [int]$m1.Groups['pg'].Value
} else {
    # Try: [<source>][<docno>]page[<pageno>]
    $m2 = [regex]::Match($citation, '^\[(?<src>[^\]]+)\]\[(?<doc>[^\]]+)\]page\[(?<pg>\d+)\]$')
    if ($m2.Success) {
        $filingSource = $m2.Groups['src'].Value.ToLower()
        $docNo        = $m2.Groups['doc'].Value
        $pageNo       = [int]$m2.Groups['pg'].Value
    } else {
        Write-Result @{
            ok       = $false
            citation = $citation
            error    = "Unrecognized citation format. Expected: ecf[document_no]page[page_no]"
        }
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Locate matching file in ECF_FILES
# ---------------------------------------------------------------------------
$RepoRoot = Split-Path $PSScriptRoot -Parent
$EcfDir   = Join-Path $RepoRoot 'ECF_FILES'

if (-not (Test-Path $EcfDir)) {
    Write-Result @{ ok = $false; citation = $citation; error = "ECF_FILES directory not found at: $EcfDir" }
    exit 1
}

# Match any file whose name contains _<docno>_ or _<docno>.
$filePattern  = "Case_*_$($docNo)*"
$matchedFiles = @(Get-ChildItem -Path $EcfDir -Filter $filePattern -File)

if ($matchedFiles.Count -eq 0) {
    Write-Result @{
        ok            = $false
        citation      = $citation
        document_no   = $docNo
        page_no       = $pageNo
        filing_source = $filingSource
        error         = "No file found for document_no '$docNo' in ECF_FILES."
    }
    exit 1
}

# Use the first match (most specific match preferred)
$best = $matchedFiles | Sort-Object Name | Select-Object -First 1

# Extract case_no from filename
$caseNo = ''
if ($best.Name -match '^Case_(\d+)_') {
    $caseNo = $Matches[1]
}

Write-Result @{
    ok            = $true
    citation      = $citation
    document_no   = $docNo
    page_no       = $pageNo
    filing_source = $filingSource
    case_no       = $caseNo
    file_name     = $best.Name
}
