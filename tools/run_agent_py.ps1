# Run an agent Python script and clean up ephemeral copies under _logs/agent-py/.
# Usage (from repo root):
#   powershell -File tools/run_agent_py.ps1 -Script _logs/agent-py/patch.py
#   powershell -File tools/run_agent_py.ps1 -Script tools/some_checked_in.py -KeepScript
#
# Default: if -Script is under _logs/agent-py/, delete it after the run (success or fail).
# Checked-in tools/ scripts are never deleted unless -Cleanup is forced (refused for paths outside _logs/agent-py/).

param(
    [Parameter(Mandatory = $true)][string]$Script,
    [switch]$KeepScript,
    [switch]$Cleanup
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "_logs\agent-py"
$Summary = Join-Path $OutDir "summary.txt"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$scriptPath = $Script
if (-not [System.IO.Path]::IsPathRooted($scriptPath)) {
    $scriptPath = Join-Path $Root $Script
}
$scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Script not found: $scriptPath"
}

$agentPyRoot = [System.IO.Path]::GetFullPath($OutDir)
$underAgentPy = $scriptPath.StartsWith($agentPyRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) `
    -or $scriptPath.StartsWith($agentPyRoot + [System.IO.Path]::AltDirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)

# Cleanup policy: default delete only under _logs/agent-py/. -KeepScript opts out. -Cleanup on a non-ephemeral path is refused.
$doCleanup = $false
if ($KeepScript) {
    $doCleanup = $false
} elseif ($underAgentPy) {
    $doCleanup = $true
} elseif ($Cleanup) {
    throw "Refusing -Cleanup for script outside _logs/agent-py/: $scriptPath"
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("agent-py $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("script=$scriptPath")
$lines.Add("under_agent_py=$underAgentPy cleanup=$doCleanup keep=$KeepScript")
$lines.Add("")

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $py) { throw "python not found on PATH" }

$exit = 0
$outText = ""
try {
    $outText = & $py.Source $scriptPath 2>&1 | Out-String
    if ($null -ne $LASTEXITCODE) { $exit = [int]$LASTEXITCODE }
} catch {
    $exit = 1
    $outText = "$_"
}

# Trim oversized stdout in summary
$trim = $outText
if ($trim.Length -gt 4000) {
    $trim = $trim.Substring(0, 4000) + "`n...[truncated]"
}
$lines.Add("----- stdout/stderr -----")
$lines.Add($trim.TrimEnd())
$lines.Add("----- end -----")
$lines.Add("")

$cleaned = $false
if ($doCleanup) {
    try {
        Remove-Item -LiteralPath $scriptPath -Force -ErrorAction Stop
        $cleaned = $true
    } catch {
        $lines.Add("cleanup_error=$($_.Exception.Message)")
    }
}
$lines.Add(("RESULT exit={0} cleaned={1}" -f $exit, $cleaned))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host "Summary -> $Summary"
Write-Host ("exit={0} cleaned={1}" -f $exit, $cleaned)
exit $exit
