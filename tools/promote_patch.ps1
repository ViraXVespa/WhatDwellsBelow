[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [string]$Root = "",
    [int]$LockSeconds = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "agent_log.ps1")

$script:cur = $null
$script:inHunk = $false
$script:old = New-Object System.Collections.Generic.List[string]
$script:new = New-Object System.Collections.Generic.List[string]
$script:files = New-Object System.Collections.Generic.List[object]

function Get-RepoRoot {
    param([string]$Hint)
    if ($Hint) { return (Resolve-Path -LiteralPath $Hint).Path }
    if ($PSScriptRoot) { return (Split-Path -Parent $PSScriptRoot) }
    return (Get-Location).Path
}

function Get-WdbSha256([string]$full) {
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return "" }
    return (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Flush-WdbHunk {
    if ($null -eq $script:cur) { return }
    if (-not $script:inHunk) { return }
    $script:cur.hunks.Add([pscustomobject]@{
            old = ($script:old -join "`n")
            new = ($script:new -join "`n")
        })
    $script:old.Clear()
    $script:new.Clear()
    $script:inHunk = $false
}

function Flush-WdbFile {
    Flush-WdbHunk
    if ($null -ne $script:cur) {
        $script:files.Add($script:cur)
        $script:cur = $null
    }
}

function Apply-WdbHunks([string]$text, $hunks) {
    $live = $text -replace "`r`n", "`n"
    foreach ($h in $hunks) {
        $needle = $h.old -replace "`r`n", "`n"
        $repl = $h.new -replace "`r`n", "`n"
        $found = $live.IndexOf($needle)
        if ($found -lt 0) { throw "hunk_missing" }
        if ($live.IndexOf($needle, $found + [Math]::Max($needle.Length, 1)) -ge 0) {
            throw "hunk_not_unique"
        }
        $live = $live.Substring(0, $found) + $repl + $live.Substring($found + $needle.Length)
    }
    return $live
}

$repoRoot = Get-RepoRoot -Hint $Root
$session = Get-WdbAgentSession -Root $repoRoot
$stale = $false
$busy = $false
$applied = $false
$note = ""
$lockDir = Join-Path $repoRoot "_logs\patch-lock"
$lockPath = Join-Path $lockDir "apply.lock"
$scratchRoot = Join-Path $repoRoot ("_logs\patch-scratch\{0}\{1}" -f $session, $Id)
$haveLock = $false

if ($LockSeconds -lt 30) { $LockSeconds = 30 }
if ($LockSeconds -gt 60) { $LockSeconds = 60 }

try {
    New-Item -ItemType Directory -Force -Path $lockDir | Out-Null
    if (Test-Path -LiteralPath $lockPath) {
        $existing = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $exp = [datetime]::Parse($existing.expires_utc, $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        if ($exp -gt [datetime]::UtcNow) {
            $busy = $true
            throw "busy"
        }
    }
    $expires = [datetime]::UtcNow.AddSeconds($LockSeconds).ToString("o")
    $lockObj = [ordered]@{ session = $session; id = $Id; expires_utc = $expires }
    Set-Content -Path $lockPath -Value ($lockObj | ConvertTo-Json) -Encoding utf8
    $haveLock = $true

    $manifestPath = Join-Path $scratchRoot "manifest.json"
    $diffPath = Join-Path $scratchRoot "patch.diff"
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw "manifest_missing" }
    if (-not (Test-Path -LiteralPath $diffPath)) { throw "diff_missing" }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $manifest.unique_ok) { throw "unique_ok=false" }

    $raw = Get-Content -LiteralPath $diffPath -Encoding UTF8
    foreach ($line in $raw) {
        if ($line -like "--- *") {
            Flush-WdbFile
            $rel = $line.Substring(4).Trim()
            if ($rel.StartsWith("a/")) { $rel = $rel.Substring(2) }
            $rel = $rel.Replace("\", "/")
            if ($rel -eq "/dev/null") { continue }
            $script:cur = [pscustomobject]@{ rel = $rel; hunks = New-Object System.Collections.Generic.List[object] }
            continue
        }
        if ($line -like "+++ *") { continue }
        if ($line -like "@@ *") {
            Flush-WdbHunk
            $script:inHunk = $true
            continue
        }
        if (-not $script:inHunk) { continue }
        if ($line.StartsWith("-") -and -not $line.StartsWith("---")) {
            $script:old.Add($line.Substring(1))
        } elseif ($line.StartsWith("+") -and -not $line.StartsWith("+++")) {
            $script:new.Add($line.Substring(1))
        } elseif ($line.StartsWith(" ")) {
            $script:old.Add($line.Substring(1))
            $script:new.Add($line.Substring(1))
        }
    }
    Flush-WdbFile

    foreach ($file in $script:files) {
        $full = Join-Path $repoRoot ($file.rel.Replace("/", "\"))
        $liveHash = Get-WdbSha256 $full
        $staged = @($manifest.files | Where-Object { $_.path -eq $file.rel } | Select-Object -First 1)
        if (-not $staged) { throw "manifest_path_missing $($file.rel)" }
        if ($liveHash -ne ([string]$staged.live_sha256)) {
            $stale = $true
        }
    }
    if ($stale) { throw "stale" }

    $pending = @()
    foreach ($file in $script:files) {
        $full = Join-Path $repoRoot ($file.rel.Replace("/", "\"))
        $text = Get-Content -LiteralPath $full -Raw -Encoding UTF8
        $next = Apply-WdbHunks $text $file.hunks
        $pending += [pscustomobject]@{ full = $full; text = $next }
    }
    foreach ($item in $pending) {
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($item.full, $item.text.Replace("`n", "`r`n"), $utf8)
    }
    $applied = $true
}
catch {
    $note = "$_"
    if ($note -eq "stale") { $stale = $true }
    if ($note -eq "busy") { $busy = $true }
}
finally {
    if ($haveLock -and (Test-Path -LiteralPath $lockPath)) {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("patch-promote $(Get-Date -Format o)")
$lines.Add("session=$session")
$lines.Add("id=$Id")
$lines.Add("stale=$($stale.ToString().ToLower())")
$lines.Add("busy=$($busy.ToString().ToLower())")
$lines.Add("applied=$($applied.ToString().ToLower())")
$lines.Add("truncated=false")
if ($note) { $lines.Add("note=$note") }
$lines.Add(("RESULT applied={0} stale={1} busy={2}" -f $applied.ToString().ToLower(), $stale.ToString().ToLower(), $busy.ToString().ToLower()))

$jobDir = Ensure-WdbAgentLogDir -Job "patch-promote" -Root $repoRoot
Set-Content -Path (Join-Path $jobDir "summary.txt") -Value $lines -Encoding utf8
Write-Host "Summary -> $(Join-Path $jobDir 'summary.txt')"
if ($stale -or $busy -or -not $applied) { exit 2 }
exit 0
