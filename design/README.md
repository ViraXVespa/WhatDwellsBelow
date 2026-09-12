# Design database

Status: index  
Read when: starting any session, or when you do not know which file to open  
See also: `AGENTS.md`, `design/protocol.md`, `design/web-session.md`, `design/grok-build.md`, `design/grok-bot-session.md`, `design/refactor.md`, `design/versioning.md`

This folder is the documentation database for humans and agents.  
It is not one Game Design Document.

`docs/` is the GitHub Pages web export. Never store design notes there. Player-facing changelog pages are built in CI to `/changelog/` on Pages from `design/changelog/*.md`, not stored in `docs/` on `main`.

`_logs/` is local Grok Bot sweep notes. It is gitignored. Do not store design there and do not commit it.

## How to use

1. Grok agents read `design/protocol.md` and `design/constraints.md` first. Grok Bot does not — after `AGENTS.md` it follows `design/grok-bot-session.md` only.
2. On a fresh Grok Build instance after a gap, follow `design/grok-build.md`: read `design/sessions.md` (leave-off), then every `design/changelog/{current epoch}.{current series}.*.md`, then inspect git / the live tree from the code map below. Do not pin unless the User said **new week**. Do not follow git commit links into web-session conversations. The User works between sessions.
3. Web / chat: after the repo-review message, follow `design/web-session.md`. `design/sessions.md` is context only. Do not read `design/session-log.md`. Do not read `design/changelog/` in Phase 1–3 unless the named work is versioning, a named past build, or a revert.
4. Grok Bot: follow `design/grok-bot-session.md` and `design/refactor.md`. Do not read topic files, `design/sessions.md`, `design/session-log.md`, or `design/changelog/`.
5. Open only the topic files that match the requested work.
6. Use `design/tunables.md` for numbers.
7. Use the code map below for live scripts. Do not walk `assets/` unless the task names sprites or audio.
8. After a behavior change, update the matching topic file in the same slice. End of a Grok Build session: update `design/sessions.md`, prepend `design/session-log.md`, and write the series-open changelog file when the User commits `0.N.0`. End of a web / chat goal: finish Phase 7 in `design/web-session.md`, including one `design/changelog/{label}.md` when the goal shipped a visible change. Grok Bot does not write those files; optional notes go in `_logs/grok-bot-sweep.md` only.

Sprite / I2V / paper-doll work starts at `design/art-pipeline.md`. Open only the sibling that file names for the job (`art-i2v.md`, `art-pack.md`, `art-review.md`). Prompts live in `tools/i2v_seeds.py`. Off-magenta plates go through `tools/plate_remap.py` before I2V. Walk packing is `tools/pack_locomotion.py`. One-shot packing is `tools/pack_oneshot.py`. I2V and complex animation packing stay in Grok Build sessions unless the User says otherwise. Animation Browser review briefs and the regen tree are `tools/anim_review_*.py`; output under `tools/anim_review/` is gitignored.

## Document kinds

| Marker | Meaning |
|--------|---------|
| Binding design | Required behavior unless the User overrides it |
| Live snapshot | What the current live path actually does |
| Protocol | How agents must work |

## Topic map

| When the work is about… | File | Old GDD home |
|-------------------------|------|----------------|
| Agent workflow | `protocol.md` | Front matter |
| Web / chat session flow | `web-session.md` | — |
| Grok Build session flow | `grok-build.md` | — |
| Grok Bot session flow | `grok-bot-session.md` | — |
| Refactor recipe | `refactor.md` | — |
| Grok Build leave-off | `sessions.md` | — |
| Grok Build session log | `session-log.md` | — |
| Version scheme, changelog, week pins | `versioning.md` | — |
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
| I2V unit + seed + prompt | `art-i2v.md` | §19.2 |
| Harvest, pack, cleanup | `art-pack.md` | §19.4 |
| Animation Browser briefs | `art-review.md` | §19.6 |
| Pinned archive commits | `archives.md` | §20 |
| Suggested starts + live defaults | `tunables.md` | App. A + live `balance.gd` |
| Anvil leftovers for the next session | `handoff-anvil.md` | — |

Per-build player notes are `design/changelog/{label}.md`. They are not topic files. Do not open them unless `versioning.md` says to.

## House rules for editing these files

- Keep one concern per file.
- Put numbers in `tunables.md`, not buried in paragraphs.
- Mark live-only behavior under **Live snapshot**.
- Do not reintroduce a single 100KB GDD.
- When live scripts are split under the 10KB cap, update this code map in the same slice.

## Code map (live path)

Every live `scripts/**/*.gd` file must stay under **10KB** when it ships. Facades keep the original public path; helpers take `host` / `pt` / `ui` / `p`. Split mechanics: `design/refactor.md`. Web / chat applies the 10KB cap in Phase 6 of `design/web-session.md`, not while drafting. Grok Bot’s under-5KB sweep target is only in `design/grok-bot-session.md`.
