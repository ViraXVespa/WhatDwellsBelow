# Move facade + siblings into a folder; rewrite res:// paths across the repo.
# Usage (from repo root):
#   powershell -File tools/move_script_cluster.ps1 -Stem gear_board -FromDir scripts/ui -ToDir scripts/ui/gear_board -DryRun
#   powershell -File tools/move_script_cluster.ps1 -Stem debug_menu -FromDir scripts/combat -ToDir scripts/debug/debug_menu
#   powershell -File tools/move_script_cluster.ps1 -Files scripts/combat/sfx.gd -ToDir scripts/audio
# Writes _logs/move-cluster/summary.txt

param(
    [string]$Stem = "",
    [string]$FromDir = "",
    [Parameter(Mandatory = $true)][string]$ToDir,
    [string[]]$Files = @(),
    [switch]$DryRun,
    [switch]$Wrapper,
    [switch]$NoGit
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Py = Join-Path $Root "tools\move_script_cluster.py"
if (-not (Test-Path $Py)) { throw "missing $Py" }
$argsList = @($Py, "--to-dir", $ToDir)
if ($Stem) { $argsList += @("--stem", $Stem) }
if ($FromDir) { $argsList += @("--from-dir", $FromDir) }
if ($Files.Count -gt 0) { $argsList += @("--files"); $argsList += $Files }
if ($DryRun) { $argsList += "--dry-run" }
if ($Wrapper) { $argsList += "--wrapper" }
if ($NoGit) { $argsList += "--no-git" }
Push-Location $Root
try {
    & python @argsList
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
