# Editor import / script-reload check (Steam Godot).
# Usage (from repo root):
#   powershell -File tools/run_godot_import_check.ps1
# Writes _logs/godot-import-check/summary.txt - agents should read that, not the raw logs.
# See design/grok-bot-session.md (Headless compile check).

param(
    [int]$TimeoutSec = 180
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$OutDir = Join-Path $Root "_logs\godot-import-check"
$Summary = Join-Path $OutDir "summary.txt"
$OutLog = Join-Path $OutDir "import-out.log"
$ErrLog = Join-Path $OutDir "import-err.log"

if (-not (Test-Path $Godot)) {
    throw "Steam Godot not found at: $Godot"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 400

Remove-Item $OutLog, $ErrLog, $Summary -Force -ErrorAction SilentlyContinue

$godotArgs = @(
    "--headless",
    "--editor",
    "--import",
    "--path", $Root,
    "--quit"
)

Write-Host "Running editor import check..."
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
    # Godot GUI-subsystem + redirected IO often leaves ExitCode $null even on a clean quit.
    $code = $p.ExitCode
    if ($null -eq $code) { $code = 0 }
    $status = "EXIT=$code"
}

Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force

$errBytes = if (Test-Path $ErrLog) { (Get-Item $ErrLog).Length } else { 0 }
$outBytes = if (Test-Path $OutLog) { (Get-Item $OutLog).Length } else { 0 }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("godot import check $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("status=$status ms=$($sw.ElapsedMilliseconds) errBytes=$errBytes outBytes=$outBytes")
$lines.Add("")
$lines.Add("--- highlights ---")

$hits = New-Object System.Collections.Generic.List[string]
foreach ($log in @($ErrLog, $OutLog)) {
    if (-not (Test-Path $log)) { continue }
    Select-String -Path $log -Pattern 'SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|WARNING:' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Line } |
        Select-Object -Unique |
        ForEach-Object { [void]$hits.Add($_) }
}

if ($hits.Count -eq 0) {
    $lines.Add("(no SCRIPT ERROR / WARNING highlights)")
} else {
    foreach ($h in ($hits | Select-Object -Unique | Select-Object -First 120)) {
        $lines.Add($h)
    }
}

$hasHard = $false
foreach ($h in $hits) {
    if ($h -match 'SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed') { $hasHard = $true; break }
}
$clean = ($status -eq "EXIT=0") -and ($errBytes -eq 0) -and (-not $hasHard)
$lines.Add("")
if ($clean) { $lines.Add("RESULT clean=true") } else { $lines.Add("RESULT clean=false") }
$lines | Set-Content -Path $Summary -Encoding utf8

Write-Host ""
Write-Host "Summary -> $Summary"
Write-Host ("clean={0}" -f $clean)

if (-not $clean) { exit 1 }
exit 0
