# Move non-current-series design/changelog/*.md into design/changelog/archive/{epoch}.{series}/
# Usage (from repo root):
#   powershell -File tools/archive_prior_changelogs.ps1
#   powershell -File tools/archive_prior_changelogs.ps1 -DryRun
# Writes _logs/changelog-archive/summary.txt

param([switch]$DryRun)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Py = Join-Path $Root "tools\archive_prior_changelogs.py"
$argsList = @($Py)
if ($DryRun) { $argsList += "--dry-run" }
Push-Location $Root
try { & python @argsList; exit $LASTEXITCODE } finally { Pop-Location }
