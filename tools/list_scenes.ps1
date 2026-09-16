# List .tscn nodes and attached scripts without dumping scene files into chat.
# Usage (from repo root):
#   powershell -File tools/list_scenes.ps1
#   powershell -File tools/list_scenes.ps1 -Path scenes/dungeon.tscn
# Writes _logs/scenes/summary.txt - agents should read that, not open whole .tscn files.

param(
    [string[]]$Path = @("scenes"),
    [int]$MaxNodes = 200
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "_logs\scenes"
$Summary = Join-Path $OutDir "summary.txt"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function RelPath([string]$full) {
    $r = $Root.TrimEnd('\')
    if ($full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($r.Length).TrimStart('\', '/').Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

$sceneFiles = New-Object System.Collections.Generic.List[string]
foreach ($p in $Path) {
    $full = if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $Root $p }
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $item = Get-Item -LiteralPath $full
    if ($item.PSIsContainer) {
        Get-ChildItem -Path $item.FullName -Recurse -File -Filter *.tscn |
            Where-Object { $_.FullName -notmatch '\\archives\\|\\.archive_worktrees\\' } |
            ForEach-Object { [void]$sceneFiles.Add($_.FullName) }
    } elseif ($item.Extension -ieq ".tscn") {
        [void]$sceneFiles.Add($item.FullName)
    }
}

$extRe = [regex]'^\[ext_resource[^\]]*\bpath="([^"]+)"[^\]]*\bid="([^"]+)"'
$nodeRe = [regex]'^\[node\s+name="([^"]+)"(?:\s+type="([^"]*)")?(?:\s+parent="([^"]*)")?'
$scriptRe = [regex]'^script\s*=\s*ExtResource\("([^"]+)"\)'

$lines = New-Object System.Collections.Generic.List[string]
$nodeCount = 0
$scriptCount = 0
$truncated = $false

$pathNote = ($Path | ForEach-Object { $_.Replace('\', '/') }) -join ","
$lines.Add("scene inventory $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("path=$pathNote scenes=$($sceneFiles.Count) maxNodes=$MaxNodes")
$lines.Add("measure=parse .tscn headers; do not open scene bodies in chat")
$lines.Add("")

foreach ($scene in ($sceneFiles | Sort-Object)) {
    if ($nodeCount -ge $MaxNodes) {
        $truncated = $true
        break
    }
    $rel = RelPath $scene
    $bytes = [int](Get-Item -LiteralPath $scene).Length
    $lines.Add("SCENE $rel bytes=$bytes")
    $res = @{}
    foreach ($raw in [IO.File]::ReadLines($scene)) {
        $ext = $extRe.Match($raw)
        if ($ext.Success) {
            $res[$ext.Groups[2].Value] = $ext.Groups[1].Value
            continue
        }
        $node = $nodeRe.Match($raw)
        if ($node.Success) {
            if ($nodeCount -ge $MaxNodes) {
                $truncated = $true
                break
            }
            $nodeCount += 1
            $name = $node.Groups[1].Value
            $type = $node.Groups[2].Value
            if (-not $type) { $type = "?" }
            $parent = $node.Groups[3].Value
            if (-not $parent) { $parent = "." }
            $lines.Add(("NODE {0} type={1} parent={2}" -f $name, $type, $parent))
            continue
        }
        $sc = $scriptRe.Match($raw)
        if ($sc.Success) {
            $scriptCount += 1
            $sid = $sc.Groups[1].Value
            $spath = $sid
            if ($res.ContainsKey($sid)) { $spath = $res[$sid] }
            $lines.Add(("SCRIPT {0}" -f $spath))
        }
    }
    $lines.Add("")
}

$lines.Add(("RESULT scenes={0} nodes={1} scripts={2} truncated={3}" -f $sceneFiles.Count, $nodeCount, $scriptCount, $truncated))
$lines | Set-Content -Path $Summary -Encoding utf8

Write-Host "scenes=$($sceneFiles.Count) nodes=$nodeCount scripts=$scriptCount truncated=$truncated"
Write-Host "Summary -> $Summary"
exit 0