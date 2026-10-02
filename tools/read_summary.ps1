# SHIM (kept one release): forwards every argument to read_summary.py. The old -Flag spellings work there.
# Prefer: python3 tools/read_summary.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "read_summary.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
