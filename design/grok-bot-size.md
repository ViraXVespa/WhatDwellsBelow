# Grok Bot — size sweep

Status: protocol  
Read when: Grok Bot Job table → size sweep  
See also: `design/grok-bot-session.md`, `design/refactor.md`, `design/pc-offload.md`

`See also:` is an index, not a read list. Open the door first. Then this file. Recipes stay in `design/refactor.md`.

Binding for **Grok Bot** size sweeps only. Ship rules stay on `design/grok-bot-session.md`.

## Mandate

Sweep live `scripts/**/*.gd` for size. Not a feature slice. Not the staged reuse-map brief.

- Ship floor: every touched live script under **10KB**.
- Sweep target: under **5KB** when whole existing functions can move. If a single function is over 5KB, leave it whole and report it.
- Files already under the relevant cap are not split “for cleanliness.”
- No behavior change.

Out of scope: `scenes/`, `assets/`, `tools/` (unless a preload path or PC-offload runner must change), `archives/`, pinned commits, `project.godot` unless a moved script must be registered.

## Read set

1. `AGENTS.md`
2. `design/grok-bot-session.md`
3. This file
4. `design/refactor.md`
5. The `design/README.md` **code map** row for the cluster about to be edited
6. After inventory: only the live `.gd` files in that one cluster
7. At ship: baked `scripts/data/version.json` and `design/versioning.md` body shape — not the changelog tree

Do not open `design/reuse-map.md`, `design/doc-refactor.md`, or the other Bot flow siblings.

## Inventory

Do not edit yet. Show the ranked list first.

1. `powershell -File tools/list_oversize_scripts.ps1` → `_logs/oversize/summary.txt`
2. Rank: over 10KB first, then over 5KB where whole functions can move
3. Optional func inventory: `tools/summarize_scripts.ps1` / facade cluster: `tools/list_facade_cluster.ps1` (see `design/pc-offload.md`)

## Pass

1. Split every over-10KB live script with `design/refactor.md`. Facade keeps the public path. Stop each file at under 10KB.
2. Then split over-5KB files only when whole functions can move.
3. One size PR may batch over-10KB then over-5KB clusters. Do not start extract, relocate, docs, or reuse-map work in this PR.

Prefer a local checkout (`WDB_ROOT`) for large sweeps. Commit locally per cluster; push the PR branch when the cluster is done. Cloud agent is optional. Document a `WDB_ROOT` change on the door only if that path itself changed.

## Verify

After each cluster: `design/pc-offload.md` runners (`run_post_split_gate.ps1`, `check_script_cap.ps1`, import check). Smokes when behavior risk warrants. Then ship per the door.
