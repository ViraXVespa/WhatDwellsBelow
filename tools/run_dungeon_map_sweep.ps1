param(
    [int]$Count = 10,
    [int]$Floor = 1,
    [int]$Scale = 8,
    [int]$TimeoutSec = 180,
    [int[]]$Seeds = @(),
    [string]$SeedList = ""
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "agent_log.ps1")

$OutDir = Ensure-WdbAgentLogDir -Job "dungeon-map" -Root $Root
$Sweep = Join-Path $OutDir "sweep.txt"
$Summary = Join-Path $OutDir "summary.txt"
$Runner = Join-Path $PSScriptRoot "run_dungeon_map.ps1"

if ($SeedList -ne "") {
    $Seeds = @()
    foreach ($part in $SeedList.Split(",")) {
        $trim = $part.Trim()
        if ($trim -ne "") { $Seeds += [int]$trim }
    }
}

if ($Seeds.Count -eq 0) {
    $Seeds = @(42)
    $need = [Math]::Max(0, $Count - 1)
    $i = 0
    while ($i -lt $need) {
        $s = Get-Random -Minimum 1 -Maximum 100000
        if ($Seeds -contains $s) { continue }
        $Seeds += $s
        $i += 1
    }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("dungeon map sweep $(Get-Date -Format o)")
$lines.Add("floor=$Floor scale=$Scale n=$($Seeds.Count)")
$lines.Add("seeds=$($Seeds -join ',')")
$lines.Add("")

$failN = 0
$seedI = 0
foreach ($seed in $Seeds) {
    $seedI += 1
    Write-Host ("sweep {0}/{1} seed={2}" -f $seedI, $Seeds.Count, $seed)
    & powershell -NoProfile -File $Runner -Seed $seed -Floor $Floor -Scale $Scale -TimeoutSec $TimeoutSec
    $code = $LASTEXITCODE
    $spec = "?"
    $rim = "?"
    $span = "?"
    $gates = "?"
    $ok = "?"
    if (Test-Path $Summary) {
        foreach ($ln in Get-Content $Summary) {
            if ($ln -match 'spec rim_closed (.+)$') { $rim = $Matches[1].Trim() }
            elseif ($ln -match 'spec span_on_solid (.+)$') { $span = $Matches[1].Trim() }
            elseif ($ln -match 'spec gates_placed (.+)$') { $gates = $Matches[1].Trim() }
            elseif ($ln -match '^RESULT ') { $ok = $ln }
            elseif ($ln -match 'spec_fail=(\d+)') { $spec = $Matches[1] }
        }
    }
    if ($code -ne 0) { $failN += 1 }
    $row = "seed={0} exit={1} spec_fail={2} rim={3} span={4} gates={5} {6}" -f $seed, $code, $spec, $rim, $span, $gates, $ok
    $lines.Add($row)
    Write-Host $row
}

$lines.Add("")
$lines.Add(("RESULT sweep_fail={0} n={1}" -f $failN, $Seeds.Count))
$lines | Set-Content -Path $Sweep -Encoding utf8
Write-Host ("Sweep -> {0}" -f $Sweep)
Write-Host ("sweep_fail={0}" -f $failN)
exit $(if ($failN -gt 0) { 1 } else { 0 })