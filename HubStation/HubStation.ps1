param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ConfigPath = Join-Path $PSScriptRoot 'hub_config.json'
if (-not (Test-Path $ConfigPath)) {
    $default = @{ Port = 9099; OllamaBaseUrl = 'http://127.0.0.1:11434'; DefaultVoice = $null; Rate = 0; Volume = 100 }
    $default | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
}

$Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

$Port = if ($Config.Port) { [int]$Config.Port } else { 9099 }
$OllamaBaseUrl = if ($Config.OllamaBaseUrl) { [string]$Config.OllamaBaseUrl } else { 'http://127.0.0.1:11434' }
$DefaultVoice = $Config.DefaultVoice
$DefaultRate  = if ($Config.Rate -ne $null) { [int]$Config.Rate } else { 0 }
$DefaultVolume= if ($Config.Volume -ne $null) { [int]$Config.Volume } else { 100 }
$MaxCtxTokens = if ($Config -and $Config.PSObject.Properties.Match('MaxCtxTokens').Count -gt 0 -and $Config.MaxCtxTokens -ne $null) { [int]$Config.MaxCtxTokens } else { 10000 }
$MaxPredictTokens = if ($Config -and $Config.PSObject.Properties.Match('MaxPredictTokens').Count -gt 0 -and $Config.MaxPredictTokens -ne $null) { [int]$Config.MaxPredictTokens } else { 512 }
$DefaultModel = if ($Config -and $Config.PSObject.Properties.Match('DefaultModel').Count -gt 0 -and $Config.DefaultModel) { [string]$Config.DefaultModel } else { 'qwen3:latest' }

# Static website root
$StaticRoot = $null
if ($Config -and $Config.PSObject.Properties.Match('StaticRoot').Count -gt 0 -and $Config.StaticRoot) {
    $candidate = [string]$Config.StaticRoot
    try {
        $resolved = if ([IO.Path]::IsPathRooted($candidate)) { $candidate } else { Join-Path $PSScriptRoot $candidate }
        $StaticRoot = (Resolve-Path $resolved -ErrorAction Stop).Path
    } catch {
        Write-Log ("[INIT] Failed to resolve StaticRoot '{0}': {1}" -f $candidate, $_.Exception.Message) 'WARN'
        $StaticRoot = $null
    }
}

if (-not $StaticRoot) {
    $fallbackPrimary = Join-Path $PSScriptRoot '..\personal-website'
    try { $StaticRoot = (Resolve-Path $fallbackPrimary).Path } catch { $StaticRoot = $null }
}

if (-not $StaticRoot) {
    $fallbackSecondary = Join-Path $PSScriptRoot '..\scripts'
    try { $StaticRoot = (Resolve-Path $fallbackSecondary).Path } catch { $StaticRoot = $null }
}

$__sr = if ($StaticRoot) { $StaticRoot } else { '<null>' }
Write-Host ("[INIT] StaticRoot={0}" -f $__sr)

# Heartbeat state
if (-not (Get-Variable -Scope Script -Name Heartbeat -ErrorAction SilentlyContinue)) { $script:Heartbeat = @{ enabled = $false; last = $null; count = 0 } }

# Voice preferences
$script:VoiceBlockList = if ($Config -and $Config.PSObject.Properties.Match('VoiceBlockList').Count -gt 0 -and $Config.VoiceBlockList)
{ @($Config.VoiceBlockList) } else { @('Microsoft David Desktop','Microsoft David') }

Add-Type -AssemblyName System.Speech | Out-Null

# Import custom modules
$ReflectionsModule = Join-Path $PSScriptRoot 'Reflections.psm1'
$UIDParserModule = Join-Path $PSScriptRoot 'UIDParser.psm1'
$ModelDispatchModule = Join-Path $PSScriptRoot 'ModelDispatch.psm1'

if (Test-Path $ReflectionsModule) { Import-Module $ReflectionsModule -Force }
if (Test-Path $UIDParserModule) { Import-Module $UIDParserModule -Force }
if (Test-Path $ModelDispatchModule) { Import-Module $ModelDispatchModule -Force }

# Evidence Card prompt (externalized, never modified)
$script:GeminiPromptPath = Join-Path $PSScriptRoot '..\docs\GEMINI_EVIDENCE_PROMPT.txt'

# CSV log path
$script:CsvLogPath = Join-Path $PSScriptRoot '..\data\logs\actions.csv'

function Write-Log { param([string]$Msg,[string]$Level='INFO')
    $line = "[$(Get-Date -Format o)] [$Level] $Msg"
    try {
        if (-not (Get-Variable -Scope Script -Name LogBuffer -ErrorAction SilentlyContinue)) { $script:LogBuffer = New-Object System.Collections.ArrayList }
        [void]$script:LogBuffer.Add($line)
        if ($script:LogBuffer.Count -gt 2000) {
            $remove = $script:LogBuffer.Count - 2000
            $script:LogBuffer.RemoveRange(0, $remove)
        }
    } catch {}
    Write-Host ("[$(Get-Date -Format HH:mm:ss)] [$Level] $Msg")
}

