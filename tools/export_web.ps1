# SHIM (kept one release): forwards every argument to export_web.py. The old -Flag spellings work there.
# Prefer: python3 tools/export_web.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "export_web.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
