# Export the GitHub Pages build (Godot Web, no threads).
# Usage: from repo root,
#   powershell -File tools/export_web.ps1
#   powershell -File tools/export_web.ps1 -Archives
# Live-only writes docs/. -Archives writes a combined site to _pages/ (gitignored).

param(
    [switch]$Archives
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$CatalogPath = Join-Path $Root "scripts\data\archive_catalog.json"
$OutDir = if ($Archives) { Join-Path $Root "_pages" } else { Join-Path $Root "docs" }
$OutHtml = Join-Path $OutDir "index.html"

if (-not (Test-Path $Godot)) {
    throw "Steam Godot not found at: $Godot"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Steam Godot is a GUI-subsystem exe; PowerShell "&" does not wait for it.
function Invoke-Godot([string[]]$GodotArgs, [string]$LogName) {
    $log = Join-Path $Root $LogName
    $err = Join-Path $Root ($LogName + ".err")
    if (Test-Path $log) { Remove-Item $log }
    if (Test-Path $err) { Remove-Item $err }
    $p = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $err
    if (Test-Path $log) { Get-Content $log | Write-Host }
    if (Test-Path $err) { Get-Content $err | Write-Host }
    if ($p.ExitCode -ne 0) {
        throw "Godot failed (exit $($p.ExitCode)): $($GodotArgs -join ' ')"
    }
    Remove-Item $log, $err -ErrorAction SilentlyContinue
}

function Stamp-ArchiveName([string]$ProjectFile, [string]$Label) {
    if (-not (Test-Path $ProjectFile)) { throw "Missing $ProjectFile" }
    $named = "What Dwells Below — $Label"
    $t = Get-Content -Raw -Path $ProjectFile
    $t = [regex]::Replace($t, 'config/name="[^"]*"', "config/name=`"$named`"")
    Set-Content -Path $ProjectFile -Value $t -NoNewline
}

Write-Host "Importing live project..."
Invoke-Godot @("--headless", "--path", $Root, "--import") "godot-import.log"

Write-Host "Exporting live Web (nothreads) -> $OutHtml"
Invoke-Godot @("--headless", "--path", $Root, "--export-release", "Web", $OutHtml) "godot-export.log"

$nojekyll = Join-Path $OutDir ".nojekyll"
if (-not (Test-Path $nojekyll)) {
    New-Item -ItemType File -Path $nojekyll | Out-Null
}

if ($Archives) {
    if (-not (Test-Path $CatalogPath)) {
        throw "Catalog missing: $CatalogPath"
    }
    $cat = Get-Content -Raw -Path $CatalogPath | ConvertFrom-Json
    $wtRoot = Join-Path $Root ".archive_worktrees"
    New-Item -ItemType Directory -Force -Path $wtRoot | Out-Null
    foreach ($e in $cat.archives) {
        $id = [string]$e.id
        $sha = [string]$e.commit
        $label = [string]$e.label
        $slug = [string]$e.pages_slug
        Write-Host "Archive $id @ $sha -> $slug"
        $wt = Join-Path $wtRoot $id
        if (Test-Path $wt) {
            git -C $Root worktree remove --force $wt 2>$null
            if (Test-Path $wt) { Remove-Item -Recurse -Force $wt }
        }
        git -C $Root worktree add --detach $wt $sha
        Stamp-ArchiveName (Join-Path $wt "project.godot") $label
        $destDir = Join-Path $OutDir ($slug -replace "/", [IO.Path]::DirectorySeparatorChar)
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        $destHtml = Join-Path $destDir "index.html"
        Invoke-Godot @("--headless", "--path", $wt, "--import") "godot-arch-$id-import.log"
        Invoke-Godot @("--headless", "--path", $wt, "--export-release", "Web", $destHtml) "godot-arch-$id-export.log"
    }
}

Write-Host "Done. Files:"
Get-ChildItem $OutDir | Select-Object Name, Length | Format-Table -AutoSize
