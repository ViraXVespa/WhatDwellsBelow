# Copy opted-in repo skills into .cursor/skills so local Grok Bot sees them.
# A skill is copied only when SKILL.md frontmatter has `cursor-copy: true`.
# Imagine / I2V skills stay Build-only (no cursor-copy flag).
# Usage (from repo root):
#   powershell -File tools/sync_agent_skills.ps1
#   powershell -File tools/sync_agent_skills.ps1 -DryRun
# Writes _logs/skill-sync/summary.txt - agents should read that, not open every SKILL.md.

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "agent_log.ps1")
$SrcRoot = Join-Path $Root ".grok\skills"
$DstRoot = Join-Path $Root ".cursor\skills"
$OutDir = Ensure-WdbAgentLogDir -Job "skill-sync" -Root $Root
$Summary = Join-Path $OutDir "summary.txt"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $DstRoot | Out-Null
}

function RelPath([string]$full) {
    $r = $Root.TrimEnd('\')
    if ($full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($r.Length).TrimStart('\', '/').Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

function HasCursorCopy([string]$skillPath) {
    $text = [IO.File]::ReadAllText($skillPath)
    if ($text.StartsWith("---") -eq $false) { return $false }
    $end = $text.IndexOf("`n---", 3)
    if ($end -lt 0) {
        $end = $text.IndexOf("`r`n---", 3)
    }
    if ($end -lt 0) { return $false }
    $fm = $text.Substring(0, $end)
    return [regex]::IsMatch($fm, "(?im)^\s*cursor-copy\s*:\s*true\s*$")
}

$srcSkills = @()
if (Test-Path -LiteralPath $SrcRoot) {
    $srcSkills = @(Get-ChildItem -Path $SrcRoot -Directory | Sort-Object Name)
}

$copied = 0
$unchanged = 0
$skipped = 0
$missing = 0
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("skill sync $(Get-Date -Format o)")
$lines.Add("root=$Root")
$lines.Add("src=.grok/skills dst=.cursor/skills dryRun=$DryRun")
$lines.Add("measure=copy SKILL.md only when frontmatter cursor-copy: true")
$lines.Add("")

foreach ($dir in $srcSkills) {
    $name = $dir.Name
    $src = Join-Path $dir.FullName "SKILL.md"
    $dstDir = Join-Path $DstRoot $name
    $dst = Join-Path $dstDir "SKILL.md"
    if (-not (Test-Path -LiteralPath $src)) {
        $missing += 1
        $lines.Add("MISSING $($name)/SKILL.md")
        continue
    }
    if (-not (HasCursorCopy $src)) {
        $skipped += 1
        $lines.Add("SKIP $name reason=no-cursor-copy")
        continue
    }
    $srcLen = [int](Get-Item -LiteralPath $src).Length
    $dstExists = Test-Path -LiteralPath $dst
    $dstLen = 0
    $same = $false
    if ($dstExists) {
        $dstLen = [int](Get-Item -LiteralPath $dst).Length
        if ($srcLen -eq $dstLen) {
            $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
            $same = ($srcHash -eq $dstHash)
        }
    }
    if ($same) {
        $unchanged += 1
        $lines.Add(("KEEP {0} bytes={1}" -f $name, $srcLen))
        continue
    }
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $dstLen = [int](Get-Item -LiteralPath $dst).Length
    }
    $copied += 1
    $action = if ($DryRun) { "WOULD_COPY" } else { "COPY" }
    $lines.Add(("{0} {1} src={2} dst={3}" -f $action, $name, $srcLen, $dstLen))
}

$lines.Add("")
$lines.Add(("RESULT skills={0} copied={1} unchanged={2} skipped={3} missing={4}" -f $srcSkills.Count, $copied, $unchanged, $skipped, $missing))
$lines | Set-Content -Path $Summary -Encoding utf8

Write-Host "skills=$($srcSkills.Count) copied=$copied unchanged=$unchanged skipped=$skipped missing=$missing dryRun=$DryRun"
Write-Host "Summary -> $Summary"
exit 0