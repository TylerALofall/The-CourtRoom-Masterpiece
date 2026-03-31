<#
.SYNOPSIS
    get_xml_object — Returns the XML master record for a document.

.DESCRIPTION
    XML is the canonical format. This tool locates or generates an XML
    representation for the requested document. The lookup order is:

    1. Check for a pre-existing <filename>.xml sidecar in ECF_FILES.
    2. Check for a matching entry in the Case_<n>_0-Master_ECF_List.json
       and return it as an XML fragment.
    3. Return a minimal stub XML record with the known metadata so callers
       always get a consistent XML shape.

    CSV/text views are secondary; XML is what this tool returns.

.PARAMETER InputJson
    JSON string. Accepted fields:
        document_no  (string, required)
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

$docNo  = [string]$in.document_no
$caseNo = if ($in.PSObject.Properties['case_no']) { [string]$in.case_no } else { '' }

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
# Locate the source document file
# ---------------------------------------------------------------------------
$filePattern  = if ($caseNo) { "Case_$($caseNo)_$($docNo)*" } else { "Case_*_$($docNo)*" }
$matchedFiles = @(Get-ChildItem -Path $EcfDir -Filter $filePattern -File |
                  Where-Object { $_.Extension.ToLower() -ne '.xml' })

$docFile = $null
if ($matchedFiles.Count -gt 0) {
    $docFile = $matchedFiles | Sort-Object Name | Select-Object -First 1
    if (-not $caseNo -and $docFile.Name -match '^Case_(\d+)_') {
        $caseNo = $Matches[1]
    }
}

# ---------------------------------------------------------------------------
# Check for an existing XML sidecar file
# ---------------------------------------------------------------------------
$xmlPath    = ''
$xmlContent = ''

if ($docFile) {
    $sidecarXml = [IO.Path]::ChangeExtension($docFile.FullName, '.xml')
    if (Test-Path $sidecarXml) {
        $xmlPath    = $sidecarXml
        try {
            $xmlContent = Get-Content -Path $sidecarXml -Raw -Encoding UTF8
        } catch {
            $xmlContent = "<!-- Could not read XML sidecar: $($_.Exception.Message) -->"
        }
    }
}

# ---------------------------------------------------------------------------
# Check Master ECF List JSON for metadata
# ---------------------------------------------------------------------------
$masterMeta = $null
if ($caseNo) {
    $masterJsonPattern = "Case_$($caseNo)_0-Master_ECF_List.json"
    $masterJson = Get-ChildItem -Path $EcfDir -Filter $masterJsonPattern -File |
                  Select-Object -First 1
    if ($masterJson) {
        try {
            $masterData = Get-Content -Path $masterJson.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            # Try to find the entry matching document_no
            $entries = if ($masterData.PSObject.Properties['entries']) { $masterData.entries }
                       elseif ($masterData -is [array]) { $masterData }
                       else { @() }
            $masterMeta = @($entries) | Where-Object {
                $_.PSObject.Properties['document_no'] -and $_.document_no -eq $docNo
            } | Select-Object -First 1
        } catch { }
    }
}

# ---------------------------------------------------------------------------
# Build XML if no sidecar exists
# ---------------------------------------------------------------------------
if (-not $xmlContent) {
    $fileName    = if ($docFile) { $docFile.Name } else { "unknown" }
    $caseName    = ''
    if ($fileName -match '^Case_\d+_[\d-]+[_-](.+)\.\w+$') {
        $caseName = ($Matches[1] -replace '_', ' ').Trim()
    }

    $authorship  = ''
    $totalPages  = '0'
    $filingDate  = ''

    if ($masterMeta) {
        if ($masterMeta.PSObject.Properties['authorship'])  { $authorship  = [string]$masterMeta.authorship }
        if ($masterMeta.PSObject.Properties['total_pages']) { $totalPages  = [string]$masterMeta.total_pages }
        if ($masterMeta.PSObject.Properties['filing_date']) { $filingDate  = [string]$masterMeta.filing_date }
        if ($masterMeta.PSObject.Properties['case_name'])   { $caseName    = [string]$masterMeta.case_name }
    }

    $createdAt = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

    # Escape XML special characters in text fields; handles null/empty safely
    $xmlEscape = { param($s) if (-not $s) { return '' }; [string]$s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' }

    $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<document>
  <document_no>$docNo</document_no>
  <case_no>$caseNo</case_no>
  <case_name>$(& $xmlEscape $caseName)</case_name>
  <filing_source>ecf</filing_source>
  <authorship>$(& $xmlEscape $authorship)</authorship>
  <total_pages>$totalPages</total_pages>
  <filing_date>$filingDate</filing_date>
  <file_name>$(& $xmlEscape $fileName)</file_name>
  <created_at>$createdAt</created_at>
  <note>Generated stub — replace with authoritative XML sidecar when available.</note>
</document>
"@

    # Optionally write the stub XML sidecar for future reuse
    if ($docFile) {
        $sidecarXml = [IO.Path]::ChangeExtension($docFile.FullName, '.xml')
        if (-not (Test-Path $sidecarXml)) {
            try {
                $xmlContent | Out-File -FilePath $sidecarXml -Encoding UTF8
                $xmlPath = $sidecarXml
            } catch { }
        }
    }
}

Write-Result @{
    ok          = $true
    document_no = $docNo
    case_no     = $caseNo
    xml_path    = $xmlPath
    xml_content = $xmlContent
}
