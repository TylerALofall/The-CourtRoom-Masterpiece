<#
.SYNOPSIS
    get_tool_menu — Returns the list of registered MCP tools with contracts.

.DESCRIPTION
    Reads tool_registry.json from the mcp_local/ directory and returns a
    formatted tool menu. This is the discovery endpoint; agents should call
    this first to understand what tools are available before invoking them.

.PARAMETER InputJson
    Accepted for interface consistency. Ignored (no required inputs).
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

# Locate the registry relative to this script
$ToolsDir    = $PSScriptRoot
$McpLocalDir = Join-Path (Split-Path $ToolsDir -Parent) 'mcp_local'
$RegistryPath = Join-Path $McpLocalDir 'tool_registry.json'

if (-not (Test-Path $RegistryPath)) {
    Write-Result @{ ok = $false; error = "tool_registry.json not found at: $RegistryPath" }
    exit 1
}

try {
    $Registry = Get-Content -Path $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Result @{ ok = $false; error = "Failed to parse tool_registry.json: $($_.Exception.Message)" }
    exit 1
}

$tools = @($Registry.tools | ForEach-Object {
    @{
        tool_name   = $_.tool_name
        description = $_.description
        script      = $_.script
        input       = $_.input
        output      = $_.output
    }
})

Write-Result @{
    ok          = $true
    tool_count  = $tools.Count
    tools       = $tools
}
