# Func-level script inventory. Agents read _logs/script-summary/summary.txt only.
# Usage (from repo root):
#   powershell -File tools/summarize_scripts.ps1
#   powershell -File tools/summarize_scripts.ps1 -OverKb 5 -TopFuncs 8
#   powershell -File tools/summarize_scripts.ps1 -Path scripts/combat/enemy.gd

param(
    [double]$OverKb = 0,
    [int]$TopFuncs = 6,
    [string[]]$Path = @()
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Py = Join-Path $Root "tools\summarize_scripts.py"
if (-not (Test-Path $Py)) { throw "missing $Py" }
$argsList = @($Py, "--over-kb", "$OverKb", "--top-funcs", "$TopFuncs")
foreach ($p in $Path) { $argsList += @("--path", $p) }
Push-Location $Root
try {
    & python @argsList
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
