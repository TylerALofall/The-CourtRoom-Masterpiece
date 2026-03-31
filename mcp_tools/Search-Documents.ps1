<#
.SYNOPSIS
    search_documents — Full-text keyword search across document filenames and metadata.

.DESCRIPTION
    Searches ECF_FILES filenames (and XML metadata when present) for documents
    matching the query. Returns ranked results with a relevance score and a
    snippet showing which part of the filename/metadata matched.

    Filtering by case_no and filing_source is supported.

.PARAMETER InputJson
    JSON string. Accepted fields:
        query         (string, required)
        case_no       (string, optional)
        filing_source (string, optional)
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

if (-not $in.PSObject.Properties['query'] -or [string]::IsNullOrWhiteSpace($in.query)) {
    Write-Result @{ ok = $false; error = "Required field 'query' is missing or empty." }
    exit 1
}

$query         = [string]$in.query
$filterCaseNo  = if ($in.PSObject.Properties['case_no'])       { [string]$in.case_no }       else { '' }
$filterFiling  = if ($in.PSObject.Properties['filing_source']) { [string]$in.filing_source } else { '' }

# ---------------------------------------------------------------------------
# Locate ECF_FILES directory
# ---------------------------------------------------------------------------
$RepoRoot = Split-Path $PSScriptRoot -Parent
$EcfDir   = Join-Path $RepoRoot 'ECF_FILES'

if (-not (Test-Path $EcfDir)) {
    Write-Result @{ ok = $false; error = "ECF_FILES directory not found at: $EcfDir" }
    exit 1
}

# ---------------------------------------------------------------------------
# Build query terms (split on whitespace for multi-word matching)
# ---------------------------------------------------------------------------
$terms = @($query -split '\s+' | Where-Object { $_ -ne '' })

# ---------------------------------------------------------------------------
# Scan files and score
# ---------------------------------------------------------------------------
$pattern = '^Case_(\d+)_(\d+(?:-\d+)?)(?:[_-](.+?))?\.(\w+)$'

$results = @()

Get-ChildItem -Path $EcfDir -File | ForEach-Object {
    $file = $_
    if ($file.Name -match $pattern) {
        $docCaseNo = $Matches[1]
        $docNo     = $Matches[2]
        $descRaw   = if ($Matches[3]) { $Matches[3] } else { '' }

        # Apply case_no / filing_source filter first
        $fileFilingSource = 'ecf'
        if ($filterCaseNo  -ne '' -and $docCaseNo       -notlike "*$filterCaseNo*")   { return }
        if ($filterFiling  -ne '' -and $fileFilingSource -notlike "*$filterFiling*")   { return }

        $searchText = ($file.Name + ' ' + ($descRaw -replace '_', ' ')).ToLower()

        # Score = count of matched terms (case-insensitive)
        $score   = 0
        $matched = @()
        foreach ($term in $terms) {
            if ($searchText -like "*$($term.ToLower())*") {
                $score++
                $matched += $term
            }
        }

        if ($score -gt 0) {
            $caseName = ($descRaw -replace '_', ' ').Trim()
            if (-not $caseName) { $caseName = "Document $docNo" }

            $results += @{
                document_no   = $docNo
                case_no       = $docCaseNo
                case_name     = $caseName
                file_name     = $file.Name
                filing_source = $fileFilingSource
                score         = $score
                snippet       = "Matched: $($matched -join ', ') in '$($file.Name)'"
            }
        }
    }
}

# Sort by descending score
$sorted = @($results | Sort-Object { -[int]$_.score })

Write-Result @{
    ok      = $true
    query   = $query
    count   = $sorted.Count
    results = $sorted
}
