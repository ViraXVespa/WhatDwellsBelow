[CmdletBinding()]
param(
    [string]$Since = "",
    [string]$Until = "",
    [int]$Top = 10,
    [string]$SessionRoot = "",
    [string]$PackDir = "",
    [string]$OutDir = "",
    [string]$Root = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    param([string]$Hint)
    if ($Hint) {
        return (Resolve-Path -LiteralPath $Hint).Path
    }
    if ($PSScriptRoot) {
        $parent = Split-Path -Parent $PSScriptRoot
        $py = Join-Path $PSScriptRoot "report_grok_sessions.py"
        if (Test-Path -LiteralPath $py) {
            return $parent
        }
    }
    return (Get-Location).Path
}

$repoRoot = Get-RepoRoot -Hint $Root
. (Join-Path $repoRoot "tools\agent_log.ps1")
if (-not $OutDir) {
    $OutDir = Ensure-WdbAgentLogDir -Job "grok-sessions-report" -Root $repoRoot
}
if (-not $PackDir) {
    try {
        $PackDir = Get-WdbAgentLogDir -Job "grok-sessions-pack" -Root $repoRoot
    } catch {
        $PackDir = ""
    }
}
$py = Join-Path $repoRoot "tools\report_grok_sessions.py"
if (-not (Test-Path -LiteralPath $py)) {
    throw "missing $py"
}

$pyArgs = @(
    $py,
    "--root", $repoRoot,
    "--top", "$Top"
)
if ($Since) { $pyArgs += @("--since", $Since) }
if ($Until) { $pyArgs += @("--until", $Until) }
if ($SessionRoot) { $pyArgs += @("--session-root", $SessionRoot) }
if ($PackDir) { $pyArgs += @("--pack-dir", $PackDir) }
if ($OutDir) { $pyArgs += @("--out-dir", $OutDir) }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw "python not found on PATH"
}

$exe = $python.Source
if ($python.Name -eq "py" -or $exe -match '\\py\.exe$') {
    & $exe -3 @pyArgs
} else {
    & $exe @pyArgs
}
exit $LASTEXITCODE
