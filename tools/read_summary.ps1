[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Job = "",
    [string]$Path = "",
    [string]$Root = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "agent_log.ps1")

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
    "grok-sessions-pack"   = "_logs/sess/<session>/grok-sessions-pack/summary.txt"
    "grok-sessions-report" = "_logs/sess/<session>/grok-sessions-report/summary.txt"
    "smokes"               = "_logs/smokes/summary.txt"
    "load-timing"          = "_logs/load-timing/summary.txt"
    "dungeon-load-timing"  = "_logs/dungeon-load-timing/summary.txt"
    "dungeon-map"          = "_logs/dungeon-map/summary.txt"
    "hostify-lint"         = "_logs/hostify-lint/summary.txt"
    "post-split-gate"      = "_logs/post-split-gate/summary.txt"
    "build-gate"           = "_logs/build-gate/summary.txt"
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

function Resolve-JobSummary {
    param(
        [string]$Name,
        [string]$Repo
    )
    $sessionPath = $null
    try {
        $sessionPath = Get-WdbAgentSummaryPath -Job $Name -Root $Repo
    } catch {
        $sessionPath = $null
    }
    if ($sessionPath -and (Test-Path -LiteralPath $sessionPath -PathType Leaf)) {
        return $sessionPath
    }
    if ($JobMap.ContainsKey($Name)) {
        $rel = $JobMap[$Name]
    } else {
        $rel = Join-Path "_logs" (Join-Path $Name "summary.txt")
    }
    if ([System.IO.Path]::IsPathRooted($rel)) {
        return $rel
    }
    return Join-Path $Repo $rel
}

$repoRoot = Get-RepoRoot -Hint $Root

if (-not $Job -and -not $Path) {
    $names = ($JobMap.Keys | Sort-Object) -join ", "
    Write-Output "usage: powershell -File tools/read_summary.ps1 -Job <name>"
    Write-Output "jobs: $names"
    exit 2
}

if ($Path) {
    $full = $Path
    if (-not [System.IO.Path]::IsPathRooted($full)) {
        $full = Join-Path $repoRoot $Path
    }
    $rel = $Path
} else {
    $full = Resolve-JobSummary -Name $Job -Repo $repoRoot
    $rel = $full
    if ($full.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $full.Substring($repoRoot.Length).TrimStart("\", "/").Replace("\", "/")
    }
}

if (-not (Test-Path -LiteralPath $full)) {
    Write-Output "missing $rel"
    exit 1
}

Get-Content -LiteralPath $full -Raw -Encoding UTF8
exit 0
