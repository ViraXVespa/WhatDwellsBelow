# Capped text search. Writes a short hit list instead of dumping ripgrep into chat.
# Usage (from repo root):
#   powershell -File tools/list_xref.ps1 -Pattern "pc-offload"
#   powershell -File tools/list_xref.ps1 -Pattern "pc-offload" -Path design -Path tools
#   powershell -File tools/list_xref.ps1 -Pattern "preload" -Path scripts -Include *.gd
# Writes _logs/xref/summary.txt - agents should read that, not paste full search output.

param(
    [Parameter(Mandatory = $true)]
    [string]$Pattern,
    [string[]]$Path = @("scripts", "scenes", "tools", "design"),
    [string]$Include = "*",
    [int]$MaxHits = 30,
    [int]$MaxFiles = 20,
    [switch]$Regex
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "agent_log.ps1")
$OutDir = Ensure-WdbAgentLogDir -Job "xref" -Root $Root
$Summary = Join-Path $OutDir "summary.txt"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function RelPath([string]$full) {
    $r = $Root.TrimEnd('\')
    if ($full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($r.Length).TrimStart('\', '/').Replace('\', '/')
    }
    return $full.Replace('\', '/')
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

$Path = SplitList $Path

$scanRoots = New-Object System.Collections.Generic.List[string]
foreach ($p in $Path) {
    $full = if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $Root $p }
    if (Test-Path -LiteralPath $full) {
        [void]$scanRoots.Add((Resolve-Path -LiteralPath $full).Path)
    }
}

$hitLines = New-Object System.Collections.Generic.List[string]
$filesHit = New-Object "System.Collections.Generic.HashSet[string]" ([StringComparer]::OrdinalIgnoreCase)
$truncated = $false
$scanned = 0
$useFilter = ($Include -ne "*")

foreach ($scanRoot in $scanRoots) {
    if ($useFilter) {
        $files = @(Get-ChildItem -Path $scanRoot -Recurse -File -Filter $Include -ErrorAction SilentlyContinue)
    } else {
        $files = @(Get-ChildItem -Path $scanRoot -Recurse -File -ErrorAction SilentlyContinue)
    }
    $files = @($files | Where-Object {
        $_.FullName -notmatch '\\archives\\|\\.archive_worktrees\\|\\_logs\\|\\docs\\'
    })
    foreach ($f in $files) {
        $scanned += 1
        if ($filesHit.Count -ge $MaxFiles -or $hitLines.Count -ge $MaxHits) {
            $truncated = $true
            break
        }
        $matches = @(Select-String -LiteralPath $f.FullName -Pattern $Pattern -SimpleMatch:(-not $Regex) -ErrorAction SilentlyContinue)
        if ($matches.Count -lt 1) { continue }
        $rel = RelPath $f.FullName
        [void]$filesHit.Add($rel)
        foreach ($m in $matches) {
            if ($hitLines.Count -ge $MaxHits) {
                $truncated = $true
                break
            }
            $text = $m.Line.Trim()
            if ($text.Length -gt 160) {
                $text = $text.Substring(0, 160) + "..."
            }
            [void]$hitLines.Add(("{0}:{1}:{2}" -f $rel, $m.LineNumber, $text))
        }
    }
    if ($truncated) { break }
}

$pathNote = ($Path | ForEach-Object { $_.Replace('\', '/') }) -join ","
$mode = if ($Regex) { "regex" } else { "simple" }
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("xref inventory $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("pattern=$Pattern mode=$mode include=$Include path=$pathNote")
$lines.Add("maxHits=$MaxHits maxFiles=$MaxFiles scanned=$scanned files=$($filesHit.Count) hits=$($hitLines.Count) truncated=$truncated")
$lines.Add("measure=Select-String; agents read this summary only")
$lines.Add("")
foreach ($h in $hitLines) {
    $lines.Add($h)
}
$lines.Add("")
$lines.Add(("RESULT files={0} hits={1} scanned={2} truncated={3}" -f $filesHit.Count, $hitLines.Count, $scanned, $truncated))
$lines | Set-Content -Path $Summary -Encoding utf8

Write-Host "xref files=$($filesHit.Count) hits=$($hitLines.Count) scanned=$scanned truncated=$truncated"
Write-Host "Summary -> $Summary"
exit 0