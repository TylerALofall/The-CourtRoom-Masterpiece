param(
    [string]$Description = 'blueprint test'
)

$b = @{ description=$Description; quote='test'; context='manual' } | ConvertTo-Json -Depth 6
try {
    $resp = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:9099/api/gemini/analyze' -Body $b -ContentType 'application/json' -TimeoutSec 5
    $resp | ConvertTo-Json -Depth 8
} catch {
    Write-Host "ERR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response -and $_.Exception.Response.Content) {
        try { $_.Exception.Response.Content | Out-String | Write-Host } catch {}
    }
    exit 1
}
