# SHIM (kept one release): forwards every argument to list_changed.py. The old -Flag spellings work there.
# Prefer: python3 tools/list_changed.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "list_changed.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
