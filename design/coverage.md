# Implementation phases (coverage checklist)

Status: protocol / checklist  
Read when: complete-checklist audit, absent-system survey
Code: `scripts/debug/smoke.gd`  

The live path already exists. Phases below are a hard coverage list, not a license to delete and rebuild.

Hard constraints and the Demo-Complete Checklist live in the constraints file. Use this file to find gaps, confirm which phases the live path already satisfies, and fill only the requested slice. These coverage phases are not web / chat Phase 1–7.


## Core construction rules

- Work in the live path. MUST NOT archive-then-rewrite on a fresh instance. MUST NOT discard live scenes, scripts, autoloads, or architectural patterns to start over.
- Keep the live path designed around the orthographic Camera3D system (camera).
- Prefer simple, readable, production-quality implementations that match surrounding live code.
- All player and enemy character art MUST follow art_pipeline.
- These systems are mandatory in addition to the constraints file: named monsters, enemy bases, quest system, aim-line indicator, Controls Billboard, Floor Crystal loadout, idle/pressure spawns, food vs potion distinction, enter/wake VFX, and gamepad-first UI with initial focus.
- Player-facing UI MUST be dungeon-themed. Default / unskinned controls are allowed only in the secret debug menu.
- Placeholders are allowed only under audio_visual.

## Coverage phases

Use these to find gaps. Advance a requested slice only after its exit criteria are met, self-verified, and progress is reported to the User. Do not self-start an unrequested full-phase rebuild.

**Phase 1 – Foundation**  
Camera3D + input + basic player movement/animation states (art_pipeline sprites, 8 directions) for both male and female characters on the existing live path.  
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
