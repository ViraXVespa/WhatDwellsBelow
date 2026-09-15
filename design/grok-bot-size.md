# Grok Bot — size sweep

Status: protocol  
Read when: Grok Bot Job table → size sweep  
See also:

Binding for **Grok Bot** size sweeps only. Ship rules stay on `design/grok-bot-session.md` (already open). Recipes stay in `design/refactor.md`. Do not reopen the door. `See also:` is not a read list.

## Mandate

Sweep live `scripts/**/*.gd` for size. Not a feature slice. Not the staged reuse-map brief.

- Ship floor: every touched live script under **10KB**.
- Sweep target: under **5KB** when whole functions can move. If a single function is over 5KB, leave it whole and report it.
- Files already under the relevant cap are not split “for cleanliness.”
- No behavior change.

Out of scope: `scenes/`, `assets/`, `tools/` (unless a preload path or PC-offload runner must change), `archives/`, pinned commits, `project.godot` unless a moved script must be registered.

## Read set

1. This file
2. `design/refactor.md` (recipe only)
3. One `design/code-map.md` **system row** for the cluster about to be edited
4. After inventory: only the live `.gd` files in that one cluster
5. At ship: baked `scripts/data/version.json` and `design/versioning.md` body shape — not the changelog tree

Do not reopen `AGENTS.md` unless types, warnings, tabs, or the 10KB cap left context. Do not open `design/reuse-map.md`, `design/doc-refactor.md`, or the other Bot flow siblings.

## Inventory

Do not edit yet. Show the ranked list first.

1. `powershell -File tools/list_oversize_scripts.ps1` → `_logs/oversize/summary.txt`
2. Rank: over 10KB first, then over 5KB where whole functions can move
3. Optional func inventory: `tools/summarize_scripts.ps1` / facade cluster: `tools/list_facade_cluster.ps1` (see `design/pc-offload.md`)

Inventory and before/after sizes use filesystem Length. Do not `ReadAllText` + `Encoding.UTF8.GetByteCount` just to measure.

## Pass

1. Split every over-10KB live script with `design/refactor.md`. Facade keeps the public path. Stop each file at under 10KB.
2. Then split over-5KB files only when whole functions can move.
3. One size PR may batch over-10KB then over-5KB clusters. Do not start extract, relocate, docs, or reuse-map work in this PR.

Prefer a local checkout (`WDB_ROOT`) for large sweeps. Commit locally per cluster; push the PR branch when the cluster is done. Cloud agent is optional. Document a `WDB_ROOT` change on the door only if that path itself changed.

## Verify

After each cluster: `design/pc-offload.md` runners (`run_post_split_gate.ps1`, `check_script_cap.ps1`, import check). Then ship per the door.

- Godot binary (Steam tools): `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- Required import check: `--headless --editor --import --path <WDB_ROOT> --quit` (or `tools/run_godot_import_check.ps1`). Clean bar: exit 0 and empty stderr.
- Smokes when behavior risk warrants: `--headless --display-driver headless --audio-driver Dummy --path <WDB_ROOT> -- --wdb-phaseN-smoke` (or `tools/run_smokes.ps1`). Plain `--headless` without those drivers can hang.
- Advisory hostify lint: `tools/lint_hostify.ps1` / `python tools/lint_hostify.py` → `_logs/hostify-lint/summary.txt`. Always exits 0; read `RESULT hits=`. Not a compile substitute.
- If a split introduced a SCRIPT ERROR, parse error, or new actionable warning, stop. Fix it and record the prevention under `design/refactor.md`. Do not continue past a red import check.
