[CmdletBinding()]
param(
    [string]$Since = "",
    [string]$Until = "",
    [int]$Top = 10,
    [string]$SessionRoot = "",
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
        $py = Join-Path $PSScriptRoot "pack_grok_sessions.py"
        if (Test-Path -LiteralPath $py) {
            return $parent
        }
    }
    return (Get-Location).Path
}

$repoRoot = Get-RepoRoot -Hint $Root
$py = Join-Path $repoRoot "tools\pack_grok_sessions.py"
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