# Housekeep _logs so agent runners do not clog the disk.
# Default: keep only summary.txt files + wipe raw redirected Godot logs.
# Usage (from repo root):
#   powershell -File tools/clean_agent_logs.ps1
#   powershell -File tools/clean_agent_logs.ps1 -KeepRaw
#   powershell -File tools/clean_agent_logs.ps1 -MaxAgeHours 24
# Writes _logs/clean/summary.txt
#
# Policy:
# - _logs/ is gitignored; never commit it.
# - Preferred runners overwrite their summary.txt each run (Set-Content).
# - Raw *.log / *.err under _logs are disposable; this tool deletes them unless -KeepRaw.
# - Optional -MaxAgeHours also deletes any non-summary file older than that age.
# - Does not touch design notes outside _logs.

param(
    [switch]$KeepRaw,
    [double]$MaxAgeHours = 0,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Logs = Join-Path $Root "_logs"
$OutDir = Join-Path $Logs "clean"
$Summary = Join-Path $OutDir "summary.txt"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("clean agent logs $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("keepRaw=$KeepRaw maxAgeHours=$MaxAgeHours whatIf=$WhatIf")
$lines.Add("")

if (-not (Test-Path $Logs)) {
    $lines.Add("RESULT deleted=0 bytes_freed=0 note=no_logs_dir")
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $lines | Set-Content -Path $Summary -Encoding utf8
    Write-Host "no _logs dir"
    exit 0
}

$deleted = 0
$freed = [int64]0
$kept = 0
$cutoff = $null
if ($MaxAgeHours -gt 0) {
    $cutoff = (Get-Date).AddHours(-$MaxAgeHours)
}

function ShouldDelete([System.IO.FileInfo]$f) {
    $name = $f.Name
    if ($name -ieq "summary.txt") { return $false }
    # always allow deleting raw redirected IO unless KeepRaw
    $isRaw = $name -like "*.log" -or $name -like "*.err" -or $name -like "*-out.log" -or $name -like "*-err.log"
    if ($isRaw -and -not $KeepRaw) { return $true }
    if ($cutoff -ne $null -and $f.LastWriteTime -lt $cutoff -and $name -ine "summary.txt") { return $true }
    return $false
}

Get-ChildItem -Path $Logs -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    if (ShouldDelete $_) {
        $freed += [int64]$_.Length
        $rel = $_.FullName.Substring($Root.Length).TrimStart('\')
        $lines.Add("DEL $rel bytes=$($_.Length)")
        if (-not $WhatIf) { Remove-Item -LiteralPath $_.FullName -Force }
        $deleted += 1
    } else {
        $kept += 1
    }
}

# remove empty dirs under _logs except we still need clean/ for summary
Get-ChildItem -Path $Logs -Recurse -Directory -ErrorAction SilentlyContinue |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        if ($_.FullName -eq $OutDir) { return }
        $left = @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)
        if ($left.Count -eq 0) {
            $rel = $_.FullName.Substring($Root.Length).TrimStart('\')
            $lines.Add("RMDIR $rel")
            if (-not $WhatIf) { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        }
    }

$lines.Add("")
$lines.Add(("RESULT deleted={0} kept={1} bytes_freed={2}" -f $deleted, $kept, $freed))
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host "Summary -> $Summary"
Write-Host ("deleted={0} kept={1} bytes_freed={2}" -f $deleted, $kept, $freed)
exit 0
