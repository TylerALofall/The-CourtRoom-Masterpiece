param(
    [string]$PdfPath,
    [switch]$HiddenText,
    [switch]$Attachments,
    [switch]$Invoice,
    [string]$Vendor,
    [string]$InvoiceNumber,
    [string]$Amount,
    [string]$Date,
    [string]$EmlPath,
    [switch]$Eml,
    [string]$OutDir = "$PSScriptRoot\outputs"
)

Import-Module -Force "$PSScriptRoot\ForensicLab.psm1"

$runDir = Join-Path $OutDir (Get-Date -Format 'yyyyMMdd-HHmmss')
if (-not (Test-Path $runDir)) { New-Item -ItemType Directory -Path $runDir | Out-Null }

if ($HiddenText -and $PdfPath) {
    $res = Find-PdfHiddenText -PdfPath $PdfPath
    $res | ConvertTo-Json -Depth 6 | Out-File (Join-Path $runDir 'hidden_text.json') -Encoding UTF8
}

if ($Attachments -and $PdfPath) {
    $res = Find-PdfAttachments -PdfPath $PdfPath
    $res | ConvertTo-Json -Depth 6 | Out-File (Join-Path $runDir 'attachments.json') -Encoding UTF8
}

if ($Invoice -and $PdfPath) {
    $res = Verify-Invoice -PdfPath $PdfPath -Vendor $Vendor -InvoiceNumber $InvoiceNumber -Amount $Amount -Date $Date
    $res | ConvertTo-Json -Depth 6 | Out-File (Join-Path $runDir 'invoice_verify.json') -Encoding UTF8
}

if ($Eml -and $EmlPath) {
    $res = Extract-EMLParts -EmlPath $EmlPath -OutputDir (Join-Path $runDir 'eml')
    $res | ConvertTo-Json -Depth 6 | Out-File (Join-Path $runDir 'eml_summary.json') -Encoding UTF8
}

Write-Host "Output: $runDir" -ForegroundColor Green
