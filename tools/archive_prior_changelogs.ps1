# SHIM (kept one release): forwards every argument to archive_prior_changelogs.py. The old -Flag spellings work there.
# Prefer: python3 tools/archive_prior_changelogs.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "archive_prior_changelogs.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
