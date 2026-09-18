# Phase smoke runner. Per-path Godot lock; never kills godot*.
# Usage (from repo root):
#   powershell -File tools/run_smokes.ps1
#   & .\tools\run_smokes.ps1 -Phases @(4,5)

param(
    [int[]]$Phases = @(1, 2, 3, 4, 5, 6, 7, 8, 9),
    [int]$TimeoutSec = 120,
    [switch]$VerboseGodot
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "invoke_godot.ps1")
. (Join-Path $PSScriptRoot "agent_log.ps1")

$OutDir = Ensure-WdbAgentLogDir -Job "smokes" -Root $Root
$Summary = Join-Path $OutDir "summary.txt"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Get-ChildItem -Path $OutDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "^p\d+-(err|out)\.log$" } |
    ForEach-Object {
        $m = [regex]::Match($_.Name, "^p(\d+)-")
        if ($m.Success) {
            $n = [int]$m.Groups[1].Value
            if ($Phases -notcontains $n) { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        }
    }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("smoke summary $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("phases=$($Phases -join ',') timeoutSec=$TimeoutSec")
$lines.Add("")

$fail = 0
foreach ($n in $Phases) {
    $se = Join-Path $OutDir ("p{0}-err.log" -f $n)
    $so = Join-Path $OutDir ("p{0}-out.log" -f $n)
    $godotArgs = @(
        "--headless",
        "--display-driver", "headless",
        "--audio-driver", "Dummy",
        "--path", $Root
    )
    if ($VerboseGodot) { $godotArgs += "--verbose" }
    $godotArgs += @("--", ("--wdb-phase{0}-smoke" -f $n))

    Write-Host ("Running phase {0}..." -f $n)
    $r = Invoke-WdbGodot -RepoRoot $Root -GodotPath $Root -GodotArgs $godotArgs `
        -OutLog $so -ErrLog $se -TimeoutSec $TimeoutSec
    $status = $r.Status
    if ($r.TimedOut -or ($r.ExitCode -ne 0)) { $fail += 1 }

    $header = "p$n $status ms=$($r.Ms) errBytes=$($r.ErrBytes)"
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

$lines.Add(("RESULT fail_signals={0}" -f $fail))
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host ""
Write-Host "Summary -> $Summary"
Write-Host ("fail_signals={0}" -f $fail)
if ($fail -gt 0) { exit 1 }
exit 0
