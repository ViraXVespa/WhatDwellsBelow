# Grok Build session flow

Status: protocol  
Read when: Grok Build (CLI) path; every CLI instance after a gap  

## Recognize

You can write the live tree. If you cannot, you are not on this path — use the web path file.

One development week may run several concurrent Grok Build CLI chats. A new CLI chat is not a new week.

| Role | How many | Does |
|------|----------|------|
| Slice | one or two | Named live-path work (I2V, hub, features). **Work** below. A slice (including one I2V clip) stays in its slice thread. |
| Bot notes | as named sessions in one instance | Park Grok Bot refactor notes with `tools/bot_opt.py`. **Bot notes session** below. |
| PC offload | as named sessions in one instance | Catalog / runner / skill optimizations. Habits: **Dedicated Grok Build session** in `design/pc-offload.md`. |
| Smoke tests | as named sessions in one instance | Create or extend smoke coverage when the User names it. Habits: **Dedicated Grok Build session** on the debug smokes job. |

Do not fold another role’s work into this thread unless the User names that work here.


## Catch-up vs slice

| User / situation | What it is | Pin |
|------------------|------------|-----|
| Resume after corruption | Same week, sick thread | Do **not** move the web pin. Do not create a second Grok Build pin for that week. |
| Mid-week new CLI chat (fat thread, job change, or another concurrent role) | Catch-up | No pin. |
| Next slice or next I2V unit in the same slice thread | Slice | No pin. |

Do not pin because time passed, because the last slice ended, or because a new CLI instance started. Pins are User-only.

## Read order

1. the agents file, then this file. Do not re-read the agents file after that.
2. `design/protocol.md` and `design/constraints.md` only when they are not already in this session.
3. Name the next unit only when the User asks. It is not a boot list and must not send you back through this Read order.
4. Changelog: skip on a mid-week slice or catch-up. Open `design/versioning.md` only when the User named a pin or archive. Open `design/versioning-log.md` for changelog body shape, a revert, or when the User asks what shipped. Do not ingest every `design/changelog/{epoch}.{series}.*.md`. Do not treat `scripts/data/version.json` as the version ledger. Do not follow GitHub commit links into web-session conversations.
5. Only topic that matches the requested work. Do not open `design/README.md` to pick it. Sprite / pack / review: art_pipeline, then only the sibling it names. Before any Imagine call, load `design/isolated-media.md` (gate, not an art-pipeline job).
6. Git inventory is `powershell -File tools/list_changed.ps1` (optional `-Head`). Live tree from **one** `python tools/list_code_map_row.py --path <one live script>`. Read those summaries only. Open a `.gd` body when you are about to patch it. Do not paste `git status` / `git log` into the thread. Do not walk `assets/` unless the task names sprites or audio. Tree search is `tools/list_xref.ps1`, not the grep tool, unless that file is already open for edit. No `python -c` (use `write_utf8_file.py` / `run_agent_py.ps1`).

git is not part of every boot. Read it when the User asks what shipped, or when git plus `_logs/sess/` is not enough to name the next unit.

Do not start by archiving or rewriting the live path. Do not resume unfinished Grok Build work from git status unless the User names that work.

Archived builds are pinned commits in `scripts/data/archive_catalog.json`, not project trees under `archives/`. Do not create archive pins unless the User already named that pin.

## Work

First message names the area (door, job, or live system). Run `powershell -File tools/start_build_slice.ps1 -Door <door>` (or `-Job` / `-Area`). Gather read-only on the live tree per `design/build-job-cycle.md`. Then the User launches the FORK line from that postcard (`grok --worktree=... --ref main -r <gather-id> --fork-session`). Change and prove only in that worktree. Do not take the live `--path` while the User editor holds it. CLI does not auto-resume the pin; the postcard is the return argv. Red retry is the RETRY line (`grok -r <id> --fork-session`), not another patch on the guilty transcript.

This path is unconstrained on **implementation** inside one system: new helpers, same-system APIs, and local module shape are in scope when they ship the asked work more cleanly. Product scope stays locked (`design/constraints.md`, `design/protocol.md`).

**Just do:** add, rename, or replace helpers and APIs inside the same system; decide code structure inside one system without asking. A new helper file or 10KB split is not a new player-facing system.

**Stop and propose first:** a new **cross-system** owner; replacing a **named live architecture** that design already pins (camera, dungeon gen, gear board, debug menu, save format, input router); a greenfield rewrite; copying archive scripts/scenes over live.

Still required:

- MUST extend and reuse live scenes, scripts, and architecture unless they contradict binding design or the User’s request.
- The live path remains the orthographic Camera3D system in camera until the User accepts a camera rework.
- Match surrounding style unless a just-do change or an accepted rework replaces it. Tabs. Types: `design/gdscript-law.md`.
- Open numbers and player-facing ambiguity: `design/protocol.md`.

Web / chat and Grok Bot leashes do not apply here.

Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

## Weekly role sessions

Bot notes, PC offload, and Smoke tests are **sessions in one Grok instance**, kept thin enough to last about one quota. Keep those threads thin:

