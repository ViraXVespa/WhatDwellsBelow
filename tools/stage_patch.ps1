[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Diff,
    [string]$Root = "",
    [string]$Id = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "agent_log.ps1")

$script:cur = $null
$script:inHunk = $false
$script:minus = New-Object System.Collections.Generic.List[string]
$script:files = New-Object System.Collections.Generic.List[object]

function Get-RepoRoot {
    param([string]$Hint)
    if ($Hint) { return (Resolve-Path -LiteralPath $Hint).Path }
    if ($PSScriptRoot) { return (Split-Path -Parent $PSScriptRoot) }
    return (Get-Location).Path
}

function Get-WdbRel([string]$path) {
    return $path.Replace("\", "/")
}

function Get-WdbSha256([string]$full) {
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return "" }
    $hash = Get-FileHash -LiteralPath $full -Algorithm SHA256
    return $hash.Hash.ToLowerInvariant()
}

function Flush-WdbHunk {
    if ($null -eq $script:cur) { return }
    if (-not $script:inHunk) { return }
    $old = ($script:minus -join "`n")
    $script:cur.hunks.Add($old)
    $script:minus.Clear()
    $script:inHunk = $false
}

function Flush-WdbFile {
    Flush-WdbHunk
    if ($null -ne $script:cur) {
        $script:files.Add($script:cur)
        $script:cur = $null
    }
}

$repoRoot = Get-RepoRoot -Hint $Root
$session = Get-WdbAgentSession -Root $repoRoot
if (-not $Id) {
    $Id = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
}

$diffFull = $Diff
if (-not [System.IO.Path]::IsPathRooted($diffFull)) {
    $diffFull = Join-Path $repoRoot $Diff
}

$uniqueOk = $true
$note = ""
$entries = @()

try {
    if (-not (Test-Path -LiteralPath $diffFull -PathType Leaf)) {
        throw "diff_missing $Diff"
    }
    $raw = Get-Content -LiteralPath $diffFull -Encoding UTF8
    foreach ($line in $raw) {
        if ($line -like "--- *") {
            Flush-WdbFile
            $rel = $line.Substring(4).Trim()
            if ($rel.StartsWith("a/")) { $rel = $rel.Substring(2) }
            $rel = $rel.Replace("\", "/")
            if ($rel -eq "/dev/null") { continue }
            $script:cur = [pscustomobject]@{ rel = $rel; hunks = New-Object System.Collections.Generic.List[string] }
            continue
        }
        if ($line -like "+++ *") { continue }
        if ($line -like "@@ *") {
            Flush-WdbHunk
            $script:inHunk = $true
            continue
        }
        if ($script:inHunk -and $line.StartsWith("-") -and -not $line.StartsWith("---")) {
            $script:minus.Add($line.Substring(1))
        }
    }
    Flush-WdbFile

    foreach ($file in $script:files) {
        $full = Join-Path $repoRoot ($file.rel.Replace("/", "\"))
        $liveHash = Get-WdbSha256 $full
        $matches = 0
        $exists = Test-Path -LiteralPath $full -PathType Leaf
        if ($exists) {
            $live = Get-Content -LiteralPath $full -Raw -Encoding UTF8
            $live = $live -replace "`r`n", "`n"
            foreach ($hunk in $file.hunks) {
                if (-not $hunk) { continue }
                $needle = $hunk -replace "`r`n", "`n"
                $count = 0
                $idx = 0
                while ($idx -ge 0) {
                    $found = $live.IndexOf($needle, $idx)
                    if ($found -lt 0) { break }
                    $count += 1
                    $idx = $found + [Math]::Max($needle.Length, 1)
                }
                if ($count -ne 1) { $uniqueOk = $false }
                $matches += $count
            }
        } else {
            $uniqueOk = $false
            $matches = 0
        }
        $entries += [pscustomobject]@{
            path      = $file.rel
            live_sha256 = $liveHash
            exists    = $exists
            hunks     = $file.hunks.Count
            matches   = $matches
        }
    }
    if ($script:files.Count -eq 0) {
        $uniqueOk = $false
        $note = "no_files"
    }
}
catch {
    $uniqueOk = $false
    $note = "$_"
}

$scratchRoot = Join-Path $repoRoot (Join-Path "_logs" (Join-Path "patch-scratch" (Join-Path $session $Id)))
New-Item -ItemType Directory -Force -Path $scratchRoot | Out-Null
if (Test-Path -LiteralPath $diffFull -PathType Leaf) {
    Copy-Item -LiteralPath $diffFull -Destination (Join-Path $scratchRoot "patch.diff") -Force
}

$manifest = [ordered]@{
    session   = $session
    id        = $Id
    unique_ok = $uniqueOk
    note      = $note
    files     = @($entries | ForEach-Object {
            [ordered]@{
                path        = $_.path
                live_sha256 = $_.live_sha256
                exists      = $_.exists
                hunks       = $_.hunks
                matches     = $_.matches
            }
        })
}
$manifestJson = $manifest | ConvertTo-Json -Depth 6
Set-Content -Path (Join-Path $scratchRoot "manifest.json") -Value $manifestJson -Encoding utf8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("patch-stage $(Get-Date -Format o)")
$lines.Add("session=$session")
$lines.Add("id=$Id")
$lines.Add("unique_ok=$($uniqueOk.ToString().ToLower())")
$lines.Add("stale=false")
$lines.Add("truncated=false")
$lines.Add("busy=false")
$lines.Add("scratch=_logs/patch-scratch/$session/$Id/")
if ($note) { $lines.Add("note=$note") }
foreach ($e in $entries) {
    $lines.Add(("file path={0} exists={1} hunks={2} matches={3} live_sha256={4}" -f $e.path, $e.exists, $e.hunks, $e.matches, $e.live_sha256))
}
$lines.Add(("RESULT unique_ok={0} files={1}" -f $uniqueOk.ToString().ToLower(), $entries.Count))
Set-Content -Path (Join-Path $scratchRoot "summary.txt") -Value $lines -Encoding utf8

$jobDir = Ensure-WdbAgentLogDir -Job "patch-stage" -Root $repoRoot
Set-Content -Path (Join-Path $jobDir "summary.txt") -Value $lines -Encoding utf8
Write-Host "Summary -> $(Join-Path $jobDir 'summary.txt')"
if (-not $uniqueOk) { exit 2 }
exit 0
