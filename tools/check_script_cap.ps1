# Fail if live scripts exceed the size cap (filesystem Length).
# Usage (from repo root):
#   powershell -File tools/check_script_cap.ps1
#   powershell -File tools/check_script_cap.ps1 -OverKb 10
#   powershell -File tools/check_script_cap.ps1 -OverKb 10 -GitChanged
#   powershell -File tools/check_script_cap.ps1 -Path scripts/app.gd,scripts/ui/hud.gd
# Writes _logs/script-cap/summary.txt - agents read that file only.
# Default OverKb=10 (Grok Build ship floor). Use -OverKb 5 for Bot sweep target.

param(
    [double]$OverKb = 10,
    [switch]$GitChanged,
    [string[]]$Path = @()
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "_logs\script-cap"
$Summary = Join-Path $OutDir "summary.txt"
$Limit = [int]([math]::Round($OverKb * 1000))
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function RelPath([string]$full) {
    $r = $Root.TrimEnd('\')
    if ($full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($r.Length).TrimStart('\')
    }
    return $full
}

$files = New-Object System.Collections.Generic.List[string]
if ($Path.Count -gt 0) {
    foreach ($p in $Path) {
        $full = if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $Root $p }
        if (Test-Path $full) { [void]$files.Add((Resolve-Path $full).Path) }
    }
} elseif ($GitChanged) {
    Push-Location $Root
    try {
        $porcelain = @(git status --porcelain -- scripts 2>$null)
        foreach ($line in $porcelain) {
            if (-not $line) { continue }
            $n = $line.Substring(3).Trim()
            if ($n -like "* -> *") { $n = ($n -split " -> ")[-1].Trim() }
            if ($n -like "*.gd") {
                $full = Join-Path $Root $n
                if (Test-Path $full) { [void]$files.Add($full) }
            }
        }
        $uniq = $files | Select-Object -Unique
        $files = New-Object System.Collections.Generic.List[string]
        foreach ($u in $uniq) { [void]$files.Add($u) }
    } finally { Pop-Location }
} else {
    Get-ChildItem -Path (Join-Path $Root "scripts") -Recurse -File -Filter *.gd |
        Where-Object { $_.FullName -notlike "*\archives\*" -and $_.FullName -notlike "*\.archive_worktrees\*" } |
        ForEach-Object { [void]$files.Add($_.FullName) }
}

$over = New-Object System.Collections.Generic.List[string]
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("script cap $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("limit_bytes=$Limit over_kb=$OverKb gitChanged=$GitChanged files_checked=$($files.Count)")
$lines.Add("")

foreach ($f in ($files | Sort-Object)) {
    $len = [int](Get-Item $f).Length
    $rel = RelPath $f
    if ($len -ge $Limit) {
        $over.Add("$rel bytes=$len")
        $lines.Add("OVER $rel bytes=$len")
    }
}

$lines.Add("")
$lines.Add(("RESULT over={0} checked={1}" -f $over.Count, $files.Count))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host "Summary -> $Summary"
Write-Host ("over={0} checked={1} limit={2}" -f $over.Count, $files.Count, $Limit)
if ($over.Count -gt 0) { exit 1 }
exit 0
