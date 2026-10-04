# Agent protocol

Status: protocol
Read when: every fresh Grok instance (Build / web), before writing code

The design here is the current plan: the road we are building, not a route we have to take. The User can change it; the game is an evolving ecosystem. The live tree at the repo root is what ships.
If a path file is already loaded, stay on that path.

## Core rules

- Fresh web / Build: this file, `design/constraints.md`, then the topic that matches the work. Web, User present: picture-read is uncapped inside `design/` and the live tree the thread is on. Implementation reads the doc and `design/code-map.md` row of every system the job touches (Build: read first, `grok-build.md`). Do not walk `assets/` unless the task names sprites or audio. Do not start by archiving or rewriting the live path. Do not read `design/changelog/` to learn history (only for a named archive pin, a revert, a named past build, or when the User asks what shipped). Web writes the changelog entry for every change (`tools/doc_patch.py changelog --bullet`); Build writes none (its notes go in commit messages).
- Implement the **game** systems the plan names. Do not add skills, rarities, hub upgrades, meta-progression, or co-op scaffolding unasked; suggest them with a question prompt. Grok Build may add helpers and same-system APIs. A new cross-system owner or named live-module replace is asked first.
- Open numbers may start coherent. Expose every invented value in the secret debug menu and record it in `design/tunables.md`.
- Coverage fills gaps in the live build. It is not a license to delete and rebuild.
- Design or product ambiguity (not only player-facing): web asks one blocking question; Build asks with `ask_user_question` (Build session flow, Design decisions), even under always-allow. Code shape inside one system: Build decides. Chain related steps; report when done.
- Git history on `main` is the game version. `scripts/data/version.json` is the baked copy.
- When editing GDScript, load `design/gdscript-law.md`. Splitting files is the Grok Bot's job (`BOT.md`).
- Before calling the build complete, self-verify against the Demo-complete checklist in `design/constraints-demo.md`.

## Long-running

Do not fetch a file already in the loaded set. Live-path code must not share state with an archive. Archive pins are CI-only (`ci_archive.py`); agents never pin. (Web emit-pass loop: `web-test.md`.)

## Database

Open a topic door only when its `Read when` matches, a Job table names it, or the User names that work. Do not treat this paragraph as a read list.
Design questions the User already answered stay answered unless she reopens them. A new request raises new questions: ask them (Build: `ask_user_question`), do not invent systems or answers.

Numbers, formulas, enemy specifics and set bonuses start in `design/tunables.md` and the debug menu and are non-final.
