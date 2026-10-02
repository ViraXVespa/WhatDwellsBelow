# SHIM (kept one release): forwards every argument to move_script_cluster.py. The old -Flag spellings work there.
# Prefer: python3 tools/move_script_cluster.py --help
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "move_script_cluster.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
