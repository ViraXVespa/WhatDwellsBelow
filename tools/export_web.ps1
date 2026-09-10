# Export the GitHub Pages build (Godot Web, no threads).
# Usage: from repo root,
#   powershell -File tools/export_web.ps1
#   powershell -File tools/export_web.ps1 -Archives
# Live-only writes docs/. -Archives writes a combined site to _pages/ (gitignored).
# Archive pins are best-effort and cached under .archive_export_cache/.

param(
    [switch]$Archives
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
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

function Invoke-WebPostexport([string]$Dir) {
    $script = Join-Path $Root "tools\web_postexport.py"
    Write-Host "Stamping Web export -> $Dir"
    python $script $Dir
}

Write-Host "Importing live project..."
Invoke-Godot @("--headless", "--path", $Root, "--import") "godot-import.log"

Write-Host "Exporting live Web (nothreads) -> $OutHtml"
Invoke-Godot @("--headless", "--path", $Root, "--export-release", "Web", $OutHtml) "godot-export.log"
Invoke-WebPostexport $OutDir

$nojekyll = Join-Path $OutDir ".nojekyll"
if (-not (Test-Path $nojekyll)) {
    New-Item -ItemType File -Path $nojekyll | Out-Null
}

if ($Archives) {
    $exporter = Join-Path $Root "tools\export_archives.py"
    if (-not (Test-Path $exporter)) {
        throw "Missing $exporter"
    }
    $cache = Join-Path $Root ".archive_export_cache"
    $wtRoot = Join-Path $Root ".archive_worktrees"
    Write-Host "Exporting catalog archives (cached, best-effort) -> $OutDir"
    python $exporter --root $Root --site $OutDir --godot $Godot --cache $cache --worktrees $wtRoot
    if ($LASTEXITCODE -ne 0) {
        throw "export_archives.py failed (exit $LASTEXITCODE)"
    }
}

Write-Host "Done. Files:"
Get-ChildItem $OutDir | Select-Object Name, Length | Format-Table -AutoSize