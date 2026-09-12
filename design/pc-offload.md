# PC offload (Bot + Build)

Status: binding for agents on a local checkout  
Read when: measuring scripts, planning splits, verifying after edits, or cutting token use  
See also: `design/grok-bot-session.md`, `design/grok-build.md`, `design/debug.md`, `design/refactor.md`

Run heavy inventory / Godot / smoke work on the **User's PC** via these tools. Agents should **read only the `_logs/*/summary.txt` files** those tools write - not raw Godot logs, not whole script bodies just to measure or inventory.

`_logs/` is gitignored. Tools may write summaries there. Do not commit `_logs/`. Optional Bot notes may still go in `_logs/grok-bot-sweep.md`.

## Rules

1. Prefer filesystem `Length` (dir / Get-Item / Get-ChildItem) over reading file contents to measure size.
2. After a preferred runner finishes, open **only** its summary path below.
3. Do not dump whole `.gd` files into chat unless editing them or the User asked.
4. Steam Godot under redirected IO often leaves Process `ExitCode` null - runners treat null as 0. Headless smokes need `--display-driver headless --audio-driver Dummy`. Compile check needs `--headless --editor --import --path <WDB_ROOT> --quit`.
5. ASCII hyphens only inside PowerShell `.ps1` double-quoted strings (no em dashes).

## Catalog

| Job | Command (from repo root) | Summary (read only this) |
|-----|--------------------------|--------------------------|
| Oversize inventory | `powershell -File tools/list_oversize_scripts.ps1` (optional `-OverKb 5` or `10`) | `_logs/oversize/summary.txt` |
| Func-level inventory | `powershell -File tools/summarize_scripts.ps1` (optional `-OverKb 5`, `-TopFuncs 8`, `-Path scripts/...`) | `_logs/script-summary/summary.txt` |
| Facade + siblings by size | `powershell -File tools/list_facade_cluster.ps1 -Facade scripts/combat/enemy.gd` | `_logs/facade-cluster/summary.txt` |
| Script cap gate | `powershell -File tools/check_script_cap.ps1` (optional `-OverKb 10`, `-GitChanged`, `-Path ...`) | `_logs/script-cap/summary.txt` |
| Editor import / compile | `powershell -File tools/run_godot_import_check.ps1` | `_logs/godot-import-check/summary.txt` |
| Phase smokes | Prefer `& .\tools\run_smokes.ps1 -Phases @(4,5)` (avoid `-File ... -Phases 4,5` binding as phase 45) | `_logs/smokes/summary.txt` |
| Hostify lint (advisory) | `powershell -File tools/lint_hostify.ps1` | `_logs/hostify-lint/summary.txt` |
| Post-split gate (Bot) | `powershell -File tools/run_post_split_gate.ps1` (optional `-WithSmokes`, `-Force`) | `_logs/post-split-gate/summary.txt` |
| Build gate (Build) | `powershell -File tools/run_build_gate.ps1` (optional `-SkipImport`, `-OverKb 10`, `-Force`) | `_logs/build-gate/summary.txt` |

## Who uses what

### Grok Bot

- Inventory / sweep planning: oversize list, then `summarize_scripts` / `list_facade_cluster` before opening bodies.
- After each size cluster: import check or `run_post_split_gate.ps1`; hostify lint advisory; smokes when behavior risk warrants.
- Cap target: ship floor 10KB; sweep target 5KB when whole functions can move (`check_script_cap.ps1 -OverKb 5` optional).

### Grok Build

- While editing: enforce 10KB with `check_script_cap.ps1` (full tree or `-Path` / `-GitChanged`). Prefer Length summaries over reading untouched siblings.
- After a slice that touched `.gd`: `run_build_gate.ps1` (cap on changed scripts + import check) unless the User says skip.
- Do **not** run a full-repo Bot size sweep. Do **not** keep splitting toward 5KB.
- Writing tool summaries under `_logs/` is allowed and preferred. Do not commit that folder. Optional Bot-only notes file remains Bot's concern.

### Web / chat

- No requirement to run these. Cap still applies in Phase 6 per `design/web-session.md`.
