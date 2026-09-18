# Grok Build session flow

Status: protocol  
Read when: Grok Build (CLI) path; every CLI instance after a gap  

## Recognize

You can write the live tree. If you cannot, you are not on this path — use the web path file.

One development week may run several concurrent Grok Build CLI chats. They share the week pin. A new CLI chat is not a new week.

| Role | How many | Does |
|------|----------|------|
| Slice | one or two | Named live-path work (I2V, hub, features). **Work** below. A slice (including one I2V clip) stays in its slice thread. |
| Bot notes | one per week | Park Grok Bot refactor notes with `tools/bot_opt.py`. **Bot notes session** below. |
| PC offload | one per week | Catalog / runner / skill optimizations. Habits: **Dedicated Grok Build session** in `design/pc-offload.md`. |
| Smoke tests | one per week | Create or extend smoke coverage when the User names it. Habits: **Dedicated Grok Build session** on the debug smokes job. |

Do not fold another role’s work into this thread unless the User names that work here.


## New week vs catch-up vs slice

| User / situation | What it is | Pin ritual |
|------------------|------------|------------|
| Opens CLI by saying **new week** (token refresh counts only if they say that) | Week N init | Yes. Follow **Week ritual** below and `design/versioning.md`. |
| Resume after corruption | Same week, sick thread | Do **not** move the web pin. Do not create a second Grok Build pin for that week. |
| Mid-week new CLI chat (fat thread, compaction, job change, or another concurrent role) | Catch-up | No pin. |
| Next slice or next I2V unit in the same slice thread | Slice | No pin. |

Do not pin because time passed, because the last slice ended, or because a new CLI instance started. The trigger is the User saying **new week**.

## Read order

1. the agents file, then this file. Do not re-read the agents file after that.
2. `design/protocol.md` and `design/constraints.md` only when they are not already in this session.
3. Leave-off only when it must name the next unit. It is not a boot list and must not send you back through this Read order.
4. Changelog: skip on a mid-week slice or catch-up. Open `design/versioning.md` for **new week** pins. Open `design/versioning-log.md` for changelog body shape, a revert, or when the User asks what shipped. Do not ingest every `design/changelog/{epoch}.{series}.*.md`. Do not treat `scripts/data/version.json` as the version ledger. Do not follow GitHub commit links into web-session conversations.
5. Only topic that matches the requested work. Do not open `design/README.md` to pick it. Sprite / pack / review: art_pipeline, then only the sibling it names. Before any Imagine call, load `design/isolated-media.md` (gate, not an art-pipeline job).
6. Git inventory is `powershell -File tools/list_changed.ps1` (optional `-Head`). Live tree from **one** `python tools/list_code_map_row.py --path <one live script>`. Read those summaries only. Open a `.gd` body when you are about to patch it. Do not paste `git status` / `git log` into the thread. Do not walk `assets/` unless the task names sprites or audio. Tree search is `tools/list_xref.ps1`, not the grep tool, unless that file is already open for edit. No `python -c` (use `write_utf8_file.py` / `run_agent_py.ps1`).

`design/session-log.md` is not part of every boot. Read it when rewriting it at session close, when the User asks what shipped, or when leave-off is not enough to name the next unit.

Do not start by archiving or rewriting the live path. Do not resume unfinished Grok Build work from `design/sessions.md` unless the User names that work.

## Week ritual

Run this block **only** when the User said **new week**. Otherwise skip it. After the series seed / `0.N.0` lands, run `python tools/archive_prior_changelogs.py` so prior-series markdown leaves the flat `design/changelog/` folder (CI also runs it on stamp). Then run `powershell -File tools/clean_agent_logs.ps1 -NewWeek` so `_logs/sess`, patch-scratch, apply.lock, and leftover singleton summaries start empty. Job cycle (gather once, change once, prove once): `design/protocol.md`.

Follow `design/versioning.md`. In short:

- Pin current `main` as `grok_web_w{N-1}` (Grok Web Results for the completed week).
- Do not pin `grok_build_wN` until the User’s completion commit (`0.N.0`).
- Resume-after-corruption does not move the web pin.
- Do not create any other archive unless the User asks.

Archived builds are pinned commits in `scripts/data/archive_catalog.json`, not project trees under `archives/`.

## Work

Implement the requested work by patching the live path in place.

This path is unconstrained on **implementation** inside one system: new helpers, same-system APIs, and local module shape are in scope when they ship the asked work more cleanly. Product scope stays locked (`design/constraints.md`, `design/protocol.md`).

**Just do:** add, rename, or replace helpers and APIs inside the same system; decide code structure inside one system without asking.

