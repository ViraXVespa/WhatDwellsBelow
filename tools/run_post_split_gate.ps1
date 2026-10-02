# SHIM (kept one release): forwards every argument to run_post_split_gate.py. The old -Flag spellings work there.
# Prefer: python3 tools/run_post_split_gate.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "run_post_split_gate.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
