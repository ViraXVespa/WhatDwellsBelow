# SHIM (kept one release): forwards every argument to check_script_cap.py. The old -Flag spellings work there.
# Prefer: python3 tools/check_script_cap.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "check_script_cap.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
