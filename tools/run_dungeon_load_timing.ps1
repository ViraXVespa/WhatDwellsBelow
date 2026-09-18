# Placeholdia -> Dungeon load-timing smoke. Writes a short summary agents can read.
# Usage (from repo root):
#   powershell -File tools/run_dungeon_load_timing.ps1
#   powershell -File tools/run_dungeon_load_timing.ps1 -TimeoutSec 180
# See design/debug-smokes.md and design/pc-offload.md.

param([int]$TimeoutSec = 180)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "invoke_godot.ps1")
. (Join-Path $PSScriptRoot "agent_log.ps1")

$OutDir = Ensure-WdbAgentLogDir -Job "dungeon-load-timing" -Root $Root
$Summary = Join-Path $OutDir "summary.txt"
$ErrLog = Join-Path $OutDir "err.log"
$OutLog = Join-Path $OutDir "out.log"

$godotArgs = @(
    "--headless",
    "--display-driver", "headless",
    "--audio-driver", "Dummy",
    "--path", $Root,
    "--",
    "--wdb-dungeon-load-timing-smoke"
)

Write-Host "Running Placeholdia to Dungeon load timing..."
$r = Invoke-WdbGodot -RepoRoot $Root -GodotPath $Root -GodotArgs $godotArgs `
    -OutLog $OutLog -ErrLog $ErrLog -TimeoutSec $TimeoutSec
$status = $r.Status
$ms = $r.Ms

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("dungeon load timing $(Get-Date -Format o)")
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
if ($loadHits.Count -eq 0) { $lines.Add("(no LOAD: lines)") }
else { foreach ($h in ($loadHits | Select-Object -Unique)) { $lines.Add($h) } }
$lines.Add("")
$lines.Add("--- errors ---")
if ($errHits.Count -eq 0) { $lines.Add("(none)") }
else { foreach ($h in ($errHits | Select-Object -Unique | Select-Object -First 40)) { $lines.Add($h) } }
$fail = 0
if ($status -eq "TIMEOUT") { $fail += 1 }
if ($status -match '^EXIT=' -and $status -ne "EXIT=0") { $fail += 1 }
if ($errHits.Count -gt 0) { $fail += 1 }
$total = ""; $hasOk = $false
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
