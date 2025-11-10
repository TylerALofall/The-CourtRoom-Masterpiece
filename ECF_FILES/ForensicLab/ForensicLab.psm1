# ESCAPE Forensic Lab - PowerShell Module

Set-StrictMode -Version Latest

function Get-PdfRawContent {
    param(
        [Parameter(Mandatory=$true)][string]$PdfPath
    )
    if (-not (Test-Path $PdfPath)) { throw "File not found: $PdfPath" }
    Get-Content -Path $PdfPath -Raw
}

function Find-PdfHiddenText {
    param(
        [Parameter(Mandatory=$true)][string]$PdfPath,
        [int]$MaxBlocks = 20
    )
    $content = Get-PdfRawContent -PdfPath $PdfPath

    $whiteTextPatterns = @(
        '1 1 1 rg',
        '1 1 1 RG',
        '1\.0+ 1\.0+ 1\.0+',
        '/DeviceRGB\s+1\s+1\s+1',
        '/TR\s+/Identity'
    )

    $whiteHits = @{}
    foreach ($p in $whiteTextPatterns) {
        $m = [regex]::Matches($content, $p)
        $whiteHits[$p] = $m.Count
    }

    $renderModes = @('3 Tr','7 Tr','/Tr 3','/Tr 7')
    $renderFound = @()
    foreach ($rm in $renderModes) {
        if ($content -match [regex]::Escape($rm)) { $renderFound += $rm }
    }

    $zeroOpacity = ($content -match '/ca\s+0' -or $content -match '/CA\s+0')
    $hasLayers = ($content -match '/OC\s+' -or $content -match '/Layer')

    $textBlocks = [regex]::Matches($content, 'BT(.*?)ET', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $suspicious = @()
    for ($i = 0; $i -lt [Math]::Min($MaxBlocks, $textBlocks.Count); $i++) {
        $block = $textBlocks[$i].Value
        if ($block -match '1 1 1 rg|1 1 1 RG|3 Tr|/ca 0') {
            $suspicious += [pscustomobject]@{
                Index = $i
                Preview = $block.Substring(0, [Math]::Min(200, $block.Length))
            }
        }
    }

    [pscustomobject]@{
        File = $PdfPath
        WhiteTextHits = $whiteHits
        RenderModes = $renderFound
        ZeroOpacity = $zeroOpacity
        HasLayers = $hasLayers
        TotalTextBlocks = $textBlocks.Count
        SuspiciousBlocks = $suspicious
    }
}

function Find-PdfAttachments {
    param(
        [Parameter(Mandatory=$true)][string]$PdfPath,
        [string]$NameLike
    )
    $content = Get-PdfRawContent -PdfPath $PdfPath

    $markers = @(
        '/Type\s*/EmbeddedFile',
        '/Type\s*/Filespec',
        '/EmbeddedFiles',
        '/Names\s*/EmbeddedFiles',
        '/AF\s*\[',
        '/Attachment'
    )

    $foundMarkers = @()
    foreach ($m in $markers) { if ($content -match $m) { $foundMarkers += $m } }

    $nameHit = $false
    if ($NameLike) { $nameHit = ($content -match [regex]::Escape($NameLike)) }

    $parentRefs = [regex]::Matches($content, '/Parent\s+\d+\s+\d+\s+R')

    [pscustomobject]@{
        File = $PdfPath
        FoundMarkers = $foundMarkers
        HasEmbeddedFiles = ($foundMarkers.Count -gt 0)
        NameReference = $NameLike
        NameReferenceFound = $nameHit
        ParentRefCount = $parentRefs.Count
        ParentRefsSample = ($parentRefs | Select-Object -First 5 | ForEach-Object { $_.Value })
    }
}

function Extract-EMLParts {
    param(
        [Parameter(Mandatory=$true)][string]$EmlPath,
        [string]$OutputDir
    )
    if (-not (Test-Path $EmlPath)) { throw "File not found: $EmlPath" }
    $emlContent = Get-Content -Path $EmlPath -Raw

    $sections = [regex]::Matches($emlContent, 'Content-Transfer-Encoding:\s*base64\s+([\s\S]+?)(?=--_|Content-Type:|$)')

    $results = @()
    $i = 1
    foreach ($s in $sections) {
        $b64 = $s.Groups[1].Value -replace '\s+', ''
        try {
            $bytes = [Convert]::FromBase64String($b64)
            $text = [Text.Encoding]::UTF8.GetString($bytes)
            $kind = if ($text -match '<html') { 'text/html' } else { 'text/plain' }
            $saved = @()
            if ($OutputDir) {
                if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
                $tfile = Join-Path $OutputDir "section_$i.txt"
                $bfile = Join-Path $OutputDir "section_${i}_binary.dat"
                $text | Out-File -FilePath $tfile -Encoding UTF8
                [IO.File]::WriteAllBytes($bfile, $bytes)
                $saved = @($tfile,$bfile)
            }
            $results += [pscustomobject]@{
                Index = $i
                ContentTypeGuess = $kind
                Bytes = $bytes.Length
                TextPreview = $text.Substring(0, [Math]::Min(200, $text.Length))
                Saved = $saved
            }
        } catch {
            $results += [pscustomobject]@{
                Index = $i
                Error = $_.Exception.Message
            }
        }
        $i++
    }

    $fnRef = $null
    if ($emlContent -match 'filename=["\'']?([^"\'']+?)["\'']?') { $fnRef = $Matches[1] }
    $pdfType = ($emlContent -match 'Content-Type:\s*application/pdf')

    [pscustomobject]@{
        File = $EmlPath
        Base64Sections = $results
        FilenameReference = $fnRef
        PdfContentTypeMentioned = $pdfType
    }
}

function Verify-Invoice {
    param(
        [Parameter(Mandatory=$true)][string]$PdfPath,
        [string]$Vendor,
        [string]$InvoiceNumber,
        [string]$Amount,
        [string]$Date
    )
    $content = Get-PdfRawContent -PdfPath $PdfPath

    $hits = @{}
    if ($Vendor)        { $hits['Vendor']        = ($content -match [regex]::Escape($Vendor)) }
    if ($InvoiceNumber) { $hits['InvoiceNumber'] = ($content -match [regex]::Escape($InvoiceNumber)) }
    if ($Amount)        { $amt = [regex]::Escape($Amount); $hits['Amount'] = ($content -match $amt) }
    if ($Date)          { $hits['Date']          = ($content -match [regex]::Escape($Date)) }

    $verified = ($hits.Values | Where-Object { $_ -eq $true }).Count -ge (@($hits.Keys).Count)

    [pscustomobject]@{
        File = $PdfPath
        Criteria = [pscustomobject]@{ Vendor=$Vendor; InvoiceNumber=$InvoiceNumber; Amount=$Amount; Date=$Date }
        Matches = $hits
        Verified = $verified
        Note = 'Best-effort scan of raw PDF content; for compressed streams, use advanced inflate workflow.'
    }
}

Export-ModuleMember -Function Find-PdfHiddenText, Find-PdfAttachments, Extract-EMLParts, Verify-Invoice
