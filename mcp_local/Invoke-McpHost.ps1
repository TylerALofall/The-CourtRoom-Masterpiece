<#
.SYNOPSIS
    Local MCP host / dispatcher for The CourtRoom Masterpiece.

.DESCRIPTION
    Thin routing layer only. Reads a tool name and JSON input, dispatches to the
    matching PowerShell tool script in mcp_tools/, and returns the tool's JSON
    output to stdout. Tools are intentionally kept separate so a failure in one
    tool cannot crash the host or pollute other tool contexts.

    Heartbeat / autonomous loop logic is NOT implemented here. This host is a
    synchronous, on-demand dispatcher. Loop orchestration is deferred to a
    future runner layer.

.PARAMETER Tool
    The snake_case tool name to invoke (e.g. list_documents, resolve_citation).

.PARAMETER InputJson
    JSON string containing the tool's input object. Pass '{}' for tools with no
    required inputs.

.PARAMETER InputFile
    Path to a JSON file containing the tool's input. Mutually exclusive with
    -InputJson.

.PARAMETER ToolsDir
    Path to the directory containing the tool scripts. Defaults to the
    mcp_tools/ folder adjacent to this script's parent directory.

.PARAMETER ListTools
    When present, prints the tool registry and exits.

.EXAMPLE
    # List all registered tools
    pwsh -File Invoke-McpHost.ps1 -ListTools

    # List documents for a case
    pwsh -File Invoke-McpHost.ps1 -Tool list_documents -InputJson '{"case_no":"839"}'

    # Resolve a citation
    pwsh -File Invoke-McpHost.ps1 -Tool resolve_citation -InputJson '{"citation":"ecf[23]page[5]"}'
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$Tool = '',

    [Parameter(Mandatory = $false)]
    [string]$InputJson = '{}',

    [Parameter(Mandatory = $false)]
    [string]$InputFile = '',

    [Parameter(Mandatory = $false)]
    [string]$ToolsDir = '',

    [switch]$ListTools
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------
$HostDir   = $PSScriptRoot
$RepoRoot  = Split-Path $HostDir -Parent
$RegistryPath = Join-Path $HostDir 'tool_registry.json'

if (-not $ToolsDir) {
    $ToolsDir = Join-Path $RepoRoot 'mcp_tools'
}

# ---------------------------------------------------------------------------
# Helper: emit a JSON result to stdout
# ---------------------------------------------------------------------------
function Write-Result {
    param([hashtable]$Result)
    $Result | ConvertTo-Json -Depth 10 -Compress | Write-Output
}

function Write-ErrorResult {
    param([string]$Message, [string]$ToolName = '')
    Write-Result @{ ok = $false; tool = $ToolName; error = $Message }
}

# ---------------------------------------------------------------------------
# Load registry
# ---------------------------------------------------------------------------
if (-not (Test-Path $RegistryPath)) {
    Write-ErrorResult "tool_registry.json not found at: $RegistryPath"
    exit 1
}

try {
    $Registry = Get-Content -Path $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-ErrorResult "Failed to parse tool_registry.json: $($_.Exception.Message)"
    exit 1
}

# ---------------------------------------------------------------------------
# -ListTools flag: print registry summary and exit
# ---------------------------------------------------------------------------
if ($ListTools) {
    $summary = @{
        ok           = $true
        tool_count   = @($Registry.tools).Count
        tools        = @($Registry.tools | ForEach-Object {
            @{ tool_name = $_.tool_name; description = $_.description; script = $_.script }
        })
    }
    Write-Result $summary
    exit 0
}

# ---------------------------------------------------------------------------
# Validate tool name
# ---------------------------------------------------------------------------
if (-not $Tool) {
    Write-ErrorResult 'No -Tool specified. Use -ListTools to see available tools.'
    exit 1
}

$Entry = $Registry.tools | Where-Object { $_.tool_name -eq $Tool } | Select-Object -First 1
if (-not $Entry) {
    Write-ErrorResult "Unknown tool: '$Tool'. Use -ListTools to see available tools." -ToolName $Tool
    exit 1
}

# ---------------------------------------------------------------------------
# Resolve input JSON
# ---------------------------------------------------------------------------
if ($InputFile) {
    if (-not (Test-Path $InputFile)) {
        Write-ErrorResult "InputFile not found: $InputFile" -ToolName $Tool
        exit 1
    }
    try {
        $InputJson = Get-Content -Path $InputFile -Raw -Encoding UTF8
    } catch {
        Write-ErrorResult "Failed to read InputFile: $($_.Exception.Message)" -ToolName $Tool
        exit 1
    }
}

if (-not $InputJson) { $InputJson = '{}' }

# Validate JSON is parseable before passing to the tool
try {
    $null = $InputJson | ConvertFrom-Json
} catch {
    Write-ErrorResult "Input is not valid JSON: $($_.Exception.Message)" -ToolName $Tool
    exit 1
}

# ---------------------------------------------------------------------------
# Resolve tool script path
# ---------------------------------------------------------------------------
$ScriptPath = Join-Path $ToolsDir $Entry.script
if (-not (Test-Path $ScriptPath)) {
    Write-ErrorResult "Tool script not found: $ScriptPath" -ToolName $Tool
    exit 1
}

# ---------------------------------------------------------------------------
# Dispatch: invoke the tool script in a fresh scope, capture output
# ---------------------------------------------------------------------------
try {
    $output = & pwsh -NoProfile -NonInteractive -File $ScriptPath -InputJson $InputJson 2>&1
    $stdout = $output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    $stderr = $output | Where-Object { $_ -is  [System.Management.Automation.ErrorRecord] }

    if ($stderr) {
        $errText = ($stderr | ForEach-Object { $_.ToString() }) -join '; '
        Write-ErrorResult "Tool script error: $errText" -ToolName $Tool
        exit 1
    }

    # Pass through the tool's JSON output directly
    $stdout | Write-Output
} catch {
    Write-ErrorResult "Dispatch exception: $($_.Exception.Message)" -ToolName $Tool
    exit 1
}
