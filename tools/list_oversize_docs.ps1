# List design/*.md by filesystem Length. Agents read _logs/oversize-docs/summary.txt only.
# Usage (from repo root):
#   powershell -File tools/list_oversize_docs.ps1
#   powershell -File tools/list_oversize_docs.ps1 -OverKb 8

param([double]$OverKb = 8)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "_logs\oversize-docs"
$Summary = Join-Path $OutDir "summary.txt"
$Limit = [int]([math]::Round($OverKb * 1000))
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$files = Get-ChildItem -Path (Join-Path $Root "design") -File -Filter *.md |
    Where-Object { $_.FullName -notlike "*\changelog\*" } |
    Sort-Object Length -Descending
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("oversize docs $(Get-Date -Format o)")
$lines.Add("root=$Root over_kb=$OverKb limit_bytes=$Limit")
$lines.Add("")
$over = 0
foreach ($f in $files) {
    $rel = $f.FullName.Substring($Root.TrimEnd('\').Length).TrimStart('\')
    if ($f.Length -ge $Limit) {
        $lines.Add("OVER $rel bytes=$($f.Length)")
        $over += 1
    } else {
        $lines.Add("$rel bytes=$($f.Length)")
    }
}
$lines.Add("")
$lines.Add(("RESULT over={0} files={1}" -f $over, $files.Count))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host "Summary -> $Summary"
Write-Host ("over={0} files={1}" -f $over, $files.Count)
exit 0
