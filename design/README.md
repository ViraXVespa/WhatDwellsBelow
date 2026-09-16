# Design database

Status: index  
Read when: you need a topic file  

This folder is the documentation database for humans and agents.  
It is not one Game Design Document. It is not a boot file.

`docs/` is the GitHub Pages web export. Never store design notes there. Player-facing changelog pages are built in CI to `/changelog/` on Pages from flat `design/changelog/*.md` plus `design/changelog/archive/*/*.md`, not stored in `docs/` on `main`. Prior series are parked under `design/changelog/archive/{epoch}.{series}/` via `tools/archive_prior_changelogs.py`.

`_logs/` holds local agent tool summaries (and optional Bot sweep notes). It is gitignored. Do not store design there and do not commit it. Catalog: `design/pc-offload.md`.

## How to use

Boot and path procedure live in `AGENTS.md` and that path’s session file.

This file is the **topic index** only. Do not open this file’s topic table “for context.” Live-path rows stay on the code map when a live file is needed. Routing edges: `design/load-graph.md` when the User names routing work.

Open only the topic files that match the requested work. Numbers: `design/tunables.md`. Do not walk `assets/` unless the task names sprites or audio. After a behavior change, update the matching topic file in the same slice. After a live script split, update the live code map in the same slice.

`See also:` lines and index rows are not a read list. Open a listed path only when that file’s `Read when` matches, a Job table names it, or the User names that work.

Design doors (open the Job-table sibling only): `design/art-pipeline.md`, `design/isolated-media.md`, `design/ui.md`, `design/debug.md`, `design/input.md`, `design/inventory.md`, `design/grok-bot-session.md`. Rules: `design/doc-refactor.md`. Oversize check: `tools/list_oversize_docs.ps1`.

Do not open `design/art-attack-keyframes.md` unless the User is resuming the attack animation keyframe pipeline. Web / chat writes `design/reuse-map.md` in Phase 7 when that is the goal.

## Document kinds

| Marker | Meaning |
|--------|---------|
| Binding design | Required behavior unless the User overrides it |
| Live snapshot | What the current live path actually does |
| Protocol | How agents must work |

## Topic map

| When the work is about… | File | Old GDD home |
|-------------------------|------|----------------|
| Version scheme, week pins | `versioning.md` | — |
| Changelog body / ship label | `versioning-log.md` | — |
| Must / must-not, checklist | `constraints.md` | Hard constraints, success, App. B |
| Vision, scope, lore | `overview.md` | §§1–3 |
| Gamepad, KB/M, web pad, web touch, menu binds | `input.md` | §4 input |
| Camera, renderer | `camera.md` | §4 camera / renderer |
| Avatar, move, facing | `player.md` | §5 |
| Weapons, dash, crits, adrenaline, hit coverage | `combat.md` | §6 |
| Eleven skills, XP, combat level | `skills.md` | §7 |
| Bag, gear, artifacts, extract, analyze / forge | `inventory.md` | §8 |
| Shared inventory / loadout / anvil board | `gear-ui.md` | §8 / §13 |
| Placeholdia | `hub.md` | §9 |
| Gen, floors, stream, doors, crystals | `dungeon.md` | §10 |
| Roster, AI, named, pressure | `enemies.md` | §11 |
| Mine, wood, shrine, puzzles, crystals | `interactables.md` | §12 |
| HUD, pause, recap, maps, UIs | `ui.md` | §13 player UI |
| Secret debug, playtest, anim browser | `debug.md` | §13 debug |
| Music, SFX, art rules, splash | `audio-visual.md` | §14, App. E |
| Save, web export, perf | `save-tech.md` | §15 |
| Time targets, polish, a11y | `feel.md` | §16 |
| Failure modes | `edge-cases.md` | §17 |
| Phase 1–9 checklist | `coverage.md` | §18 |
| Sprite / paper-doll door | `art-pipeline.md` | §19, App. C–D |
| Bible lock, plate remap, overlays, quality bar | `art-bible.md` | §19.0–19.1 |
| Isolated Imagine / I2V (CLI) | `isolated-media.md` | — |
| I2V unit + seed + prompt | `art-i2v.md` | §19.2 |
| Harvest, pack, cleanup | `art-pack.md` | §19.4 |
| Animation Browser briefs | `art-review.md` | §19.6 |
| Attack body stills / coil keys (parked; User must resume) | `art-attack-keyframes.md` | §19.2 |
| Live code map | `code-map.md` | — |
| Pinned archive commits | `archives.md` | §20 |
| Suggested starts + live defaults | `tunables.md` | App. A + live `balance.gd` |
Per-build player notes for the **current series** are flat `design/changelog/{label}.md`. Prior series live under `design/changelog/archive/{epoch}.{series}/`. They are not topic files. Do not open them unless `versioning.md` says to.


## House rules for editing these files

- Keep one concern per file.
- Put numbers in `tunables.md`, not buried in paragraphs.
- Mark live-only behavior under **Live snapshot**.
- Do not reintroduce a single 100KB GDD.
- When live scripts are split under the 10KB cap, update `design/code-map.md` in the same slice.
- Do not treat `design/reuse-map.md` as an owners encyclopedia. Web Phase 7 writes that brief; Bot does not log extracts there.
