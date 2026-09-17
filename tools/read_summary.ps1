[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Job = "",
    [string]$Path = "",
    [string]$Root = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$JobMap = @{
    "clean"                = "_logs/clean/summary.txt"
    "oversize-docs"        = "_logs/oversize-docs/summary.txt"
    "agent-py"             = "_logs/agent-py/summary.txt"
    "oversize"             = "_logs/oversize/summary.txt"
    "script-summary"       = "_logs/script-summary/summary.txt"
    "facade-cluster"       = "_logs/facade-cluster/summary.txt"
    "script-cap"           = "_logs/script-cap/summary.txt"
    "changed"              = "_logs/changed/summary.txt"
    "show-func"            = "_logs/show-func/summary.txt"
    "xref"                 = "_logs/xref/summary.txt"
    "route"                = "_logs/route/summary.txt"
    "code-map-row"         = "_logs/code-map-row/summary.txt"
    "code-map-patch"       = "_logs/code-map-patch/summary.txt"
    "code-map-check"       = "_logs/code-map-check/summary.txt"
    "bot-opt"              = "_logs/bot-opt/summary.txt"
    "scenes"               = "_logs/scenes/summary.txt"
    "changelog-label"      = "_logs/changelog-label/summary.txt"
    "skill-sync"           = "_logs/skill-sync/summary.txt"
    "godot-import-check"   = "_logs/godot-import-check/summary.txt"
    "smokes"               = "_logs/smokes/summary.txt"
    "load-timing"          = "_logs/load-timing/summary.txt"
    "dungeon-load-timing"  = "_logs/dungeon-load-timing/summary.txt"
    "dungeon-map"          = "_logs/dungeon-map/summary.txt"
    "hostify-lint"         = "_logs/hostify-lint/summary.txt"
    "post-split-gate"      = "_logs/post-split-gate/summary.txt"
    "build-gate"           = "_logs/build-gate/summary.txt"
    "grok-sessions-pack"   = "_logs/grok-sessions-pack/summary.txt"
    "grok-sessions-report" = "_logs/grok-sessions-report/summary.txt"
}

function Get-RepoRoot {
    param([string]$Hint)
    if ($Hint) {
        return (Resolve-Path -LiteralPath $Hint).Path
    }
    if ($PSScriptRoot) {
        return (Split-Path -Parent $PSScriptRoot)
    }
    return (Get-Location).Path
}

$repoRoot = Get-RepoRoot -Hint $Root

if (-not $Job -and -not $Path) {
    $names = ($JobMap.Keys | Sort-Object) -join ", "
    Write-Output "usage: powershell -File tools/read_summary.ps1 -Job <name>"
    Write-Output "jobs: $names"
    exit 2
}

if ($Path) {
    $rel = $Path
} elseif ($JobMap.ContainsKey($Job)) {
    $rel = $JobMap[$Job]
} else {
    $rel = Join-Path "_logs" (Join-Path $Job "summary.txt")
}

if ([System.IO.Path]::IsPathRooted($rel)) {
    $full = $rel
} else {
    $full = Join-Path $repoRoot $rel
}

if (-not (Test-Path -LiteralPath $full)) {
    Write-Output "missing $rel"
    exit 1
}

Get-Content -LiteralPath $full -Raw -Encoding UTF8
exit 0