function Add-CorsHeaders($resp) {
    $resp.Headers['Access-Control-Allow-Origin'] = '*'
    $resp.Headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    $resp.Headers['Access-Control-Allow-Headers'] = 'Content-Type'
}

function Send-Json($ctx, $obj, [int]$status=200){
    $json = ($obj | ConvertTo-Json -Depth 8)
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $resp = $ctx.Response
    Add-CorsHeaders $resp
    $resp.ContentType = 'application/json'
    $resp.StatusCode = $status
    $resp.ContentLength64 = $bytes.Length
    $resp.OutputStream.Write($bytes,0,$bytes.Length)
    $resp.OutputStream.Close()
}

function Send-Empty($ctx, [int]$status=204){
    $resp = $ctx.Response
    Add-CorsHeaders $resp
    $resp.StatusCode = $status
    $resp.OutputStream.Close()
}

function Get-MimeType([string]$Path){
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.html' { return 'text/html' }
        '.htm'  { return 'text/html' }
        '.js'   { return 'application/javascript' }
        '.css'  { return 'text/css' }
        '.json' { return 'application/json' }
        '.png'  { return 'image/png' }
        '.jpg'  { return 'image/jpeg' }
        '.jpeg' { return 'image/jpeg' }
        '.gif'  { return 'image/gif' }
        '.svg'  { return 'image/svg+xml' }
        '.wav'  { return 'audio/wav' }
        '.mp3'  { return 'audio/mpeg' }
        Default { return 'application/octet-stream' }
    }
}

function Send-File($ctx, [string]$FullPath){
    try {
        $bytes = [IO.File]::ReadAllBytes($FullPath)
        $resp = $ctx.Response
        Add-CorsHeaders $resp
        $resp.ContentType = Get-MimeType -Path $FullPath
        $resp.StatusCode = 200
        $resp.ContentLength64 = $bytes.Length
        $resp.OutputStream.Write($bytes,0,$bytes.Length)
        $resp.OutputStream.Close()
    } catch {
        Send-Json $ctx (@{ ok=$false; error='File read error' }) 500
    }
}

function Read-Body($ctx){
    $sr = New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)
    $body = $sr.ReadToEnd(); $sr.Close(); return $body
}

function Get-Voices(){
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try {
        $names = @($s.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name })
        if ($script:VoiceBlockList) {
            $names = @($names | Where-Object { $script:VoiceBlockList -notcontains $_ })
        }
        return $names
    } finally { $s.Dispose() }
}

function Select-PreferredVoice([string[]]$Preferred){
    try {
        $names = @(Get-Voices)
        if ($Preferred) {
            foreach ($p in $Preferred) { if ($names -contains $p) { return $p } }
        }
        if ($names -contains 'Microsoft Brian') { return 'Microsoft Brian' }
        if ($names -contains 'Microsoft Mark') { return 'Microsoft Mark' }
        if ($names -contains 'Microsoft Zira') { return 'Microsoft Zira' }
        if ($names.Count -gt 0) { return $names[0] }
        return $null
    } catch { return $null }
}

function Save-Config(){
    try {
        if (-not $Config) { return $false }
        $Config.Port = $Port
        $Config.OllamaBaseUrl = $OllamaBaseUrl
        $Config.DefaultVoice = $DefaultVoice
        $Config.Rate = $DefaultRate
        $Config.Volume = $DefaultVolume
        $Config.MaxCtxTokens = $MaxCtxTokens
        $Config.MaxPredictTokens = $MaxPredictTokens
        $Config.VoiceBlockList = $script:VoiceBlockList
        $Config.DefaultModel = $DefaultModel
        if ($StaticRoot) { $Config.StaticRoot = $StaticRoot }
        $Config | ConvertTo-Json -Depth 8 | Set-Content -Path $ConfigPath -Encoding UTF8
        return $true
    } catch {
        Write-Log ("Save-Config failed: {0}" -f $_.Exception.Message) 'ERROR'
        return $false
    }
}

function Use-TTS([string]$Text,[string]$Voice,[int]$Rate,[int]$Volume,[string]$SaveTo){
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try {
        $v = $null
        if ($Voice) { $v = $Voice }
        elseif ($DefaultVoice -and (-not $script:VoiceBlockList -or $script:VoiceBlockList -notcontains $DefaultVoice)) { $v = $DefaultVoice }
        if (-not $v) { $v = Select-PreferredVoice -Preferred @($Config.PreferredVoices) }
        if ($v) { $s.SelectVoice($v) }
        $s.Rate = $Rate
        $s.Volume = $Volume
        if ($SaveTo) { $s.SetOutputToWaveFile($SaveTo); $s.Speak($Text); $s.SetOutputToDefaultAudioDevice() } else { $s.Speak($Text) }
        return @{ ok = $true; voice = $v; rate = $Rate; volume = $Volume; saved = $SaveTo }
    } catch { return @{ ok = $false; error = $_.Exception.Message } } finally { $s.Dispose() }
}

