# Agent protocol

Status: protocol  
Read when: every fresh Grok instance (Build / web), before writing code  

Treat the design requirements in this database as binding. Treat the live codebase at the repository root as the project to maintain.

Recognize the path from the Path table in `AGENTS.md`. Follow that path’s session file. MUST NOT treat another path’s deliverable rules as a license to skip your own. Web / chat and Grok Bot leashes MUST NOT bind Grok Build implementation — that freedom lives in `design/grok-build.md`.

**Binding design** is required player-facing behavior. **Live snapshot** is current code. If they disagree, patch live toward binding or ask. Do not invent a third **game** system. A new code API is not a third game system.


## Core rules

- Fresh **Grok** (Build / web): this file, `design/constraints.md`, then only the topic door that matches the requested work. Inspect the live path from **one system row** in `design/code-map.md` (`project.godot`, then the listed scenes/scripts). MUST NOT walk `assets/` unless the task names sprites or audio. MUST NOT begin by archiving or rewriting the live path. MUST NOT read `design/changelog/` on a mid-week slice. Open it only for **new week**, a revert, a named past build, or when the User asks what shipped. MUST NOT open `design/reuse-map.md` unless this session’s goal is to write that brief or the User named the staged reuse PR.
- **Grok Bot** does not follow that read list (`AGENTS.md` → `design/grok-bot-session.md` only). Types, warnings, tabs, and the 10KB cap in `AGENTS.md` still bind.
- Path procedures live in that path’s session file. `design/sessions.md` and `design/session-log.md` are Grok Build leave-off / log only. Leave-off is not a boot list.
- MUST implement only the **game** systems this database explicitly requires. MUST NOT invent skills, rarities, hub upgrades, meta-progression, or co-op scaffolding. Grok Build MAY add helpers and same-system APIs per `design/grok-build.md`. A new cross-system owner or a named-architecture replace is Build **Stop and propose first**.
- Open numbers, formulas, enemy details, and artifact-set bonuses: MAY invent coherent starts, then MUST expose every value in the secret debug menu and record them in `design/tunables.md`. Grok Bot MUST NOT invent numbers.
- `design/coverage.md` is a checklist against the existing live build. Fill gaps. MUST NOT use the phases as a license to delete and rebuild. Grok Bot MUST NOT treat coverage as a feature list. Open coverage only when its `Read when` matches.
- After a requested slice: pause and report progress, verification, and issues before continuing.
- Ambiguity about **player-facing design**: ask. Grok Build MUST decide code structure inside one system without asking, and MUST stop and propose before a new cross-system owner or a named live-architecture replace.
- This database is the source of design intent across compaction. The live tree is the source of truth for shipping code. Git history on `main` is the source of truth for the game version number; `scripts/data/version.json` is the baked copy.
- Prefer simple, readable, production-quality code. Match existing live patterns unless Grok Build is doing a just-do same-system reshape or an accepted rework. Sprite / I2V work starts at `design/art-pipeline.md` when that door’s `Read when` matches.
- GDScript indent is tab characters. Types: `AGENTS.md`. Size splits: `design/refactor.md` (recipe only; pick a Bot flow from the Bot door). Deliver as that path’s session file specifies.
- Self-verify against the Demo-Complete Checklist in `design/constraints.md` before calling the build complete.

## Long-running behavior

On multi-session or compacted runs, re-affirm the Hard Constraints and the current requested work before resuming. Never allow live-path code to share state with any archive. Do not “recover” a stale session by archiving or rewriting the live path.

One goal per web / chat session (stop after Phase 7). One Grok Build session family per development week (week pins only when the User says **new week**). One Grok Bot flow per session (one Job-table sibling; one PR).

## How to use this database

Topic index (one row): `design/README.md`. Live code map (one system row): `design/code-map.md`. Open topic **doors**, then only the Job-table sibling. I2V and complex animation packing stay in Grok Build unless the User says otherwise.

Topic doors, gates, and recipes are named in `design/routes.yaml`. Open one only when its `Read when` matches, a Job table names it, or the User names that work. Do not treat this paragraph as a read list.

All previously open **design** questions are closed. Do not invent additional game systems or reopen settled design decisions. Grok Build may still invent code shape inside a required system.

## Variation philosophy

Numbers, exact formulas, enemy specifics, and artifact-set bonuses are deliberately left open so implementations can produce a varied but coherent result. Starting values in `design/tunables.md` are only suggested seeds.
The secret debug menu and Automated Playtest system exist to drive rapid, data-driven tuning toward the Success Criterion and Design Pillars. Variation *within* the required systems is expected and desired.
Everything that is marked tunable or left for Grok to invent should be treated as a starting point that will be refined through the tuning tools.

**Global rule**: Unless otherwise noted, all numeric values, formulas, rates, ranges, timings, and scaling are fully tunable via the secret debug menu and treated as non-final starting points. MAY invent coherent values freely within this Variation Philosophy. Grok Bot MUST NOT invent values.
