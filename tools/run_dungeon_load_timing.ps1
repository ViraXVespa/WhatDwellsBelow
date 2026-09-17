# Placeholdia -> Dungeon load-timing smoke. Writes a short summary agents can read.
# Usage (from repo root):
#   powershell -File tools/run_dungeon_load_timing.ps1
#   powershell -File tools/run_dungeon_load_timing.ps1 -TimeoutSec 180
# See design/debug-smokes.md and design/pc-offload.md.

param(
    [int]$TimeoutSec = 180
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$OutDir = Join-Path $Root "_logs\dungeon-load-timing"
$Summary = Join-Path $OutDir "summary.txt"
$ErrLog = Join-Path $OutDir "err.log"
$OutLog = Join-Path $OutDir "out.log"

if (-not (Test-Path $Godot)) {
    throw "Steam Godot not found at: $Godot"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 400
Remove-Item $ErrLog, $OutLog, $Summary -Force -ErrorAction SilentlyContinue

$godotArgs = @(
    "--headless",
    "--display-driver", "headless",
    "--audio-driver", "Dummy",
    "--path", $Root,
    "--",
    "--wdb-dungeon-load-timing-smoke"
)

Write-Host "Running Placeholdia to Dungeon load timing..."
$sw = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process -FilePath $Godot -ArgumentList $godotArgs -PassThru -NoNewWindow `
    -RedirectStandardOutput $OutLog -RedirectStandardError $ErrLog
$ok = $p.WaitForExit([Math]::Max(1000, $TimeoutSec * 1000))
if (-not $ok) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 400
    Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
    $status = "TIMEOUT"
} else {
    $code = $p.ExitCode
    if ($null -eq $code) { $code = 0 }
    $status = "EXIT=$code"
}

Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
$ms = $sw.ElapsedMilliseconds
$errBytes = if (Test-Path $ErrLog) { (Get-Item $ErrLog).Length } else { 0 }
$outBytes = if (Test-Path $OutLog) { (Get-Item $OutLog).Length } else { 0 }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("dungeon load timing $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("status=$status wall_ms=$ms errBytes=$errBytes outBytes=$outBytes")
$lines.Add("")
$lines.Add("--- LOAD lines ---")

$loadHits = New-Object System.Collections.Generic.List[string]
$errHits = New-Object System.Collections.Generic.List[string]
foreach ($log in @($ErrLog, $OutLog)) {
    if (-not (Test-Path $log)) { continue }
    Select-String -Path $log -Pattern '^LOAD:' -ErrorAction SilentlyContinue |
        ForEach-Object { [void]$loadHits.Add($_.Line) }
    Select-String -Path $log -Pattern 'SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to' -ErrorAction SilentlyContinue |
        ForEach-Object { [void]$errHits.Add($_.Line) }
}

if ($loadHits.Count -eq 0) {
    $lines.Add("(no LOAD: lines - check err.log if TIMEOUT)")
} else {
    foreach ($h in ($loadHits | Select-Object -Unique)) {
        $lines.Add($h)
    }
}

$lines.Add("")
$lines.Add("--- errors ---")
if ($errHits.Count -eq 0) {
    $lines.Add("(none)")
} else {
    foreach ($h in ($errHits | Select-Object -Unique | Select-Object -First 40)) {
        $lines.Add($h)
    }
}

$fail = 0
if ($status -eq "TIMEOUT") { $fail += 1 }
if ($status -match '^EXIT=' -and $status -ne "EXIT=0") { $fail += 1 }
if ($errHits.Count -gt 0) { $fail += 1 }
$total = ""
$hasOk = $false
foreach ($h in $loadHits) {
    if ($h -match 'total_ms=(\d+)') { $total = $Matches[1] }
    if ($h -match 'ok=true') { $hasOk = $true }
}
if (-not $hasOk -or $total -eq "") { $fail += 1 }

$lines.Add("")
if ($total -eq "") {
    $lines.Add(("RESULT fail_signals={0} total_ms=-1" -f $fail))
} else {
    $lines.Add(("RESULT fail_signals={0} total_ms={1}" -f $fail, $total))
}
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host ("Summary -> {0}" -f $Summary)
if ($total -ne "") { Write-Host ("total_ms={0}" -f $total) }
exit $(if ($fail -gt 0) { 1 } else { 0 })
