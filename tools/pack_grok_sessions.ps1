# SHIM (kept one release): forwards every argument to pack_grok_sessions.py. The old -Flag spellings work there.
# Prefer: python3 tools/pack_grok_sessions.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "pack_grok_sessions.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
