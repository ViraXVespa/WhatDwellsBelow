param([int]$TimeoutSec = 180)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "invoke_godot.ps1")
. (Join-Path $PSScriptRoot "agent_log.ps1")
$OutDir = Ensure-WdbAgentLogDir -Job "bake-camp" -Root $Root
$Summary = Join-Path $OutDir "summary.txt"
$OutLog = Join-Path $OutDir "bake-out.log"
$ErrLog = Join-Path $OutDir "bake-err.log"
$godotArgs = @(
    "--headless",
    "--display-driver", "headless",
    "--audio-driver", "Dummy",
    "--path", $Root,
    "--",
    "--wdb-bake-camp"
)
Write-Host "Baking camp.tscn..."
$r = Invoke-WdbGodot -RepoRoot $Root -GodotPath $Root -GodotArgs $godotArgs -OutLog $OutLog -ErrLog $ErrLog -TimeoutSec $TimeoutSec
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("bake camp $(Get-Date -Format o)")
$lines.Add("root=.")
$lines.Add("status=$($r.Status) ms=$($r.Ms) errBytes=$($r.ErrBytes) outBytes=$($r.OutBytes)")
$lines.Add("")
$lines.Add("--- highlights ---")
$hits = New-Object System.Collections.Generic.List[string]
foreach ($log in @($ErrLog, $OutLog)) {
    if (-not (Test-Path $log)) { continue }
    Select-String -Path $log -Pattern "SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|bake_camp:" -ErrorAction SilentlyContinue |
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
    if ($h -match "SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed") { $hasHard = $true; break }
}
$clean = ($r.Status -eq "EXIT=0") -and (-not $hasHard)
$lines.Add("")
if ($clean) { $lines.Add("RESULT clean=true") } else { $lines.Add("RESULT clean=false") }
$lines | Set-Content -Path $Summary -Encoding utf8
Write-Host ("Summary -> _logs/{0}/summary.txt" -f (Split-Path $OutDir -Leaf))
if (-not $clean) { exit 1 }
exit 0
