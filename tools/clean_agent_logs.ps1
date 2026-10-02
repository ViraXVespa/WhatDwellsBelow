# SHIM (kept one release): forwards every argument to clean_agent_logs.py. The old -Flag spellings work there.
# Prefer: python3 tools/clean_agent_logs.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "clean_agent_logs.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
