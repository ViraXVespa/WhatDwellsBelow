# SHIM (kept one release): forwards every argument to lint_hostify.py. The old -Flag spellings work there.
# Prefer: python3 tools/lint_hostify.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "lint_hostify.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