**Stop and propose first:** a new **cross-system** owner; replacing a **named live architecture** that design already pins (camera, dungeon gen, gear board, debug menu, save format, input router); a greenfield rewrite; copying archive scripts/scenes over live.

Still required:

- MUST extend and reuse live scenes, scripts, and architecture unless they contradict binding design or the User’s request.
- The live path remains the orthographic Camera3D system in camera until the User accepts a camera rework.
- Match surrounding style unless a just-do change or an accepted rework replaces it. Tabs. Types: `design/gdscript-law.md`.
- Open numbers and player-facing ambiguity: `design/protocol.md`.

Web / chat and Grok Bot leashes do not apply here.

Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

## Weekly role sessions

Bot notes, PC offload, and Smoke tests each get **one CLI per development week**, sized to last about one quota. Keep those threads thin:

- Boot once (this file + law pair). Do not re-fetch a file already in the loaded set.
- Catalog summaries only. When the User names a thing, at most one `list_xref` and/or one code-map row. Do not walk the tree into chat.
- Bot-notes queue: `--list` (titles). `--id` only when changing that item. Do not open the queue file.
- Do not paste whole `.gd` / `.md` / tool bodies, raw Godot logs, or growing inventories back into the thread.
- After a slice: stop. Do not recap the whole week into the next turn.

## Bot notes session

Weekly CLI. Parks notes for Grok Bot. Does not implement those items and does not open a Bot PR.

- Park with `python tools/bot_opt.py` (`--add` / `--replace` / `--list` / `--id`). Read `_logs/bot-opt/summary.txt` only.
- Keep a general layout sense from the loaded set, one code-map row, and the named search. Expand the User’s wording enough that Bot can start (likely paths, owner, an obvious in/out). Ask once if a gap is obvious.
- Do not do Bot’s job: no full-tree inventory, no pass plan, no ranked worklist dumped into the item. Bot investigates, plans, and implements.
- Do not overwrite a parked item’s body unless the User asks.
- May add or fix the queue runner and catalog row when that is the named work.
- Do not run Imagine / I2V, a Bot size sweep, or an unrelated live-path slice.
- After a park: stop and report the id. Do not chain a second note unless the User names it.

## PC-offload session

Weekly CLI. Implement catalog / runner / skill work the User names. New runner: propose and wait (catalog rule). Do not Imagine, do not open a Bot PR, do not week-pin.

Habits (typical slice, just-do extras, extra do-nots) live in `design/pc-offload.md` under **Dedicated Grok Build session**. Slice, Bot-notes, and Smoke-tests chats must not rewrite them.

## Smoke-tests session

Weekly CLI. Create or extend smoke coverage the User names (`scripts/debug/smoke.gd` and phase helpers). Run via the catalog; read only those summaries. New runner: propose and wait (catalog rule). Do not Imagine, do not open a Bot PR, do not week-pin. Do not invent coverage the User did not name.

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
- Plus `grok_web_w{N-1}` and `grok_build_wN` rows required by `design/versioning.md` after each **new week** ritual / completion commit.

## After a slice

Preferred verify when `.gd` changed: `powershell -File tools/run_build_gate.ps1`. Read `_logs/build-gate/summary.txt` only.

Stop and report: files changed, how you verified, what is still open. Do not chain an unrelated goal.

## End of session

Rewrite only **this role’s** block in `design/sessions.md` (leave-off only). Do not wipe another role’s pickup. Prepend a factual entry to `design/session-log.md` and name the role (slice / Bot notes / PC offload / smoke tests). Write `design/changelog/{label}.md` for the `0.N.0` completion commit per `design/versioning.md` (body shape only; do not read older changelog files).

Those two session files are for later Grok Build instances, not for web / chat or Grok Bot.

## Do not

- Do not dump whole files unless asked, or the file does not exist on disk yet.
- Do not grep `scripts/`, `design/`, `tools/`, or `scenes/` with the built-in grep tool; use `tools/list_xref.ps1`.
- Do not paste `git status` / `git log` into the thread; use `tools/list_changed.ps1`.
- Do not run `python -c` for repo work; use `tools/write_utf8_file.py` / `tools/run_agent_py.ps1`.
- Do not claim a paste-emit workflow. This path writes the checkout.
- Do not use the web path file phases.
- Do not run a Grok Bot full-repo sweep.
- Do not commit `_logs/`. Writing tool summaries there via `design/pc-offload.md` is allowed; read only those summaries.
- Do not follow git commit links into web-session conversations.
- Do not run the week pin ritual unless the User said **new week**.
- Do not call Imagine in the game-repo cwd when `design/isolated-media.md` says to isolate.

Mid-week slice or catch-up: do not rerun the Week ritual section.
