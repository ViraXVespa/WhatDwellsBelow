# Dungeon generation map smoke. Writes a short summary agents can read.
# Usage (from repo root):
#   powershell -File tools/run_dungeon_map.ps1
#   powershell -File tools/run_dungeon_map.ps1 -Seed 42 -Floor 1 -Scale 8
#   powershell -File tools/run_dungeon_map.ps1 -TimeoutSec 180
# See design/debug-smokes.md and design/pc-offload.md.

param(
    [int]$TimeoutSec = 180,
    [int]$Seed = 42,
    [int]$Floor = 1,
    [int]$Scale = 8
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$OutDir = Join-Path $Root "_logs\dungeon-map"
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
    "--wdb-dungeon-map-smoke",
    ("--wdb-dungeon-map-seed={0}" -f $Seed),
    ("--wdb-dungeon-map-floor={0}" -f $Floor),
    ("--wdb-dungeon-map-scale={0}" -f $Scale)
)

Write-Host ("Running dungeon map smoke seed={0} floor={1} scale={2}..." -f $Seed, $Floor, $Scale)
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
$lines.Add("dungeon map $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("status=$status wall_ms=$ms errBytes=$errBytes outBytes=$outBytes seed=$Seed floor=$Floor scale=$Scale")
$lines.Add("")
$lines.Add("--- MAP lines ---")

$mapHits = New-Object System.Collections.Generic.List[string]
$errHits = New-Object System.Collections.Generic.List[string]
foreach ($log in @($ErrLog, $OutLog)) {
    if (-not (Test-Path $log)) { continue }
    Select-String -Path $log -Pattern '^MAP:' -ErrorAction SilentlyContinue |
        ForEach-Object { [void]$mapHits.Add($_.Line) }
    Select-String -Path $log -Pattern 'SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to' -ErrorAction SilentlyContinue |
        ForEach-Object { [void]$errHits.Add($_.Line) }
}

if ($mapHits.Count -eq 0) {
    $lines.Add("(no MAP: lines - check err.log if TIMEOUT)")
} else {
    foreach ($h in $mapHits) {
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
$hasOk = $false
$specFail = "-1"
foreach ($h in $mapHits) {
    if ($h -match 'ok=true' -and $h -notmatch 'spec ') { $hasOk = $true }
    if ($h -match 'spec_fail=(\d+)') { $specFail = $Matches[1] }
}
if (-not $hasOk) { $fail += 1 }
if ($specFail -eq "-1") { $fail += 1 }
elseif ([int]$specFail -gt 0) { $fail += 1 }

$lines.Add("")
$lines.Add(("RESULT fail_signals={0} spec_fail={1} map_ok={2}" -f $fail, $specFail, $hasOk))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host ("Summary -> {0}" -f $Summary)
Write-Host ("spec_fail={0} fail_signals={1}" -f $specFail, $fail)
exit $(if ($fail -gt 0) { 1 } else { 0 })
