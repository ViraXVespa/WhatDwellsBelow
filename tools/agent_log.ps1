# SHIM (kept one release): forwards every argument to agent_log.py. The old -Flag spellings work there.
# Prefer: python3 tools/agent_log.py --help
# The dot-sourced Ensure-WdbAgentLogDir helpers are gone; use agent_log.py (agent_log.finish / emit_result).
$ErrorActionPreference = "Stop"
$py = Join-Path $PSScriptRoot "agent_log.py"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "python not found on PATH" }
& $python.Source $py @args
exit $LASTEXITCODE
