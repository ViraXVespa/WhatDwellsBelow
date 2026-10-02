# SHIM (kept one release): forwards every argument to week_start.py. The old -Flag spellings work there.
# Prefer: python3 tools/week_start.py --help
# QUARANTINE: human-only. Agents must not run this file.
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "week_start.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
