# Shared Godot start. Dot-source from runners:
#   . (Join-Path $PSScriptRoot "invoke_godot.ps1")
#   $r = Invoke-WdbGodot -RepoRoot $Root -GodotPath $Root -GodotArgs $godotArgs `
#        -OutLog $so -ErrLog $se -TimeoutSec 120
#
# Never Get-Process godot* | Stop-Process.
# Timeout / cleanup kills only the PID this call started.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "godot_lock.ps1")

function Get-WdbGodotExe {
    param([string]$Override = "")
    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override)) {
            throw "invoke_godot: Godot not found at $Override"
        }
        return $Override
    }
    $steam = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
    if (Test-Path -LiteralPath $steam) { return $steam }
    throw "invoke_godot: Steam Godot not found at $steam"
}

function Stop-WdbChildPid {
    param([int]$PidToKill)
    if ($PidToKill -le 0) { return }
    Stop-Process -Id $PidToKill -Force -ErrorAction SilentlyContinue
}

function Invoke-WdbGodot {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string[]]$GodotArgs,
        [string]$OutLog = "",
        [string]$ErrLog = "",
        [int]$TimeoutSec = 120,
        [int]$LockTimeoutSec = 120,
        [int]$LockHoldSec = 0,
        [string]$GodotExe = ""
    )

    $exe = Get-WdbGodotExe -Override $GodotExe
    $path = Get-WdbNormalizedGodotPath -GodotPath $GodotPath
    $hold = $LockHoldSec
    if ($hold -le 0) { $hold = [Math]::Max(60, $TimeoutSec + 30) }

    $hasPath = $false
    foreach ($a in $GodotArgs) {
        if ($a -eq "--path") { $hasPath = $true; break }
    }
    if (-not $hasPath) {
        $GodotArgs = @("--path", $path) + $GodotArgs
    }

    $token = Lock-WdbGodotPath -RepoRoot $RepoRoot -GodotPath $path `
        -TimeoutSec $LockTimeoutSec -HoldSec $hold
    $proc = $null
    $status = "ERROR"
    $code = -1
    $timedOut = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()

    try {
        $start = @{
            FilePath     = $exe
            ArgumentList = $GodotArgs
            PassThru     = $true
            NoNewWindow  = $true
        }
        if ($OutLog) {
            $outDir = Split-Path -Parent $OutLog
            if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
            if (Test-Path -LiteralPath $OutLog) { Remove-Item -LiteralPath $OutLog -Force }
            $start.RedirectStandardOutput = $OutLog
        }
        if ($ErrLog) {
            $errDir = Split-Path -Parent $ErrLog
            if ($errDir) { New-Item -ItemType Directory -Force -Path $errDir | Out-Null }
            if (Test-Path -LiteralPath $ErrLog) { Remove-Item -LiteralPath $ErrLog -Force }
            $start.RedirectStandardError = $ErrLog
        }

        $proc = Start-Process @start
        $ok = $proc.WaitForExit([Math]::Max(1000, $TimeoutSec * 1000))
        if (-not $ok) {
            Stop-WdbChildPid -PidToKill $proc.Id
            Start-Sleep -Milliseconds 200
            $timedOut = $true
            $status = "TIMEOUT"
            $code = -1
        } else {
            $code = $proc.ExitCode
            if ($null -eq $code) { $code = 0 }
            $status = "EXIT=$code"
        }
    } finally {
        Unlock-WdbGodotPath -Token $token
    }

    $sw.Stop()
    $errBytes = 0
    $outBytes = 0
    if ($ErrLog -and (Test-Path -LiteralPath $ErrLog)) {
        $errBytes = (Get-Item -LiteralPath $ErrLog).Length
    }
    if ($OutLog -and (Test-Path -LiteralPath $OutLog)) {
        $outBytes = (Get-Item -LiteralPath $OutLog).Length
    }

    return [pscustomobject]@{
        Status    = $status
        ExitCode  = $code
        TimedOut  = $timedOut
        Pid       = if ($proc) { $proc.Id } else { 0 }
        Ms        = $sw.ElapsedMilliseconds
        ErrBytes  = $errBytes
        OutBytes  = $outBytes
        GodotPath = $path
        Exe       = $exe
    }
}