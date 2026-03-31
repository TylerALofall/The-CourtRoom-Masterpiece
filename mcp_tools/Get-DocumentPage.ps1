<#
.SYNOPSIS
    get_document_page — Returns content for a specific page of a document.

.DESCRIPTION
    Locates the document file in ECF_FILES by document_no (and optional
    case_no), then returns page metadata and whatever text content is
    available. For PDF files, text extraction is attempted via .NET's
    built-in capabilities; if extraction is not available, a stub response
    is returned indicating the file path and page range so the caller can
    open the file directly.

    This tool does NOT require any Python or third-party executables.
    Full PDF text extraction requires iTextSharp or a similar library;
    that integration is noted as a future extension point. The current
    implementation returns the file location and page metadata so document
    retrieval workflows can proceed immediately.

.PARAMETER InputJson
    JSON string. Accepted fields:
        document_no  (string, required)
        page_no      (int, required)
        case_no      (string, optional)
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

if (-not $in.PSObject.Properties['document_no'] -or [string]::IsNullOrWhiteSpace($in.document_no)) {
    Write-Result @{ ok = $false; error = "Required field 'document_no' is missing or empty." }
    exit 1
}
if (-not $in.PSObject.Properties['page_no']) {
    Write-Result @{ ok = $false; error = "Required field 'page_no' is missing." }
    exit 1
}

$docNo  = [string]$in.document_no
$pageNo = [int]$in.page_no
$caseNo = if ($in.PSObject.Properties['case_no']) { [string]$in.case_no } else { '' }

if ($pageNo -lt 1) { $pageNo = 1 }

# ---------------------------------------------------------------------------
# Locate file in ECF_FILES
# ---------------------------------------------------------------------------
$RepoRoot = Split-Path $PSScriptRoot -Parent
$EcfDir   = Join-Path $RepoRoot 'ECF_FILES'

if (-not (Test-Path $EcfDir)) {
    Write-Result @{ ok = $false; error = "ECF_FILES directory not found at: $EcfDir" }
    exit 1
}

$filePattern  = if ($caseNo) { "Case_$($caseNo)_$($docNo)*" } else { "Case_*_$($docNo)*" }
$matchedFiles = @(Get-ChildItem -Path $EcfDir -Filter $filePattern -File)

if ($matchedFiles.Count -eq 0) {
    Write-Result @{
        ok          = $false
        document_no = $docNo
        page_no     = $pageNo
        error       = "No file found for document_no '$docNo'$(if ($caseNo) { " in case '$caseNo'" })."
    }
    exit 1
}

$docFile = $matchedFiles | Sort-Object Name | Select-Object -First 1

# Derive case_no from filename if not provided
if (-not $caseNo -and $docFile.Name -match '^Case_(\d+)_') {
    $caseNo = $Matches[1]
}

# Derive a case_name / description fragment
$caseName = ''
if ($docFile.Name -match '^Case_\d+_[\d-]+[_-](.+)\.\w+$') {
    $caseName = ($Matches[1] -replace '_', ' ').Trim()
}

# ---------------------------------------------------------------------------
# Attempt text extraction (stub — extend with PDF library if available)
# ---------------------------------------------------------------------------
$contentText = ''
$totalPages  = 0
$authorship  = ''

$ext = $docFile.Extension.ToLower()

if ($ext -eq '.pdf') {
    # PDF text extraction requires an external library (e.g. iTextSharp).
    # Stub: return file path and page reference so the caller can open it.
    $contentText = "[PDF] Page $pageNo of '$($docFile.Name)' — open file for full text. Path: $($docFile.FullName)"
    $totalPages  = 0  # Unknown without PDF library; extend this later.
} elseif ($ext -in @('.txt', '.xml', '.json', '.md')) {
    # Plain text / XML: read and return the relevant portion
    try {
        $lines      = Get-Content -Path $docFile.FullName -Encoding UTF8 -ErrorAction Stop
        $totalPages = [Math]::Max(1, [Math]::Ceiling($lines.Count / 50))
        $startLine  = ($pageNo - 1) * 50
        $pageLines  = @($lines | Select-Object -Skip $startLine -First 50)
        $contentText = $pageLines -join "`n"
        if (-not $contentText) { $contentText = "(Page $pageNo is beyond the end of this document.)" }
    } catch {
        $contentText = "Could not read file: $($_.Exception.Message)"
    }
} else {
    $contentText = "[Binary/Unknown format] File: $($docFile.FullName)"
}

Write-Result @{
    ok            = $true
    document_no   = $docNo
    case_no       = $caseNo
    case_name     = $caseName
    page_no       = $pageNo
    total_pages   = $totalPages
    filing_source = 'ecf'
    authorship    = $authorship
    file_name     = $docFile.Name
    content_text  = $contentText
}
