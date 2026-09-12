# List a facade + same-folder sibling helpers by Length (no body reads).
# Usage (from repo root):
#   powershell -File tools/list_facade_cluster.ps1 -Facade scripts/combat/enemy.gd
# Writes _logs/facade-cluster/summary.txt

param(
    [Parameter(Mandatory = $true)]
    [string]$Facade
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "_logs\facade-cluster"
$Summary = Join-Path $OutDir "summary.txt"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function RelPath([string]$full) {
    $r = $Root.TrimEnd('\')
    if ($full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($r.Length).TrimStart('\')
    }
    return $full
}

$full = if ([IO.Path]::IsPathRooted($Facade)) { $Facade } else { Join-Path $Root $Facade }
if (-not (Test-Path $full)) { throw "missing facade: $Facade" }
$full = (Resolve-Path $full).Path
$dir = Split-Path -Parent $full
$stem = [IO.Path]::GetFileNameWithoutExtension($full)
$sibs = Get-ChildItem -Path $dir -File -Filter "*.gd" |
    Where-Object {
        $n = $_.BaseName
        ($n -eq $stem) -or ($n.StartsWith($stem + "_"))
    } |
    Sort-Object Length -Descending

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("facade cluster $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("facade=$(RelPath $full)")
$lines.Add("stem=$stem dir=$(RelPath $dir)")
$lines.Add("siblings=$($sibs.Count)")
$lines.Add("")
$total = 0
foreach ($f in $sibs) {
    $lines.Add("$(RelPath $f.FullName) bytes=$($f.Length)")
    $total += [int]$f.Length
}
$lines.Add("")
$lines.Add(("RESULT siblings={0} total_bytes={1}" -f $sibs.Count, $total))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host "Summary -> $Summary"
$sibs | ForEach-Object { Write-Host ("{0,6} {1}" -f $_.Length, $_.Name) }
exit 0
