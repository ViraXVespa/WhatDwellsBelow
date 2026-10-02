# SHIM (kept one release): forwards every argument to godot_lib.py. The old -Flag spellings work there.
# Prefer: python3 tools/godot_lib.py --help
# The lock library lives in godot_lib.py; this forwards the old CLI probe (-Path -Root -TimeoutSec).
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "godot_lib.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
