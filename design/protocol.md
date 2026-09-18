# Agent protocol

Status: protocol  
Read when: every fresh Grok instance (Build / web), before writing code  

Treat the design requirements in this database as binding. Treat the live codebase at the repository root as the project to maintain.

If a path session file is already loaded, stay on that path. Do not re-select a path from this file. MUST NOT treat another path’s deliverable rules as a license to skip your own. Web / chat and Grok Bot leashes MUST NOT bind Grok Build implementation — that freedom lives in the Build path file.

**Binding design** is required player-facing behavior. **Live snapshot** is current code. If they disagree, patch live toward binding or ask. Do not invent a third **game** system. A new code API is not a third game system.


## Core rules

- Fresh **Grok** (Build / web): this file, `design/constraints.md`, then only topic that matches the requested work. Inspect the live path from **one system row** in `design/code-map.md` (`project.godot`, then the listed scenes/scripts). MUST NOT walk `assets/` unless the task names sprites or audio. MUST NOT begin by archiving or rewriting the live path. MUST NOT read `design/changelog/` on a mid-week slice. Open it only for **new week**, a revert, a named past build, or when the User asks what shipped. MUST NOT open `design/reuse-map.md` unless this session’s goal is to write that brief or the User named the staged reuse PR.
- **Grok Bot** does not follow that read list (Bot path file only after boot). When editing GDScript, load `design/gdscript-law.md`.
- Path procedures live in that path’s session file. git and git are Grok Build leave-off / log only. Leave-off is not a boot list.
- MUST implement only the **game** systems this database explicitly requires. MUST NOT invent skills, rarities, hub upgrades, meta-progression, or co-op scaffolding. Grok Build MAY add helpers and same-system APIs per the Build path file. A new cross-system owner or a named-architecture replace is Build **Stop and propose first**.
- Open numbers, formulas, enemy details, and artifact-set bonuses: MAY invent coherent starts, then MUST expose every value in the secret debug menu and record them in `design/tunables.md`. Grok Bot MUST NOT invent numbers.
- coverage is a checklist against the existing live build. Fill gaps. MUST NOT use the phases as a license to delete and rebuild. Grok Bot MUST NOT treat coverage as a feature list. Open coverage only when its `Read when` matches.
- After a requested slice: pause and report progress, verification, and issues before continuing.
- Ambiguity about **player-facing design**: ask. Grok Build MUST decide code structure inside one system without asking, and MUST stop and propose before a new cross-system owner or a named live-architecture replace.
- This database is the source of design intent across compaction. The live tree is the source of truth for shipping code. Git history on `main` is the source of truth for the game version number; `scripts/data/version.json` is the baked copy.
- Prefer simple, readable, production-quality code. Match existing live patterns unless Grok Build is doing a just-do same-system reshape or an accepted rework. Sprite / I2V work starts at art_pipeline when that door’s `Read when` matches.
- GDScript indent, types, and warnings: `design/gdscript-law.md` when editing GDScript. The 10KB ship floor lives in that same file; Grok Build does not enforce it while running. Size splits: `design/refactor.md` for Grok Bot and for web / chat Phase 6 only (recipe only; Bot flow from the Bot door). Deliver as that path's session file specifies.
- Self-verify against the Demo-Complete Checklist in `design/constraints.md` before calling the build complete.

## Long-running behavior

On multi-session or compacted runs, name Hard Constraints and the current requested work. Do not fetch a file already in the loaded set. Never allow live-path code to share state with any archive. Do not “recover” a stale session by archiving or rewriting the live path.

One goal per web / chat session (stop after Phase 7). One development week may run several concurrent Grok Build CLI sessions (slice, plus week-scoped Bot notes, PC offload, and smoke tests); they share one week pin (pins only when the User says **new week**). One Grok Bot flow per session (one Job-table sibling; one PR).

## How to use this database

Topic index uses door keys only and is not a boot fetch. Live code map (one system row): `design/code-map.md`. Open topic **doors**, then only the Job-table sibling. I2V and complex animation packing stay in Grok Build unless the User says otherwise.

Topic doors, gates, and recipes are named in `design/routes.yaml`. Open one only when its `Read when` matches, a Job table names it, or the User names that work. Do not treat this paragraph as a read list.

All previously open **design** questions are closed. Do not invent additional game systems or reopen settled design decisions. Grok Build may still invent code shape inside a required system.

## Variation philosophy

Numbers, exact formulas, enemy specifics, and artifact-set bonuses are deliberately left open so implementations can produce a varied but coherent result. Starting values in `design/tunables.md` are only suggested seeds.
The secret debug menu and Automated Playtest system exist to drive rapid, data-driven tuning toward the Success Criterion and Design Pillars. Variation *within* the required systems is expected and desired.
Everything that is marked tunable or left for Grok to invent should be treated as a starting point that will be refined through the tuning tools.

**Global rule**: Unless otherwise noted, all numeric values, formulas, rates, ranges, timings, and scaling are fully tunable via the secret debug menu and treated as non-final starting points. MAY invent coherent values freely within this Variation Philosophy. Grok Bot MUST NOT invent values.

## Loaded set

After boot, do not fetch a file already in the loaded set. Name it only.
Default set: the agents file, this path file, and (web / Build) protocol plus constraints.
Load cap: boot files + at most one topic door + one Job sibling + gates whose when matches. Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

## Job cycle

A **job** is one cycle: gather once, then change once, then prove once. Pause and report after every job.

Gather is `list_xref` plus `show_func` plus `summarize_scripts` plus one `list_code_map_row`. `list_route` and `list_changed` stay outside the gather set.

Name a **planned gather list** (distinct xref patterns and show-func names) before the first catalog call. Those planned calls are one gather phase. Until show-func/xref can batch names into one summary, read that job's session summary once after each distinct planned call. That is not a second job. A gather call invented after a prove summary, or the same command with the same args again, or a ninth show-func not on the list, is a second job.

Change is one slice or one worktree edit that merges into the live checkout. Prove is one measure, or one listed smoke set, or both **once**. Do not measure, then smoke, then measure.

Read each job summary once via `powershell -File tools/read_summary.ps1 -Job <name>`. Preferred path is `_logs/sess/<session>/<job>/summary.txt` (session = `WDB_AGENT_SESSION` or the inferred Grok session id). Do not open the summary file directly. Catalog and protocol must agree: once per job, and once per planned gather call as above.

A second job in the same Grok Build session is allowed only when a **new field** is named first. Do not wait for the User between job 1 and job 2 when that field is named. Still pause and report after every job. The field must already be a key printed by that job's summary template, or `truncated` / crash / `busy` / wrong scene. Do not invent a key the template does not print. "Add a field so I can rerun" is invalid. The only valid same-command rerun is `truncated`, crash, `busy` lock, or wrong scene, and then the same command once.

Concurrent agents share catalog tools. They do not share summary files: each session writes under `_logs/sess/<session>/`. A new week starts with `powershell -File tools/week_start.ps1` (pins previous-week Web results, seeds the next series, `clean_agent_logs -NewWeek`).

