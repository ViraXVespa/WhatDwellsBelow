# BOT.md

Status: protocol
Read when: Grok Bot (The Refactorer) boots or starts a job

This is the only Bot constitution. Grok Build and web/chat keep their path files.
Do not collapse those into this file.
Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.
## Workspace

Clone github.com/ViraXVespa/WhatDwellsBelow to /workspace/WhatDwellsBelow.
Work that tree. Work a fresh `bot/<flow>` branch per flow. One open Bot PR. Commit per cluster.
User squash-merges. Never push main. Never merge the PR.

Publish with plain `git push` over HTTPS (gh credential helper) to `bot/*` or the PR branch only. No force pushes, ever. After the User squash-merges, create a fresh `bot/<flow>` branch from `origin/main` (e.g. `bot/reuse-xyz`, `bot/size-xyz`), push it with `git push -u origin bot/<flow>`, and open the PR with `gh pr create` (if that fails, GitHub MCP `create_pull_request`).

The box repo has a local git identity (Grok Bot / grok-bot@users.noreply.github.com), so plain `git commit` works. PR body edits: `gh api -X PATCH repos/<repo>/pulls/N -F body=@file` (`gh pr edit` fails on the Projects classic shutdown).

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

If the User names more than one job, ask which flow this session is. One flow, one PR, then stop.

If this session woke because main moved: run python3 tools/bot_status.py first.
If over_10kb count is 0, report and stop. If over_10kb count is above 0,
open only design/grok-bot-size.md. Do not start reuse, extract, relocate,
docs, or opt from that wake. Commit on the Bot branch only. Never push main.
Never merge the PR.


Prove a cluster with:

- python3 tools/check_script_cap.py --git-changed
- python3 tools/check_load_graph.py
- python3 tools/bot_status.py --prove
- python3 tools/check_code_map.py (no new UNMAPPED for files you touched; older ones are expected)
- python3 tools/check_tool_docs.py (only when `tools/` or the catalog changed); `python3 tools/check_tool_docs.py --stale-refs` after any doc edit that names paths

CI: .github/workflows/bot-gate.yml
Allowlist: tools/bot_allow.txt (default deny; deny lines first)
Stale docs: the allowlist exists so unattended Bot jobs never change out-of-scope files on their own. The Bot does not edit design docs outside it. It flags stale lines in the PR body under `Stale doc lines (for the User)`: file, line, what it says, what it should say. The User edits them, and the red `Allowlist on bot branches` check on that PR can then be ignored. When the User works alongside the Bot in session and says so, the Bot may edit them.
Measure: os.path.getsize, same floor as Get-Item Length (10,000 bytes).
Touched live `scripts/**/*.gd` must ship under 10KB. Split with `design/refactor.md` (recipe only). The under-5KB target is only `design/grok-bot-size.md`. Label math: `design/versioning-log.md`.
Do not open `design/reuse-map.md` except from `design/grok-bot-reuse.md` when that brief is not the empty template.

New `tools/` runners: `design/tools.md` rule 5 (propose first; implement after the User approves).
Minimum compile wiring on a moved line is allowed: `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`, and `: Type` on a line already being moved.

Work only in `/workspace/WhatDwellsBelow` on the Bot VM. Never open the Build docs (`design/pc-offload.md`, `design/tools-build.md`, `design/tools-media.md`), the pc-offload skill, or Imagine / I2V skills. Do not use a Windows desktop checkout, `WDB_ROOT`, or the Steam Godot path.

## Smokes

Not a boot step. Not a Job flow. When a cluster needs a headless prove,
run `python3 tools/bot_smokes.py --phases 1,2,6` from the repo root.
Setup downloads the official 4.7.2 Linux tools binary only if the pin is missing.
Binary: `GODOT_BIN`, else the pin `/workspace/godot/Godot_v4.7.2-stable_linux.x86_64` (the `godot` symlink may not be on PATH).
New `.gd` files need `.uid` sidecars: run the pinned binary once with `--headless --display-driver headless --audio-driver Dummy --editor --import --path . --quit`, then `git checkout -- assets`, and commit the `.uid` files only. That is the import, not an editor session.
Do not run editor playtest. Do not schedule a routine that launches Godot.
Shots and light bakes are not headless: `run_shots.py`, `run_shot_flow.py` and `run_bake_camp.py` pick the box display themselves (`$DISPLAY`, a live X socket, else `xvfb-run`; `python3 tools/godot_lib.py --display`). Menu/NPC proof: `bot_smokes.py --door D --flows` (headless asserts) and `design/shot-flows.md`. Required Bot gate: `check_shot_gaps.py --changed` (run by `bot_smokes.py` unless `--no-gaps`, and by `run_build_gate.py --batch`) FAILS on a new UI state with no shot flow; add a small flow in `tools/shot-flows/` in the same PR. Published shots go to `_out/shots/<flow>/`; never write under `assets/` (Grok Build places those).

Warning sweep (User-named only): `python3 tools/bot_warnscan.py` runs every smoke area plus boot/static, collects Godot warnings, errors, and leaks, and exits 0 only on zero findings. It reports; it does not fix game code. `--list` shows areas, `--repeat 2` steadies leaks.
Findings by kind: `--findings-md PATH`. One-shot gate for a fix batch: `python3 tools/run_build_gate.py --batch --warnscan-baseline PATH --areas ...`. Before/after a change: `--save-baseline PATH` before, then `--non-leak-diff PATH` after (the baseline and the after run must use the same `--areas`). It ignores leaks and sites, prints NEW and FIXED, and exits 1 only on NEW.
Targeted areas for a split: the smoke phases that load the file, `dungeon-load-timing`, `map-f1`, `static`.
Tools: `design/tools.md` is the catalog (single source: what each tool does, `--help` for flags, gotchas, which are allowlisted). The Bot runs only tools marked `A=Y` there, always as `python3 tools/X.py`; the `.ps1` files are shims the Bot never runs. Tools, not scratches: update the tool or propose one; a scratch is for a niche one-off, in temp. Every tool ends with a `RESULT PASS|FAIL|INFO ... summary=<path>` line.

## Hard stops

No new player-facing systems, tunables, combat feel, editor playtest,
art/I2V, locale sweeps, or pause redesign.
Smokes are headless (see Smokes); shots and bakes use the box display. Do not install a Windows or Steam Godot. Do not open the editor.
Do not enable Execution on Local Computer.
Bot may save its own skill after two good clusters. Skills are the account private library.
Do not walk design/ for context beyond this file and the one Job file.
Do not pin weeks or run `tools/week_start.py` (human-only).
Do not invent numbers.
Behavior changes, drive-by renames, comment rewrites, wholesale retypes, reformats
are out unless a User-named `design/grok-bot-opt.md` item lists that change.
No `Entity.gd`, UI framework, ECS, or flattening hostify clusters back into one oversized script.
Do not declare the whole sweep done and then start a second flow.

## After-cluster report

PR URL, squash-merge reminder, path + bytes before/after, changelog path if
shipping, what is still over 10KB, next printed item.

No loops: batch same-kind fixes, run gates once per batch, at most 2 reruns, then report (`design/tools.md` rule 10). Rough edges: the rule is `design/tools.md` rule 9; apply it at the end of each file in a size pass. Anything not fixable (outside the allowlist) goes in the PR body for the User.
