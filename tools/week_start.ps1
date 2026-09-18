# Local week start. From repo root:
#   powershell -File tools/week_start.ps1
#   powershell -File tools/week_start.ps1 -WhatIf
#
# Pins HEAD as grok_web_w{current series} (previous week's Web results),
# seeds epoch.{series+1}.0 + open_commit, archives prior changelogs,
# then worktree gc / Godot locks / clean -NewWeek.
# Does not pin grok_build_w* (that is the 0.N.0 completion commit).
# Does not bump epoch. Does not kill Godot. Does not write leave-off.

param(
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$OutDir = Join-Path $Root "_logs\week-start"
$Summary = Join-Path $OutDir "summary.txt"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

. (Join-Path $PSScriptRoot "godot_lock.ps1")

$lines = New-Object System.Collections.Generic.List[string]
function Add-Line([string]$s) { $lines.Add($s); Write-Host $s }

Add-Line "week start $(Get-Date -Format o)"
Add-Line "root=$Root"
Add-Line "whatIf=$WhatIf"
Add-Line ""

$verPath = Join-Path $Root "scripts\data\version.json"
$catPath = Join-Path $Root "scripts\data\archive_catalog.json"
if (-not (Test-Path -LiteralPath $verPath)) { throw "missing $verPath" }
if (-not (Test-Path -LiteralPath $catPath)) { throw "missing $catPath" }

$ver = Get-Content -LiteralPath $verPath -Raw -Encoding UTF8 | ConvertFrom-Json
$epoch = [int]$ver.epoch
$series = [int]$ver.series
$patch = [int]$ver.patch
$oldLabel = [string]$ver.label
$sha = (git rev-parse HEAD).Trim()
$pinId = "grok_web_w$series"
$pinLabel = "Grok Web Results (Week $series)"
$tagName = "archive/grok-web-w$series"

Add-Line "version=$oldLabel epoch=$epoch series=$series patch=$patch"
Add-Line "head=$sha"
Add-Line "pin=$pinId (previous week Web results)"

$cat = Get-Content -LiteralPath $catPath -Raw -Encoding UTF8 | ConvertFrom-Json
$builds = @()
if ($null -eq $cat) { $builds = @() }
elseif ($cat -is [System.Array]) { $builds = @($cat) }
elseif (@($cat.PSObject.Properties.Name) -contains "builds") { $builds = @($cat.builds) }
$existing = @($builds | Where-Object { $_.id -eq $pinId })
$pinStatus = "exists"
$copied = 0
$docCount = 0
if ($existing.Count -eq 0) {
    $pinStatus = "added"
    $docDir = Join-Path $Root "archives\docs\$pinId"
    $changeSrc = Join-Path $Root "design\changelog"
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Force -Path $docDir | Out-Null
        if (Test-Path -LiteralPath $changeSrc) {
            Get-ChildItem -LiteralPath $changeSrc -File -Filter "$epoch.$series.*.md" | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $docDir $_.Name) -Force
                $copied += 1
            }
        }
    }
    $docs = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -LiteralPath (Join-Path $Root "design") -File -Recurse |
        Where-Object { $_.Extension -match '^\.(md|yaml|yml)$' } |
        ForEach-Object {
            $rel = $_.FullName.Substring($Root.Length).TrimStart("\", "/").Replace("\", "/")
            $docs.Add($rel)
        }
    $docCount = $docs.Count
    $row = [ordered]@{
        id         = $pinId
        label      = $pinLabel
        desc       = "Live path at the end of Grok Web week $series ($oldLabel)."
        commit     = $sha
        pages_slug = "archives/$pinId"
        video      = ""
        docs       = @($docs)
    }
    if (-not $WhatIf) {
        $desc = "Live path at the end of Grok Web week $series ($oldLabel)."
        python (Join-Path $Root "tools\week_pin.py") --root $Root --id $pinId --label $pinLabel --desc $desc --commit $sha
        if ($LASTEXITCODE -ne 0) { throw "week_pin.py failed" }
        $tagExists = (git tag --list $tagName)
        if (-not $tagExists) {
            git tag $tagName $sha
            Add-Line "tag=$tagName"
        } else {
            Add-Line "tag=exists $tagName"
        }
    }
    Add-Line "catalog=$pinStatus changelog_copied=$copied docs=$docCount"
} else {
    Add-Line "catalog=exists $($existing[0].commit)"
}

