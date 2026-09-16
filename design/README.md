# Design database

Status: index  
Read when: you need a topic file  

This folder is the documentation database for humans and agents.  
It is not one design monolith. It is not a boot file.
Never open `notes/` from an agent path.

`docs/` is the GitHub Pages web export. Never store design notes there. Player-facing changelog pages are built in CI to `/changelog/` on Pages from flat `design/changelog/*.md` plus `design/changelog/archive/*/*.md`, not stored in `docs/` on `main`. Prior series are parked under `design/changelog/archive/{epoch}.{series}/` via `tools/archive_prior_changelogs.py`.

`_logs/` holds local agent tool summaries (and optional Bot sweep notes). It is gitignored. Do not store design there and do not commit it. Catalog: `design/pc-offload.md`.

## How to use

Boot and path procedure live in `AGENTS.md` and that path’s session file.

This file is the **topic index** only. Do not open this file’s topic table “for context.” Live-path rows stay on the code map when a live file is needed. Routing edges: load-graph sketch when the User names routing work.

Open only the topic files that match the requested work. Numbers: `design/tunables.md`. Do not walk `assets/` unless the task names sprites or audio. After a behavior change, update matching file in the same slice. After a live script split, update the live code map in the same slice.

Do not open this table as a boot list. Open a topic when `design/routes.yaml` names that door / job or the User names that work.

Design doors: open the facade, then only the Job-table sibling. Isolated Imagine is a gate, not an art-pipeline job. Rules: `design/doc-refactor.md`. Oversize check: `tools/list_oversize_docs.ps1`.

Do not open art_pipeline parked attack-keyframes unless the User is resuming the attack animation keyframe pipeline. Web / chat writes `design/reuse-map.md` in Phase 7 when that is the goal.

## Document kinds

| Marker | Meaning |
|--------|---------|
| Binding design | Required behavior unless the User overrides it |
| Live snapshot | What the current live path actually does |
| Protocol | How agents must work |

## Topic map

| When the work is about… | File |
|-------------------------|------|
| Version scheme, week pins | `versioning.md` |
| Changelog body / ship label | `versioning-log.md` |
| Must / must-not, checklist | `constraints.md` |
| Vision, scope, lore | `overview.md` |
| Gamepad, KB/M, web pad, web touch, menu binds | `input.md` |
| Camera, renderer | `camera.md` |
| Avatar, move, facing | `player.md` |
| Weapons, dash, crits, adrenaline, hit coverage | `combat.md` |
| Eleven skills, XP, combat level | `skills.md` |
| Bag, gear, artifacts, extract, analyze / forge | `inventory.md` |
| Shared inventory / loadout / anvil board | `gear-ui.md` |
| Placeholdia | `hub.md` |
| Gen, floors, stream, doors, crystals | `dungeon.md` |
| Roster, AI, named, pressure | `enemies.md` |
| Mine, wood, shrine, puzzles, crystals | `interactables.md` |
| HUD, pause, recap, maps, UIs | `ui.md` |
| Secret debug, playtest, anim browser | `debug.md` |
| Music, SFX, art rules, splash | `audio-visual.md` |
| Save, web export, perf | `save-tech.md` |
| Time targets, polish, a11y | `feel.md` |
| Failure modes | `edge-cases.md` |
| Phase 1–9 checklist | `coverage.md` |
| Sprite / paper-doll door | `art-pipeline.md` |
| Bible lock, plate remap, overlays, quality bar | `art-bible.md` |
| Isolated Imagine / I2V (CLI) | `isolated-media.md` |
| I2V unit + seed + prompt | `art-i2v.md` |
| Harvest, pack, cleanup | `art-pack.md` |
| Animation Browser briefs | `art-review.md` |
| Attack body stills / coil keys (parked; User must resume) | `art-attack-keyframes.md` |
| Live code map | `code-map.md` |
| Pinned archive commits | `archives.md` |
| Suggested starts + live defaults | `tunables.md` |
Per-build player notes for the **current series** are flat `design/changelog/{label}.md`. Prior series live under `design/changelog/archive/{epoch}.{series}/`. They are not topic files. Do not open them unless `versioning.md` says to.


## House rules for editing these files

- Keep one concern per file.
- Put numbers in `tunables.md`, not buried in paragraphs.
- Mark live-only behavior under **Live snapshot**.
- Do not collapse `design/` into one document.
- When live scripts are split under the 10KB cap, update `design/code-map.md` in the same slice.
- Do not treat `design/reuse-map.md` as an owners encyclopedia. Web Phase 7 writes that brief; Bot does not log extracts there.
