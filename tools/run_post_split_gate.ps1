# Post-split gate: import check, then optional smokes. One summary for agents.
# Usage (from repo root):
#   powershell -File tools/run_post_split_gate.ps1
#   powershell -File tools/run_post_split_gate.ps1 -WithSmokes
#   powershell -File tools/run_post_split_gate.ps1 -WithSmokes -Phases 1,2,6
# Writes _logs/post-split-gate/summary.txt
# Refuses to start if Godot is already running unless -Force.

param(
    [switch]$WithSmokes,
    [int[]]$Phases = @(1, 2, 3, 4, 5, 6, 7, 8, 9),
    [int]$ImportTimeoutSec = 180,
    [int]$SmokeTimeoutSec = 120,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "_logs\post-split-gate"
$Summary = Join-Path $OutDir "summary.txt"
$ImportScript = Join-Path $Root "tools\run_godot_import_check.ps1"
$SmokeScript = Join-Path $Root "tools\run_smokes.ps1"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$existing = @(Get-Process -Name "godot*" -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0 -and -not $Force) {
    $msg = "Godot already running (pids=$($existing.Id -join ',')). Pass -Force to kill and continue, or wait."
    Write-Host $msg
    $msg | Set-Content -Path $Summary -Encoding utf8
    exit 2
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("post-split gate $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("withSmokes=$WithSmokes force=$Force")
$lines.Add("")
$fail = 0

Write-Host "== import check =="
$importArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ImportScript, "-TimeoutSec", "$ImportTimeoutSec")
$p = Start-Process -FilePath "powershell.exe" -ArgumentList $importArgs -Wait -PassThru -NoNewWindow
$importSummary = Join-Path $Root "_logs\godot-import-check\summary.txt"
$lines.Add("--- import check exit=$($p.ExitCode) ---")
if (Test-Path $importSummary) {
    Get-Content $importSummary | ForEach-Object { $lines.Add($_) }
} else {
    $lines.Add("(missing import summary)")
    $fail += 1
}
if ($p.ExitCode -ne 0) { $fail += 1 }
$lines.Add("")

if ($WithSmokes) {
    Write-Host "== smokes =="
    $smokeArgs = New-Object System.Collections.Generic.List[string]
    [void]$smokeArgs.Add("-NoProfile")
    [void]$smokeArgs.Add("-ExecutionPolicy")
    [void]$smokeArgs.Add("Bypass")
    [void]$smokeArgs.Add("-File")
    [void]$smokeArgs.Add($SmokeScript)
    [void]$smokeArgs.Add("-TimeoutSec")
    [void]$smokeArgs.Add("$SmokeTimeoutSec")
    [void]$smokeArgs.Add("-Phases")
    foreach ($n in $Phases) { [void]$smokeArgs.Add("$n") }
    $p2 = Start-Process -FilePath "powershell.exe" -ArgumentList $smokeArgs.ToArray() -Wait -PassThru -NoNewWindow
    $smokeSummary = Join-Path $Root "_logs\smokes\summary.txt"
    $lines.Add("--- smokes exit=$($p2.ExitCode) ---")
    if (Test-Path $smokeSummary) {
        Get-Content $smokeSummary | ForEach-Object { $lines.Add($_) }
    } else {
        $lines.Add("(missing smoke summary)")
        $fail += 1
    }
    if ($p2.ExitCode -ne 0) { $fail += 1 }
    $lines.Add("")
} else {
    $lines.Add("--- smokes skipped (pass -WithSmokes to run) ---")
    $lines.Add("")
}

$lines.Add(("RESULT fail_signals={0}" -f $fail))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host ""
Write-Host "Summary -> $Summary"
Write-Host ("fail_signals={0}" -f $fail)
if ($fail -gt 0) { exit 1 }
exit 0
