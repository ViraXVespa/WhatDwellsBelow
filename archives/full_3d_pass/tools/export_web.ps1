# Export the GitHub Pages build (Godot Web, no threads).
# Usage: from repo root,  powershell -File tools/export_web.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$OutDir = Join-Path $Root "docs"
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

Write-Host "Importing project..."
Invoke-Godot @("--headless", "--path", $Root, "--import") "godot-import.log"

Write-Host "Exporting Web (nothreads) -> $OutHtml"
Invoke-Godot @("--headless", "--path", $Root, "--export-release", "Web", $OutHtml) "godot-export.log"

$nojekyll = Join-Path $OutDir ".nojekyll"
if (-not (Test-Path $nojekyll)) {
    New-Item -ItemType File -Path $nojekyll | Out-Null
}

Write-Host "Done. Files:"
Get-ChildItem $OutDir | Select-Object Name, Length | Format-Table -AutoSize
