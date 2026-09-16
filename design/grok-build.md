# Grok Build session flow

Status: protocol  
Read when: Grok Build (CLI) path; every CLI instance after a gap  

## Recognize

You can write the live tree. If you cannot, you are not on this path — use the web path file.

One session family per development week. A **slice** (including one I2V clip) stays in that thread. A mid-week new CLI chat is a catch-up, not a new week.


## New week vs catch-up vs slice

| User / situation | What it is | Pin ritual |
|------------------|------------|------------|
| Opens CLI by saying **new week** (token refresh counts only if they say that) | Week N init | Yes. Follow **Week ritual** below and `design/versioning.md`. |
| Resume after corruption | Same week, sick thread | Do **not** move the web pin. Do not create a second Grok Build pin for that week. |
| Mid-week new CLI chat (fat thread, compaction, job change) | Catch-up | No pin. |
| Next slice or next I2V unit in the same thread | Slice | No pin. |

Do not pin because time passed, because the last slice ended, or because a new CLI instance started. The trigger is the User saying **new week**.

## Read order

1. the agents file, then this file. Do not re-read the agents file after that.
2. `design/protocol.md` and `design/constraints.md` only when they are not already in this session.
3. Leave-off only when it must name the next unit. It is not a boot list and must not send you back through this Read order.
4. Changelog: skip on a mid-week slice or catch-up. Open `design/versioning.md` for **new week** pins. Open `design/versioning-log.md` for changelog body shape, a revert, or when the User asks what shipped. Do not ingest every `design/changelog/{epoch}.{series}.*.md`. Do not treat `scripts/data/version.json` as the version ledger. Do not follow GitHub commit links into web-session conversations.
5. Only topic that matches the requested work. Do not open `design/README.md` to pick it. Sprite / pack / review: art_pipeline, then only the sibling it names. Before any Imagine call, load `design/isolated-media.md` (gate, not an art-pipeline job).
6. Inspect git and the live tree from **one system row** in `design/code-map.md` (`project.godot`, then the listed scenes/scripts). Do not walk `assets/` unless the task names sprites or audio.

`design/session-log.md` is not part of every boot. Read it when rewriting it at session close, when the User asks what shipped, or when leave-off is not enough to name the next unit.

Do not start by archiving or rewriting the live path. Do not resume unfinished Grok Build work from `design/sessions.md` unless the User names that work.

## Week ritual

Run this block **only** when the User said **new week**. Otherwise skip it. After the series seed / `0.N.0` lands, run `python tools/archive_prior_changelogs.py` so prior-series markdown leaves the flat `design/changelog/` folder (CI also runs it on stamp).

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

## I2V week

Sprite / I2V / paper-doll work stays on this path unless the User says otherwise. Before Imagine, load `design/isolated-media.md` only. Open art_pipeline only after the User names pack, review, or bible work.

Path-only: mid-week new CLI chat is a catch-up (no pin). A thin isolated child is not a new week. Do not `/resume` a fat art thread to “just do one more” media turn.

## Script cap

Ship floor is the **10,000 byte** cap in `design/gdscript-law.md`. Enforce it while editing. Split in that same slice with `design/refactor.md` (recipe only; do not open the Bot door from it). Stop once under 10KB. Do not chase Grok Bot’s 5KB target.

A size split MAY introduce a new same-system helper API. A new cross-system owner during a split is **Stop and propose first**.

Preferred: `powershell -File tools/check_script_cap.ps1`. Read `_logs/script-cap/summary.txt` only. Catalog: `design/pc-offload.md`.

## Archives

The Archives browser MUST ship. Title “Play” always launches the current live path.

Catalog rows (each a pinned commit, isolated per archives):

- **classic_2d** — Classic 2D
- **art_experiment** — Art experiment
- **full_3d_pass** — Full 3D Pass
- **grok_build_w1** / **grok_web_w1**
- **grok_build_w2** / **grok_web_w2**
- **grok_build_w3**
- Plus `grok_web_w{N-1}` and `grok_build_wN` rows required by `design/versioning.md` after each **new week** ritual / completion commit.

## After a slice

Preferred verify when `.gd` changed: `powershell -File tools/run_build_gate.ps1`. Read `_logs/build-gate/summary.txt` only.

Stop and report: files changed, how you verified, what is still open. Do not chain an unrelated goal.

## End of session

Update `design/sessions.md` (leave-off only). Prepend a factual entry to `design/session-log.md`. Write `design/changelog/{label}.md` for the `0.N.0` completion commit per `design/versioning.md` (body shape only; do not read older changelog files).

Those two session files are for the next Grok Build instance, not for web / chat or Grok Bot.

## Do not

- Do not dump whole files unless asked, or the file does not exist on disk yet.
- Do not claim a paste-emit workflow. This path writes the checkout.
- Do not use the web path file phases.
- Do not run a Grok Bot full-repo sweep.
- Do not commit `_logs/`. Writing tool summaries there via `design/pc-offload.md` is allowed; read only those summaries.
- Do not follow git commit links into web-session conversations.
- Do not run the week pin ritual unless the User said **new week**.
- Do not call Imagine in the game-repo cwd when `design/isolated-media.md` says to isolate.

Mid-week slice or catch-up: do not rerun the Week ritual section.
