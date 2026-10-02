# SHIM (kept one release): forwards every argument to start_build_slice.py. The old -Flag spellings work there.
# Prefer: python3 tools/start_build_slice.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "start_build_slice.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
