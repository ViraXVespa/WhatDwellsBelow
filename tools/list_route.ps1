[CmdletBinding()]
param(
    [string]$Door = "",
    [string]$Job = "",
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
        $py = Join-Path $PSScriptRoot "list_route.py"
        if (Test-Path -LiteralPath $py) {
            return $parent
        }
    }
    return (Get-Location).Path
}

$repoRoot = Get-RepoRoot -Hint $Root
$py = Join-Path $repoRoot "tools\list_route.py"
if (-not (Test-Path -LiteralPath $py)) {
    throw "missing $py"
}

$pyArgs = @($py, "--root", $repoRoot)
if ($Door) { $pyArgs += @("--door", $Door) }
if ($Job) { $pyArgs += @("--job", $Job) }

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