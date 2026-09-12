# List live oversize GDScript files by on-disk Length (not ReadAllText).
# Usage (from repo root):
#   powershell -File tools/list_oversize_scripts.ps1
#   powershell -File tools/list_oversize_scripts.ps1 -OverKb 5
#   powershell -File tools/list_oversize_scripts.ps1 -OverKb 10 -UnderKb 0
# Writes _logs/oversize/summary.txt - agents should read that, not open every .gd.
# Caps match design/refactor.md / design/grok-bot-session.md (10KB ship floor, 5KB sweep target).

param(
    [int]$OverKb = 5,
    [int]$UnderKb = 0,
    [string]$Glob = "scripts\\**\\*.gd"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "_logs\oversize"
$Summary = Join-Path $OutDir "summary.txt"
$OverBytes = $OverKb * 1000
$UnderBytes = if ($UnderKb -gt 0) { $UnderKb * 1000 } else { [int]::MaxValue }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Prefer -Filter *.gd under scripts; -Recurse. Length is filesystem bytes.
$files = Get-ChildItem -Path (Join-Path $Root "scripts") -Recurse -File -Filter *.gd |
    Where-Object { $_.FullName -notmatch '\\archives\\|\\.archive_worktrees\\' }

$rows = foreach ($f in $files) {
    $len = [int]$f.Length
    if ($len -ge $OverBytes -and $len -lt $UnderBytes) {
        [pscustomobject]@{
            Bytes = $len
            Kb = [math]::Round($len / 1000.0, 2)
            Rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
        }
    }
}

$sorted = @($rows | Sort-Object Bytes -Descending)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("oversize inventory $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("overKb=$OverKb underKb=$(if ($UnderKb -gt 0) { $UnderKb } else { 'none' }) count=$($sorted.Count)")
$lines.Add("measure=filesystem Length (Get-ChildItem .Length)")
$lines.Add("")
$lines.Add("bytes`tkb`tpath")
foreach ($r in $sorted) {
    $lines.Add(("{0}`t{1}`t{2}" -f $r.Bytes, $r.Kb, $r.Rel))
}
$lines.Add("")
$lines.Add(("RESULT count={0}" -f $sorted.Count))
$lines | Set-Content -Path $Summary -Encoding utf8

Write-Host "Over $($OverKb)KB: $($sorted.Count) files"
$sorted | Select-Object -First 30 | ForEach-Object {
    Write-Host ("{0,6}  {1}" -f $_.Bytes, $_.Rel)
}
if ($sorted.Count -gt 30) {
    Write-Host ("... +{0} more (see summary)" -f ($sorted.Count - 30))
}
Write-Host ""
Write-Host "Summary -> $Summary"
exit 0
