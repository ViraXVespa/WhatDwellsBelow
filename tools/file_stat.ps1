param(
    [string[]]$Path = @(),
    [string]$Glob = "",
    [int]$Max = 40,
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $PSScriptRoot
if (-not $Root) { $Root = $here }
$py = Join-Path $PSScriptRoot "file_stat.py"
$argv = @($py, "--root", $Root, "--max", "$Max")
foreach ($item in $Path) {
    $argv += @("--path", $item)
}
if ($Glob) { $argv += @("--glob", $Glob) }
& python @argv
exit $LASTEXITCODE
