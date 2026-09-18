# Session-keyed agent log paths. Dot-source from other tools:
#   . (Join-Path $PSScriptRoot "agent_log.ps1")
#   $Summary = Get-WdbAgentSummaryPath -Root $Root -Job "xref"
#
# Resolve order: $env:WDB_AGENT_SESSION, else newest updates.jsonl
# under $GROK_HOME/sessions/<url-encoded-repo-cwd>/ (same layout as pack).
# No session -> throw / exit 2. Never write a shared _logs/<job>/ singleton.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-WdbRepoRoot {
    param([string]$Hint = "")
    if ($Hint) {
        $full = [IO.Path]::GetFullPath($Hint)
        if (Test-Path -LiteralPath (Join-Path $full "project.godot")) {
            return $full.TrimEnd("\", "/")
        }
    }
    if ($PSScriptRoot) {
        $fromTools = Split-Path -Parent $PSScriptRoot
        if (Test-Path -LiteralPath (Join-Path $fromTools "project.godot")) {
            return $fromTools.TrimEnd("\", "/")
        }
    }
    $here = [IO.Path]::GetFullPath((Get-Location).Path)
    $cur = $here
    while ($cur) {
        if (Test-Path -LiteralPath (Join-Path $cur "project.godot")) {
            return $cur.TrimEnd("\", "/")
        }
        $parent = Split-Path -Parent $cur
        if ($parent -eq $cur) { break }
        $cur = $parent
    }
    throw "agent_log: repo root not found (no project.godot)"
}

function Get-WdbGrokHome {
    $raw = [string]$env:GROK_HOME
    if ($raw) {
        return [IO.Path]::GetFullPath($raw.Trim())
    }
    return [IO.Path]::GetFullPath((Join-Path $HOME ".grok"))
}

function Get-WdbEncodedCwd {
    param([Parameter(Mandatory = $true)][string]$Root)
    $norm = [IO.Path]::GetFullPath($Root)
    return [Uri]::EscapeDataString($norm)
}

function Test-WdbSessionDir {
    param([Parameter(Mandatory = $true)][string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
        return $false
    }
    $names = @(
        "summary.json",
        "signals.json",
        "updates.jsonl",
        "chat_history.jsonl",
        "system_prompt.txt",
        "prompt_context.json"
    )
    foreach ($n in $names) {
        if (Test-Path -LiteralPath (Join-Path $Dir $n) -PathType Leaf) {
            return $true
        }
    }
    return $false
}

function Get-WdbSessionRoot {
    param([Parameter(Mandatory = $true)][string]$Root)
    $sessions = Join-Path (Get-WdbGrokHome) "sessions"
    $direct = Join-Path $sessions (Get-WdbEncodedCwd -Root $Root)
    if (Test-Path -LiteralPath $direct -PathType Container) {
        return $direct
    }
    if (Test-Path -LiteralPath $sessions -PathType Container) {
        $want = [IO.Path]::GetFullPath($Root)
        Get-ChildItem -LiteralPath $sessions -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $marker = Join-Path $_.FullName ".cwd"
            if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { return }
            $body = (Get-Content -LiteralPath $marker -Raw -Encoding UTF8).Trim()
            if (-not $body) { return }
            try {
                $got = [IO.Path]::GetFullPath($body)
            } catch {
                return
            }
            if ($got -eq $want) {
                return $_.FullName
            }
        }
    }
    return $direct
}

function Get-WdbInferredSessionId {
    param([Parameter(Mandatory = $true)][string]$Root)
    $sessionRoot = Get-WdbSessionRoot -Root $Root
    if (-not (Test-Path -LiteralPath $sessionRoot -PathType Container)) {
        return ""
    }
    $bestId = ""
    $bestTime = [datetime]::MinValue
    Get-ChildItem -LiteralPath $sessionRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not (Test-WdbSessionDir -Dir $_.FullName)) { return }
        $updates = Join-Path $_.FullName "updates.jsonl"
        if (Test-Path -LiteralPath $updates -PathType Leaf) {
            $when = [IO.File]::GetLastWriteTimeUtc($updates)
        } else {
            $when = $_.LastWriteTimeUtc
        }
        if ($when -ge $bestTime) {
            $bestTime = $when
            $bestId = $_.Name
        }
    }
    return $bestId
}

function Test-WdbSessionKey {
    param([string]$Key)
    if (-not $Key) { return $false }
    return [bool]($Key -match '^[A-Za-z0-9._-]{1,128}$')
}

function Get-WdbAgentSession {
    param([string]$Root = "")
    if (-not $Root) { $Root = Get-WdbRepoRoot }
    $explicit = [string]$env:WDB_AGENT_SESSION
    if ($explicit) {
        $explicit = $explicit.Trim()
        if (-not (Test-WdbSessionKey -Key $explicit)) {
            throw "agent_log: WDB_AGENT_SESSION is not a usable folder key"
        }
        return $explicit
    }
    $inferred = Get-WdbInferredSessionId -Root $Root
    if ($inferred -and (Test-WdbSessionKey -Key $inferred)) {
        return $inferred
    }
    throw "agent_log: no session key (set WDB_AGENT_SESSION or run inside a Grok session for this repo)"
}

function Get-WdbAgentLogDir {
    param(
        [Parameter(Mandatory = $true)][string]$Job,
        [string]$Root = ""
    )
    if ($Job -notmatch '^[A-Za-z0-9._-]+$') {
        throw "agent_log: bad job name"
    }
    if (-not $Root) { $Root = Get-WdbRepoRoot }
    $session = Get-WdbAgentSession -Root $Root
    return [IO.Path]::GetFullPath((Join-Path $Root ("_logs\sess\{0}\{1}" -f $session, $Job)))
}

function Get-WdbAgentSummaryPath {
    param(
        [Parameter(Mandatory = $true)][string]$Job,
        [string]$Root = ""
    )
    return Join-Path (Get-WdbAgentLogDir -Job $Job -Root $Root) "summary.txt"
}

function Ensure-WdbAgentLogDir {
    param(
        [Parameter(Mandatory = $true)][string]$Job,
        [string]$Root = ""
    )
    $dir = Get-WdbAgentLogDir -Job $Job -Root $Root
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return $dir
}

if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name -or $MyInvocation.Line -match 'agent_log\.ps1') {
    if ($args -contains "-Job" -or $args.Count -ge 1) {
        $jobArg = ""
        $rootArg = ""
        for ($i = 0; $i -lt $args.Count; $i++) {
            if ($args[$i] -eq "-Job" -and ($i + 1) -lt $args.Count) {
                $jobArg = [string]$args[$i + 1]
                $i++
            } elseif ($args[$i] -eq "-Root" -and ($i + 1) -lt $args.Count) {
                $rootArg = [string]$args[$i + 1]
                $i++
            } elseif (-not $jobArg -and $args[$i] -notlike "-*") {
                $jobArg = [string]$args[$i]
            }
        }
        try {
            $root = Get-WdbRepoRoot -Hint $rootArg
            $session = Get-WdbAgentSession -Root $root
            Write-Output ("session={0}" -f $session)
            if ($jobArg) {
                $dir = Ensure-WdbAgentLogDir -Job $jobArg -Root $root
                $sum = Join-Path $dir "summary.txt"
                Write-Output ("job={0}" -f $jobArg)
                Write-Output ("dir={0}" -f $dir)
                Write-Output ("summary={0}" -f $sum)
            }
            exit 0
        } catch {
            Write-Output $_.Exception.Message
            exit 2
        }
    }
}