# List git-changed paths with on-disk Length (not ReadAllText).
# Usage (from repo root):
#   powershell -File tools/list_changed.ps1
#   powershell -File tools/list_changed.ps1 -Scope scripts,tools
# Writes _logs/changed/summary.txt - agents should read that, not paste git diffs.

param(
    [string[]]$Scope = @(
        "scripts",
        "scenes",
        "tools",
        "design",
        ".grok/skills",
        ".cursor/skills"
    ),
    [switch]$Head,
    [int]$LogCount = 10
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "agent_log.ps1")
$OutDir = Ensure-WdbAgentLogDir -Job "changed" -Root $Root
$Summary = Join-Path $OutDir "summary.txt"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function RelPath([string]$full) {
    $r = $Root.TrimEnd('\')
    if ($full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($r.Length).TrimStart('\', '/').Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

function NormalizeGitPath([string]$raw) {
    $n = $raw.Trim()
    if ($n.StartsWith('"') -and $n.EndsWith('"') -and $n.Length -ge 2) {
        $n = $n.Substring(1, $n.Length - 2)
    }
    return $n.Replace('\', '/')
}

function SplitList([string[]]$values) {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($v in $values) {
        foreach ($part in @($v -split "[,\s]+")) {
            if ($part) { [void]$out.Add($part) }
        }
    }
    return @($out)
}

function InScope([string]$rel, [string[]]$scopes) {
    $posix = $rel.Replace('\', '/').TrimStart('/')
    foreach ($s in $scopes) {
        $prefix = $s.Replace('\', '/').TrimStart('/').TrimEnd('/')
        if ($posix -eq $prefix -or $posix.StartsWith($prefix + '/', [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

$Scope = SplitList $Scope
$scopeNote = ($Scope | ForEach-Object { $_.Replace('\', '/') }) -join ","
Push-Location $Root
try {
    $porcelain = @(git status --porcelain --untracked-files=all 2>$null)
} finally {
    Pop-Location
}

$rows = New-Object System.Collections.Generic.List[object]
$seen = New-Object "System.Collections.Generic.HashSet[string]" ([StringComparer]::OrdinalIgnoreCase)

foreach ($line in $porcelain) {
    if (-not $line) { continue }
    if ($line.Length -lt 4) { continue }
    $code = $line.Substring(0, 2)
    $rest = $line.Substring(3)
    $pathPart = $rest
    if ($rest -like "* -> *") {
        $pathPart = ($rest -split " -> ")[-1]
    }
    $rel = NormalizeGitPath $pathPart
    if (-not (InScope $rel $Scope)) { continue }
    if (-not $seen.Add($rel)) { continue }

    $full = Join-Path $Root ($rel.Replace('/', '\'))
    $exists = Test-Path -LiteralPath $full
    $bytes = 0
    if ($exists) {
        $item = Get-Item -LiteralPath $full
        if ($item.PSIsContainer) { continue }
        $bytes = [int]$item.Length
    }

    $state = $code.Trim()
    if (-not $exists) { $state = "D" }

    [void]$rows.Add([pscustomobject]@{
        Bytes = $bytes
        Kb    = [math]::Round($bytes / 1000.0, 2)
        State = $state
        Rel   = $rel
    })
}

$sorted = @(
    $rows | Sort-Object -Property @(
        @{ Expression = "Bytes"; Descending = $true },
        @{ Expression = "Rel"; Descending = $false }
    )
)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("changed inventory $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("scope=$scopeNote count=$($sorted.Count)")
$lines.Add("measure=git status --porcelain + filesystem Length")
$lines.Add("")
$lines.Add("state`tbytes`tKB`tpath")
foreach ($r in $sorted) {
    $lines.Add(("{0}`t{1}`t{2}`t{3}" -f $r.State, $r.Bytes, $r.Kb, $r.Rel))
}
$lines.Add("")
$lines.Add(("RESULT count={0}" -f $sorted.Count))
if ($Head) {
    Push-Location $Root
    try {
        $headSha = (git rev-parse HEAD 2>$null)
        $logLines = @(git log -n $LogCount --oneline 2>$null)
    } finally {
        Pop-Location
    }
    $lines.Add("")
    $lines.Add(("HEAD={0}" -f $headSha))
    $lines.Add(("logCount={0}" -f $logLines.Count))
    foreach ($lg in $logLines) {
        $lines.Add(("  {0}" -f $lg))
    }
}
$lines | Set-Content -Path $Summary -Encoding utf8

Write-Host "Changed in scope: $($sorted.Count) paths"
$sorted | Select-Object -First 30 | ForEach-Object {
    Write-Host ("{0,3} {1,6}  {2}" -f $_.State, $_.Bytes, $_.Rel)
}
if ($sorted.Count -gt 30) {
    Write-Host ("... +{0} more (see summary)" -f ($sorted.Count - 30))
}
Write-Host ""
Write-Host "Summary -> $Summary"
exit 0