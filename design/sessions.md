# Grok Build leave-off

Status: working notes  
Read when: rewriting this leave-off, or the User asked what the next Build unit is  

This is the Grok Build leave-off. It is **not** binding game design. Binding behavior stays in the topic files. The live tree is still the source of truth for shipping code.

This file is leave-off, not a boot list. Do not paste a path required-read list back in here. Do not name path session files from this leave-off.

Keep this file short. History goes in `design/session-log.md`.

The User does other work between weeks (git commits, stills, systems). **Image-to-video and complex animation packing stay in Grok Build** unless the User says otherwise.

Do not resume unfinished work from this file unless the User names that work. A listed next-work line is a hint, not a start order.


## Leave-off

Concurrent Grok Build CLIs share this file. Each chat rewrites **only its role block**.

### Slice

**Last closed:** 2026-09-17  
**Closed because:** Week 4 Grok Build completion (`0.4.0`). Token limit. Waiting for the User to commit and send the SHA.

Pickup: after the User sends the `0.4.0` SHA, write `grok_build_w4` into `archive_catalog.json`, tag `archive/grok-build-w4`, and put that SHA on `design/versioning.md` Week 4 open. `powershell -File tools/list_changed.ps1` (optional `-Head`) and one code-map row for named work. Do not assume this file matches disk. Do not read `design/changelog/` on a mid-week slice.

Likely next (only if the User names it):

1. **Pin `grok_build_w4`.** User commits `0.4.0` (uncommitted week-4 tree + `design/changelog/0.4.0.md`) and sends the SHA. Do **not** invent it. `grok_web_w3` stays `b87bd169fb4dce839753a37cb8dbb7a837d82f48`. CI stamps `version.json` to `0.4.0`; then `python tools/archive_prior_changelogs.py` is idempotent (`0.3.*` already under `design/changelog/archive/0.3/`).
2. **Replace all live attack I2V** (still placeholders). Every Down `atk_great_axe` / `atk_staff` / `atk_longbow` on male and female. Between-week commits include Attack Animation Pipeline Rework Pt. 1 and Attack Animation Keyframes Pt 2 — inspect live before regenerating. User will bring a new I2V pipeline. Detail: `design/session-log.md` (2026-09-09 animation handoff).
3. Next CLI opened by saying **new week** is week 5 init: pin then-current `main` as `grok_web_w4`. User packs walks from `_src/walk_final/` when they choose. Special / gather / death / Dispel / overlays / remaining attack facings still later.

Do not redo unless asked:

- Week 4 init / moving `grok_web_w3`. The pin is `b87bd169fb4dce839753a37cb8dbb7a837d82f48`.
- Inventing a `grok_build_w4` SHA. Wait for the User’s completion commit.
- Enter-dungeon cover hitch: `cover_enter` → `wait_painted` (always-timer + two `frame_post_draw`) before save / `go_dungeon`. Do not `force_draw` on the GUI stack that set the cover.
- Streaming world props / lazy map / crystal spur early-out / Floor Guardian as a stream job (P5 still dumps props).
- Plaza roof / tarp / awning tiles and guild russet remap.
- Mid-action video-extract as an I2V seed.
- Prompting I2V with pack-slot / frame-index language.
- Rewriting great-axe MOTION into geometry-only / no-haft / belly-fist language (destroyed motion).
- Re-keying idle with remap + `spill_flood=False`.
- Replacing dungeon clerks with Extraction Gates.
- Splash graffiti treatment (Proudly struck, Shamelessly tag).
- Playtest think-script parse errors (`playtest_ai_think.gd` local helpers).
- Downscaling world stills before chroma key (hurts plate detection). Key at native size, then nearest-neighbor fit.
- 50% quadrant crops of single-subject world stills.
- Consolas / TTF on the Welcome banner.
- Inventing a `grok_build_w3` SHA. The pin is `e7a9d2cf56965b711dc5b22eb7735a1875d96407`.
- Running `tools/archive_prior_changelogs.py` while `version.json` is still `0.3.43` (it would park `0.4.0.md`).

### Bot notes

**Open:** 2026-09-17. Weekly CLI. Parks Grok Bot refactor notes (`tools/bot_opt.py`). Expand from a thin layout check; ask if a gap is obvious. Does not implement those items.

Pending: opt-001 (reusable markdown formatting library), opt-002 (shared path/load helper for `res://` strings), opt-003 (shared helper for Title/Placeholdia/Dungeon load legs). Do not overwrite those bodies unless the User asks.

Last: Concurrent roles are binding (slice / Bot notes / PC offload / Smoke tests). Dedicated habits are filled; this thread dropped leftover FILL/skeleton language.

### PC offload

**Open:** 2026-09-17. Weekly dedicated CLI. Keep the thread quota-thin.

Last: Dedicated Grok Build skeleton filled from this thread. Code-map patch/check runners already shipped.

Pickup: named catalog / runner / skill job only. Catalog summaries. Propose a new runner and wait.

Likely next: only if the User names another catalog/runner/skill job.

### Smoke tests

**Open:** 2026-09-17. Weekly dedicated CLI. Keep the thread quota-thin.

Last: Dedicated Grok Build skeleton filled from this thread (dungeon map dump + Placeholdia→Dungeon load-timing).

Pickup: named coverage add only. Catalog summaries. Propose a new runner and wait.

Likely next: only if the User names another smoke.

## How to maintain

**Session start** (including mid-week catch-up / concurrent role):

- Read this leave-off (this role’s block first).
- Diff live vs git via `tools/list_changed.ps1`.
- Ask once if between-week work conflicts with a *named* next slice.
- Do not run the week pin ritual unless the User said **new week**.

**Session end:**

- Rewrite **only this role’s** block (date, why we stopped, pickup, likely next, do-not-redo).
- Prepend a factual entry to `design/session-log.md` and name the role. Name I2V units: gender, facing, action, seed/path. Do not narrate clips.
- Binding behavior changes still go in matching file, not only here.
