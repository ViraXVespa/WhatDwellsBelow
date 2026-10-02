# SHIM (kept one release): forwards every argument to summarize_scripts.py. The old -Flag spellings work there.
# Prefer: python3 tools/summarize_scripts.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "summarize_scripts.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
