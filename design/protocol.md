# Agent protocol

Status: protocol  
Read when: every fresh Grok instance, before writing code  
See also: `AGENTS.md`, `design/constraints.md`

`See also:` is an index, not a read list. Do not open those files unless this file’s `Read when`, a Job table, or the User names that work.

Treat the design requirements in this database as binding. Treat the live codebase at the repository root as the project to maintain.

Recognize the path from the Path table in `AGENTS.md`. Follow that path’s session file. MUST NOT treat another path’s deliverable rules as a license to skip your own.

## Core rules

- MUST begin every fresh **Grok** instance by reading this file, `design/constraints.md`, and the topic files that match the requested work. Inspect the live path from the code map in `design/README.md` (`project.godot`, then the listed scenes/scripts). MUST NOT walk `assets/` unless the task names sprites or audio. MUST NOT begin by archiving the project or rewriting the live path. MUST NOT read `design/changelog/` unless the work is versioning, a named past build, or a revert. MUST NOT open `design/reuse-map.md` unless this session’s goal is to write that brief or the User named the staged reuse PR.
- **Grok Bot** MUST NOT follow that read list. After `AGENTS.md`, follow `design/grok-bot-session.md` only. That door’s Job table names the one flow sibling. Open `design/reuse-map.md` only from `design/grok-bot-reuse.md` when that brief is not the empty template.
- Path procedures live in `design/grok-build.md`, `design/web-session.md`, and `design/grok-bot-session.md`. `design/sessions.md` and `design/session-log.md` are Grok Build leave-off / log only — not a web or Bot hand-off.
- MUST implement only what this database explicitly requires. MUST NOT invent systems, skills, rarities, hub upgrades, meta-progression, or co-op scaffolding.
- When numbers, formulas, enemy details, or artifact-set bonuses are left open, MAY invent coherent starting values freely, then MUST expose every value in the secret debug menu and record them in `design/tunables.md`. Grok Bot MUST NOT invent numbers.
- MUST treat `design/coverage.md` as a coverage checklist against the existing live build. Fill gaps in the live path. MUST NOT use the phases as a license to delete and rebuild. Grok Bot MUST NOT treat coverage as a feature list.
- After completing a requested slice of work, MUST pause and report progress, verification results, and any issues to the User before continuing.
- If any ambiguity, conflict, or missing information arises, MUST immediately prompt the User for clarification rather than guessing.
- This database remains the source of design intent across context compaction, tool calls, or new sessions. The live tree remains the source of truth for shipping code. Git history on `main` remains the source of truth for the game version number; `scripts/data/version.json` is the baked copy.
- Prefer simple, readable, production-quality code that matches existing live patterns. Sprite / I2V work starts at `design/art-pipeline.md`.
- GDScript indent is tab characters. Types follow `AGENTS.md` → GDScript types. Size splits follow `design/refactor.md`. Deliver as that path’s session file specifies.
- Self-verify against the Demo-Complete Checklist in `design/constraints.md`. Only declare the build complete when every item is satisfied.

## Long-running behavior

On multi-session or compacted runs, re-affirm the Hard Constraints and the current requested work before resuming. Never allow live-path code to share state with any archive. Do not “recover” a stale session by archiving or rewriting the live path.

One goal per web / chat session (stop after Phase 7). One Grok Build session family per development week (week pins only when the User says **new week**). One Grok Bot flow per session (one Job-table sibling; one PR).

## How to use this database

- Topic files from overview through feel, plus `design/art-pipeline.md` and `design/versioning.md`, are mandatory design intent for the live implementation.
- Open topic **doors**, then only the Job-table sibling. Art door: `design/art-pipeline.md`. I2V and complex animation packing stay in Grok Build unless the User says otherwise.
- `design/archives.md` governs Archives isolation. Pins are frozen commits. Do not copy a pinned commit into `archives/` as a project tree. Grok Bot MUST NOT create or rewrite archives.
- Hard constraints, secret debug, Automated Playtest, and Animation Browser shipping rules live in `design/constraints.md`. Telemetry cap: `design/debug.md`.
- All previously open design questions are closed. Do not invent additional systems or reopen settled decisions.
- `design/reuse-map.md` is a User-authored staging brief for the next Grok Bot reuse PR. Web / chat Phase 7 writes it. It is not an owners encyclopedia and not default Bot context.

## Variation philosophy

Numbers, exact formulas, enemy specifics, and artifact-set bonuses are deliberately left open so implementations can produce a varied but coherent result. Starting values in `design/tunables.md` are only suggested seeds.
The secret debug menu and Automated Playtest system exist to drive rapid, data-driven tuning toward the Success Criterion and Design Pillars. Variation *within* the required systems is expected and desired.
Everything that is marked tunable or left for Grok to invent should be treated as a starting point that will be refined through the tuning tools.

**Global rule**: Unless otherwise noted, all numeric values, formulas, rates, ranges, timings, and scaling are fully tunable via the secret debug menu and treated as non-final starting points. MAY invent coherent values freely within this Variation Philosophy. Grok Bot MUST NOT invent values.