function Save-TempAudio([string]$Base64, [string]$Extension){
    $ext = if ($Extension) { $Extension.TrimStart('.') } else { 'wav' }
    $tmp = Join-Path $env:TEMP ("hubstt_" + [guid]::NewGuid().ToString() + ".$ext")
    $bytes = [Convert]::FromBase64String($Base64)
    [IO.File]::WriteAllBytes($tmp, $bytes)
    return $tmp
}

function Invoke-WhisperTranscribe([string]$AudioPath, [string]$Language, [string]$ExeOverride, [string]$ModelOverride){
    $exe = if ($ExeOverride) { $ExeOverride } elseif ($Config.WhisperCppExe) { [string]$Config.WhisperCppExe } else { $null }
    $model = if ($ModelOverride) { $ModelOverride } elseif ($Config.WhisperModelPath) { [string]$Config.WhisperModelPath } else { $null }
    if (-not $exe) { return @{ ok=$false; error='WhisperCppExe not configured'; code='NO_EXE' } }
    if (-not $model) { return @{ ok=$false; error='WhisperModelPath not configured'; code='NO_MODEL' } }
    if (-not (Test-Path $AudioPath)) { return @{ ok=$false; error="Audio file not found: $AudioPath" } }
    $base = Join-Path $env:TEMP ("hubstt_" + [IO.Path]::GetFileNameWithoutExtension($AudioPath) + "_" + ([guid]::NewGuid().ToString().Substring(0,8)))
    $txtOut = "$base.txt"
    $args = @('-m', $model, '-f', $AudioPath, '-otxt', '-of', $base)
    if ($Language) { $args += @('-l', $Language) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if (-not (Test-Path $txtOut)) { return @{ ok=$false; error='No transcript produced'; stdout=$stdout; stderr=$stderr } }
    $text = Get-Content -Path $txtOut -Raw
    return @{ ok=$true; text=$text; stdout=$stdout; stderr=$stderr }
}

function Invoke-OllamaChat([string]$Model, $Messages, [double]$Temperature, $Options){
    $uri = "$OllamaBaseUrl/api/chat"
    $opts = @{ temperature = $Temperature }
    if ($Options) { foreach ($k in $Options.Keys) { $opts[$k] = $Options[$k] } }
    $body = @{ model = $Model; messages = $Messages; stream = $false; options = $opts } | ConvertTo-Json -Depth 6
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Body $body -TimeoutSec 120
        if ($resp.message -and $resp.message.content) { return @{ ok=$true; response = [string]$resp.message.content } }
        if ($resp.response) { return @{ ok=$true; response = [string]$resp.response } }
        return @{ ok=$false; error='Unexpected Ollama response' }
    } catch { return @{ ok=$false; error=$_.Exception.Message } }
}

