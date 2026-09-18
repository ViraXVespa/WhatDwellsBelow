# Housekeep _logs so agent runners do not clog the disk.
# Default: keep only summary.txt files + wipe raw redirected Godot logs.
# New week pin: powershell -File tools/clean_agent_logs.ps1 -NewWeek
# Writes session-keyed _logs/sess/<session>/clean/summary.txt when a session key exists.
#
# Policy:
# - _logs/ is gitignored; never commit it.
# - Preferred runners overwrite their summary.txt each run (Set-Content).
# - Raw *.log / *.err under _logs are disposable; this tool deletes them unless -KeepRaw.
# - Optional -MaxAgeHours also deletes any non-summary file older than that age.
# - -NewWeek deletes sess, patch-scratch, apply.lock, and leftover singleton summaries.
# - Does not touch design notes outside _logs.

param(
    [switch]$KeepRaw,
    [double]$MaxAgeHours = 0,
    [switch]$WhatIf,
    [switch]$NewWeek
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "agent_log.ps1")

$Root = Split-Path -Parent $PSScriptRoot
$Logs = Join-Path $Root "_logs"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("clean agent logs $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("keepRaw=$KeepRaw maxAgeHours=$MaxAgeHours whatIf=$WhatIf newWeek=$NewWeek")
$lines.Add("")

$deleted = 0
$freed = [int64]0
$kept = 0

function Remove-WdbLogTarget([string]$full, [string]$kind) {
    if (-not (Test-Path -LiteralPath $full)) { return }
    $item = Get-Item -LiteralPath $full -Force
    $rel = $item.FullName.Substring($Root.Length).TrimStart('\')
    if ($item.PSIsContainer) {
        $size = 0
        Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $size += [int64]$_.Length
        }
        $script:freed += $size
        $script:lines.Add("$kind $rel")
        if (-not $WhatIf) { Remove-Item -LiteralPath $item.FullName -Recurse -Force }
        $script:deleted += 1
        return
    }
    $script:freed += [int64]$item.Length
    $script:lines.Add("$kind $rel bytes=$($item.Length)")
    if (-not $WhatIf) { Remove-Item -LiteralPath $item.FullName -Force }
    $script:deleted += 1
}

if ($NewWeek) {
    if (Test-Path $Logs) {
        Remove-WdbLogTarget (Join-Path $Logs "sess") "DELDIR"
        Remove-WdbLogTarget (Join-Path $Logs "patch-scratch") "DELDIR"
        Remove-WdbLogTarget (Join-Path $Logs "patch-lock\apply.lock") "DEL"
        Get-ChildItem -Path $Logs -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -in @("sess", "patch-scratch", "patch-lock", "clean")) { return }
            $sum = Join-Path $_.FullName "summary.txt"
            if (Test-Path -LiteralPath $sum) {
                Remove-WdbLogTarget $sum "DEL"
            }
        }
        Get-ChildItem -Path $Logs -File -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-WdbLogTarget $_.FullName "DEL"
        }
    }
    $lines.Add("")
    $lines.Add(("RESULT deleted={0} kept={1} bytes_freed={2} newWeek=true" -f $deleted, $kept, $freed))
} elseif (-not (Test-Path $Logs)) {
    $lines.Add("RESULT deleted=0 bytes_freed=0 note=no_logs_dir")
} else {
    $cutoff = $null
    if ($MaxAgeHours -gt 0) {
        $cutoff = (Get-Date).AddHours(-$MaxAgeHours)
    }

    function ShouldDelete([System.IO.FileInfo]$f) {
        $name = $f.Name
        if ($name -ieq "summary.txt") { return $false }
        $isRaw = $name -like "*.log" -or $name -like "*.err" -or $name -like "*-out.log" -or $name -like "*-err.log"
        if ($isRaw -and -not $KeepRaw) { return $true }
        if ($null -ne $cutoff -and $f.LastWriteTime -lt $cutoff -and $name -ine "summary.txt") { return $true }
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

    Get-ChildItem -Path $Logs -Recurse -Directory -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            $left = @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)
            if ($left.Count -eq 0) {
                $rel = $_.FullName.Substring($Root.Length).TrimStart('\')
                $lines.Add("RMDIR $rel")
                if (-not $WhatIf) { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
            }
        }

    $lines.Add("")
    $lines.Add(("RESULT deleted={0} kept={1} bytes_freed={2}" -f $deleted, $kept, $freed))
}

$summary = $null
try {
    $dir = Ensure-WdbAgentLogDir -Job "clean" -Root $Root
    $summary = Join-Path $dir "summary.txt"
} catch {
    $fallback = Join-Path $Logs "clean"
    if (-not $WhatIf) { New-Item -ItemType Directory -Force -Path $fallback | Out-Null }
    $summary = Join-Path $fallback "summary.txt"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $summary) | Out-Null
$lines | Set-Content -Path $summary -Encoding utf8
Write-Host "Summary -> $summary"
Write-Host ("deleted={0} kept={1} bytes_freed={2}" -f $deleted, $kept, $freed)
exit 0
