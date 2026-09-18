# Per-Godot --path lock. Dot-source from runners:
#   . (Join-Path $PSScriptRoot "godot_lock.ps1")
#   $token = Lock-WdbGodotPath -Root $Root -GodotPath $Root -TimeoutSec 120
#   try { ... } finally { Unlock-WdbGodotPath -Token $token }
#
# Rules:
# - Key is the normalized --path directory, not "any Godot on the machine".
# - Wait until that path is free. Do not Get-Process godot* | Stop-Process.
# - Timeout may not kill a process this helper did not start.
# - The user editor on live $Root and a worktree headless job are different paths.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-WdbGodotLockRoot {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $dir = Join-Path $RepoRoot "_logs\godot-lock"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return $dir
}

function Get-WdbNormalizedGodotPath {
    param([Parameter(Mandatory = $true)][string]$GodotPath)
    $full = [IO.Path]::GetFullPath($GodotPath)
    return $full.TrimEnd("\", "/")
}

function Get-WdbGodotPathKey {
    param([Parameter(Mandatory = $true)][string]$GodotPath)
    $norm = Get-WdbNormalizedGodotPath -GodotPath $GodotPath
    $sha = [BitConverter]::ToString(
        [Security.Cryptography.SHA256]::Create().ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($norm.ToLowerInvariant())
        )
    ).Replace("-", "").Substring(0, 16).ToLowerInvariant()
    return $sha
}

function Get-WdbGodotLockFile {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$GodotPath
    )
    $key = Get-WdbGodotPathKey -GodotPath $GodotPath
    return Join-Path (Get-WdbGodotLockRoot -RepoRoot $RepoRoot) ($key + ".lock")
}

function Get-WdbAgentSessionLabel {
    $explicit = [string]$env:WDB_AGENT_SESSION
    if ($explicit) { return $explicit.Trim() }
    return "no-session"
}

function Get-WdbGodotProcessesOnPath {
    param([Parameter(Mandatory = $true)][string]$GodotPath)
    $norm = Get-WdbNormalizedGodotPath -GodotPath $GodotPath
    $needle = $norm.ToLowerInvariant()
    $hits = New-Object System.Collections.Generic.List[object]
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^godot' } |
        ForEach-Object {
            $cmd = [string]$_.CommandLine
            if (-not $cmd) { return }
            $low = $cmd.ToLowerInvariant()
            if ($low.Contains($needle)) {
                $hits.Add([pscustomobject]@{
                    Pid     = [int]$_.ProcessId
                    Command = $cmd
                })
            }
        }
    return $hits
}

function Test-WdbGodotLockFresh {
    param([string]$LockFile)
    if (-not (Test-Path -LiteralPath $LockFile -PathType Leaf)) {
        return $false
    }
    try {
        $raw = Get-Content -LiteralPath $LockFile -Raw -Encoding UTF8
        $obj = $raw | ConvertFrom-Json
        $exp = [datetime]::Parse($obj.expires_utc, $null, [Globalization.DateTimeStyles]::AdjustToUniversal)
        if ($exp -gt [datetime]::UtcNow) { return $true }
    } catch {
        return $false
    }
    return $false
}

function Lock-WdbGodotPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [int]$TimeoutSec = 120,
        [int]$HoldSec = 180
    )
    $norm = Get-WdbNormalizedGodotPath -GodotPath $GodotPath
    $lockFile = Get-WdbGodotLockFile -RepoRoot $RepoRoot -GodotPath $norm
    $deadline = [datetime]::UtcNow.AddSeconds([Math]::Max(5, $TimeoutSec))
    $session = Get-WdbAgentSessionLabel

    while ([datetime]::UtcNow -lt $deadline) {
        $foreign = @(Get-WdbGodotProcessesOnPath -GodotPath $norm)
        $held = Test-WdbGodotLockFresh -LockFile $lockFile
        if ($foreign.Count -eq 0 -and -not $held) {
            $body = [ordered]@{
                path        = $norm
                session     = $session
                holder_pid  = $PID
                created_utc = [datetime]::UtcNow.ToString("o")
                expires_utc = [datetime]::UtcNow.AddSeconds([Math]::Max(30, $HoldSec)).ToString("o")
            }
            ($body | ConvertTo-Json) | Set-Content -LiteralPath $lockFile -Encoding utf8
            return [pscustomobject]@{
                LockFile  = $lockFile
                GodotPath = $norm
                Session   = $session
            }
        }
        Start-Sleep -Milliseconds 400
    }

    $still = @(Get-WdbGodotProcessesOnPath -GodotPath $norm)
    $pids = ($still | ForEach-Object { $_.Pid }) -join ","
    throw ("godot_lock: busy path={0} foreignPids={1} lock={2}" -f $norm, $pids, $lockFile)
}

function Unlock-WdbGodotPath {
    param($Token)
    if ($null -eq $Token) { return }
    $lockFile = [string]$Token.LockFile
    if ($lockFile -and (Test-Path -LiteralPath $lockFile -PathType Leaf)) {
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    }
}

if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    $pathArg = ""
    $rootArg = ""
    $timeout = 120
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq "-Path" -and ($i + 1) -lt $args.Count) {
            $pathArg = [string]$args[$i + 1]; $i++
        } elseif ($args[$i] -eq "-Root" -and ($i + 1) -lt $args.Count) {
            $rootArg = [string]$args[$i + 1]; $i++
        } elseif ($args[$i] -eq "-TimeoutSec" -and ($i + 1) -lt $args.Count) {
            $timeout = [int]$args[$i + 1]; $i++
        }
    }
    if (-not $rootArg) {
        $rootArg = Split-Path -Parent $PSScriptRoot
    }
    if (-not $pathArg) { $pathArg = $rootArg }
    try {
        $token = Lock-WdbGodotPath -RepoRoot $rootArg -GodotPath $pathArg -TimeoutSec $timeout
        Write-Output ("locked path={0} file={1} session={2}" -f $token.GodotPath, $token.LockFile, $token.Session)
        Unlock-WdbGodotPath -Token $token
        exit 0
    } catch {
        Write-Output $_.Exception.Message
        exit 2
    }
}