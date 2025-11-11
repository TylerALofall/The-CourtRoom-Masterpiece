# Reflections.psm1 - Comprehensive logging and reflection system for CourtRoom evidence analysis
# Supports both action logging and structured reflection entries

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# CSV schema with all reflection columns
$script:LogHeaders = @(
    'epoch_ms',
    'source_model',
    'user_message_id',
    'route_action',
    'uid',
    'content_preview',
    'rating_score',
    'rating_success_certainty',
    'rating_completeness_percent',
    'rating_info_sufficiency',
    'structured_task_yn',
    'task_completed_yn',
    'instructions_clear_yn',
    'redo_change_explainer',
    'redo_improvements',
    'user_change_request',
    'helpful_user_action',
    'future_task_improvement',
    'meta_tags',
    'goal_short_title',
    'goal_current_summary'
)

function Initialize-LogFile {
    param(
        [string]$LogPath
    )

    if (-not (Test-Path $LogPath)) {
        $dir = Split-Path -Parent $LogPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # Write CSV header
        $headerLine = ($script:LogHeaders -join ',')
        Set-Content -Path $LogPath -Value $headerLine -Encoding UTF8
        Write-Host "[REFLECT] Initialized log file: $LogPath"
    }
}

function Escape-CsvValue {
    param([string]$Value)

    if ([string]::IsNullOrEmpty($Value)) {
        return ''
    }

    # If contains comma, quote, or newline, escape it
    if ($Value -match '[,"\r\n]') {
        return '"' + ($Value -replace '"', '""') + '"'
    }

    return $Value
}

function Add-LogRow {
    <#
    .SYNOPSIS
    Appends a row to the reflection CSV log.

    .DESCRIPTION
    Writes either a standard action row or a full reflection row.
    All fields are optional except epoch_ms, source_model, and route_action.

    .PARAMETER LogPath
    Path to the CSV log file. Will be created if it doesn't exist.

    .PARAMETER SourceModel
    The model that generated this entry (e.g., 'qwen3', 'kimi', 'gemini').

    .PARAMETER RouteAction
    The action or route taken (e.g., 'goal', 'notepad', 'terminal', 'reflection_pass').

    .PARAMETER UID
    Optional Evidence Card UID (e.g., '111', '245B').

    .PARAMETER ContentPreview
    Brief preview of the action or response content.

    .PARAMETER IsReflection
    If true, this is a reflection entry and will populate reflection-specific fields.

    .PARAMETER ReflectionData
    Hashtable with reflection-specific fields:
    - goal_short_title
    - goal_current_summary
    - rating_score (1-10)
    - rating_success_certainty (1-10)
    - rating_completeness_percent (1-10)
    - rating_info_sufficiency (1-10)
    - structured_task_yn (Y/N)
    - task_completed_yn (Y/N)
    - instructions_clear_yn (Y/N)
    - redo_change_explainer
    - redo_improvements
    - user_change_request
    - helpful_user_action
    - future_task_improvement
    - meta_tags (pipe-separated: tag1|tag2|tag3)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$SourceModel,

        [Parameter(Mandatory)]
        [string]$RouteAction,

        [string]$UserMessageId = '',
        [string]$UID = '',
        [string]$ContentPreview = '',

        [bool]$IsReflection = $false,
        [hashtable]$ReflectionData = @{}
    )

    Initialize-LogFile -LogPath $LogPath

    $epochMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

    # Build row array matching header order
    $row = @(
        $epochMs,
        (Escape-CsvValue $SourceModel),
        (Escape-CsvValue $UserMessageId),
        (Escape-CsvValue $RouteAction),
        (Escape-CsvValue $UID),
        (Escape-CsvValue $ContentPreview),
        (Escape-CsvValue ($ReflectionData['rating_score'] -as [string])),
        (Escape-CsvValue ($ReflectionData['rating_success_certainty'] -as [string])),
        (Escape-CsvValue ($ReflectionData['rating_completeness_percent'] -as [string])),
        (Escape-CsvValue ($ReflectionData['rating_info_sufficiency'] -as [string])),
        (Escape-CsvValue ($ReflectionData['structured_task_yn'] -as [string])),
        (Escape-CsvValue ($ReflectionData['task_completed_yn'] -as [string])),
        (Escape-CsvValue ($ReflectionData['instructions_clear_yn'] -as [string])),
        (Escape-CsvValue ($ReflectionData['redo_change_explainer'] -as [string])),
        (Escape-CsvValue ($ReflectionData['redo_improvements'] -as [string])),
        (Escape-CsvValue ($ReflectionData['user_change_request'] -as [string])),
        (Escape-CsvValue ($ReflectionData['helpful_user_action'] -as [string])),
        (Escape-CsvValue ($ReflectionData['future_task_improvement'] -as [string])),
        (Escape-CsvValue ($ReflectionData['meta_tags'] -as [string])),
        (Escape-CsvValue ($ReflectionData['goal_short_title'] -as [string])),
        (Escape-CsvValue ($ReflectionData['goal_current_summary'] -as [string]))
    )

    $line = $row -join ','
    Add-Content -Path $LogPath -Value $line -Encoding UTF8

    Write-Host ("[REFLECT] Logged: {0} | {1} | {2}" -f $SourceModel, $RouteAction, ($UID -or 'N/A'))
}