function Get-RecentProcesses([int]$Count){
    try {
        $take = if ($Count -gt 0) { [int]$Count } else { 10 }
        $procs = Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
            Sort-Object -Property CreationDate -Descending |
            Select-Object -First $take -Property Name, ProcessId, CreationDate
        $items = @()
        foreach ($p in $procs) {
            $dt = $null
            try { $dt = [System.Management.ManagementDateTimeConverter]::ToDateTime($p.CreationDate) } catch { $dt = Get-Date }
            $items += @{ name = [string]$p.Name; pid = [int]$p.ProcessId; started = ($dt.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
        return @{ ok = $true; items = $items }
    } catch { return @{ ok = $false; error = $_.Exception.Message } }
}

function Save-Note([string]$Text, [string]$Prefix, [bool]$Open){
    try {
        if (-not $Text) { return @{ ok=$false; error='text required' } }
        $root = Join-Path $env:TEMP 'hub_notes'
        if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
        $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $pref = if ($Prefix) { $Prefix } else { 'note' }
        $file = Join-Path $root ("${pref}_$stamp.txt")
        Set-Content -LiteralPath $file -Value $Text -Encoding UTF8
        if ($Open) { Start-Process -FilePath 'notepad.exe' -ArgumentList @("`"$file`"") | Out-Null }
        return @{ ok=$true; path=$file }
    } catch { return @{ ok=$false; error=$_.Exception.Message } }
}

# In-memory queue for cross-UI messaging
if (-not (Get-Variable -Scope Script -Name MessageQueue -ErrorAction SilentlyContinue)) { $script:MessageQueue = New-Object System.Collections.ArrayList }

function Add-QueueItem([string]$Text, [string]$Target, [string]$Priority, [string]$Release){
    $tgt = if ($Target) { $Target } else { 'tyler' }
    $pri = if ($Priority -and @('low','normal','high') -contains $Priority) { $Priority } else { 'normal' }
    $rel = if ($Release -and @('immediate','heartbeat','end') -contains $Release) { $Release } else { 'heartbeat' }
    $item = @{ text = $Text; target = $tgt; priority=$pri; release=$rel; ts = (Get-Date).ToString('o') }
    [void]$script:MessageQueue.Add($item)
    return $item
}

function Get-QueueItems(){ return @($script:MessageQueue) }

function Pop-QueueItems([string]$Release, [int]$Max){
    $sel = @()
    $remIdx = @()
    for ($i=0; $i -lt $script:MessageQueue.Count; $i++) {
        $it = $script:MessageQueue[$i]
        if ($Release -and $it.release -ne $Release) { continue }
        $sel += $it
        $remIdx += $i
        if ($Max -gt 0 -and $sel.Count -ge $Max) { break }
    }
    if ($remIdx.Count -gt 0) {
        # remove from back to front
        foreach ($idx in ($remIdx | Sort-Object -Descending)) { $script:MessageQueue.RemoveAt($idx) }
    }
    return $sel
}

# Notification queue helpers
if (-not (Get-Variable -Scope Script -Name NotifyQueue -ErrorAction SilentlyContinue)) { $script:NotifyQueue = New-Object System.Collections.ArrayList }
function Add-Notify([string]$Text, [string]$Severity){
    $sev = if ($Severity -and @('info','warn','error') -contains $Severity) { $Severity } else { 'info' }
    $item = @{ text=$Text; severity=$sev; ts=(Get-Date).ToString('o') }
    [void]$script:NotifyQueue.Add($item)
    return $item
}
function Get-NotifyItems(){ return @($script:NotifyQueue) }
function Pop-NotifyItems([int]$Max){
    $take = if ($Max -gt 0) { [int]$Max } else { $script:NotifyQueue.Count }
    $items = @()
    for ($i=0; $i -lt $take -and $script:NotifyQueue.Count -gt 0; $i++) {
        $items += $script:NotifyQueue[0]
        $script:NotifyQueue.RemoveAt(0)
    }
    return $items
}

$prefix = "http://127.0.0.1:$Port/"
$prefixLocal = "http://localhost:$Port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Prefixes.Add($prefixLocal)
try {
    $listener.Start()
    Write-Log "Hub Station listening on $prefix and $prefixLocal"
} catch {
    $err = $_.Exception.Message
    Write-Log ("Listener start failed (both prefixes): {0}" -f $err) 'ERROR'
    # Retry with only 127.0.0.1 to avoid localhost ACL/conflict issues
    try { $listener.Close() } catch {}
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add($prefix)
    try {
        $listener.Start()
        Write-Log "Hub Station listening on $prefix (localhost disabled due to previous error)" 'WARN'
    } catch {
        Write-Log ("Fallback listener start failed on {0}: {1}" -f $prefix, $_.Exception.Message) 'ERROR'
        throw
    }
}

while ($true) {
    $ctx = $listener.GetContext()
    try {
        $req = $ctx.Request
        $path = $req.Url.AbsolutePath.ToLowerInvariant()
        if ($req.HttpMethod -eq 'OPTIONS') { Send-Empty $ctx 204; continue }

        switch ($path) {
            '/status' {
                $out = @{ ok = $true; port = $Port; ollama = $OllamaBaseUrl; default_model = $DefaultModel; voices = (Get-Voices); time = (Get-Date).ToString('o'); max_ctx = $MaxCtxTokens; max_predict = $MaxPredictTokens; heartbeat = $script:Heartbeat }
                Send-Json $ctx $out 200
            }
            '/heartbeat/tick' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $script:Heartbeat.last = (Get-Date).ToString('o')
                $script:Heartbeat.count = [int]$script:Heartbeat.count + 1
                Write-Log ("Heartbeat tick #{0}" -f $script:Heartbeat.count)
                Send-Json $ctx (@{ ok=$true; heartbeat=$script:Heartbeat }) 200
            }
            '/heartbeat/enable' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }
                $en = $false; if ($json.enabled -ne $null) { $en = [bool]$json.enabled }
                $script:Heartbeat.enabled = $en
                Write-Log ("Heartbeat enabled=${en}")
                Send-Json $ctx (@{ ok=$true; heartbeat=$script:Heartbeat }) 200
            }
            '/heartbeat/state' {
                if ($req.HttpMethod -ne 'GET') { Send-Json $ctx (@{ ok=$false; error='GET required' }) 405; break }
                Send-Json $ctx (@{ ok=$true; heartbeat=$script:Heartbeat }) 200
            }
            '/notify/push' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }
                $text = [string]$json.text
                $sev = [string]$json.severity
                if (-not $text) { Send-Json $ctx (@{ ok=$false; error='text required' }) 400; break }
                $item = Add-Notify -Text $text -Severity $sev
                Send-Json $ctx (@{ ok=$true; count=$script:NotifyQueue.Count; item=$item }) 200
            }
            '/notify/list' {
                if ($req.HttpMethod -ne 'GET') { Send-Json $ctx (@{ ok=$false; error='GET required' }) 405; break }
                $items = Get-NotifyItems
                Send-Json $ctx (@{ ok=$true; items=$items; total=($items.Count) }) 200
            }
            '/notify/pop' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $max = 0
                try { $b = Read-Body $ctx; if ($b) { $j = ConvertFrom-Json -InputObject $b -ErrorAction Stop; if ($j.max) { $max = [int]$j.max } } } catch {}
                $items = Pop-NotifyItems -Max $max
                Send-Json $ctx (@{ ok=$true; items=$items }) 200
            }
            '/ollama/stop' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }
                $model = [string]$json.model
                if (-not $model) { Send-Json $ctx (@{ ok=$false; error='model required' }) 400; break }
                Write-Log "Stop requested: $model"
                try {
                    $cmd = Get-Command ollama -ErrorAction SilentlyContinue
                    if (-not $cmd) { Send-Json $ctx (@{ ok=$false; error='ollama cli not found' }) 500; break }
                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = 'ollama'
                    $psi.Arguments = "stop `"$model`""
                    $psi.UseShellExecute = $false
                    $psi.RedirectStandardOutput = $true
                    $psi.RedirectStandardError = $true
                    $p = New-Object System.Diagnostics.Process
                    $p.StartInfo = $psi
                    [void]$p.Start()
                    $stdout = $p.StandardOutput.ReadToEnd()
                    $stderr = $p.StandardError.ReadToEnd()
                    $p.WaitForExit()
                    if ($stdout) { $stdout -split "`r?`n" | ForEach-Object { if ($_){ Write-Log $_ 'STOP' } } }
                    if ($stderr) { $stderr -split "`r?`n" | ForEach-Object { if ($_){ Write-Log $_ 'STOP-ERR' } } }
                    Send-Json $ctx (@{ ok=$true; exit=$p.ExitCode }) 200
                } catch {
                    Write-Log ("Stop failed: {0}" -f $_.Exception.Message) 'ERROR'
                    Send-Json $ctx (@{ ok=$false; error=$_.Exception.Message }) 500
                }
            }
            '/voices' {
                $list = Get-Voices
                Send-Json $ctx (@{ voices = $list; default = $DefaultVoice }) 200
            }
            '/voices/set' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }
                $voice = [string]$json.voice
                if (-not $voice) { Send-Json $ctx (@{ ok=$false; error='voice required' }) 400; break }
                $available = Get-Voices
                if ($available -notcontains $voice) { Send-Json $ctx (@{ ok=$false; error='voice not installed'; available=$available }) 400; break }
                $DefaultVoice = $voice
                $Config.DefaultVoice = $voice
                $saved = Save-Config
                Write-Log ("DefaultVoice set to '{0}' (saved={1})" -f $DefaultVoice, $saved)
                Send-Json $ctx (@{ ok=$true; default=$DefaultVoice; saved=$saved }) 200
            }
            '/logs' {
                $n = 200
                try {
                    if ($req.Url.Query) {
                        $qry = $req.Url.Query.TrimStart('?')
                        foreach ($pair in ($qry -split '&')) {
                            if (-not $pair) { continue }
                            $kv = $pair -split '=',2
                            if ($kv.Length -ge 1 -and $kv[0] -eq 'n' -and $kv.Length -ge 2) {
                                try { $n = [int]$kv[1] } catch {}
                            }
                        }
                    }
                } catch {}
                $lines = @()
                if ($script:LogBuffer) {
                    $start = [Math]::Max(0, $script:LogBuffer.Count - $n)
                    for ($i = $start; $i -lt $script:LogBuffer.Count; $i++) { $lines += $script:LogBuffer[$i] }
                }
                $total = if ($script:LogBuffer) { [int]$script:LogBuffer.Count } else { 0 }
                Send-Json $ctx (@{ ok=$true; lines=$lines; total=$total }) 200
            }
            { $path -like '/web*' } {
                if (-not $StaticRoot -or -not (Test-Path $StaticRoot)) { Send-Json $ctx (@{ ok=$false; error='Static root not found' }) 500; break }
                $rel = if ($path -eq '/web' -or $path -eq '/web/') { 'index.html' } else { ($path.Substring(5)).TrimStart('/') }
                $combined = Join-Path $StaticRoot ($rel -replace '/', '\')
                try { $full = [IO.Path]::GetFullPath($combined) } catch { Send-Json $ctx (@{ ok=$false; error='Bad path' }) 400; break }
                $rootLC = $StaticRoot.ToLowerInvariant()
                $fullLC = $full.ToLowerInvariant()
                if (-not $fullLC.StartsWith($rootLC)) { Send-Json $ctx (@{ ok=$false; error='Forbidden' }) 403; break }
                if (-not (Test-Path $full)) { Send-Json $ctx (@{ ok=$false; error='Not found' }) 404; break }
                Write-Log ("/web -> {0}" -f $rel)
                Send-File $ctx $full
            }
            '/models' {
                try {
                    $uri = "$OllamaBaseUrl/api/tags"
                    $resp = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 60
                    $models = @()
                    if ($resp -and $resp.models) { $models = @($resp.models | ForEach-Object { $_.name }) }
                    Send-Json $ctx (@{ ok = $true; models = $models }) 200
                } catch {
                    Send-Json $ctx (@{ ok = $false; error = $_.Exception.Message }) 500
                }
            }
            '/ollama/list' {
                try {
                    $resp = Invoke-RestMethod -Method Get -Uri ("$OllamaBaseUrl/api/tags") -TimeoutSec 60
                    $models = @()
                    if ($resp -and $resp.models) { $models = @($resp.models | ForEach-Object { $_.name }) }
                    Write-Log ("Ollama list -> {0} models" -f $models.Count)
                    Send-Json $ctx (@{ ok=$true; models=$models }) 200
                } catch { Send-Json $ctx (@{ ok=$false; error=$_.Exception.Message }) 500 }
            }
            '/ollama/ps' {
                try {
                    $resp = Invoke-RestMethod -Method Get -Uri ("$OllamaBaseUrl/api/ps") -TimeoutSec 60
                    Send-Json $ctx (@{ ok=$true; processes=$resp.models }) 200
                } catch { Send-Json $ctx (@{ ok=$false; error=$_.Exception.Message }) 500 }
            }
            '/ollama/pull' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }
                $model = [string]$json.model
                if (-not $model) { Send-Json $ctx (@{ ok=$false; error='model required' }) 400; break }
                Write-Log "Pull requested: $model"
                try {
                    $cmd = Get-Command ollama -ErrorAction SilentlyContinue
                    if ($cmd) {
                        $psi = New-Object System.Diagnostics.ProcessStartInfo
                        $psi.FileName = 'ollama'
                        $psi.Arguments = "pull `"$model`""
                        $psi.UseShellExecute = $false
                        $psi.RedirectStandardOutput = $true
                        $psi.RedirectStandardError = $true
                        $p = New-Object System.Diagnostics.Process
                        $p.StartInfo = $psi
                        [void]$p.Start()
                        $stdout = $p.StandardOutput.ReadToEnd()
                        $stderr = $p.StandardError.ReadToEnd()
                        $p.WaitForExit()
                        if ($stdout) { $stdout -split "`r?`n" | ForEach-Object { if ($_){ Write-Log $_ 'PULL' } } }
                        if ($stderr) { $stderr -split "`r?`n" | ForEach-Object { if ($_){ Write-Log $_ 'PULL-ERR' } } }
                        Send-Json $ctx (@{ ok=$true; method='cli'; exit=$p.ExitCode }) 200
                    } else {
                        $pullBody = @{ name = $model; stream = $false } | ConvertTo-Json
                        $resp = Invoke-RestMethod -Method Post -Uri ("$OllamaBaseUrl/api/pull") -ContentType 'application/json' -Body $pullBody -TimeoutSec 600
                        Write-Log ("Pulled via REST: {0}" -f $model)
                        Send-Json $ctx (@{ ok=$true; method='rest'; result=$resp }) 200
                    }
                } catch {
                    Write-Log ("Pull failed: {0}" -f $_.Exception.Message) 'ERROR'
                    Send-Json $ctx (@{ ok=$false; error=$_.Exception.Message }) 500
                }
            }
            '/tts' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop
                $text = [string]$json.text
                $voice= [string]$json.voice
                $rate = if ($json.rate -ne $null) { [int]$json.rate } else { $DefaultRate }
                $vol  = if ($json.volume -ne $null) { [int]$json.volume } else { $DefaultVolume }
                $save = [string]$json.saveToFile
                if (-not $text) { Send-Json $ctx (@{ ok=$false; error='text required' }) 400; break }
                $res = Use-TTS -Text $text -Voice $voice -Rate $rate -Volume $vol -SaveTo $save
                Send-Json $ctx $res 200
            }
            '/stt' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop
                $audioPath = [string]$json.audioPath
                $audioB64  = [string]$json.audioBase64
                $ext       = [string]$json.extension
                $lang      = [string]$json.language
                $exeOver   = [string]$json.whisperExe
                $modelOver = [string]$json.modelPath
                $tempFile = $null
                if (-not $audioPath -and -not $audioB64) { Send-Json $ctx (@{ ok=$false; error='audioPath or audioBase64 required' }) 400; break }
                if ($audioB64) { $tempFile = Save-TempAudio -Base64 $audioB64 -Extension ($ext -or 'wav'); $audioPath = $tempFile }
                $res = Invoke-WhisperTranscribe -AudioPath $audioPath -Language $lang -ExeOverride $exeOver -ModelOverride $modelOver
                if ($tempFile -and (Test-Path $tempFile)) { Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue }
                Send-Json $ctx $res 200
            }
            '/chat' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop
                $model = if ($json.model) { [string]$json.model } else { $DefaultModel }
                $temp  = if ($json.temperature -ne $null) { [double]$json.temperature } else { 0.7 }
                $messages = @()
                foreach ($m in $json.messages) { $messages += @{ role = [string]$m.role; content = [string]$m.content } }
                # Clamp options
                $reqOpts = $json.options
                $numCtx = if ($reqOpts -and $reqOpts.num_ctx) { [int]$reqOpts.num_ctx } else { $MaxCtxTokens }
                $numPred= if ($reqOpts -and $reqOpts.num_predict) { [int]$reqOpts.num_predict } else { $MaxPredictTokens }
                $numCtx = [Math]::Min($numCtx, $MaxCtxTokens)
                $numPred= [Math]::Min($numPred, $MaxPredictTokens)
                Write-Log ("/chat -> model=$model temp=$temp num_ctx=$numCtx num_predict=$numPred msgs=$($messages.Count)")
                $opt = @{ num_ctx = $numCtx; num_predict = $numPred }
                $res = Invoke-OllamaChat -Model $model -Messages $messages -Temperature $temp -Options $opt
                Send-Json $ctx $res 200
            }
            '/tool' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $tb = [string]$Config.ToolBridgePath
                if (-not $tb -or -not (Test-Path $tb)) { Send-Json $ctx (@{ ok=$false; error='ToolBridgePath not configured or not found' }) 500; break }
                $body = Read-Body $ctx
                # Write JSON body to temp file to avoid escaping issues
                $tmpJson = Join-Path $env:TEMP ("hubtool_" + [guid]::NewGuid().ToString() + ".json")
                Set-Content -Path $tmpJson -Value $body -Encoding UTF8
                try {
                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = 'pwsh'
                    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$tb`" -JsonFile `"$tmpJson`""
                    $psi.UseShellExecute = $false
                    $psi.RedirectStandardOutput = $true
                    $psi.RedirectStandardError = $true
                    $p = New-Object System.Diagnostics.Process
                    $p.StartInfo = $psi
                    [void]$p.Start()
                    $stdout = $p.StandardOutput.ReadToEnd()
                    $stderr = $p.StandardError.ReadToEnd()
                    $p.WaitForExit()
                    if (-not $stdout) { Send-Json $ctx (@{ ok=$false; error='No output from tool bridge'; stderr=$stderr }) 500; break }
                    try {
                        $obj = $stdout | ConvertFrom-Json -ErrorAction Stop
                        # If the bridge already returns our JSON structure, pass it
                        $pass = @{ ok = $true; result = $obj }
                        Send-Json $ctx $pass 200
                    } catch {
                        Send-Json $ctx (@{ ok=$false; error='Invalid JSON from tool bridge'; raw=$stdout; stderr=$stderr }) 500
                    }
                } finally {
                    if (Test-Path $tmpJson) { Remove-Item -LiteralPath $tmpJson -Force -ErrorAction SilentlyContinue }
                }
            }
            '/run' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }
                $action = [string]$json.action
                switch ($action) {
                    'recent-processes' {
                        $cnt = if ($json.count -ne $null) { [int]$json.count } else { 10 }
                        $res = Get-RecentProcesses -Count $cnt
                        if ($res.ok) { Send-Json $ctx (@{ ok=$true; action='recent-processes'; items=$res.items }) 200 }
                        else { Send-Json $ctx (@{ ok=$false; error=$res.error }) 500 }
                    }
                    'save-note' {
                        $text = [string]$json.text
                        $prefix = [string]$json.prefix
                        $open = $false
                        if ($json.open -ne $null) { $open = [bool]$json.open }
                        $res = Save-Note -Text $text -Prefix $prefix -Open:$open
                        if ($res.ok) { Send-Json $ctx (@{ ok=$true; action='save-note'; path=$res.path }) 200 }
                        else { Send-Json $ctx (@{ ok=$false; error=$res.error }) 500 }
                    }
                    Default { Send-Json $ctx (@{ ok=$false; error='Unknown action' }) 400 }
                }
            }
            '/queue/push' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }
                $text = [string]$json.text
                $target = [string]$json.target
                $priority = [string]$json.priority
                $release = [string]$json.release
                if (-not $text) { Send-Json $ctx (@{ ok=$false; error='text required' }) 400; break }
                $item = Add-QueueItem -Text $text -Target $target -Priority $priority -Release $release
                Send-Json $ctx (@{ ok=$true; count = $script:MessageQueue.Count; item=$item }) 200
            }
            '/queue/list' {
                if ($req.HttpMethod -ne 'GET') { Send-Json $ctx (@{ ok=$false; error='GET required' }) 405; break }
                $items = Get-QueueItems
                $counts = @{}
                foreach ($it in $items) { $k = $it.release; if (-not $counts.ContainsKey($k)) { $counts[$k]=0 }; $counts[$k]++ }
                Send-Json $ctx (@{ ok=$true; items = $items; counts=$counts; total=($items.Count) }) 200
            }
            '/queue/pop' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $rel = $null; $max = 0
                try {
                    if ($req.HasEntityBody) {
                        $body = Read-Body $ctx
                        if ($body) {
                            $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop
                            if ($json.release) { $rel = [string]$json.release }
                            if ($json.max) { $max = [int]$json.max }
                        }
                    }
                } catch {}
                $items = Pop-QueueItems -Release $rel -Max $max
                Send-Json $ctx (@{ ok=$true; items = $items }) 200
            }
            '/api/gemini/analyze' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }
                $evidenceText = [string]$json.evidence
                if (-not $evidenceText) { Send-Json $ctx (@{ ok=$false; error='evidence field required' }) 400; break }

                # Load Gemini prompt template (never modified)
                $promptTemplate = ''
                if (Test-Path $script:GeminiPromptPath) {
                    $promptTemplate = Get-Content -Path $script:GeminiPromptPath -Raw
                } else {
                    Send-Json $ctx (@{ ok=$false; error='Gemini prompt template not found' }) 500; break
                }

                # Build full prompt
                $fullPrompt = $promptTemplate + "`n`n--- EVIDENCE TO ANALYZE ---`n" + $evidenceText

                # Get API key from config
                $geminiKey = if ($Config.GeminiApiKey) { [string]$Config.GeminiApiKey } else { '' }
                if (-not $geminiKey) { Send-Json $ctx (@{ ok=$false; error='GeminiApiKey not configured' }) 500; break }

                Write-Log "[GEMINI] Analyzing evidence (${evidenceText.Length} chars)"

                # Call Gemini via ModelDispatch
                $result = Invoke-Model -ModelName 'gemini' -Prompt $fullPrompt -GeminiApiKey $geminiKey -Temperature 0.4

                if (-not $result.ok) {
                    Send-Json $ctx (@{ ok=$false; error=$result.error }) 500
                    break
                }

                # Process response: split into cards and save
                $cards = Process-GeminiResponse -ResponseText $result.response -SourceModel 'gemini'

                # Log to CSV
                foreach ($card in $cards) {
                    if ($card.ok) {
                        Add-LogRow -LogPath $script:CsvLogPath -SourceModel 'gemini' -RouteAction 'evidence_card' -UID $card.uid -ContentPreview "Saved card: $($card.uid)"
                    }
                }

                Write-Log "[GEMINI] Processed $($cards.Count) cards"
                Send-Json $ctx (@{ ok=$true; cards=$cards; count=$cards.Count }) 200
            }
            '/api/models/run' {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx (@{ ok=$false; error='POST required' }) 405; break }
                $body = Read-Body $ctx
                try { $json = ConvertFrom-Json -InputObject $body -ErrorAction Stop } catch { Send-Json $ctx (@{ ok=$false; error='Invalid JSON' }) 400; break }

                $modelName = [string]$json.model
                $prompt = [string]$json.prompt
                $sysPrompt = [string]$json.system_prompt
                $temp = if ($json.temperature -ne $null) { [double]$json.temperature } else { 0.7 }
                $format = [string]$json.format

                if (-not $modelName -or -not $prompt) {
                    Send-Json $ctx (@{ ok=$false; error='model and prompt required' }) 400
                    break
                }

                if ($modelName -notin @('qwen3', 'kimi', 'gemini')) {
                    Send-Json $ctx (@{ ok=$false; error='Invalid model. Use: qwen3, kimi, or gemini' }) 400
                    break
                }

                Write-Log "[DISPATCH] Running model: $modelName (temp=$temp, format=$format)"

                $geminiKey = if ($Config.GeminiApiKey) { [string]$Config.GeminiApiKey } else { '' }

                $result = Invoke-Model `
                    -ModelName $modelName `
                    -Prompt $prompt `
                    -SystemPrompt $sysPrompt `
                    -Temperature $temp `
                    -Format $format `
                    -GeminiApiKey $geminiKey `
                    -OllamaBaseUrl $OllamaBaseUrl

                # Log to CSV
                $preview = if ($result.response.Length -gt 100) { $result.response.Substring(0, 100) + '...' } else { $result.response }
                Add-LogRow -LogPath $script:CsvLogPath -SourceModel $modelName -RouteAction 'model_run' -ContentPreview $preview

                Send-Json $ctx $result 200
            }
            '/logs/csv/tail' {
                if ($req.HttpMethod -ne 'GET') { Send-Json $ctx (@{ ok=$false; error='GET required' }) 405; break }

                $count = 50
                $filterUser = $false

                # Parse query string
                try {
                    if ($req.Url.Query) {
                        $qry = $req.Url.Query.TrimStart('?')
                        foreach ($pair in ($qry -split '&')) {
                            if (-not $pair) { continue }
                            $kv = $pair -split '=',2
                            if ($kv.Length -ge 2) {
                                if ($kv[0] -eq 'count') { try { $count = [int]$kv[1] } catch {} }
                                if ($kv[0] -eq 'filter_user' -and $kv[1] -eq 'true') { $filterUser = $true }
                            }
                        }
                    }
                } catch {}

                Write-Log "[CSV] Fetching tail: count=$count, filter_user=$filterUser"

                $rows = Get-LogTail -LogPath $script:CsvLogPath -Count $count -FilterUserOnly $filterUser

                Send-Json $ctx (@{ ok=$true; rows=$rows; count=$rows.Count; filtered=$filterUser }) 200
            }
            Default {
                Send-Json $ctx (@{ ok=$false; error='Not found' }) 404
            }
        }
    } catch {
        try { Send-Json $ctx (@{ ok=$false; error=$_.Exception.Message }) 500 } catch {}
    }
}
