# Slice boot for Grok Build. From repo root, inside a Grok session:
#   powershell -File tools/start_build_slice.ps1 -Door dungeon
#   powershell -File tools/start_build_slice.ps1 -Job ui.pause
#   powershell -File tools/start_build_slice.ps1 -Area player
#   powershell -File tools/start_build_slice.ps1 -Door dungeon -WhatIf
#
# Resolves one routes.yaml door/job, writes a session postcard, and prints
# the one grok argv that forks that gather pin into a clean-main worktree.
# Does not run week_start. Does not edit the live tree. Does not kill Godot.
# Does not spawn grok unless -Launch is passed.

param(
    [string]$Door = "",
    [string]$Job = "",
    [string]$Area = "",
    [string]$Root = "",
    [string]$Ref = "main",
    [switch]$Launch,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot([string]$hint) {
    if ($hint) {
        $cand = (Resolve-Path -LiteralPath $hint).Path
        if (Test-Path -LiteralPath (Join-Path $cand "project.godot")) {
            return $cand
        }
    }
    $here = Split-Path -Parent $PSScriptRoot
    if (Test-Path -LiteralPath (Join-Path $here "project.godot")) {
        return $here
    }
    throw "start_build_slice: repo root not found (no project.godot)"
}

function Get-AreaSlug([string]$door, [string]$job, [string]$area) {
    $raw = $area
    if (-not $raw) { $raw = $job }
    if (-not $raw) { $raw = $door }
    $raw = $raw.Trim()
    if (-not $raw) {
        throw "start_build_slice: pass -Door, -Job, or -Area"
    }
    $slug = ($raw.ToLower() -replace "[^a-z0-9._-]+", "-").Trim("-")
    if (-not $slug) {
        throw "start_build_slice: area slug is empty after sanitize"
    }
    if ($slug.Length -gt 48) {
        $slug = $slug.Substring(0, 48).Trim("-")
    }
    return $slug
}

function Find-GrokExe {
    $cmd = Get-Command grok -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }
    return ""
}

$repo = Get-RepoRoot $Root
. (Join-Path $repo "tools\agent_log.ps1")

$door = $Door.Trim()
$job = $Job.Trim()
$area = $Area.Trim()
$slug = Get-AreaSlug $door $job $area
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$wtName = "wdb-$slug-$stamp"

$session = ""
$sessionNote = ""
try {
    $session = Get-WdbAgentSession -Root $repo
} catch {
    $sessionNote = $_.Exception.Message
}
if (-not $session) {
    $envSess = [string]$env:GROK_SESSION_ID
    if ($envSess -and $envSess -match "^[A-Za-z0-9._-]{1,128}$") {
        $session = $envSess.Trim()
        $sessionNote = "from GROK_SESSION_ID"
    }
}

$sessionReady = [bool]$session
if ($sessionReady) {
    $OutDir = Ensure-WdbAgentLogDir -Job "slice-boot" -Root $repo
} else {
    $OutDir = Join-Path $repo "_logs\slice-boot"
}
$Summary = Join-Path $OutDir "summary.txt"

$routeLines = New-Object System.Collections.Generic.List[string]
$routeStatus = "skipped"
if ($door -or $job) {
    $routeScript = Join-Path $repo "tools\list_route.ps1"
    if ($WhatIf) {
        $routeStatus = "whatif"
        [void]$routeLines.Add("list_route whatif door=$door job=$job")
    } else {
        try {
            $argSplat = @{ Root = $repo }
            if ($door) { $argSplat["Door"] = $door }
            if ($job) { $argSplat["Job"] = $job }
            $routeOut = & $routeScript @argSplat 2>&1
            $code = $LASTEXITCODE
            if ($null -eq $code) { $code = 0 }
            $routeStatus = if ($code -eq 0) { "ok" } else { "exit=$code" }
            foreach ($line in @($routeOut)) {
                [void]$routeLines.Add([string]$line)
            }
        } catch {
            $routeStatus = "error"
            [void]$routeLines.Add(("list_route error: {0}" -f $_.Exception.Message))
        }
    }
}

$resume = if ($session) { $session } else { "<gather-session-id>" }
$forkCmd = "grok --worktree=$wtName --ref $Ref -r $resume --fork-session"
$retryCmd = "grok -r $resume --fork-session"

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("slice-boot $(Get-Date -Format o)")
[void]$lines.Add("root=$repo")
[void]$lines.Add("door=$door job=$job area=$area slug=$slug")
[void]$lines.Add("ref=$Ref worktree=$wtName")
[void]$lines.Add("session=$resume")
if ($sessionNote) { [void]$lines.Add("session_note=$sessionNote") }
[void]$lines.Add("session_ready=$sessionReady")
[void]$lines.Add("route=$routeStatus")
[void]$lines.Add("whatif=$WhatIf launch=$Launch")
[void]$lines.Add("gather=list_route + list_xref + show_func + summarize_scripts + one list_code_map_row")
[void]$lines.Add("change=worktree only; do not edit live checkout")
[void]$lines.Add("prove=one run_build_gate or one listed smoke set")
[void]$lines.Add("return=you launch the fork argv; CLI does not auto-resume this pin")
[void]$lines.Add("")
[void]$lines.Add("FORK $forkCmd")
[void]$lines.Add("RETRY $retryCmd")
[void]$lines.Add("")
if ($routeLines.Count -gt 0) {
    [void]$lines.Add("--- route ---")
    foreach ($rl in $routeLines) {
        [void]$lines.Add($rl)
    }
    [void]$lines.Add("")
}
[void]$lines.Add(("RESULT worktree={0} session_ready={1} route={2}" -f $wtName, $sessionReady, $routeStatus))

$launchStatus = "skipped"
if ($Launch -and -not $WhatIf) {
    $grok = Find-GrokExe
    if (-not $sessionReady) {
        $launchStatus = "blocked-no-session"
    } elseif (-not $grok) {
        $launchStatus = "blocked-no-grok"
    } else {
        try {
            $gArgs = @(
                "--worktree=$wtName",
                "--ref", $Ref,
                "-r", $session,
                "--fork-session"
            )
            Start-Process -FilePath $grok -ArgumentList $gArgs -WorkingDirectory $repo | Out-Null
            $launchStatus = "started"
        } catch {
            $launchStatus = "error"
            Write-Host ("launch error: {0}" -f $_.Exception.Message)
        }
    }
}
[void]$lines.Add("launch=$launchStatus")

if (-not $WhatIf) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $lines | Set-Content -Path $Summary -Encoding utf8
}

Write-Host ("worktree={0}" -f $wtName)
Write-Host ("session={0}" -f $resume)
Write-Host ("FORK {0}" -f $forkCmd)
Write-Host ("RETRY {0}" -f $retryCmd)
Write-Host ("launch={0}" -f $launchStatus)
Write-Host ("Summary -> {0}" -f $Summary)

if (-not $sessionReady) { exit 2 }
if ($routeStatus -eq "error") { exit 1 }
exit 0