# Agent protocol

Status: protocol
Read when: every fresh Grok instance (Build / web), before writing code

Design in this database is binding. The live tree at the repo root is what ships.
If a path file is already loaded, stay on that path. Web / Bot leashes do not bind Grok Build.

## Core rules

- Fresh web / Build: this file, `design/constraints.md`, then only the topic that matches the work. One system row in `design/code-map.md`. Do not walk `assets/` unless the task names sprites or audio. Do not start by archiving or rewriting the live path. Open `design/changelog/` only for a named pin, a revert, a named past build, or when the User asks what shipped.
- Grok Bot does not follow that read list. Onboard is `BOT.md` plus `python tools/bot_status.py`, then one Job file.
- Implement only the **game** systems this database requires. Do not invent skills, rarities, hub upgrades, meta-progression, or co-op scaffolding. Grok Build MAY add helpers and same-system APIs. A new cross-system owner or named-architecture replace is Build stop-and-propose.
- Open numbers MAY start coherent. Expose every invented value in the secret debug menu and record it in `design/tunables.md`. Grok Bot MUST NOT invent numbers.
- Coverage fills gaps in the live build. It is not a license to delete and rebuild.
- Player-facing ambiguity: ask. Code shape inside one system: Build decides. After a slice: pause and report.
- Git history on `main` is the game version. `scripts/data/version.json` is the baked copy.
- When editing GDScript, load `design/gdscript-law.md`. Size splits are `design/refactor.md` for Grok Bot only. Web / chat does not cap-split.
- Self-verify against the Demo-Complete Checklist in `design/constraints.md` before calling the build complete.

## Long-running

Do not fetch a file already in the loaded set. Live-path code must not share state with an archive.
One web emit pass is Phase 3 through Phase 4. Phase 5 returns to Phase 2 unless the User changes the goal.
Pins are User-only. One Grok Bot flow per session.

## Database

Open a topic door only when its `Read when` matches, a Job table names it, or the User names that work. Do not treat this paragraph as a read list.
All previously open design questions are closed. Do not invent additional game systems or reopen settled decisions.

## Variation

Numbers, formulas, enemy specifics, and set bonuses start in `design/tunables.md` and the debug menu. They are non-final. Grok Bot MUST NOT invent values.

## Loaded set

Default: the agents file, this path file, and (web / Build) this file plus constraints.
Cap: boot files + one topic door + one Job sibling + matching gates.