function Get-LogTail {
    <#
    .SYNOPSIS
    Returns the last N rows from the log, optionally filtered.

    .PARAMETER LogPath
    Path to the CSV log file.

    .PARAMETER Count
    Number of rows to return (default 50).

    .PARAMETER FilterUserOnly
    If true, exclude rows with route_action containing 'reflection' or internal thinking.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [int]$Count = 50,
        [bool]$FilterUserOnly = $false
    )

    if (-not (Test-Path $LogPath)) {
        return @()
    }

    $lines = Get-Content -Path $LogPath -Encoding UTF8
    if ($lines.Count -le 1) {
        return @()  # Only header or empty
    }

    # Skip header
    $dataLines = $lines[1..($lines.Count - 1)]

    if ($FilterUserOnly) {
        # Simple heuristic: exclude rows with route_action = 'reflection_pass' or 'thinking'
        $filtered = $dataLines | Where-Object {
            $_ -notmatch ',reflection_pass,' -and $_ -notmatch ',thinking,'
        }
        $dataLines = $filtered
    }

    $take = [Math]::Min($Count, $dataLines.Count)
    $start = [Math]::Max(0, $dataLines.Count - $take)

    return $dataLines[$start..($dataLines.Count - 1)]
}

function New-ReflectionEntry {
    <#
    .SYNOPSIS
    Creates a reflection entry after reviewing the last N interactions.

    .DESCRIPTION
    Analyzes recent log entries and produces a structured reflection row.
    This should be called every ~10 model interactions.

    .PARAMETER LogPath
    Path to the CSV log file.

    .PARAMETER SourceModel
    The model performing the reflection.

    .PARAMETER LookbackCount
    Number of recent entries to reflect on (default 10).

    .PARAMETER ReflectionPrompt
    Optional custom prompt to guide the reflection analysis.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$SourceModel,

        [int]$LookbackCount = 10,
        [string]$ReflectionPrompt = ''
    )

    # For now, this is a stub that logs a reflection marker
    # In a full implementation, this would:
    # 1. Read the last N log entries
    # 2. Build a prompt asking the model to reflect
    # 3. Parse the model's response into the 10-point structure
    # 4. Call Add-LogRow with IsReflection=$true

    $recentRows = Get-LogTail -LogPath $LogPath -Count $LookbackCount

    $reflectionData = @{
        goal_short_title = 'Periodic reflection'
        goal_current_summary = "Reviewed last $LookbackCount actions"
        rating_score = 0
        rating_success_certainty = 0
        rating_completeness_percent = 0
        rating_info_sufficiency = 0
        structured_task_yn = 'Y'
        task_completed_yn = 'N'
        instructions_clear_yn = 'Y'
        redo_change_explainer = ''
        redo_improvements = ''
        user_change_request = ''
        helpful_user_action = ''
        future_task_improvement = ''
        meta_tags = 'reflection|periodic|auto'
    }

    Add-LogRow `
        -LogPath $LogPath `
        -SourceModel $SourceModel `
        -RouteAction 'reflection_pass' `
        -ContentPreview "Auto-reflection over $LookbackCount entries" `
        -IsReflection $true `
        -ReflectionData $reflectionData

    Write-Host "[REFLECT] Created reflection entry for model: $SourceModel"
}

Export-ModuleMember -Function @(
    'Initialize-LogFile',
    'Add-LogRow',
    'Get-LogTail',
    'New-ReflectionEntry'
)
