# Phase smoke runner (Steam Godot). Writes a short summary agents can read.
# Usage (from repo root):
#   powershell -File tools/run_smokes.ps1
#   powershell -File tools/run_smokes.ps1 -Phases 1,2,3
#   powershell -File tools/run_smokes.ps1 -Phases 6 -TimeoutSec 180
# Prefer from a PowerShell session: & .\tools\run_smokes.ps1 -Phases @(4,5)
# (powershell -File ... -Phases 4,5 can bind as a single int 45.)
# See design/debug.md (Live snapshot - smoke tests).

param(
    [int[]]$Phases = @(1, 2, 3, 4, 5, 6, 7, 8, 9),
    [int]$TimeoutSec = 120,
    [switch]$VerboseGodot
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$OutDir = Join-Path $Root "_logs\smokes"
$Summary = Join-Path $OutDir "summary.txt"

if (-not (Test-Path $Godot)) {
    throw "Steam Godot not found at: $Godot"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 400

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("smoke summary $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("phases=$($Phases -join ',') timeoutSec=$TimeoutSec")
$lines.Add("")

$fail = 0
foreach ($n in $Phases) {
    Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500

    $se = Join-Path $OutDir ("p{0}-err.log" -f $n)
    $so = Join-Path $OutDir ("p{0}-out.log" -f $n)
    Remove-Item $se, $so -Force -ErrorAction SilentlyContinue

    $godotArgs = @(
        "--headless",
        "--display-driver", "headless",
        "--audio-driver", "Dummy",
        "--path", $Root
    )
    if ($VerboseGodot) {
        $godotArgs += "--verbose"
    }
    $godotArgs += @("--", ("--wdb-phase{0}-smoke" -f $n))

    Write-Host ("Running phase {0}..." -f $n)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $Godot -ArgumentList $godotArgs -PassThru -NoNewWindow `
        -RedirectStandardOutput $so -RedirectStandardError $se
    $ok = $p.WaitForExit([Math]::Max(1000, $TimeoutSec * 1000))
    if (-not $ok) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 400
        Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
        $status = "TIMEOUT"
        $fail += 1
    } else {
        # Godot GUI-subsystem + redirected IO often leaves ExitCode $null even on a clean quit.
        $code = $p.ExitCode
        if ($null -eq $code) { $code = 0 }
        $status = "EXIT=$code"
        if ($code -ne 0) { $fail += 1 }
    }

    $ms = $sw.ElapsedMilliseconds
    $errBytes = if (Test-Path $se) { (Get-Item $se).Length } else { 0 }
    $header = "p$n $status ms=$ms errBytes=$errBytes"
    $lines.Add($header)
    $lines.Add("--- highlights ---")
    Write-Host $header

    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($log in @($se, $so)) {
        if (-not (Test-Path $log)) { continue }
        Select-String -Path $log -Pattern '^P\d:|SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to' -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Line } |
            Select-Object -Unique |
            ForEach-Object { [void]$hits.Add($_) }
    }
    if ($hits.Count -eq 0) {
        $lines.Add("(no P*/SCRIPT ERROR highlights - check logs if TIMEOUT)")
    } else {
        foreach ($h in ($hits | Select-Object -Unique | Select-Object -First 80)) {
            $lines.Add($h)
            Write-Host ("  " + $h)
        }
        foreach ($h in $hits) {
            if ($h -match 'SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to') {
                if ($status -ne "TIMEOUT") { $fail += 1; break }
            }
        }
    }
    $lines.Add("")
}

Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
$lines.Add(("RESULT fail_signals={0}" -f $fail))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host ""
Write-Host "Summary -> $Summary"
Write-Host ("fail_signals={0}" -f $fail)

if ($fail -gt 0) {
    exit 1
}
exit 0
