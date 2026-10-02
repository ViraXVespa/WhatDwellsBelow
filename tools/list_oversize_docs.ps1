# SHIM (kept one release): forwards every argument to list_oversize_docs.py. The old -Flag spellings work there.
# Prefer: python3 tools/list_oversize_docs.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "list_oversize_docs.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
