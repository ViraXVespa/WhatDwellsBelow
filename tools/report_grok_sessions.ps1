# SHIM (kept one release): forwards every argument to report_grok_sessions.py. The old -Flag spellings work there.
# Prefer: python3 tools/report_grok_sessions.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "report_grok_sessions.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
