# Agent protocol

Status: protocol  
Read when: every fresh Grok instance, before writing code  
See also: `AGENTS.md`, `design/constraints.md`, `design/web-session.md`, `design/grok-build.md`, `design/grok-bot-session.md`, `design/refactor.md`, `design/versioning.md`, `design/sessions.md`, `design/session-log.md`, `design/art-pipeline.md`

Treat the design requirements in this database as binding. Treat the live codebase at the repository root as the project to maintain.

Path is **Grok Build (CLI)**, **web / chat**, or **Grok Bot**. Recognize the path from `AGENTS.md`. Follow that path’s session file. MUST NOT treat another path’s deliverable rules as a license to skip your own.

| Path | Session file |
|------|----------------|
| Grok Build (CLI) | `design/grok-build.md` |
| Web / chat | `design/web-session.md` |
| Grok Bot | `design/grok-bot-session.md` plus `design/refactor.md` |

## Core rules

- MUST begin every fresh **Grok** instance by reading this file, `design/constraints.md`, and the topic files that match the requested work. Inspect the live path from the code map row in `design/README.md` (`project.godot`, then the listed scenes/scripts). MUST NOT walk `assets/` unless the task names sprites or audio. MUST NOT begin by archiving the project or rewriting the live path. MUST NOT read `design/changelog/` unless the requested work is versioning, a named past build, or a revert.
- **Grok Bot** MUST NOT follow that read list. After `AGENTS.md`, follow `design/grok-bot-session.md` only.
- After a gap between **Grok Build** sessions, MUST follow `design/grok-build.md`. That includes `design/sessions.md` and current-series changelog files. MUST NOT run the week pin ritual unless the User said **new week**. MUST NOT treat `design/sessions.md` as a substitute for git / live-tree inspection. MUST NOT follow git commit links into web-session conversations. `design/sessions.md` and `design/session-log.md` are not the web / chat or Grok Bot hand-off.
- Web / chat MUST follow `design/web-session.md` after the User’s repo-review message. MUST NOT emit files during Phase 1–3. MUST NOT apply the 10KB script cap until Phase 6. MUST write `design/changelog/{label}.md` in Phase 7 when the goal shipped a player-visible or agent-visible change.
- Grok Bot MUST follow `design/grok-bot-session.md`. MUST use `design/refactor.md` on script tasks and `design/doc-refactor.md` on documentation facade tasks. MUST ship via branch + PR (never paste-emit; never claim a write landed until the PR exists). MUST NOT implement features or invent systems. MUST NOT invent numbers. MUST prefer **new shared modules** when near-identical control flow spans places (see `design/grok-bot-session.md` and `design/refactor.md`). MUST NOT write `design/sessions.md`, `design/session-log.md`, or `design/changelog/`.
- MUST implement only what this database explicitly requires. MUST NOT invent systems, skills, rarities, hub upgrades, meta-progression, or co-op scaffolding.
- When numbers, formulas, enemy details, or artifact-set bonuses are left open, MAY invent coherent starting values freely, then MUST expose every value in the secret debug menu and record them in `design/tunables.md`. Grok Bot MUST NOT invent numbers.
- MUST treat `design/coverage.md` as a coverage checklist against the existing live build. Fill gaps in the live path. MUST NOT use the phases as a license to delete and rebuild. Grok Bot MUST NOT treat coverage as a feature list.
- After completing a requested slice of work, MUST pause and report progress, verification results, and any issues to the User before continuing.
- If any ambiguity, conflict, or missing information arises, MUST immediately prompt the User for clarification rather than guessing.
- This database remains the source of design intent across context compaction, tool calls, or new sessions. The live tree remains the source of truth for shipping code. Git history on `main` remains the source of truth for the game version number; `scripts/data/version.json` is the baked copy.
- Prefer simple, readable, production-quality code that matches existing live patterns. Use available tools as needed. Sprite / I2V work starts at `design/art-pipeline.md`.
- GDScript indent is tab characters. Types follow `AGENTS.md` → GDScript types. Size splits follow `design/refactor.md`. Grok Build: when the User asks for a full file, output the entire file. Web / chat: emit files only as `design/web-session.md` specifies. Grok Bot: ship via branch + PR; do not paste-emit.
- Self-verify continuously against the Demo-Complete Checklist in `design/constraints.md`. Only declare the build complete when every item is satisfied.

## Long-running behavior

On multi-session or compacted runs, re-affirm the Hard Constraints and the current requested work before resuming. Never allow live-path code to share state with any archive. Do not “recover” a stale session by archiving or rewriting the live path.

Web / chat: one goal per session. After Phase 7 in `design/web-session.md`, stop. The next goal is a new session.

Grok Build: one session family per development week. Slices stay in that thread. A mid-week new CLI chat is a catch-up, not a new week. Week pins run only when the User says **new week**. Details: `design/grok-build.md`.

Grok Bot: one sweep session. After the User ends the sweep or the legal worklist is empty, stop. The next goal is a new session.

## How to use this database

- Treat every requirement in the topic files covering overview through feel, plus `design/art-pipeline.md` and `design/versioning.md`, as mandatory design intent for the current live implementation.
- `design/art-pipeline.md` is the character-art door. Open only the sibling it names for the job (`design/art-i2v.md`, `design/art-pack.md`, `design/art-review.md`). Consult Appendix C and D on demand. I2V and complex animation packing stay in Grok Build unless the User says otherwise.
- `design/archives.md` governs Archives isolation and MUST be obeyed. Pins are frozen commits. New archives are created only when the User explicitly requests one, except the standing Grok Build week pins in `design/versioning.md` when the User has said **new week**. Grok Bot MUST NOT create or rewrite archives.
- The public repository live path (`project.godot`, `scenes/`, `scripts/`, `assets/`) is the codebase to update. Do not copy a pinned commit into `archives/` as a project tree.
- The secret debug / Automated Playtest system is a shipping feature (behind the input sequence) and MUST be implemented to production quality.
- Automated Playtest is specified so its hooks live in base systems from the start and do not have to be retrofitted. Implement only the telemetry listed in `design/debug.md` unless a Medium-bar recommendation cannot be computed without a closely related field.
- The Animation Browser is specified early so its menu entry, label, and gamepad focus exist when the secret debug menu is first built. Full viewer behavior is a late-stage implementation task, not an early-phase blocker, but it is required for Demo-Complete.
- All previously open design questions are closed. Do not invent additional systems or reopen settled decisions.

## Variation philosophy

Numbers, exact formulas, enemy specifics, and artifact-set bonuses are deliberately left open so implementations can produce a varied but coherent result. Starting values in `design/tunables.md` are only suggested seeds.  
The secret debug menu and Automated Playtest system exist to drive rapid, data-driven tuning toward the Success Criterion and Design Pillars. Variation *within* the required systems is expected and desired.  
Everything that is marked tunable or left for Grok to invent should be treated as a starting point that will be refined through the tuning tools.

**Global rule**: Unless otherwise noted, all numeric values, formulas, rates, ranges, timings, and scaling are fully tunable via the secret debug menu and treated as non-final starting points. MAY invent coherent values freely within this Variation Philosophy. Grok Bot MUST NOT invent values.
