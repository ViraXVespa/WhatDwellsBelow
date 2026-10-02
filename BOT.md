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

Publish with plain `git push` over HTTPS (gh credential helper) to `bot/*` or the PR branch only. Push to `dungeon-reshape` only when the User asks. No force pushes, ever. After the User squash-merges, create a fresh `bot/<flow>` branch from `origin/main` (e.g. `bot/reuse-xyz`, `bot/size-xyz`), push it with `git push -u origin bot/<flow>`, and open the PR with `gh pr create` (if that fails, GitHub MCP `create_pull_request`).

The box repo has a local git identity (Grok Bot / grok-bot@users.noreply.github.com), so plain `git commit` works. PR body edits: `gh api -X PATCH repos/<repo>/pulls/N -F body=@file` (`gh pr edit` fails on the Projects classic shutdown).

## Boot

1. Read this file. If the agents file already routed you here, do not fetch it again.
2. Run: python tools/bot_status.py
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

If this session woke because main moved: run python tools/bot_status.py first.
If over_10kb count is 0, report and stop. If over_10kb count is above 0,
open only design/grok-bot-size.md. Do not start reuse, extract, relocate,
docs, or opt from that wake. Commit on the Bot branch only. Never push main.
Never merge the PR.


Prove a cluster with:

- python tools/check_script_cap.py --git-changed
- python tools/check_load_graph.py
- python tools/bot_status.py --prove

CI: .github/workflows/bot-gate.yml
Allowlist: tools/bot_allow.txt (default deny; deny lines first)
Stale docs: the allowlist exists so unattended Bot jobs never change out-of-scope files on their own. The Bot does not edit design docs outside it. It flags stale lines in the PR body under `Stale doc lines (for the User)`: file, line, what it says, what it should say. The User edits them, and the red `Allowlist on bot branches` check on that PR can then be ignored. When the User works alongside the Bot in session and says so, the Bot may edit them.
Measure: os.path.getsize, same floor as Get-Item Length (10,000 bytes).
Touched live `scripts/**/*.gd` must ship under 10KB. Split with `design/refactor.md` (recipe only). The under-5KB target is only `design/grok-bot-size.md`. Label math: `design/versioning-log.md`.
Do not open `design/reuse-map.md` except from `design/grok-bot-reuse.md` when that brief is not the empty template.

New `tools/` runners: propose first; implement only after the User approves that runner this session.
Minimum compile wiring on a moved line is allowed: `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`, and `: Type` on a line already being moved.

Work only in `/workspace/WhatDwellsBelow` on the Bot VM. Do not open `design/pc-offload.md`. Do not load the pc-offload skill. Do not use a Windows desktop checkout, `WDB_ROOT`, or the Steam Godot path.

## Smokes

Not a boot step. Not a Job flow. When a cluster needs a headless prove,
run `python tools/bot_smokes.py --phases 1,2,6` from the repo root.
Setup downloads the official 4.7.2 Linux tools binary only if the pin is missing.
Binary: `GODOT_BIN`, else the pin `/workspace/godot/Godot_v4.7.2-stable_linux.x86_64` (the `godot` symlink may not be on PATH).
New `.gd` files need `.uid` sidecars: run the pinned binary once with `--headless --display-driver headless --audio-driver Dummy --editor --import --path . --quit`, then `git checkout -- assets`, and commit the `.uid` files only. That is the import, not an editor session.
Do not run editor playtest. Do not schedule a routine that launches Godot.

Warning sweep (User-named only): `python tools/bot_warnscan.py` runs every smoke area plus boot/static, collects Godot warnings, errors, and leaks, and exits 0 only on zero findings. It reports; it does not fix game code. `--list` shows areas, `--repeat 2` steadies leaks.
Before/after a change: `--save-baseline PATH` before, then `--non-leak-diff PATH` after (the baseline and the after run must use the same `--areas`). It ignores leaks and sites, prints NEW and FIXED, and exits 1 only on NEW.
Targeted areas for a split: the smoke phases that load the file, `dungeon-load-timing`, `map-f1`, `static`.
Facade names after a split: `python tools/facade_requal.py FILE --sym NAME=Mod` rewrites bare moved names to `Mod.NAME` (keeps BOM and line endings; `--dry-run` previews).

## Hard stops

No new player-facing systems, tunables, combat feel, editor playtest,
art/I2V, locale sweeps, or pause redesign.
Headless smokes only: `python tools/bot_smokes.py` may install the official
Godot 4.7.2 Linux tools binary under the VM pin and run phase smokes.
Do not install a Windows or Steam Godot. Do not open the editor.
Do not enable Execution on Local Computer.
Do not load Imagine / I2V / pc-offload skills. Those are Build skills on the User PC.
Bot may save its own skill after two good clusters. Skills are the account private library.
Do not walk design/ for context beyond this file and the one Job file.
Do not pin weeks or run `tools/week_start.ps1` (human-only).
Do not invent numbers.
Do not load Imagine / I2V / pc-offload skills.
Behavior changes, drive-by renames, comment rewrites, wholesale retypes, reformats
are out unless a User-named `design/grok-bot-opt.md` item lists that change.
No `Entity.gd`, UI framework, ECS, or flattening hostify clusters back into one oversized script.
Do not declare the whole sweep done and then start a second flow.

## After-cluster report

PR URL, squash-merge reminder, path + bytes before/after, changelog path if
shipping, what is still over 10KB, next printed item.