$newSeries = $series + 1
$newLabel = "{0}.{1}.0" -f $epoch, $newSeries
$seedStatus = "skipped"
if ($patch -eq 0 -and [string]$ver.label -eq $newLabel) {
    Add-Line "seed=already $newLabel"
} else {
    $seedStatus = "wrote"
    Add-Line "seed=$newLabel open_commit=$sha"
    if (-not $WhatIf) {
        $verOut = [ordered]@{
            epoch       = $epoch
            series      = $newSeries
            patch       = 0
            label       = $newLabel
            open_commit = $sha
        }
        $verJson = $verOut | ConvertTo-Json-DISABLED
        [IO.File]::WriteAllText($verPath, $verJson + "`n")
    }
}

$archStatus = "skipped"
$arch = Join-Path $Root "tools\archive_prior_changelogs.py"
if (Test-Path -LiteralPath $arch) {
    if ($WhatIf) {
        $archStatus = "whatif"
        python $arch --dry-run | Out-Host
    } else {
        python $arch
        if ($LASTEXITCODE -eq 0) { $archStatus = "ok" } else { $archStatus = "exit=$LASTEXITCODE" }
    }
    Add-Line "archive_changelogs=$archStatus"
}

$gcStatus = "skipped"
$grok = Get-Command grok -ErrorAction SilentlyContinue
if ($grok) {
    Add-Line "grok=found path=$($grok.Source)"
    if ($WhatIf) {
        $gcStatus = "whatif"
    } else {
        try {
            $gcOut = & grok worktree gc 2>&1 | Out-String
            $gcStatus = "ok"
            foreach ($ln in ($gcOut -split "`r?`n")) {
                if ($ln.Trim()) { $lines.Add("gc: $($ln.Trim())") }
            }
        } catch {
            $gcStatus = "error"
            Add-Line ("gc=error {0}" -f $_.Exception.Message)
        }
    }
    Add-Line "gc=$gcStatus"
} else {
    Add-Line "grok=missing (no worktree gc)"
}

$lockRoot = Join-Path $Root "_logs\godot-lock"
$lockDeleted = 0
if (Test-Path -LiteralPath $lockRoot) {
    Get-ChildItem -LiteralPath $lockRoot -File -Filter *.lock -ErrorAction SilentlyContinue | ForEach-Object {
        Add-Line ("lock-del {0}" -f $_.Name)
        if (-not $WhatIf) { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        $lockDeleted += 1
    }
} else {
    Add-Line "locks=none"
}

$cleanStatus = "skipped"
$cleanScript = Join-Path $Root "tools\clean_agent_logs.ps1"
if (Test-Path -LiteralPath $cleanScript) {
    if ($WhatIf) {
        $cleanStatus = "whatif"
    } else {
        & powershell -NoProfile -File $cleanScript -NewWeek
        if ($LASTEXITCODE -eq 0) { $cleanStatus = "ok" } else { $cleanStatus = "exit=$LASTEXITCODE" }
    }
    Add-Line "clean=$cleanStatus"
}

$lines.Add("")
$lines.Add(("RESULT pin={0} seed={1} archive={2} gc={3} locks_deleted={4} clean={5}" -f $pinStatus, $seedStatus, $archStatus, $gcStatus, $lockDeleted, $cleanStatus))
$lines | Set-Content -LiteralPath $Summary -Encoding utf8
Write-Host ""
Write-Host "Summary -> $Summary"
exit 0