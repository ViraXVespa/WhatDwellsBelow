# Grok Build post-slice gate: script cap on changed .gd + editor import check.
# Usage (from repo root):
#   powershell -File tools/run_build_gate.ps1
#   powershell -File tools/run_build_gate.ps1 -SkipImport
#   powershell -File tools/run_build_gate.ps1 -OverKb 10 -Force
# Writes _logs/build-gate/summary.txt
# Refuses if Godot is already running unless -Force.

param(
    [double]$OverKb = 10,
    [int]$ImportTimeoutSec = 180,
    [switch]$SkipImport,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "_logs\build-gate"
$Summary = Join-Path $OutDir "summary.txt"
$CapScript = Join-Path $Root "tools\check_script_cap.ps1"
$ImportScript = Join-Path $Root "tools\run_godot_import_check.ps1"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$existing = @(Get-Process -Name "godot*" -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0 -and -not $Force -and -not $SkipImport) {
    $msg = "Godot already running (pids=$($existing.Id -join ',')). Pass -Force to continue, or -SkipImport."
    Write-Host $msg
    $msg | Set-Content -Path $Summary -Encoding utf8
    exit 2
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("build gate $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("overKb=$OverKb skipImport=$SkipImport force=$Force")
$lines.Add("")
$fail = 0

Write-Host "== script cap (git changed) =="
$capArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $CapScript, "-OverKb", "$OverKb", "-GitChanged")
$p = Start-Process -FilePath "powershell.exe" -ArgumentList $capArgs -Wait -PassThru -NoNewWindow
$capSummary = Join-Path $Root "_logs\script-cap\summary.txt"
$lines.Add("--- script cap exit=$($p.ExitCode) ---")
if (Test-Path $capSummary) {
    Get-Content $capSummary | ForEach-Object { $lines.Add($_) }
} else {
    $lines.Add("(missing script-cap summary)")
    $fail += 1
}
if ($p.ExitCode -ne 0) { $fail += 1 }
$lines.Add("")

if (-not $SkipImport) {
    Write-Host "== import check =="
    $importArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ImportScript, "-TimeoutSec", "$ImportTimeoutSec")
    $p2 = Start-Process -FilePath "powershell.exe" -ArgumentList $importArgs -Wait -PassThru -NoNewWindow
    $importSummary = Join-Path $Root "_logs\godot-import-check\summary.txt"
    $lines.Add("--- import check exit=$($p2.ExitCode) ---")
    if (Test-Path $importSummary) {
        Get-Content $importSummary | ForEach-Object { $lines.Add($_) }
    } else {
        $lines.Add("(missing import summary)")
        $fail += 1
    }
    if ($p2.ExitCode -ne 0) { $fail += 1 }
    $lines.Add("")
} else {
    $lines.Add("--- import skipped ---")
    $lines.Add("")
}

$lines.Add(("RESULT fail_signals={0}" -f $fail))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host ""
Write-Host "Summary -> $Summary"
Write-Host ("fail_signals={0}" -f $fail)
if ($fail -gt 0) { exit 1 }
exit 0
