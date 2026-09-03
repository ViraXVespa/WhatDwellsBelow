# Implementation phases (coverage checklist)

Status: protocol / checklist
Read when: deciding whether a system is missing, or when running smoke
Code: `scripts/debug/smoke.gd`
See also: `design/protocol.md`, `design/debug.md`

This database is the authoritative specification for the demo of *What Dwells Below*.

The live path already exists. Phases below are a hard coverage list, not a license to delete and rebuild.

A fresh Grok Build instance MUST:

1. Read the needed `design/` files and the live tree. Do not archive or rewrite as a first action.
2. Confirm which phases the live path already satisfies.
3. Fill gaps in the live path until the requested work and the relevant exit criteria are met.
4. Stop and report to the User after the requested slice.

## Core construction rules

- Work in the live path. MUST NOT archive-then-rewrite on a fresh instance. MUST NOT discard live scenes, scripts, autoloads, or architectural patterns to start over.
- Keep the live path designed around the orthographic Camera3D system (`design/camera.md`).
- The live path MUST never share runtime code, scenes, scripts, or global state with any archived build.
- Treat every numeric value as tunable and expose it in the secret debug menu.
- Prefer simple, readable, production-quality implementations that match surrounding live code.
- All player and enemy character art MUST follow the mandatory pipeline in `design/art-pipeline.md`.
- Male and female player characters with full animation parity and complete peer voice-over sets, the three-weapon system, hit-based mining and woodcutting, eleven skills, blue rarity (boss-only), named monsters, enemy bases, quest system, artifact collections/sets, aim-line indicator, Controls Billboard, Floor Crystal loadout, idle/pressure spawns, food vs potion distinction, enter/wake VFX, and gamepad-first UI with initial focus are mandatory.
- The secret debug menu (including profile Save/Load, Automated Playtest / AI Player system) MUST ship at production quality but remain hidden behind the documented shoulder-button sequence.
- Automated Playtest hooks MUST live in the same systems the player uses. Telemetry is limited to the `design/debug.md` cap.
- Animation Browser controls belong in the first secret-debug implementation; the full viewer is required at Demo-Complete, not in early phases.
- Player-facing UI MUST be dungeon-themed. Default / unskinned controls are allowed only in the secret debug menu.
- Production / Gold quality is required for every system that ships. Placeholders are allowed only under the explicit policy in `design/audio-visual.md`.

## Coverage phases

Use these to find gaps. Advance a requested slice only after its exit criteria are met, self-verified, and progress is reported to the User. Do not self-start an unrequested full-phase rebuild.

**Phase 1 – Foundation**
Camera3D + input + basic player movement/animation states (`design/art-pipeline.md` sprites, 8 directions) for both male and female characters on the existing live path.
*Exit criteria*: Player can move, face 8 directions, and idle/walk with Y-billboard at 60 FPS. Depth sorting SHOULD be correct under implied real-world positions, with popping avoided wherever possible. Report to User.
Smoke: `--wdb-phase1-smoke`

**Phase 2 – Core Combat**
Three weapons with basic + LT specials, Dash, target-lock, crits, Adrenaline Rush, full attack telegraphs, aim-line indicator, proper depth sorting and juice.
*Exit criteria*: All three weapons fully playable with telegraphs and active indicators; 60 FPS; all values exposed in debug. Report to User.
Smoke: `--wdb-phase2-smoke`

**Phase 3 – Dungeon Structure**
Dungeon generation + boss doors + locked stairs + Floor Guardians / Gate Master + enemy bases.
*Exit criteria*: Repeating 5-floor loop generates, bosses spawn behind doors, stairs lock/unlock correctly. Report to User.
Smoke: `--wdb-phase3-smoke`

**Phase 4 – Enemies**
≥12 types, variety, named monsters, flee event, telegraphs, AI including leash / drop-pursuit and idle / pressure spawns.
*Exit criteria*: At least 5 types per floor, named monsters appear, flee event triggers, all telegraphs readable, enemies drop pursuit at leash range, idle/pressure spawns function outside safe rooms. Report to User.
Smoke: `--wdb-phase4-smoke`

**Phase 5 – Gathering & Interactables**
Hit-based mining and woodcutting, breakables, and all interactables (including expanded Artifact sources).
*Exit criteria*: Nodes function with correct hit timing and rewards; all listed interactables present and usable. Report to User.
Smoke: `--wdb-phase5-smoke`

**Phase 6 – Progression Systems**
Inventory, equipment (including tool type lock), food vs potion rules, forged holds, extraction/Extraction Gates, anvil, Floor Crystal loadout, quest system, artifact collections/sets (exactly eight).
*Exit criteria*: Full inventory/extraction/forge/quest/artifact loop works; loadout opens from the Floor Crystal; eight sets with progressive bonuses; food HoT and potion instant heal behave as specified. Report to User.
Smoke: `--wdb-phase6-smoke`

**Phase 7 – UI & Debug**
Full HUD (including food HoT indicator), pause menu (three tabs + character switch + aim-line controls + “Dispel” Avatar), secret debug menu (profiles + Automated Playtest Medium bar + Animation Browser *entry*), recap screen with XP drain sequence. Player-facing UI uses dungeon theming.
*Exit criteria*: All UI elements present, gamepad-first with initial focus, no unskinned player-facing UI, secret menu accessible only via sequence, Medium-bar Automated Playtest functional using the telemetry cap, Animation Browser control present and focusable (stub allowed). Report to User.
Smoke: `--wdb-phase7-smoke`

**Phase 8 – Persistence & Hub**
Save / load with backup + isolated save paths for archives and for the two autoplay saves. Placeholdia hub layout (buildings with real depth) including Controls Billboard, Floor Crystal loadout, consciousness-transfer enter VFX, and wake-up return sequence.
*Exit criteria*: Save/load + backup works; hub complete with all listed interactables and depth; enter/wake presentation beats play; Archives browser lists every catalog pin including Full 3D Pass. Report to User.
Smoke: `--wdb-phase8-smoke`

**Phase 9 – Final Polish & Verification**
Final audio pass (including Bitter loop rule and linked masters), placeholder replacement, no default UI on the playable path, Archives browser verification, full Animation Browser viewer, full Demo-Complete Checklist self-audit, 60 FPS under load, Success Criterion simulation.
*Exit criteria*: Checklist fully satisfied including the complete Animation Browser; report final verification results to User and await confirmation before declaring complete.
Smoke: `--wdb-phase9-smoke`