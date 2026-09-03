# Agent protocol

Status: protocol
Read when: every fresh instance, before writing code
See also: `AGENTS.md`, `design/constraints.md`, `design/sessions.md`, `design/web-session.md`

Treat the design requirements in this database as binding. Treat the live codebase at the repository root as the project to maintain.

Path is **Grok Build (CLI)** or **web / chat**. Recognize the path from `AGENTS.md`. Web / chat MUST follow `design/web-session.md` and MUST NOT treat this file’s CLI deliverable rules as a license to skip that flow.

## Core rules

- MUST begin every fresh instance by reading this file, `design/constraints.md`, and the topic files that match the requested work, then inspecting the live path (`project.godot`, `scenes/`, `scripts/`, `assets/`). MUST NOT begin by archiving the project or rewriting the live path.
- After a gap between **Grok Build** sessions, MUST also read `design/sessions.md` (leave-off + log) and MUST NOT treat that log as a substitute for git / live-tree inspection. `design/sessions.md` is not the web / chat hand-off.
- Web / chat MUST follow `design/web-session.md` after the User’s repo-review message. MUST NOT emit files during Phase 1–3. MUST NOT apply the 10KB script cap until Phase 6.
- MUST implement only what this database explicitly requires. MUST NOT invent systems, skills, rarities, hub upgrades, meta-progression, or co-op scaffolding.
- When numbers, formulas, enemy details, or artifact-set bonuses are left open, MAY invent coherent starting values freely, then MUST expose every value in the secret debug menu and record it in `design/tunables.md`.
- MUST treat `design/coverage.md` as a coverage checklist against the existing live build. Fill gaps in the live path. MUST NOT use the phases as a license to delete and rebuild.
- After completing a requested slice of work, MUST pause and report progress, verification results, and any issues to the User before continuing.
- If any ambiguity, conflict, or missing information arises, MUST immediately prompt the User for clarification rather than guessing.
- This database remains the source of design intent across context compaction, tool calls, or new sessions. The live tree remains the source of truth for shipping code.
- Prefer simple, readable, production-quality code that matches existing live patterns. Use available tools as needed, especially for the sprite pipeline in `design/art-pipeline.md`.
- GDScript indent is tab characters. Grok Build: when the User asks for a full file, output the entire file. Web / chat: emit files only as `design/web-session.md` specifies.
- Self-verify continuously against the Demo-Complete Checklist in `design/constraints.md`. Only declare the build complete when every item is satisfied.

## Long-running behavior

On multi-session or compacted runs, re-affirm the Hard Constraints and the current requested work before resuming. Never allow live-path code to share state with any archive. Do not “recover” a stale session by archiving or rewriting the live path.

Web / chat: one goal per session. After Phase 7 in `design/web-session.md`, stop. The next goal is a new session.

## Mandatory workflow for any fresh Grok Build instance

1. **Orient on the live path**
   Read the needed `design/` files and the live tree at the repository root. Archived builds are pinned git commits in `scripts/data/archive_catalog.json`, not project trees under `archives/`. Do not copy a snapshot into `archives/` or overwrite a pin unless the User explicitly orders a new archive.

2. **Change the live path in place**
   Implement the requested work by updating the current live scenes, scripts, autoloads, assets, and project settings.
   - MUST extend, patch, and reuse live scenes, scripts, and architectural decisions unless they contradict this database or the User's request.
   - MUST NOT replace the live tree with a greenfield rewrite.
   - MUST NOT copy archive scripts or scenes over live files as a default strategy.
   - The live path remains designed around the orthographic Camera3D system described in `design/camera.md` (fixed ~–58° pitch, proper depth sorting that respects implied real-world positions, paper-doll sprites, readable 64×64 art, 8-directional facing, etc.).
   - Match surrounding style. When presenting a revised source file to the User, output the entire file and indent with tab characters.

3. **Preserve the Archives system**
   The Archives browser MUST ship. Selecting title “Play” always launches the current live path.
   Catalog rows (each a pinned commit, isolated per `design/archives.md`):
   - **classic_2d** — Classic 2D
   - **art_experiment** — Art experiment
   - **full_3d_pass** — Full 3D Pass
   - **grok_build_w1** — Grok Build Results (Week 1)
   - **grok_web_w1** — Grok Web Results (Week 1)

## How to use this database

- Treat every requirement in the topic files covering overview through feel, plus `design/art-pipeline.md`, as mandatory design intent for the current live implementation.
- `design/art-pipeline.md` is non-negotiable for all character art and includes post-generation viability analysis + video-fill fallback. Consult its Appendix C and D sections on demand for full templates and reliability data.
- `design/archives.md` governs Archives isolation and MUST be obeyed. Pins are frozen commits; new archives are created only when the User explicitly requests one.
- The public repository live path (`project.godot`, `scenes/`, `scripts/`, `assets/`) is the codebase to update. Do not copy a pinned commit into `archives/` as a project tree.
- The secret debug / Automated Playtest system is a shipping feature (behind the input sequence) and MUST be implemented to production quality.
- Automated Playtest is specified so its hooks live in base systems from the start and do not have to be retrofitted. Implement only the telemetry listed in `design/debug.md` unless a Medium-bar recommendation cannot be computed without a closely related field.
- The Animation Browser is specified early so its menu entry, label, and gamepad focus exist when the secret debug menu is first built. Full viewer behavior is a late-stage implementation task, not an early-phase blocker, but it is required for Demo-Complete.
- All previously open design questions are closed. Do not invent additional systems or reopen settled decisions.

## Variation philosophy

Numbers, exact formulas, enemy specifics, and artifact-set bonuses are deliberately left open so implementations can produce a varied but coherent result. Starting values in `design/tunables.md` are only suggested seeds.
The secret debug menu and Automated Playtest system exist to drive rapid, data-driven tuning toward the Success Criterion and Design Pillars. Variation *within* the required systems is expected and desired.
Everything that is marked tunable or left for Grok to invent should be treated as a starting point that will be refined through the tuning tools.

**Global rule**: Unless otherwise noted, all numeric values, formulas, rates, ranges, timings, and scaling are fully tunable via the secret debug menu and treated as non-final starting points. MAY invent coherent values freely within this Variation Philosophy.