- Boot once (this file + law pair). Do not re-fetch a file already in the loaded set.
- Catalog summaries only. When the User names a thing, at most one `list_xref` and/or one code-map row. Do not walk the tree into chat.
- Bot-notes queue: `--list` (titles). `--id` only when changing that item. Do not open the queue file.
- Do not paste whole `.gd` / `.md` / tool bodies, raw Godot logs, or growing inventories back into the thread.
- After a slice: stop. Do not recap the whole week into the next turn.

## Bot notes session

Session. Parks notes for Grok Bot. Does not implement those items and does not open a Bot PR.

- Park with `python tools/bot_opt.py` (`--add` / `--replace` / `--list` / `--id`). Read `_logs/bot-opt/summary.txt` only.
- Keep a general layout sense from the loaded set, one code-map row, and the named search. Expand the User’s wording enough that Bot can start (likely paths, owner, an obvious in/out). Ask once if a gap is obvious.
- Do not do Bot’s job: no full-tree inventory, no pass plan, no ranked worklist dumped into the item. Bot investigates, plans, and implements.
- Do not overwrite a parked item’s body unless the User asks.
- May add or fix the queue runner and catalog row when that is the named work.
- Do not run Imagine / I2V, a Bot size sweep, or an unrelated live-path slice.
- After a park: stop and report the id. Do not chain a second note unless the User names it.

## PC-offload session

Session. Implement catalog / runner / skill work the User names. New runner: propose and wait (catalog rule). Do not Imagine, do not open a Bot PR, do not week-pin.

Habits (typical slice, just-do extras, extra do-nots) live in `design/pc-offload.md` under **Dedicated Grok Build session**. Slice, Bot-notes, and Smoke-tests chats must not rewrite them.

## Smoke-tests session

Session. Create or extend smoke coverage the User names (`scripts/debug/smoke.gd` and phase helpers). Run via the catalog; read only those summaries. New runner: propose and wait (catalog rule). Do not Imagine, do not open a Bot PR, do not week-pin. Do not invent coverage the User did not name.

Habits (typical slice, just-do extras, extra do-nots) live under **Dedicated Grok Build session** on the debug smokes job. Slice, Bot-notes, and PC-offload chats must not rewrite them.

## I2V week

Sprite / I2V / paper-doll work stays on this path unless the User says otherwise. Before Imagine, load `design/isolated-media.md` only. Open art_pipeline only after the User names pack, review, or bible work.

Path-only: mid-week new CLI chat (including a concurrent role) is a catch-up (no pin). A thin isolated child is not a new week. Do not `/resume` a fat art thread to “just do one more” media turn. I2V stays in a slice thread, not Bot notes, PC offload, or smoke tests.

## Script size

Do not measure live `.gd` bytes. Do not open `design/refactor.md` because a file grew. Do not split a script to satisfy the 10KB ship floor. Do not run `tools/check_script_cap.ps1`.

The 10KB floor and the 5KB sweep live in `design/gdscript-law.md` and the Bot size job. Over-cap files MAY land on `main`. Grok Bot size sweep is the owner.

Same-system helpers and APIs for the asked feature remain **Just do**. That is feature shape, not a cap split.
Before opening many untouched files, use the pc-offload skill and `design/pc-offload.md`. Read only the listed summary.

## Archives

The Archives browser MUST ship. Title “Play” always launches the current live path.

Catalog rows (each a pinned commit, isolated per archives):

- **classic_2d** — Classic 2D
- **art_experiment** — Art experiment
- **full_3d_pass** — Full 3D Pass
- **grok_build_w1** / **grok_web_w1**
- **grok_build_w2** / **grok_web_w2**
- **grok_build_w3** / **grok_web_w3**
- **grok_build_w4** — pin on the User’s `0.4.0` completion SHA (do not invent)
- Plus `grok_web_w{N-1}` and `grok_build_wN` rows required by `design/versioning.md` after a User pin or completion commit.

## After a slice

Preferred verify when `.gd` changed: `powershell -File tools/run_build_gate.ps1`. Read `_logs/build-gate/summary.txt` only.

Stop and report: files changed, how you verified, what is still open. If prove was red: do not take another change turn in this session. Tell the User to launch the RETRY line from the slice-boot postcard (or skip). Two reds, then stop. Fork is the return; do not keep patching the guilty transcript.

## End of session

Stop. Report files changed and how verified. Pickup is git plus `_logs/sess/<Grok session id>/`. Write `design/changelog/{label}.md` for the `0.N.0` completion commit per `design/versioning.md` (body shape only; do not read older changelog files).

## Do not

- Do not dump whole files unless asked, or the file does not exist on disk yet.
- Do not grep `scripts/`, `design/`, `tools/`, or `scenes/` with the built-in grep tool; use `tools/list_xref.ps1`.
- Do not paste `git status` / `git log` into the thread; use `tools/list_changed.ps1`.
- Do not run `python -c` for repo work; use `tools/write_utf8_file.py` / `tools/run_agent_py.ps1`.
- This path writes the checkout.
- - - Do not commit `_logs/`. Writing tool summaries there via `design/pc-offload.md` is allowed; read only those summaries.
- - - Do not call Imagine in the game-repo cwd when `design/isolated-media.md` says to isolate.

Mid-week slice or catch-up: do not create pins.
