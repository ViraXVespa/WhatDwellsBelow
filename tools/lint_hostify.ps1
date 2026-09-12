# Advisory hostify / := lint. Always exits 0; read RESULT hits= in the summary.
# Usage (from repo root):
#   powershell -File tools/lint_hostify.ps1
# Writes _logs/hostify-lint/summary.txt

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Py = Join-Path $Root "tools\lint_hostify.py"
if (-not (Test-Path $Py)) { throw "missing $Py" }
Push-Location $Root
try {
    & python $Py
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
