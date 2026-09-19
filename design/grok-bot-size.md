# Grok Bot — size sweep

Status: protocol  
Read when: Grok Bot Job table → size sweep  


## Mandate

Size, prove, changelog, and `version.json` rules live in `BOT.md`.

Start with `python tools/bot_status.py`. Sweep live `scripts/**/*.gd` for size (`rglob`, includes `scripts/*.gd`). Not a feature slice. Not the staged reuse-map brief.

- Ship floor: every touched live script under **10KB**.
- Sweep target: under **5KB** when whole functions can move. If a single function is over 5KB, leave it whole and report it.
- Files already under the relevant cap are not split “for cleanliness.”
- No behavior change.
- Over-10KB live scripts left on `main` by Grok Build are expected input to this job, not a missed Build split.

Out of scope: `scenes/`, `assets/`, `tools/` (unless a preload path or PC-offload runner must change), `archives/`, pinned commits, `project.godot` unless a moved script must be registered.

## Read set

1. This file
2. `design/refactor.md` (recipe only)
3. One `design/code-map.md` **system row** for the cluster about to be edited
4. After inventory: only the live `.gd` files in that one cluster
5. At ship: `design/versioning-log.md` body shape — not the changelog tree and not `scripts/data/version.json`

Do not open the staged reuse brief, `design/doc-refactor.md`, or the other Bot flow siblings.

## Inventory

Do not edit yet. Show the ranked list first.

1. `python tools/check_script_cap.py` plus `python tools/bot_status.py`
2. Rank: over 10KB first, then over 5KB where whole functions can move
3. Optional func inventory: `python tools/summarize_scripts.py` if that runner exists on the VM

Inventory and before/after sizes use `os.path.getsize`.

## Pass

1. Split every over-10KB live script with `design/refactor.md`. Facade keeps the public path. Stop each file at under 10KB.
2. Then split over-5KB files only when whole functions can move.
3. One size PR may batch over-10KB then over-5KB clusters. Do not start extract, relocate, docs, or reuse-map work in this PR.

Work in `/workspace/WhatDwellsBelow`. Commit per cluster on `bot/refactorer`.

## Verify



- Required import check: `--headless --editor --import --path </workspace/WhatDwellsBelow> --quit` (or `tools/run_godot_import_check.ps1`). Clean bar: exit 0 and empty stderr.
- Smokes when behavior risk warrants: `--headless --display-driver headless --audio-driver Dummy --path </workspace/WhatDwellsBelow> -- --wdb-phaseN-smoke` (or `tools/run_smokes.ps1`). Plain `--headless` without those drivers can hang.
- Advisory hostify lint: `tools/lint_hostify.ps1` / `python tools/lint_hostify.py` → `_logs/hostify-lint/summary.txt`. Always exits 0; read `RESULT hits=`. Not a compile substitute.
- If a split introduced a SCRIPT ERROR, parse error, or new actionable warning, stop. Fix it and record the prevention under `design/refactor.md`. Do not continue past a red import check.
