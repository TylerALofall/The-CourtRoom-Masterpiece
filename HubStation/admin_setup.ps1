$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'admin_setup.log'
function Log($m){
  $ts = (Get-Date).ToString('u'); "$ts $m" | Tee-Object -FilePath $log -Append | Out-Host
}

Log "=== Admin setup start ==="
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Log ("IsAdmin={0}" -f $IsAdmin)

Log "Show current URLACL (filtered by port)"
$cfgPath = Join-Path $PSScriptRoot 'hub_config.json'
$cfg = $null; try { if (Test-Path $cfgPath) { $cfg = Get-Content -Path $cfgPath -Raw | ConvertFrom-Json } } catch {}
$port = if ($cfg -and $cfg.Port) { [int]$cfg.Port } else { 9099 }
try { netsh http show urlacl | Select-String -Pattern "$port" -Context 2,4 | Out-String | Tee-Object -FilePath $log -Append | Out-Host } catch { Log $_ }

$urls = @("http://127.0.0.1:$port/","http://localhost:$port/")
Log "Delete stale reservations"
foreach($u in $urls){ try { Log ("Deleting: {0}" -f $u); netsh http delete urlacl url=$u | Tee-Object -FilePath $log -Append | Out-Host } catch { Log $_ } }

Log "Add reservations for Everyone"
foreach($u in $urls){ try { Log ("Adding: {0}" -f $u); netsh http add urlacl url=$u user=Everyone | Tee-Object -FilePath $log -Append | Out-Host } catch { Log $_ } }

Log "Verify URLACL (filtered by port)"
try { netsh http show urlacl | Select-String -Pattern "$port" -Context 2,4 | Out-String | Tee-Object -FilePath $log -Append | Out-Host } catch { Log $_ }

$scriptPath = Join-Path $PSScriptRoot 'HubStation.ps1'
Log ("Starting HubStation: {0}" -f $scriptPath)
$server = $null
try {
  $server = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$scriptPath") -PassThru -WindowStyle Normal
  Log ("HubStation PID: {0}" -f $server.Id)
} catch { Log ("Start-Process error: {0}" -f $_.Exception.Message) }

# Wait for status
$ok=$false; $resp=$null
for($i=0;$i -lt 50;$i++){
  try{ $resp = irm ("http://127.0.0.1:{0}/status" -f $port) -TimeoutSec 2; if($resp -and $resp.ok){ $ok=$true; break } } catch {}
  Start-Sleep -Milliseconds 300
}
if($ok){ Log "STATUS OK"; ($resp | ConvertTo-Json -Depth 6) | Tee-Object -FilePath $log -Append | Out-Host } else { Log "STATUS not responding" }

# Check /web
try{ $w=iwr ("http://127.0.0.1:{0}/web" -f $port) -TimeoutSec 4; Log ("WEB STATUS: {0} LENGTH: {1}" -f $w.StatusCode,$w.Content.Length) }catch{ Log ("WEB ERROR: {0}" -f $_.Exception.Message) }

# TTS smoke
try{ $tts = irm -Method Post ("http://127.0.0.1:{0}/tts" -f $port) -ContentType application/json -Body '{"text":"HubStation online, Tyler. Using Mark.","rate":0,"volume":100}'; ($tts | ConvertTo-Json -Depth 6) | Tee-Object -FilePath $log -Append | Out-Host } catch { Log ("TTS ERROR: {0}" -f $_.Exception.Message) }

Log "=== Admin setup end ==="
