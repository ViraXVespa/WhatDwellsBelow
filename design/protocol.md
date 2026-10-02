# Agent protocol

Status: protocol
Read when: every fresh Grok instance (Build / web), before writing code

Design in this database is binding. The live tree at the repo root is what ships.
If a path file is already loaded, stay on that path.

## Core rules

- Fresh web / Build: this file, `design/constraints.md`, then the topic that matches the work. Web, User present: picture-read is uncapped inside `design/` and the live tree the thread is on. Implementation uses one writer door. One system row in `design/code-map.md` when editing live files. Do not walk `assets/` unless the task names sprites or audio. Do not start by archiving or rewriting the live path. Do not read `design/changelog/` to learn history (only for a named pin, a revert, a named past build, or when the User asks what shipped). Writing a new entry is allowed and required for player-visible changes: `tools/doc_patch.py changelog --bullet`.
- Implement only the **game** systems this database requires. Do not invent skills, rarities, hub upgrades, meta-progression, or co-op scaffolding. Grok Build MAY add helpers and same-system APIs. A new cross-system owner or named live-module replace is Build stop-and-propose.
- Open numbers MAY start coherent. Expose every invented value in the secret debug menu and record it in `design/tunables.md`.
- Coverage fills gaps in the live build. It is not a license to delete and rebuild.
- Design or product ambiguity (not only player-facing): web asks one blocking question; Build asks with `ask_user_question` (Build session flow, Design decisions), even under always-allow. Code shape inside one system: Build decides. After a slice: pause and report.
- Git history on `main` is the game version. `scripts/data/version.json` is the baked copy.
- When editing GDScript, load `design/gdscript-law.md`. Size splits are `design/refactor.md` for Grok Bot only. Web / chat does not cap-split.
- Self-verify against the Demo-Complete Checklist in `design/constraints.md` before calling the build complete.

## Long-running

Do not fetch a file already in the loaded set. Live-path code must not share state with an archive.
One web emit pass is Phase 3 through Phase 4 for one accepted slice. On a multi-slice list, a pasted PASS goes to the next slice Phase 3. Phase 2 returns when the User changes the remaining list or opens a new brainstorm topic.
Pins are User-only.

## Database

Open a topic door only when its `Read when` matches, a Job table names it, or the User names that work. Do not treat this paragraph as a read list.
The design questions that were open when the database was frozen are closed; do not reopen them. A new request raises new questions: ask them (Build: `ask_user_question`), do not invent systems or answers.

## Variation

Numbers, formulas, enemy specifics, and set bonuses start in `design/tunables.md` and the debug menu. They are non-final.

## Loaded set

Default: the agents file, this path file, and (web / Build) this file plus constraints.
Cap (implementation): boot files + one topic door + one Job sibling + matching gates. Web picture-reads do not expand what a slice may implement.
Web docs/routing may open the load-graph and topic index without treating that as a second writer.
