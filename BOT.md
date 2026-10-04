# BOT.md

Status: protocol
Read when: Grok Bot (The Refactorer) boots or starts a job

The only Bot constitution. Second topic door: ask the User to name the owner first.

## Workspace

Clone github.com/ViraXVespa/WhatDwellsBelow to /workspace/WhatDwellsBelow and work that tree. Fresh `bot/<flow>` branch per flow (from `origin/main`; e.g. `bot/size-xyz`). One open Bot PR. Commit per cluster. User squash-merges. Never push main. Never merge the PR.

Publish with plain `git push -u origin bot/<flow>` over HTTPS (gh credential helper) to `bot/*` or the PR branch only. No force pushes, ever. Open the PR with `gh pr create` (if that fails, GitHub MCP `create_pull_request`). Edit a PR body with `gh api -X PATCH repos/<repo>/pulls/N -F body=@file` (`gh pr edit` fails on the Projects classic shutdown). The box git identity is Grok Bot, so plain `git commit` works.

## Boot

1. Read this file. If the agents file already routed you here, do not fetch it again.
2. Run: python3 tools/bot_status.py
3. Pick one printed flow. Do not invent reuse-map or opt-queue rows.
4. Open only that Job file. When editing GDScript, also load `design/gdscript-law.md`.
5. After a cluster, drop those file bodies and report.

| Job | Open |
|-----|------|
| Size sweep (over 10KB, then 5KB when whole functions can move) | `design/grok-bot-size.md` |
| Ad-hoc extract / existing-owner routing (User-gated; not the staged map) | `design/grok-bot-extract.md` |
| Staged reuse-map brief as one PR | `design/grok-bot-reuse.md` |
| Parked / named folder relocate | `design/grok-bot-relocate.md` |
| Doc facade / sibling split | `design/grok-bot-docs.md` |
| Named optimization item from the parked queue | `design/grok-bot-opt.md` |

Job files do not restate this file: size, prove, changelog and `version.json` rules live here (label math: `design/versioning-log.md` body shape, not the changelog tree or `scripts/data/version.json`, at ship; `next-label` = highest on disk + 1; same PR: `--label`). One flow, one PR, then stop; if the User names more than one job, ask which.

Woke because main moved: run bot_status first. over_10kb count 0: report and stop. Above 0: open only `design/grok-bot-size.md`; no other flow from that wake. Commit on the Bot branch only.

## Prove

- python3 tools/check_script_cap.py --git-changed
- python3 tools/check_load_graph.py
- python3 tools/bot_status.py --prove
- python3 tools/check_code_map.py (no new UNMAPPED for files you touched; older ones are expected)
- python3 tools/check_tool_docs.py (only when `tools/` or the catalog changed); `--stale-refs` after any doc edit that names paths

Proof recipes by change kind (shots, layout, keying) and extend-the-tools-not-work-around-them: `design/prove.md`.
CI: .github/workflows/bot-gate.yml. Allowlist: tools/bot_allow.txt (default deny; deny lines first).
Stale docs: `design/` and `tools/` are allowlisted, so fix stale doc lines in the job you are on. When the current truth is unclear, do not guess: list the line under `Stale doc lines (for the User)` in the PR body (file, line, what it says, what it might say).
Measure: os.path.getsize (10,000-byte floor). Touched live `scripts/**/*.gd` ship under 10KB; split with `design/refactor.md` (recipe only; the 5KB target is only `design/grok-bot-size.md`).
Do not open `design/reuse-map.md` except from `design/grok-bot-reuse.md` when that brief is not the empty template.
New `tools/` runners: `design/tools.md` rule 5 (propose first). Minimum compile wiring on a moved line is allowed: `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`, and `: Type` on a line already being moved.
Gates: batch same-kind fixes, run once, at most 2 reruns (`design/tools.md` rule 10).

Work only in `/workspace/WhatDwellsBelow`. Never open the Build docs (`design/pc-offload.md`, `design/tools-build.md`, `design/tools-shims.md`, `design/tools-media.md`), the pc-offload skill, or Imagine / I2V skills. No Windows checkout, `WDB_ROOT`, or Steam Godot.

## Smokes

When a cluster needs a headless prove: `python3 tools/bot_smokes.py --phases 1,2,6` from the repo root (`--for FILE` names the covering phases). Setup downloads the official 4.7.2 Linux tools binary only if the pin is missing. Binary: `GODOT_BIN`, else `/workspace/godot/Godot_v4.7.2-stable_linux.x86_64` (the `godot` symlink may not be on PATH).
New `.gd` files need `.uid` sidecars: run the pinned binary once with `--headless --display-driver headless --audio-driver Dummy --editor --import --path . --quit`, then `git checkout -- assets docs icon.svg.import` (the import also rewrites those `.import` files; a fresh worktree needs this import once before any smoke, else P1 fails with no marker), and commit the `.uid` files only.
No editor playtest, no routine that launches Godot.
Shots and light bakes are not headless: `run_shots.py`, `run_shot_flow.py`, `run_bake_camp.py` pick the box display themselves (`python3 tools/godot_lib.py --display`). Menu/NPC proof: `bot_smokes.py --door D --flows` and `design/shot-flows.md`. `check_shot_gaps.py --changed` (run by `bot_smokes.py` unless `--no-gaps`, and by `run_build_gate.py --batch`) FAILS on a new UI state with no shot flow; add a small flow in `tools/shot-flows/` in the same PR. Published shots go to `_out/shots/<flow>/`; never write under `assets/`.

Warning sweep (User-named only): `python3 tools/bot_warnscan.py` runs every smoke area plus boot/static and exits 0 only on zero findings. It reports; it does not fix game code. `--list`, `--repeat 2`, `--findings-md PATH`. Before/after a change: `--save-baseline PATH`, then `--non-leak-diff PATH` with the same `--areas` (prints NEW and FIXED, exits 1 only on NEW). One-shot gate: `python3 tools/run_build_gate.py --batch --warnscan-baseline PATH --areas ...`. Targeted areas for a split: the smoke phases that load the file, `dungeon-load-timing`, `map-f1`, `static`.
Tools: `design/tools.md` is the catalog. The Bot runs only `A=Y` tools, as `python3 tools/X.py`, never the `.ps1` shims. Every tool ends with a `RESULT PASS|FAIL|INFO ... summary=<path>` line.

## Hard stops

No new player-facing systems, enemy types (ask the User), tunables, combat feel, editor playtest, art/I2V, locale sweeps, pause redesign, `Entity.gd`, UI framework, ECS, or flattening hostify clusters back into one oversized script. No Windows or Steam Godot; do not open the editor or enable Execution on Local Computer.
Behavior changes, drive-by renames, comment rewrites, wholesale retypes and reformats are out unless a User-named `design/grok-bot-opt.md` item lists them.
Do not walk design/ for context beyond this file and the one Job file. Do not pin weeks or run `tools/week_start.py` (human-only). Do not invent numbers.
Bot may save its own skill after two good clusters.

## After-cluster report

PR URL, squash-merge reminder, path + bytes before/after, changelog path (every PR ships one, docs/tools-only included: `design/versioning-log.md`), what is still over 10KB, next printed item, and the rough edges you hit (`design/tools.md` rule 9). Anything not fixable (outside the allowlist) goes in the PR body for the User.
