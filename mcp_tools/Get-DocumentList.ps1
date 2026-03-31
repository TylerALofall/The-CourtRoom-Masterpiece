<#
.SYNOPSIS
    list_documents — Lists documents from the local ECF file library.

.DESCRIPTION
    Scans the ECF_FILES directory (or the path in config) and returns document
    metadata. Supports optional filtering by case_no, case_name, and
    filing_source. Pagination is supported via page_no / page_size.

    Document filenames are expected to follow the pattern:
        Case_<case_no>_<document_no>[_<description>].<ext>

    Fields returned use snake_case throughout.
    document_no is derived from the filename, not a generated id.

.PARAMETER InputJson
    JSON string. Accepted fields:
        case_no      (string, optional)
        case_name    (string, optional)
        filing_source (string, optional)
        page_no      (int, optional, 1-based, default 1)
        page_size    (int, optional, default 50)
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

$filterCaseNo      = if ($in.PSObject.Properties['case_no'])      { [string]$in.case_no }      else { '' }
$filterCaseName    = if ($in.PSObject.Properties['case_name'])    { [string]$in.case_name }    else { '' }
$filterFiling      = if ($in.PSObject.Properties['filing_source']){ [string]$in.filing_source }else { '' }
$pageNo            = if ($in.PSObject.Properties['page_no'])      { [int]$in.page_no }         else { 1 }
$pageSize          = if ($in.PSObject.Properties['page_size'])    { [int]$in.page_size }       else { 50 }

if ($pageNo -lt 1)   { $pageNo   = 1 }
if ($pageSize -lt 1) { $pageSize = 50 }

# ---------------------------------------------------------------------------
# Locate ECF_FILES directory
# ---------------------------------------------------------------------------
$RepoRoot    = Split-Path $PSScriptRoot -Parent
$EcfDir      = Join-Path $RepoRoot 'ECF_FILES'

if (-not (Test-Path $EcfDir)) {
    Write-Result @{ ok = $false; error = "ECF_FILES directory not found at: $EcfDir" }
    exit 1
}

# ---------------------------------------------------------------------------
# Scan and parse filenames
# ---------------------------------------------------------------------------
# Pattern: Case_<case_no>_<document_no>[_<rest>].<ext>
$pattern = '^Case_(\d+)_(\d+(?:-\d+)?)(?:[_-](.+?))?\.(\w+)$'

$allDocs = @()

Get-ChildItem -Path $EcfDir -File | ForEach-Object {
    $file = $_
    if ($file.Name -match $pattern) {
        $docCaseNo  = $Matches[1]
        $docNo      = $Matches[2]
        $descRaw    = if ($Matches[3]) { $Matches[3] } else { '' }
        $ext        = $Matches[4]

        # Derive a human-readable name from the description fragment
        $caseName = ($descRaw -replace '_', ' ').Trim()
        if (-not $caseName) { $caseName = "Document $docNo" }

        # filing_source: for ECF files this is 'ecf'. Could be extended later.
        $filingSource = 'ecf'

        $allDocs += @{
            document_no   = $docNo
            case_no       = $docCaseNo
            case_name     = $caseName
            authorship    = ''
            total_pages   = 0
            filing_source = $filingSource
            file_name     = $file.Name
            file_ext      = $ext.ToLower()
        }
    }
}

# ---------------------------------------------------------------------------
# Apply filters
# ---------------------------------------------------------------------------
$filtered = $allDocs | Where-Object {
    ($filterCaseNo   -eq '' -or $_.case_no       -like "*$filterCaseNo*") -and
    ($filterCaseName -eq '' -or $_.case_name      -like "*$filterCaseName*") -and
    ($filterFiling   -eq '' -or $_.filing_source  -like "*$filterFiling*")
}

$filteredArr = @($filtered)
$total       = $filteredArr.Count

# ---------------------------------------------------------------------------
# Paginate
# ---------------------------------------------------------------------------
$skip     = ($pageNo - 1) * $pageSize
$pageDocs = @($filteredArr | Select-Object -Skip $skip -First $pageSize)

Write-Result @{
    ok        = $true
    total     = $total
    page_no   = $pageNo
    page_size = $pageSize
    documents = $pageDocs
}
