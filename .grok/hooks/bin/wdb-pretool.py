#!/usr/bin/env python3
"""Phase 4 revises for the Grok Build flow rework. Run from repo root:
    python tools/_scratch.py
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def write(rel: str, body: str) -> None:
    path = ROOT / rel
    path.write_text(body.replace("\n", "\r\n"), encoding="utf-8")
    print("wrote", rel, "bytes", path.stat().st_size)


def delete(rel: str) -> None:
    path = ROOT / rel
    if path.is_file():
        path.unlink()
        print("deleted", rel)
    else:
        print("missing", rel)


def patch(rel: str, old: str, new: str) -> None:
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    if old not in text:
        print("NO MATCH", rel)
        return
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("patched", rel)


SMOKES = r'''# Phase smoke runner. Per-path Godot lock; never kills godot*.
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
'''

IMPORT = r'''# Editor import / script-reload check. Per-path lock; never kills godot*.
param([int]$TimeoutSec = 180)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "invoke_godot.ps1")
. (Join-Path $PSScriptRoot "agent_log.ps1")

$OutDir = Ensure-WdbAgentLogDir -Job "godot-import-check" -Root $Root
$Summary = Join-Path $OutDir "summary.txt"
$OutLog = Join-Path $OutDir "import-out.log"
$ErrLog = Join-Path $OutDir "import-err.log"

$godotArgs = @(
    "--headless",
    "--editor",
    "--import",
    "--path", $Root,
    "--quit"
)

Write-Host "Running editor import check..."
$r = Invoke-WdbGodot -RepoRoot $Root -GodotPath $Root -GodotArgs $godotArgs `
    -OutLog $OutLog -ErrLog $ErrLog -TimeoutSec $TimeoutSec
$status = $r.Status

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("godot import check $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("status=$status ms=$($r.Ms) errBytes=$($r.ErrBytes) outBytes=$($r.OutBytes)")
$lines.Add("")
$lines.Add("--- highlights ---")

$hits = New-Object System.Collections.Generic.List[string]
foreach ($log in @($ErrLog, $OutLog)) {
    if (-not (Test-Path $log)) { continue }
    Select-String -Path $log -Pattern 'SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|WARNING:' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Line } |
        Select-Object -Unique |
        ForEach-Object { [void]$hits.Add($_) }
}
if ($hits.Count -eq 0) {
    $lines.Add("(no SCRIPT ERROR / WARNING highlights)")
} else {
    foreach ($h in ($hits | Select-Object -Unique | Select-Object -First 120)) { $lines.Add($h) }
}
$hasHard = $false
foreach ($h in $hits) {
    if ($h -match 'SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed') { $hasHard = $true; break }
}
$clean = ($status -eq "EXIT=0") -and ($r.ErrBytes -eq 0) -and (-not $hasHard)
$lines.Add("")
if ($clean) { $lines.Add("RESULT clean=true") } else { $lines.Add("RESULT clean=false") }
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host "Summary -> $Summary"
if (-not $clean) { exit 1 }
exit 0
'''

LOAD = r'''# Title -> Placeholdia load-timing smoke. Per-path lock; never kills godot*.
param([int]$TimeoutSec = 180)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "invoke_godot.ps1")
. (Join-Path $PSScriptRoot "agent_log.ps1")

$OutDir = Ensure-WdbAgentLogDir -Job "load-timing" -Root $Root
$Summary = Join-Path $OutDir "summary.txt"
$ErrLog = Join-Path $OutDir "err.log"
$OutLog = Join-Path $OutDir "out.log"

$godotArgs = @(
    "--headless",
    "--display-driver", "headless",
    "--audio-driver", "Dummy",
    "--path", $Root,
    "--",
    "--wdb-load-timing-smoke"
)

Write-Host "Running Title to Placeholdia load timing..."
$r = Invoke-WdbGodot -RepoRoot $Root -GodotPath $Root -GodotArgs $godotArgs `
    -OutLog $OutLog -ErrLog $ErrLog -TimeoutSec $TimeoutSec
$status = $r.Status
$ms = $r.Ms

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("load timing $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("status=$status wall_ms=$ms errBytes=$($r.ErrBytes) outBytes=$($r.OutBytes)")
$lines.Add("")
$lines.Add("--- LOAD lines ---")

$loadHits = New-Object System.Collections.Generic.List[string]
$errHits = New-Object System.Collections.Generic.List[string]
foreach ($log in @($ErrLog, $OutLog)) {
    if (-not (Test-Path $log)) { continue }
    Select-String -Path $log -Pattern '^LOAD:' -ErrorAction SilentlyContinue |
        ForEach-Object { [void]$loadHits.Add($_.Line) }
    Select-String -Path $log -Pattern 'SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to' -ErrorAction SilentlyContinue |
        ForEach-Object { [void]$errHits.Add($_.Line) }
}
if ($loadHits.Count -eq 0) {
    $lines.Add("(no LOAD: lines - check err.log if TIMEOUT)")
} else {
    foreach ($h in ($loadHits | Select-Object -Unique)) { $lines.Add($h) }
}
$lines.Add("")
$lines.Add("--- errors ---")
if ($errHits.Count -eq 0) { $lines.Add("(none)") }
else {
    foreach ($h in ($errHits | Select-Object -Unique | Select-Object -First 40)) { $lines.Add($h) }
}

$fail = 0
if ($status -eq "TIMEOUT") { $fail += 1 }
if ($status -match '^EXIT=' -and $status -ne "EXIT=0") { $fail += 1 }
if ($errHits.Count -gt 0) { $fail += 1 }
$total = ""
$hasOk = $false
foreach ($h in $loadHits) {
    if ($h -match 'total_ms=(\d+)') { $total = $Matches[1] }
    if ($h -match 'ok=true') { $hasOk = $true }
}
if (-not $hasOk -or $total -eq "") { $fail += 1 }
$lines.Add("")
if ($total -eq "") { $lines.Add(("RESULT fail_signals={0} total_ms=-1" -f $fail)) }
else { $lines.Add(("RESULT fail_signals={0} total_ms={1}" -f $fail, $total)) }
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host ("Summary -> {0}" -f $Summary)
exit $(if ($fail -gt 0) { 1 } else { 0 })
'''


def ps1_agent_summary(text: str, job: str) -> str:
    needle = f'$OutDir = Join-Path $Root "_logs\\{job}"'
    if needle not in text:
        needle = f"$OutDir = Join-Path $Root \"_logs\\{job}\""
    if needle not in text:
        return text
    insert = (
        '. (Join-Path $PSScriptRoot "agent_log.ps1")\n'
        f'$OutDir = Ensure-WdbAgentLogDir -Job "{job}" -Root $Root'
    )
    if 'agent_log.ps1' not in text:
        text = text.replace("$Root = Split-Path -Parent $PSScriptRoot",
                            "$Root = Split-Path -Parent $PSScriptRoot\n. (Join-Path $PSScriptRoot \"agent_log.ps1\")", 1)
    return text.replace(needle, f'$OutDir = Ensure-WdbAgentLogDir -Job "{job}" -Root $Root', 1)


def main() -> None:
    write("tools/run_smokes.ps1", SMOKES)
    write("tools/run_godot_import_check.ps1", IMPORT)
    write("tools/run_load_timing.ps1", LOAD)

    for rel, job, flag in (
        ("tools/run_dungeon_load_timing.ps1", "dungeon-load-timing", "--wdb-dungeon-load-timing-smoke"),
        ("tools/run_dungeon_map.ps1", "dungeon-map", "--wdb-dungeon-map-smoke"),
    ):
        path = ROOT / rel
        if not path.is_file():
            print("missing", rel)
            continue
        text = path.read_text(encoding="utf-8")
        text = text.replace(
            'Get-Process -Name "godot*" -ErrorAction SilentlyContinue | Stop-Process -Force\n',
            "",
        )
        if 'invoke_godot.ps1' not in text:
            text = text.replace(
                "$Root = Split-Path -Parent $PSScriptRoot",
                "$Root = Split-Path -Parent $PSScriptRoot\n. (Join-Path $PSScriptRoot \"invoke_godot.ps1\")\n. (Join-Path $PSScriptRoot \"agent_log.ps1\")",
                1,
            )
        text = ps1_agent_summary(text, job)
        path.write_text(text, encoding="utf-8")
        print("stripped godot-kill", rel)

    for rel, job in (
        ("tools/list_xref.ps1", "xref"),
        ("tools/list_changed.ps1", "changed"),
        ("tools/list_scenes.ps1", "scenes"),
        ("tools/list_route.ps1", "route"),
        ("tools/list_oversize_scripts.ps1", "oversize"),
        ("tools/list_oversize_docs.ps1", "oversize-docs"),
        ("tools/list_facade_cluster.ps1", "facade-cluster"),
        ("tools/check_script_cap.ps1", "script-cap"),
        ("tools/summarize_scripts.ps1", "script-summary"),
        ("tools/lint_hostify.ps1", "hostify-lint"),
        ("tools/run_agent_py.ps1", "agent-py"),
        ("tools/sync_agent_skills.ps1", "skill-sync"),
        ("tools/run_build_gate.ps1", "build-gate"),
        ("tools/run_post_split_gate.ps1", "post-split-gate"),
    ):
        path = ROOT / rel
        if not path.is_file():
            print("missing", rel)
            continue
        text = path.read_text(encoding="utf-8")
        new = ps1_agent_summary(text, job)
        if new == text:
            print("no outdir swap", rel)
        else:
            path.write_text(new, encoding="utf-8")
            print("sess summary", rel)

    delete("tools/stage_patch.ps1")
    delete("tools/promote_patch.ps1")

    cg = ROOT / "tools/check_load_graph.py"
    cgt = cg.read_text(encoding="utf-8")
    for blob in (
        'if posix == "design/sessions.md":',
        'if posix == "design/web-session.md":',
    ):
        if blob in cgt:
            print("check_load_graph still has", blob, "- strip by hand if block remains")
    cgt = cgt.replace(
        'if "sessions.md` is context only" in text:\n        fails.append("web-session.md still treats sessions.md as context")\n',
        "",
    )
    cg.write_text(cgt, encoding="utf-8")
    print("touched tools/check_load_graph.py")

    rs = ROOT / "tools/read_summary.ps1"
    rst = rs.read_text(encoding="utf-8")
    rst = rst.replace('    "patch-stage"          = "_logs/patch-scratch/summary.txt"\n', "")
    rst = rst.replace('    "patch-promote"        = "_logs/patch-lock/summary.txt"\n', "")
    rs.write_text(rst, encoding="utf-8")
    print("stripped patch jobs from read_summary.ps1")

    skill = ROOT / ".grok/skills/pc-offload/SKILL.md"
    if skill.is_file():
        st = skill.read_text(encoding="utf-8")
        st = st.replace(
            "Two compacts on the same slice: stop, write leave-off, start a new CLI.",
            "Two compacts on the same slice: stop and start a new session in this instance.",
        )
        st = st.replace("or named routing work", "or named routing work")
        st = st.replace("only at ship, leave-off,", "only at ship,")
        skill.write_text(st, encoding="utf-8")
        print("patched pc-offload skill")


if __name__ == "__main__":
    main()