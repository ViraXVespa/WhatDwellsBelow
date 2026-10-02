# SHIM (kept one release): forwards every argument to file_stat.py. The old -Flag spellings work there.
# Prefer: python3 tools/file_stat.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "file_stat.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
