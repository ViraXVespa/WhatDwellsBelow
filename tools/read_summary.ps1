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

$JobNames = @(
    "agent-py",
    "bot-opt",
    "build-gate",
    "changed",
    "changelog-label",
    "clean",
    "code-map-check",
    "code-map-patch",
    "code-map-row",
    "dungeon-load-timing",
    "dungeon-map",
    "facade-cluster",
    "godot-import-check",
    "grok-sessions-pack",
    "grok-sessions-report",
    "hostify-lint",
    "load-timing",
    "oversize",
    "oversize-docs",
    "post-split-gate",
    "route",
    "scenes",
    "script-cap",
    "script-summary",
    "show-func",
    "skill-sync",
    "slice-boot",
    "smokes",
    "xref"
)

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
    try {
        return Get-WdbAgentSummaryPath -Job $Name -Root $Repo
    } catch {
        throw ("read_summary: no session path for job '{0}': {1}" -f $Name, $_.Exception.Message)
    }
}

$repoRoot = Get-RepoRoot -Hint $Root

if (-not $Job -and -not $Path) {
    $names = ($JobNames | Sort-Object) -join ", "
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
    try {
        $full = Resolve-JobSummary -Name $Job -Repo $repoRoot
    } catch {
        Write-Output $_.Exception.Message
        exit 2
    }
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
