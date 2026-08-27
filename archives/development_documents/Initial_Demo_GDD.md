***IMPORTANT***
This is an old, archived version of this document. The latest version is located in the root directory of the project. This document should now only be used for reference. The original "single source of truth" language is preserved solely for posterity. The latest version should be seen as the source of truth instead.

**Version**: 1.9 – Archive-then-Clean-Rewrite (Review Pass + Restored Archive Locks)  
**Authority**: This document is the single source of truth.

### Agent Execution Protocol (Mandatory for Every Grok Build Instance)
You are operating as a Grok Build coding agent. Treat every word of this document as immutable system instructions.

**Core Rules**
- MUST begin every fresh instance by executing the Mandatory Workflow (archive first, then clean rewrite).
- MUST implement only what this document explicitly requires. MUST NOT invent systems, skills, rarities, hub upgrades, meta-progression, or co-op scaffolding.
- When numbers, formulas, enemy details, or artifact-set bonuses are left open, MAY invent coherent starting values freely, then MUST expose every value in the secret debug menu.
- MUST follow the gated Implementation Phases in order. Each phase is a hard blocker: do not advance until the exit criteria are met and self-verified.
- After completing each phase, MUST pause and report progress, verification results, and any issues to the User before continuing.
- If any ambiguity, conflict, or missing information arises, MUST immediately prompt the User for clarification rather than guessing.
- The GDD remains the immutable source of truth across context compaction, tool calls, or new sessions. Keep it as the persistent system prompt.
- Prefer simple, readable, production-quality code. Use available tools (code execution, file system, image generation, etc.) as needed, especially for the sprite pipeline in Section 19.
- Self-verify continuously against the Demo-Complete Checklist. Only declare the build complete when every item is satisfied.

**Long-Running Behavior**  
On multi-session or compacted runs, re-affirm the Hard Constraints and current phase before resuming work. Never allow live-path code to share state with any archive.

### Mandatory Workflow for Any Fresh Grok Build Instance
1. **Archive the current build first**  
   Follow Section 20 exactly. Create a new fully standalone snapshot under `archives/` that captures the project state as it exists at the moment this GDD is handed over. Store this archive as its own Archives-browser entry with the id **`full_3d_pass`** (folder / switcher id `archives/full_3d_pass/` or equivalent; on-screen label **Full 3D Pass**). Do not overwrite `classic_2d` or `art_experiment`. `full_3d_pass` is the historical snapshot of the live path as it existed at GDD handover, before the clean rewrite. This snapshot becomes the next selectable build in the Archives browser / presentation switcher and is preserved as a historical museum piece. Do not modify the live path while creating the archive.  
   **Verification (MUST)**: Launch the new archive independently and confirm it runs with zero live-path scenes, scripts, autoloads, or global state.

2. **Then rewrite the live path from scratch**  
   After the archive is complete and verified as isolated, implement the entire playable demo as a clean new live codebase.  
   - MUST NOT extend, patch, or carry forward the previous live code, scenes, scripts, or architectural decisions.  
   - The previous pure-2D design philosophy and its accumulated compromises are retired.  
   - The new live path MUST be designed from the ground up around the orthographic Camera3D system described in Section 4 (fixed ~–58° pitch, proper depth sorting that respects implied real-world positions, paper-doll sprites, readable 64×64 art, 8-directional facing, etc.).

3. **Preserve the Archives system and presentation switcher**  
   The presentation switcher (live / classic_2d / art_experiment) plus the Archives browser MUST ship. Selecting “Play” always launches the new clean live path.  
   After the Mandatory Workflow archive step there are **four** selectable builds:  
   - **live** — the new clean rewrite  
   - **classic_2d** — existing isolated archive  
   - **art_experiment** — existing isolated archive  
   - **full_3d_pass** — the standalone snapshot of the previous live path created in step 1 (on-screen label **Full 3D Pass**)  

   classic_2d, art_experiment, and full_3d_pass remain completely isolated standalone snapshots per Section 20.

### Hard Constraints (Non-Negotiable)
- Solo play only; no co-op scaffolding left active in the live path.
- Exactly the eleven skills listed in Section 7.
- White, green, and blue rarity only (blue is boss-only).
- Repeating 5-floor structure with Floor Guardians (1–4) and Gate Master (5).
- Hit-based gathering system for both mining and woodcutting.
- Artifact collections / sets required (exactly eight, see Section 8).
- Player animations use exactly 8 directions (matching the Character Bible layout) with full male/female parity. Each character type has its own complete voice-over set.
- All numeric values exposed and tunable in the secret debug menu.
- Production / Gold quality on every system that ships.
- Consistent 60 FPS minimum on target hardware.
- No systems, skills, rarities, hub upgrades, or meta-progression beyond what this document explicitly requires.
- The secret debug menu (including Save/Load profiles, Automated Playtest / AI Player system with weapon-balance awareness, telemetry, impact coefficients, baseline coefficients, and recommended configurations) MUST ship but remains hidden behind the documented input sequence.
- The Automated Playtest / AI Player system exists so simulation, telemetry hooks, and recommended-config application are implemented *inside* the same live systems the player uses (combat, inventory, extraction, save, debug values). It is an integration requirement, not a parallel “AI game.” Keep programmatic impact low: one code path wherever practical.
- The Animation Browser is a shipping debug page. Its *controls* MUST exist in the secret debug menu from the first debug-menu implementation (Phase 7). The *full viewer* is a late-stage (Phase 9) Demo-Complete item and MUST ship in the final product.

**Global rule**: Unless otherwise noted, all numeric values, formulas, rates, ranges, timings, and scaling are fully tunable via the secret debug menu and treated as non-final starting points. MAY invent coherent values freely within the Variation Philosophy.

### Success Criterion
A first-time player on a couch with a gamepad can reach a successful extraction in 5–10 minutes without external guidance, understand the core risk/reward of extraction vs. death, and experience the permanent progression feedback on the recap screen — all at stable 60 FPS — using only the new clean live path.

**Concrete self-check proxies (MUST verify before final sign-off)**  
- Simulated new-player path reaches extraction in ≤10 minutes under default settings.  
- 60 FPS maintained under full enemy + particle load on deepest test floors.  
- Recap XP-drain sequence and permanent fragment display function correctly.  
- All three weapons remain roughly balanced per Automated Playtest Medium-bar results.

### Demo-Complete Checklist (True Non-Negotiables)
A build meets the contract only when **all** of the following are true:
- The Success Criterion above is achieved on the clean live path.
- Mandatory Workflow (archive-then-clean-rewrite) has been followed.
- Live path shares no runtime code, scenes, scripts, or global state with any archived build.
- Exactly the eleven skills listed in Section 7.
- Exactly eight artifact sets (run-only).
- Hit-based gathering for mining and woodcutting.
- Repeating 5-floor structure with Floor Guardians (1–4) and Gate Master (5).
- White / green / blue rarity only (blue is boss-only).
- Player animations use exactly 8 directions with full male/female parity. Each character type has its own complete voice-over set.
- Secret debug menu (including Medium-bar Automated Playtest) ships but remains hidden.
- Automated Playtest Medium bar ships, hidden behind the documented sequence, using the capped telemetry set in Section 13 (no open-ended analytics product).
- Secret debug menu includes a focusable Animation Browser entry from Phase 7 onward, and the full Animation Browser viewer ships by Demo-Complete (Phase 9).
- Every shipping system is Production / Gold quality and fully exposed to the debug menu.
- Consistent 60 FPS minimum.
- Solo play only; no co-op scaffolding.
- No systems, skills, rarities, hub upgrades, or meta-progression beyond what this document explicitly requires.

### How to Use This Document
- Treat every requirement in Sections 1–17 and 19 as mandatory design intent for the new live implementation.
- Section 19 (sprite pipeline) is non-negotiable for all character art and includes post-generation viability analysis + video-fill fallback. Consult Appendix C and D on demand for full templates and reliability data.
- Section 20 governs Archives isolation and MUST be obeyed.
- The public repository supplies reusable assets and the Archives infrastructure. It is **not** a code base to extend for the live path.
- The secret debug / Automated Playtest system is a shipping feature (behind the input sequence) and MUST be implemented to production quality.
- Automated Playtest is specified so its hooks live in base systems from the start and do not have to be retrofitted. Implement only the telemetry listed in Section 13 unless a Medium-bar recommendation cannot be computed without a closely related field.
- The Animation Browser is specified early so its menu entry, label, and gamepad focus exist when the secret debug menu is first built. Full viewer behavior is a late-stage implementation task, not an early-phase blocker, but it is required for Demo-Complete.
- All previously open design questions are closed. Do not invent additional systems or reopen settled decisions.

**Variation Philosophy**  
Numbers, exact formulas, enemy specifics, and artifact-set bonuses are deliberately left open so each clean live build produces a varied but coherent first implementation. Starting values in Appendix A are only suggested seeds.  
The secret debug menu and Automated Playtest system exist to drive rapid, data-driven tuning toward the Success Criterion and Design Pillars. Variation *within* the required systems is expected and desired.  
Everything that is marked tunable or left for Grok to invent should be treated as a starting point that will be refined through the tuning tools.

---

**What Dwells Below — Demo Game Design Document**  
(Compiled from all locked decisions + final sprite pipeline + full respec + Grok Build optimizations)

---

### 1. Overview & Vision
**Game Title**  
What Dwells Below

**One-line Public Description**  
(Use the exact wording currently on the public GitHub Pages / title screen; treat it as locked unless later changed.)

**Core Fantasy**  
You are a dungeon delver employed by a known and trusted guild. You repeatedly descend into a shifting underground complex from a temporary surface camp called Placeholdia, fight, gather, and attempt to extract resources and gear. Death loses almost everything you were carrying; successful extraction banks permanent progress. The surface is slightly absurd and hopeful; the depths are dangerous and increasingly hostile.

**Demo Goal**  
A complete, production-ready vertical slice that can ship as a free demo. Every system included MUST be polished enough that the identical code can carry forward into the full game with only content and expansion added on top.

**Primary Loop**  
1. Placeholdia hub  
2. Loadout selection at the Floor Crystal (including character type, starting weapon, and tool type)  
3. Confirm enter → consciousness-transfer VFX → dungeon at chosen floor  
4. Explore, fight, gather, interact  
5. Extract via clerk or die / voluntarily “Dispel”  
6. Recap screen  
7. Return to Placeholdia with wake-up sequence and permanent gains (or losses)

---

### 2. Scope, Pillars, Non-Goals & Acceptance Criteria
**In-Scope for Demo (MUST be fully implemented and polished)**  
- Solo play only  
- Placeholdia hub with all listed interactables (including quest access via the guild, a Controls Billboard, buildings with actual depth, and the Floor Crystal as the sole loadout / enter-dungeon interactable)  
- Procedural dungeon floors in a repeating 5-floor structure that continues indefinitely until death  
- Floor Guardians (floors 1–4) and Gate Master (floor 5) with boss doors and locked stairs  
- Complete combat system (Great Axe, Lightning Staff, Longbow, weapon-specific specials on LT, Dash, target-lock, critical hits, Adrenaline Rush) with clear range telegraphs and active-attack indicators on every attack  
- Aim-line indicator (tunable, dungeon-only, System-tab toggle + opacity, persisted)  
- Hit-based gathering system for both mining (pickaxe) and woodcutting (hatchet)  
- Eleven skills (Great Axe, Staff, Longbow, Strength, Magic, Ranged, Defense, Hitpoints, Mining, Woodcutting, Smithing) with permanent XP fragments  
- Inventory, equipment slots (including single Tool slot locked to one type per run), forged holds (max 3 per slot), extraction via clerks  
- Artifact collections / sets (exactly eight sets, run-only, bonuses displayed under descriptions)  
- Male and female player characters (selectable on first load, switchable later from pause menu) with full animation parity, each with its own complete voice-over set, and exactly 8 directional animations  
- Ghost shop, shrine, campfire, breakables, puzzle elements, stairs, floor crystal  
- Named monsters, enemy bases, and expanded enemy variety (≥12 normal types, ≥5 types per floor)  
- Idle / pressure enemy spawns outside safe rooms  
- Quest system (3 random choices, 1 active at a time)  
- Distinct food (heal-over-time) and potion (instant heal) rules  
- Consciousness-transfer VFX on dungeon enter and wake-up sequence on return to Placeholdia  
- Full HUD, pause menu (with System tab containing aim-line controls), all interaction UIs, recap screen — all dungeon-themed; no default / unskinned player-facing UI  
- Secret debug / balance menu (shoulder-button sequence) containing all tunable values, profile Save/Load, the Automated Playtest / AI Player system, and the Animation Browser  
- Save / load with backup, presentation switcher + Archives (including `full_3d_pass`), 60 FPS minimum  
- Debug menu that exposes every balance and generation value  
- Gamepad-first design for all controls, gameplay, and interfaces (every menu opens with valid initial focus)

**Explicit Non-Goals (MUST NOT appear)**  
- Co-op / multiplayer / split-screen  
- Any skill beyond the eleven listed  
- Rarity higher than blue  
- Hub upgrades, currency sinks beyond vendor/anvil, or meta progression systems  
- Stealth, mounts, fishing, or other side systems  
- Story cutscenes or mandatory dialogue trees beyond short flavor lines  

**Design Pillars**  
1. Combat is readable, weighty, and juiced (telegraphs, hit-stop, knockback, crits, Adrenaline Rush, clear range and active indicators on every player attack).  
2. Extraction is meaningful — the tension of what to keep vs. what to risk is the heart of every run.  
3. Permanent progression is visible and satisfying after a single good run.  
4. Floors feel expansive enough to support the target times and multiple points of interest.  
5. Tone is light and slightly irreverent on the surface, serious in the depths, never grimdark.

**Acceptance Criteria**  
- A fresh Grok Build instance can recreate the entire demo from this document + the public repository.  
- All numeric values are exposed in the debug menu and treated as tunable.  
- The demo runs at a consistent 60 FPS (higher allowed) on target hardware.  
- Every system that ships is considered production/Gold and will not be rewritten for the full game.  
- Player-facing UI and HUD use dungeon theming. Default / unskinned engine controls MUST NOT appear on the playable path. The secret debug menu is exempt.

---

### 3. Core Fantasy & Lore (Demo-Visible Only)
**Player Role**  
The player character is a dungeon delver working for a known and trusted guild that operates out of the temporary surface settlement Placeholdia. The guild’s purpose is the recovery of resources, artifacts, and knowledge from the shifting underground complex known only as “Below.” Most delvers do not return.

**Surface vs. Depths Tone**  
- Placeholdia is safe, temporary, slightly absurd, and mildly hopeful. Flavor text, the dumpster, the notice board, and the ghost shop reinforce a light, irreverent tone.  
- The dungeon is dangerous, reactive, and oppressive. Lighting, enemy density, audio, and recap copy grow darker with depth.  
- The contrast is intentional and MUST be preserved.

**Information the Player Receives**  
No mandatory intro cutscene or long exposition is required. The player learns the fantasy through:  
- Short environmental flavor text on signs and the notice board.  
- Receptionist and clerk lines (kept minimal).  
- Recap screen titles, subtitles, and special case lines (including verge and empty-run variants).  
- The mechanical consequences of death versus successful extraction.  
- Consciousness-transfer VFX when leaving Placeholdia and a wake-up sequence when returning.

**Specific Locked Flavor**  
- Empty floor-1 death/“Dispel” recap MUST include the line: “They lived just to die. What a waste.”  
- Credit splash MUST show the word “Proudly” crossed out and the word “Shamelessly” written above it in graffiti style so the phrase reads as vandalized: “Shamelessly Vibecoded with Grok.”  
- The dungeon music track is titled “Bitter”. Authoritative links:  
  - YouTube: https://youtu.be/b3Cq_-ymFVU?si=YHZRCFmxf88BXmHW  
  - Spotify: https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA&utm_source=copy-link&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f  
- Player-facing UI, pause menu, recap, and prompts MUST write the voluntary exit action as **“Dispel”** (quotation marks included) for the locked humorous tone. Internal code identifiers MAY omit the quotes.

---

### 4. Platforms, Camera, Presentation & Input
**Target Platforms**  
- PC (primary)  
- Web export that runs in modern browsers without requiring special COOP/COEP headers  
- Design MUST remain fully readable and playable from couch distance on a television (future Xbox / console consideration)

**Camera (Live 3D Path)**  
- Orthographic Camera3D  
- Fixed pitch approximately –58°  
- Camera height and ortho size calculated so that 64×64 sprites remain clearly readable  
- Player-adjustable zoom range 1.0–1.75 (persisted in save)  
- Separate independent HUD scale setting  
- Look-at point offset slightly above the player origin  
- Depth sorting SHOULD respect implied real-world positions of the player, enemies, walls, and props. Arbitrary front/back popping MUST be avoided wherever possible, but perfect freedom from popping is not required.

**Presentation Switcher**  
The demo MUST ship with the existing presentation switcher (live / classic_2d / art_experiment) plus the Archives system. This is required for the Patreon development narrative. Selecting “Play” always launches the live path. The Archives browser also includes **`full_3d_pass`** (on-screen label **Full 3D Pass**), the isolated snapshot of the previous live path created at GDD handover. classic_2d, art_experiment, and full_3d_pass remain standalone archives per Section 20.

**Input – Gamepad (Primary, Xbox Layout)**  
- Left Stick: Movement  
- Right Stick: Aim  
- R3: Toggle target-lock (default off). On activation or when current target dies, lock nearest valid enemy in LOS and on-screen. Right-stick deflection cycles to the nearest enemy in that direction after a short delay. Lock breaks when no valid targets remain but stays armed for auto-reacquisition. Second R3 press disengages.  
- RT: Hold-to-attack (basic attack of the currently equipped weapon)  
- LT: Special attack of the currently equipped weapon  
- A: Interact  
- B: Dash  
- D-pad Up: Use equipped potion  
- D-pad Left: Use equipped food  
- Menu / Start: Pause  
- View / Back: Toggle large map overlay (game continues running underneath)  
- LB / RB: Cycle tabs inside menus  

All controls, gameplay, and interfaces MUST be designed with a gamepad-first intent. Every menu MUST open with a valid initial focus already set so the player can immediately navigate and select using only the gamepad (no requirement to first highlight an element with the mouse).

**Aim-Line Indicator**  
- Simple opaque visual indicator that extends outward from the player in the direction they are facing/aiming.  
- Appearance and length are fully tunable (default style inspired by Heroes of Hammerwatch and similar games; length may optionally scale toward the farthest point the currently equipped weapon can hit).  
- Always visible while the player is inside the dungeon; never visible in Placeholdia.  
- Always draws the full configured distance (does not respect line-of-sight or stop at walls).  
- Toggleable on/off and with an independent opacity slider in the System tab of the pause menu.  
- On/off state and opacity are persisted with the player profile.  
- Fully functional with both gamepad and keyboard/mouse aiming (parity required).

**Input – Keyboard / Mouse (Fully Featured Fallback)**  
All gamepad actions MUST have keyboard/mouse equivalents. Mouse aim + hold-LMB for attack is the default mouse scheme. Rebinding of all actions is required.

**Renderer**  
Prefer the Compatibility renderer for the final shippable build if it does not compromise the web export. Mobile renderer is acceptable only if required for web stability.

---

### 5. Player Avatar, Movement & Controls
**Character Selection**  
- On first load the player chooses a male or female character.  
- The character type may be switched later from the pause menu.  
- Both character types MUST be fully animated and kept in parity so that all weapon paper-doll appearances and animations function correctly on either without special per-gender tweaks.  
- Male and female characters each require a complete, dedicated voice-over set of equal scope. Neither set is optional or derivative of the other.

**Movement**  
- Dash grants complete invulnerability frames for its entire duration and leaves a clear trail VFX.  
- Movement MUST feel responsive and weighty on both gamepad and keyboard.

**Collision & Body**  
- Prefer collision that matches the actual art silhouette / paper-doll bounds rather than a simple cylinder.  
- The player SHOULD depth-sort against walls, props, enemies, and other world objects using implied real-world positions. Popping MUST be avoided wherever possible; it is not explicitly forbidden.

**Facing & Animation System**  
- 8-directional facing derived from aim direction using smooth radial detection (not movement direction). Directions exactly match the Character Bible layout: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right.  
- Character art is generated and assembled according to the mandatory pipeline in **Section 19**.  
- Required player states at minimum: idle, walk, attack (per weapon), special (per weapon), gathering (mining/woodcutting), death, “Dispel”.  
- Each weapon requires its own paper-doll equip appearance and associated animations.  
- Male and female player characters MUST maintain full animation parity.  
- All directional variants of the same animation state MUST contain exactly the same number of frames.

---

### 6. Combat Feel & Numbers
**Weapon System**  
The player may equip one of three weapons: Great Axe, Lightning Staff, or Longbow.  
Starting weapon is selected in the loadout. Mid-run weapon changes are performed by equipping from the pause-menu inventory.  
Each weapon has its own paper-doll appearance and full set of animations.  
Specials for all weapons are activated with LT.  
All player attacks (basic and special) MUST clearly telegraph their range and provide a visible indication that the attack is currently active.

**Great Axe**  
- Basic attack: Hold-to-attack (RT / LMB). Continues automatically while held. Arc and range are tunable. A single swing can hit multiple enemies inside the arc. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation frame.  
- Special (Slam): Short wind-up and recovery. Higher damage multiplier than a basic attack (exact value tunable). Applies a readable stagger (shorter duration against Floor Guardians and the Gate Master). Produces dedicated ground-crack VFX.

**Lightning Staff**  
- Basic attack: Hold-to-attack (RT / LMB). Weak melee strikes that continue automatically while held. Range and arc are shorter and lower-damage than the Great Axe (exact values tunable). A single strike can hit multiple enemies inside its arc. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation frame.  
- Special: AoE lightning bolt that strikes a targeted area. Possesses a distinct short wind-up. Damage, radius, and any secondary effects are tunable. MUST clearly telegraph the affected area and show when the bolt is active.

**Longbow**  
- Basic attack: Hold-to-attack (RT / LMB) fires long-range single-target projectiles that continue automatically while held. Range, projectile speed, and fire rate are tunable. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation / projectile frame.  
- Special: Fires 5 arrows in a cone in front of the player (functions as an AoE attack). Possesses a distinct short wind-up. Cone angle, range, arrow count behaviour, and damage are tunable. MUST clearly telegraph the cone area and show when the arrows are active.

**Critical Hits**  
- Deal double damage.  
- Target receives a white flash.  
- Floating damage number is shown in yellow + magenta (no additional “CRIT!” text).  
- This is the minimum required implementation; additional juice may be added later.

**Dash**  
- Activated with B.  
- Full i-frames for the entire duration.  
- Clear trail VFX required.

**Adrenaline Rush**  
- Triggers after sufficient kills in a short window (exact threshold tunable).  
- Effects while active:  
  - Increased movement speed  
  - Stacking XP bonus  
  - Flaming aura on the player  
  - Continuous wooshing / crackling sound  
- Starts with a warcry.  
- No cooldown, but the effect times out if the player stops killing.  
- MUST keep killing to maintain the state.

**Defense**  
- Uses a diminishing-returns formula (exact formula tunable).  
- Armor pieces contribute defense and may carry minor secondary stats.

**Target-lock**  
See Section 4 for full behavior.

Floating damage numbers show integer values only, appear briefly, then disappear.

---

### 7. Skills, XP, Progression & Combat Level
**Skills Included in the Demo**  
- Great Axe  
- Staff  
- Longbow  
- Strength  
- Magic  
- Ranged  
- Defense  
- Hitpoints  
- Mining  
- Woodcutting  
- Smithing  

These eleven are mandatory.

**XP Gain & Permanent Progression**  
- During a run the player accumulates “run XP” in each skill.  
- On death or voluntary “Dispel”, only a small fragment of that run XP is kept permanently.  
- The recap screen MUST contain a clear visual sequence that shows the run XP values draining down to the permanent fragment amounts, after which the new permanent XP totals and resulting levels are displayed.

**Weapon-Specific XP Rules**  
- Great Axe attacks grant Great Axe XP + Strength XP.  
- Lightning Staff melee attacks grant Strength XP + Staff XP.  
- Lightning Staff special attacks grant Magic XP + Staff XP.  
- Longbow attacks (both basic and special) grant Ranged XP + Longbow XP.

**Combat Level**  
- Three separate style-specific combat levels are tracked:  
  - Melee = Great Axe + Strength  
  - Magic = Staff + Magic  
  - Ranged = Longbow + Ranged  
- Defense and Hitpoints feed into the global Combat Level.  
- The HUD displays the player’s highest (global) Combat Level.  
- If the currently equipped weapon’s style Combat Level is lower than the highest, that style level is shown in parentheses next to it (e.g. Level 14 (Magic 11)).  

**Skill Effects (High-Level)**  
- Great Axe, Staff, Longbow, Strength, Magic, and Ranged: increase damage dealt with the corresponding style or weapon (with possible differential scaling on specials).  
- Defense & Hitpoints: increase survivability.  
- Mining: improves reward chance and effectiveness with the hit-based mining system.  
- Woodcutting: improves reward chance and effectiveness with the hit-based woodcutting system.  
- Smithing: reduces forge cost/time and improves output at the anvil.  

**Visible Power Gain After One Good Run**  
After a single successful extraction and return to Placeholdia the player MUST be able to notice either:  
- a few permanent skill levels, or  
- at least one new piece of usable forged gear (or both).  

This is a required feel target. Concrete proxy: after one successful run the permanent skill levels or new forged item MUST be visible on the hub loadout/skills screens without external guidance.

---

### 8. Inventory, Gear, Extraction & Artifacts
**Bag**  
- Fixed capacity (current value 28).  
- When the bag is full, any new loot the player walks over cannot be picked up. A toast is shown and the item remains on the ground.

**Equipment Slots**  
- Weapon  
- Tool (pickaxe **or** hatchet — only one kind may be selected per run at loadout and is locked for the entire run)  
- Potion (dedicated quick-use slot)  
- Food (dedicated quick-use slot; maximum 20 of one food type may be brought into a run)  
- Head  
- Body  
- Legs  

Food discovered inside the dungeon MUST be equipped to be used with the quick button, but may also be consumed directly from the inventory UI. Potion and food have distinct visual and audio feedback when used.

**Food vs Potion (locked distinction)**  
- **Potion:** Instant heal of Z HP (Z tunable; may be a full heal if Z is set to max HP). Effect applies immediately on use.  
- **Food:** Heal-over-time. Restores a total of X HP smoothly over Y seconds (X and Y tunable).  
- While a food effect is active, a HUD indicator MUST show that food is ticking.  
- Using the same food type again while its effect is active does NOT stack and does NOT consume another item until the current effect ends.  
- Using a different food type while an effect is active cancels the current effect, consumes the new item, and starts the new food’s effect.  
- Potion and food MUST remain audibly and visually distinct.

**Gear Rules**  
- White, green, and blue rarity appear in the demo.  
- Blue items have improved stats over green items and are obtainable only from bosses (Floor Guardians and Gate Master).  
- Stats take effect immediately.  
- Weapons require paper-doll visual layers and associated animations. Armor and other gear may remain stats-only.  
- The player may maintain up to three forged “holds” per equipment slot.  
- Forged holds always return to Placeholdia on death or “Dispel”, even if the item was dropped on the floor.  
- All unextracted resources and any non-forged items still in the bag are lost on death or “Dispel”.

**Artifacts & Collections**  
- Artifacts are obtained from the Ghost Shop, boss chests, and (optionally) dead-end or trap-room chests.  
- Artifacts cannot be extracted via clerks; they function as run-only items and are lost on death or “Dispel”.  
- Artifacts with similar effects are grouped into collections (sets). The demo contains exactly eight distinct sets.  
- Typical set size is 2–3 artifacts; one or two sets may contain 4–5 artifacts.  
- Collecting multiple artifacts from the same set grants additional set bonuses. Bonuses begin at 2 pieces and may require higher thresholds depending on set size.  
- Set bonuses are progressive and are invented by Grok Build at implementation time.  
- Artifact set bonuses should feel like a natural addition to the items that make up the set. For example, if a set is made up of two items that increase health regeneration, the set bonus could provide an additional boost to health regen or a matching bonus to mana regen.  
- For 2–3 piece sets, the bonus should be roughly equal in power to the bonus from an individual piece of the set.  
- For larger sets, the bonuses should feel more powerful as more items in the collection are gathered.  
- Active set bonuses are displayed beneath the normal artifact descriptions in the relevant UI.  
- Set pieces count toward bonuses while carried or equipped in the current run.

**Extraction / Mailing**  
- Performed exclusively through clerks.  
- The interface MUST present a clear list of items that can be sent back to the surface.  
- Once extracted, items and gold are safe.  
- Clerk types: one gather specialist and one misc specialist per floor, with a chance of Packmule Patty as an additional clerk. Maximum three clerks total on any floor.

**Vendor Restock**  
If the player returns to Placeholdia with insufficient resources, a limited free restock of basic food and potions is granted.

---

### 9. Placeholdia Hub (Exact Contents & Behavior)
**Required Interactables (complete and final list)**  
- Floor Crystal (opens loadout / enter-dungeon UI)  
- Anvil  
- Vendor Stall  
- Dumpster  
- Guild Signs / Notice Board  
- Receptionist area / Guild (quest access)  
- Controls Billboard  
- “Welcome to Placeholdia!” banner  

There is no separate Loadout Station. Layout may be adjusted freely for aesthetics and usability. Existing flavor text may be lightly revised if any line feels awkward or forced.  
All buildings MUST have actual depth and realistic 3D dimensions (not flat 2D sprites) so they feel solid under the orthographic Camera3D and avoid sorting / z-axis issues. Reference feel: the city area of *Heroes of Hammerwatch 2*.

**Floor Crystal**  
- The Floor Crystal is the only enter-dungeon interactable in Placeholdia.  
- Interacting with it opens the Loadout UI.  
- That UI includes: select holds per slot (fallback to starter Great Axe + pickaxe or hatchet + potion if no holds exist), choose starting weapon, choose tool type (pickaxe or hatchet — locked for the entire run), choose starting floor, confirm enter.  
- Floor list allows travel only to deeper floors the player has previously reached. It never permits travel backward.  
- Interaction and confirmation MUST be clear and cancellable (no single-press accidental enter).  
- On confirmed enter, play a **consciousness-transfer VFX** before the dungeon loads. This is a short presentation beat, not a story cutscene.  
- Visual presentation MUST be clean, TV-readable, dungeon-themed, and consistent with the other hub / dungeon UIs.

**Return / Wake-Up**  
- After recap from death or “Dispel”, arriving back in Placeholdia MUST play a short **wake-up sequence**.  
- This is a presentation beat (animation + VFX/SFX), not a mandatory dialogue tree or cutscene.

**Anvil**  
- Full forge flow: analyze item → first forge (consumes gold + ore + root) → subsequent re-forges at reduced cost.  
- Maximum three holds per equipment slot.  
- Smithing skill influences time, cost, and quality of output.  
- UI MUST be clean, TV-readable, dungeon-themed, and consistent with the other interaction UIs.

**Vendor Stall**  
- Purchases ore for gold.  
- Sells basic food and potions.  

**Dumpster**  
- Pure flavor object only.  
- Retains its current text. No inventory interaction, dialogue tree, or gameplay effect.

**Guild / Quest Access**  
- Accessible via the guild (Receptionist area or Notice Board).  
- Presents three different random quests for the player to choose from.  
- Only one quest may be active at a time.  
- After each delve the available quests are randomly re-generated (the currently active unfinished quest is preserved).  
- Example quest types include: defeat X of enemy type Y, extract X ore in a single run, retrieve an item from floor X (quest item spawns only while active), or vanquish a specific named enemy (locks that named enemy as the only one that can appear until completed).  
- Rewards include XP in random skills, unowned equipment pieces, gold, and other desirable items.

**Controls Billboard**  
- Interactable object in Placeholdia, distinct from the guild notice board and the Welcome banner.  
- On interact, shows a TV-readable list of the current game controls.  
- The list MUST reflect the player’s active bindings (including any rebinds from the System tab).  
- Gamepad bindings are the primary listing; keyboard / mouse equivalents are shown as well.  
- Flavor text around the list is allowed; the control list itself MUST stay accurate.  
- Close with the normal menu Back / B pattern.  
- Dungeon-themed / hub-themed player-facing UI. No default unskinned panel.  
- In-world label copy MAY be invented at implementation time.

**“Welcome to Placeholdia!” Banner**  
- The text MUST be printed and clearly visible directly on the banner itself.  
- It MUST NOT be implemented as an interactable object or as floating text above a blank banner.

**Hub Audio / Atmosphere**  
- Warm, slightly hopeful and lightly comedic stand-in music and ambient sound are acceptable until final assets. Lighting and mood MUST contrast with the darker dungeon.

---

### 10. Dungeon Generation & Floor Rules
**Overall Structure**  
- Floors follow a repeating 5-floor pattern that continues indefinitely until the player dies.  
- Floors 1–4 each contain one Floor Guardian.  
- Floor 5 contains the Gate Master.  
- After floor 5 the sequence repeats with escalated difficulty.  
- There is no hard maximum depth; death is the only cap.

**Map Generation**  
Grid size, room count, room size ranges, and connection algorithm (MST + extra loops) are fully tunable.  
Target: floors MUST feel expansive enough to support a 5–10 minute first successful extraction for a new player and longer skilled runs. Starting values should be chosen to achieve this feel on the new Camera3D live path.

**Key Object Placement**  
Placement rules and probabilities for crystal, stairs, clerks, mining nodes, wood nodes, breakables, shrine, campfire, ghost shop, puzzle elements, chests, and enemy bases are fully tunable.  
Safe rooms (clerk, ghost shop, puzzle) MUST remain enemy-free.

**Enemy Bases**  
- Procedural room type containing at least one chest.  
- Heavily guarded by a large number of enemies.  
- Intended to be challenging unless the player is over-levelled for the current floor.

**Safe Rooms**  
- Clerk rooms, ghost shop rooms, and puzzle rooms are always enemy-free.  
- Idle / pressure spawns MUST NOT occur inside safe rooms.

**Boss / Guardian Rules**  
- Each Floor Guardian and the Gate Master spawns behind a special boss door that the player can see and prepare in front of.  
- Stairs remain locked until the guardian / Gate Master is defeated.  
- On death the boss drops a chest containing guaranteed equipment (including the possibility of blue rarity) plus one Artifact.

**Fog of War**  
- Reveal radius starts at a 5-tile baseline.  
- Visited tiles remain revealed for the duration of the run.  
- Large map overlay (View button) shows discovered tiles and important markers while the game continues running.

**Clerk Limits**  
- Maximum one ghost shop per floor.  
- Maximum three clerks total per floor.

**Stairs & Crystal**  
- Both only permit travel deeper.  
- Stairs are locked behind the boss door until the guardian is killed.

---

### 11. Enemies
**Enemy Variety**  
- Minimum of 12 different types of normal enemies.  
- At least 5 different types appear on each floor.  
- Enemies MUST have varied attack patterns, movement types (hopping, walking, flying, etc.), and appearances so they feel distinct in combat.  
- Palette swaps and stat swaps between floors are used to increase perceived variety.  
- Enemies should use a variety of classic fantasy representations (slimes, goblins, orcs, etc.).  
- All enemies MUST feel distinct from one another and remain visually consistent with the dungeon style and tone of the game.

**Roles Present in Demo**  
The following are suggested starting roles, not a closed or mandatory roster. Grok Build MAY invent additional or different roles so long as combat stays readable and the floor-variety rules in this section are met.  
Suggested starting roles:  
- Bruiser (melee)  
- Ranged  
- Tank  
- Mage  

Floor Guardians (floors 1–4) and the Gate Master (floor 5) MUST have high health and durability on top of their other stats. They are not required to be melee or close-range; ranged, mage, mixed, or other readable attack styles are allowed. Unique telegraphs are encouraged. Special spawn / door / chest rules already defined still apply. Tank remains only a suggested starting template, not a required boss type.

**Named Monsters**  
- Appear randomly at a rate of roughly once every 3 floors.  
- Slightly larger variants of their normal counterparts.  
- Name is randomly generated via a syllable-combination and randomization system.  
- Name appears beneath the enemy model in yellow text with a thin black border.  
- Each named monster receives a few stronger variants of the normal enemy’s attacks (example for ranged: three projectiles at the normal rate, or two projectiles at a faster rate).  
- When a “vanquish specific named enemy” quest is active, that exact named monster (name and type locked on quest acceptance) is the only named monster that can appear until the quest is completed.

**Attack Telegraphs & Feel**  
- All enemy attacks MUST have clear, readable wind-ups.  
- Melee (Bruiser / Tank): visible wind-up pose → lunge. Direction locks at the start of the wind-up.  
- Ranged: visible draw / charge pose → projectile release. Direction locks on draw.  
- Mage / other non-melee styles: visible charge / cast pose → readable area or projectile. Direction or target locks at the start of the telegraph.  
- All telegraphs respect line-of-sight.  

**AI Behavior**  
Enemies require line-of-sight to begin attacking or chasing.  
When LOS is lost they may briefly hunt the last-seen position, then return to idle.  
Enemies MUST also drop pursuit if the distance to the player exceeds a tunable leash range, even if they still have LOS. After dropping pursuit they return to idle / their post. This exists so a player who is overwhelmed can flee combat instead of being chased indefinitely.  
Exact leash distance, hunt duration after lost LOS, and re-aggro rules are tunable via the secret debug menu.  
Implement clean steering, separation, and stuck-handling appropriate for the orthographic Camera3D live path.  
Flee event occurs an average of 2 times per floor on a full clear: after the group has taken sufficient damage, the fastest enemy in the encounter flashes a clear “!” overhead, receives a small but noticeable speed boost, and flees to spawn reinforcements. No other telegraph is required beyond the “!”.

**Idle / pressure spawns**  
If the player remains idle too long outside a safe room, or stops revealing new map area for a tunable duration, additional enemies MUST spawn around the player.  
- MUST NOT spawn inside safe rooms (clerk, ghost shop, puzzle).  
- Idle timer, no-reveal timer, spawn count, and spawn radius are tunable via the secret debug menu.  
- Purpose: the dungeon stays reactive if the player camps or stalls exploration.

**Death Presentation**  
1. Play death animation.  
2. Drop loot (XP, gold, possible gear / Artifact).  
3. Body disappears cleanly.  

No lingering corpses required.

**Loot**  
- XP and gold amounts scale with floor and role.  
- Gear drop chance and rarity (white / green / blue) are tunable.  
- Floor Guardians and Gate Master always drop the special chest (guaranteed equipment that may include blue rarity + one Artifact) in addition to normal drops.

---

### 12. Interactables & World Objects
**Mining Nodes**  
- Nodes have a small number of hits (baseline 3–5).  
- Player approaches and interacts; gathering animation plays while stationary.  
- Every 2.4 seconds the node takes one hit and a reward is rolled immediately.  
- Reward chance and quality are influenced by Mining level, pickaxe quality, and node type.  
- No progress bar is shown.  
- Node is destroyed after its hit count is exhausted.

**Wood Nodes**  
- Nodes have a higher number of hits (baseline 6–10).  
- Player approaches and interacts; gathering animation plays while stationary.  
- Every 1.2 seconds the node takes one hit and a reward is rolled immediately.  
- Successful gather rate is approximately 50 % lower than mining nodes.  
- Reward chance and quality are influenced by Woodcutting level, hatchet quality, and node type.  
- No progress bar is shown.  
- Node is destroyed after its hit count is exhausted.

**Breakables (Pots / Barrels)**  
- Destroyed on a single player hit.  
- Chance to drop gold and/or an HP orb (walk-over pickup).  
- Clear smash VFX and SFX required.

**Clerks**  
- Provide the extraction / mailing interface.  
- Dialogue is minimal; the main interaction is a clean, TV-readable list of items the player can send back to the surface.  
- Maximum three clerks per floor.

**Ghost Shop**  
- Appears on approximately one in three floors.  
- Always in a safe room.  
- Sells 2–4 Artifacts (player may buy a maximum of two per visit).  
- Sells snacks at a fixed price (baseline 25 g).  
- Allows pawning of gear for a very low return.  
- Uses a distinct hopeful-but-eerie voice style (implementation may be text + SFX for the demo).  
- Distinct ghost / shopkeep sprite required.

**Shrine**  
- On interaction grants a temporary damage buff (+20 % baseline, 45 s duration).  
- Buff MUST appear on the HUD with a visible timer.  
- One use per floor.

**Campfire**  
- One-sit heal.  
- Safe interaction.

**Artifact Chests, Pressure Plates, Levers, Gates, Cracked Walls**  
- Puzzle elements are never required for progression and never appear on the critical path to stairs.  
- Cracked walls have higher HP than normal breakables (suggested start: 8).  
- Dead-end chests and trap-room chests may optionally contain Artifacts in addition to normal loot.

**Stairs & Floor Crystal**  
- Both only allow travel deeper.  
- Stairs remain locked behind the boss door until the Floor Guardian or Gate Master is defeated.  
- Interaction prompts MUST be clear and confirmation-safe where appropriate.

---

### 13. UI / HUD / Menus / Recap
**UI Theme (playable surfaces)**  
Every player-facing UI and HUD element in the live path MUST be designed with dungeon theming and MUST NOT ship as a default, unskinned, or engine-debug control. This includes the gauntlet strip, pause menu, clerk / extraction UI, Ghost Shop, anvil, Floor Crystal loadout UI, quest UI, Controls Billboard, recap, maps, toasts, title / credit flow, confirmation prompts, and any other surface a normal player can open.

The secret debug menu (including Automated Playtest, profiles, Animation Browser chrome, and raw value editors) MAY use default or lightly skinned engine controls. Appearance there is not a Demo-Complete art requirement.

**HUD – Gauntlet Strip (mandatory elements and behavior)**  
The HUD is a persistent horizontal strip that MUST remain visible at all times during dungeon play and MUST be readable from couch distance on a 1080p television.

| Required Element | Notes |
|------------------|-------|
| Player portrait | |
| HP bar with numeric value | |
| Potion quick-slot icon + cooldown sweep / numeric cooldown | |
| Dash cooldown indicator | |
| Special (LT) cooldown indicator | |
| Level | Highest global Combat Level; if the equipped weapon’s style level is lower it appears in parentheses (e.g. `Level 14 (Magic 11)`) |
| Current gold | |
| Current ore / wood | |
| Current floor number | e.g. “F3” |
| Shrine buff icon + remaining time | Appears only while active |
| Food heal-over-time icon + remaining time | Appears only while a food effect is active |
| Boss / Floor Guardian / Gate Master HP bar | Appears only while the boss is alive and in range / engaged |

Bag-fullness indicator is explicitly removed and MUST NOT appear.  
All cooldowns MUST show both a visual fill/sweep and be understandable at a glance. Exact pixel positions, colors, and sizes are left to implementation so long as the information hierarchy is preserved and the strip does not obscure critical gameplay.

**Pause Menu**  
Opened with Menu / Start / Esc. Freezes gameplay.  
Every menu (including this one) MUST open with valid initial focus so it is immediately navigable by gamepad.

Exactly three tabs, navigable with LB/RB or equivalent:  
1. Inventory – full bag grid, equipment slots, ability to use/consume/drop/equip (including mid-run weapon changes). Active artifact set bonuses are shown beneath each artifact’s normal description.  
2. Skills – list of the eleven skills with current level, XP bar to next level, and permanent XP total.  
3. System – MUST contain every one of the following:  
   - Master / Music / SFX volume sliders  
   - Camera zoom slider (1.0–1.75)  
   - HUD scale slider  
   - Aim-line toggle and opacity slider  
   - Presentation mode switcher + Archives browser  
   - Control rebinding screen  
   - Character type switch (male / female)  
   - Patreon link  
   - “Delete Save Data” with confirmation  
   - “Dispel” Avatar button with strong confirmation prompt  

The full debug / balance menu is **no longer** present in the Pause Menu.

**Secret Debug / Balance Menu**  
Accessed only by the following input sequence (gamepad): all four shoulder buttons (RT + RB + LT + LB) must go from pressed → released → pressed → released within a 1.5-second window. The 1.5-second timer resets after the first release so a full 1.5 seconds remains for the second press-and-release.  
The menu opening itself is the sole confirmation that the sequence succeeded.  
This menu contains:  
- Every previously available debug / balance page (all numeric values exposed and tunable)  
- Debug profile Save / Load / Delete / Rename system (unlimited named profiles, free naming/renaming, saved to files by default, persist across live-path sessions)  
- Automated Playtest / AI Player system (see dedicated subsection below)  
- Animation Browser page (entry MUST exist when this menu is first implemented; full viewer MAY be a stub until Phase 9, and MUST be complete for Demo-Complete)  
- All other content that was formerly under Pause → System that is not listed above

**Automated Playtest / AI Player System (inside Secret Debug Menu)**

**Why this system is in the GDD**  
The Automated Playtest system is included so its recording, simulation, and recommendation hooks are designed into the same code the player already runs. That keeps programmatic impact low: playtest actors should drive existing input, combat, inventory, extraction, recap, and save flows rather than a second parallel simulation. MUST NOT invent a separate “AI game” with its own combat, loot, or progression implementations.

**Must-ship (Medium bar)**  
The system MUST be able to:  
- Run both the fresh-start save and the progressed save  
- Collect **only** the capped telemetry set below  
- Keep Great Axe, Lightning Staff, and Longbow roughly balanced  
- Calculate per-variable impact coefficients from that set  
- Offer three recommended configurations per save type (one most-ideal + two close alternatives) that the user can further edit before applying  

**Capped telemetry set (non-exhaustive on purpose)**  
Implement the following. MAY add a small number of closely related fields if a Medium-bar recommendation cannot be computed without them. MUST NOT add heatmaps, session replay, input recordings, per-frame combat traces, per-projectile logs, exploration pathing maps, quest-step traces, artifact-set timelines, or any other open-ended analytics product.

*A. Run outcome (one row per run)*  
- End condition: extraction / death / “Dispel” / interrupted playtest  
- Run duration  
- Deepest floor reached  
- Cycle index (which 5-floor loop)  
- Starting weapon + tool type  
- Character type (male / female)

*B. Success-criterion proxies*  
- Time to first clerk interaction  
- Time to first successful extraction (fresh-start save only)  
- Deaths / “Dispels” before first extraction (fresh-start)  
- Recap XP-drain completed (bool)

*C. Combat load*  
- Time in combat vs out of combat  
- Near-death events (HP crossed a tunable threshold; default ~20%)  
- Damage dealt / damage taken  
- Kills  
- Player deaths attributed to the implemented role / type name; Guardian and Gate Master MUST still be tagged separately  
- Dash uses; special (LT) uses  
- Adrenaline Rush activations and uptime  
- Crits landed (count only)

*D. Weapon balance (required for Medium bar)*  
Per weapon (Great Axe / Lightning Staff / Longbow), while that weapon was equipped:  
- Time equipped  
- Damage dealt  
- Kills  
- Deaths while equipped  
- Specials used / specials that hit  

*E. Gathering & economy (light)*  
- Mining hits landed / successful reward rolls  
- Woodcutting hits landed / successful reward rolls  
- Time spent gathering  
- Gold gained / gold extracted / gold lost on death  
- Ore + wood extracted vs lost  
- Ghost Shop purchases (count + gold spent)  
- Forge actions this session (count only)

*F. Playtest meta*  
- Save type: fresh-start vs progressed  
- Exact debug-variable configuration snapshot / hash used for that run  
- Human run vs Automated Playtest run

**Medium-bar shipping floor:** A–D + F, plus enough of E to detect whether gathering/economy is starving first-extraction. Impact coefficients and recommended configurations MUST be computed from this set.

**Full target** (still required if time/compute allows; Medium bar remains the mandatory early shipping floor for the *playtest runner itself*):  
- Replicates natural human gameplay as closely as practical, allowing intentional sub-optimality.  
- Selects different loadouts at the start of runs; deep in-run equipment swapping is not required.  
- Uses two completely independent save files (never the player’s normal save):  
  1. Fresh-start save – repeatedly cleared so every test begins clean.  
  2. Progressed save – contains full progression in all eleven skills; can be reset to a fixed default progressed state.  
- Weapon-aware: actively works to keep Great Axe, Lightning Staff, and Longbow balanced so no single weapon is clearly stronger.  
- Records run history together with the exact variable configuration used.  
- Ships with deduced baseline impact coefficients generated at build time; these are refined by real telemetry.  
- Presents ideal values as fly-out information when a variable is highlighted: one ideal for the fresh-start save (tuned toward first-extraction goals) and one ideal for the progressed save (tuned toward later GDD constraints).  
- Supports accelerated, background, and headless runs. Unlimited queued runs; any run is interruptible without loss of already-collected telemetry.  
- The entire system ships in the public demo but remains hidden behind the secret input sequence.

**Animation Browser (secret debug page)**  
Purpose: let the User review player and enemy animation states so art and facing can be checked without playing a full run.

**Phase rule**  
- Phase 7: the Animation Browser control MUST exist in the secret debug menu. It MUST be labeled, gamepad-focusable, and reachable with the same tab/page navigation as other debug pages. A stub panel (“Animation Browser — implemented in Phase 9”) is acceptable.  
- Phase 9 / Demo-Complete: the full viewer MUST ship. This is a vital development tool in the final product. It is deliberately *not* part of early build logic so sprite pipelines and combat can land first.

**Layout**  
The Animation Browser is a full-screen page. It MUST be TV-readable and gamepad-first, and MUST open with valid initial focus.

- **Back** sits at the bottom of the screen. Activating it returns the User to the main secret debug menu. Activation methods (both required): highlight Back and press A, or press B at any time while the Animation Browser is open. B MUST work regardless of current highlight.  
- **Model selection widget** at the top of the screen:  
  - Left: Previous model button. LB at any time selects the previous model.  
  - Middle: display-only name of the current model.  
  - Right: Next model button. RB at any time selects the next model.  
  - Wrapping at the ends of the model list is allowed.  
  - Model list MUST include player male, player female, and every shipped enemy type including Floor Guardians and the Gate Master.  
- **Preview viewport** directly beneath the model selection widget. Shows a zoomed-in view of the current model playing the current animation. Updates immediately when model, facing, or animation changes.  
- **Play / Pause** sits under the preview. Default: the selected clip loops. Highlight the control and press A to toggle play/pause. Playing vs paused MUST be obvious from the couch.  
- **Direction list and animation list** sit together to the right of the model widget and preview, as two sibling list widgets with the same interaction pattern. The direction list is next to the animation list.

**Direction list**  
- Lists every available facing for the current model: the eight Character Bible directions plus **Idle / None**.  
- The User may move a highlight with the D-pad (or equivalent menu navigation) and press A to select a facing, consistent with other menu lists.  
- **Right stick** sets facing from anywhere in the Animation Browser. Deflect past a deadzone and the nearest of the eight in-game aim octants becomes the selected facing. Releasing the stick to neutral **keeps** the last facing.  
- **R3** sets facing to **Idle / None** from anywhere.  
- Manual highlight + A, right stick, and R3 all write the same current facing. The list highlight MUST match the active facing after any of those inputs.  
- Changing facing immediately rebuilds the animation list for that facing.

**Animation list**  
- Lists only animations available on the current model **for the current facing**.  
- Idle / None lists only clips that belong to that bucket (idle and any other non-directional clips shipped for that model).  
- A compass facing lists only clips that exist for that facing (walk, attack, special, gather, death, “Dispel”, directional attacks, and any other shipped per-facing clips).  
- If the newly selected facing or model does not have the previously selected animation, select the first available animation for that facing.  
- If a facing has no clips, show an empty list and a clear empty state in the preview; do not keep a clip from the old facing.  
- The list MUST refresh when the selected model or facing changes.  
- LT scrolls the animation list up and RT scrolls it down from any focus position.  
- The User may also highlight an entry with normal menu navigation and confirm with A.  
- The selected animation is the one currently playing in the preview.

**Always-available gamepad chords (Animation Browser only)**  
| Input | Action |
|---|---|
| LB / RB | Previous / next model |
| LT / RT | Scroll animation list up / down |
| Right stick | Set facing to that octant |
| R3 | Facing = Idle / None |
| A | Activate highlight (direction entry, animation entry, Play/Pause, Back, on-screen model buttons) |
| B | Back to main secret debug menu |

Keyboard / mouse MUST have equivalents for every action (suggested start: arrow keys or WASD for facing, a dedicated Idle / None key, Q/E or equivalent for model, list scroll on mouse wheel / keys). Exact bindings MAY be invented at implementation time and MUST appear in the rebinding screen.

Exact compare-two, frame-scrubber, and bible-overlay extras MAY be invented at implementation time so long as the requirements above are met.

**Extraction / Clerk UI**  
- Opens on interact with any clerk.  
- Shows a clear, scrollable list of every item currently in the player’s bag and equipped slots that can be extracted.  
- Player can select individual items or use a “Send All” option.  
- Confirmation step required before items are removed from the run and marked as banked.  
- MUST be fully usable with gamepad only and readable from couch distance.

**Ghost Shop UI**  
- Lists available Artifacts (2–4) with short descriptions and prices.  
- Player may purchase a maximum of two Artifacts per visit.  
- Lists snacks with prices.  
- Option to pawn any currently carried gear for a low gold return.  
- Clean confirmation on every transaction.  
- Active set bonuses are shown beneath artifact descriptions.

**Anvil UI**  
- Shows the three holds for the selected slot.  
- Analyze → First Forge → Re-forge flow with clear cost breakdown (gold, ore, root).  
- Smithing level influence visible.  
- Confirmation on every forge action.

**Loadout UI**  
- Opens only by interacting with the Floor Crystal in Placeholdia. There is no separate loadout station.  
- Select holds per slot (fallback to starters), choose starting weapon, choose tool type (pickaxe or hatchet — locked for the run), choose starting floor (deeper previously reached floors only; never backward), confirm enter.  
- Visual presentation MUST meet the same clean, dungeon-themed, TV-readable standard as the other interaction UIs.  
- Confirmation MUST be cancellable.

**Quest UI**  
- Accessible from the guild in Placeholdia.  
- Displays three random quests.  
- Clear accept / decline flow.  
- Active quest status visible where appropriate.

**Recap Screen (mandatory sequence)**  
Triggered on every death or “Dispel”.  
1. Display run statistics.  
2. Play a clear visual sequence that shows each skill’s run XP value draining down to the permanent fragment amount.  
3. After the drain completes, display the new permanent XP totals and the resulting levels.  
4. Show gold and items successfully extracted (if any).  
5. Title / subtitle variants according to performance, including verge states.  
6. Special case: death or “Dispel” on floor 1 with an empty bag MUST include the exact flavor line “They lived just to die. What a waste.”  
7. After the player dismisses recap, play the Placeholdia wake-up sequence.

**Minimap & Large Map**  
- Small minimap on HUD shows only visited tiles + important markers (stairs, crystal, clerks, shop, player).  
- View / Back button opens a large full-screen map overlay. Gameplay continues underneath.  
- Fog of war and visited tracking follow the rules in Dungeon Generation.

**Toasts & Floating Combat Text**  
- Floating damage / heal numbers: integers only, rise and fade quickly.  
- Critical hits use yellow + magenta colored damage numbers (no extra “CRIT!” text).  
- Toasts appear for bag-full, level-up, extraction success, and other system events. Short, readable, non-stacking or lightly stacking.

---

### 14. Audio, Visual & Art Constraints
**Music**  
- The primary dungeon music track is the piece titled “Bitter”.  
- Authoritative links MUST be referenced in the project for attribution and replacement:  
  - YouTube: https://youtu.be/b3Cq_-ymFVU?si=YHZRCFmxf88BXmHW  
  - Spotify: https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA&utm_source=copy-link&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f  
- First playthrough starts at the beginning of the track, including the full intro.  
- The loop point is the **1st beat of the 10th measure**. After that point is reached, subsequent loops MUST start there and MUST NOT replay anything before it.  
- The equivalent timestamp of that beat MUST be measured from the supplied master and exposed in the secret debug menu as the loop offset. If the measured time and the score disagree, the score rule (1st beat of measure 10) wins until the User locks a timestamp.  
- Volume and crossfade / fade behavior remain tunable.  
- Hub music may be any warm, slightly hopeful, lightly comedic stand-in until final assets are created.  
- Credit line “Bitter — ViraXVespa” MUST appear on the title screen and in the pause menu where appropriate.

**SFX – Minimum Required Set**  
See Appendix E for the complete list. All volumes are controlled by the SFX slider. Additional short UI, weapon-specific, and ambient sounds may be added.

**Visual & Art Rules**  
- Base resolution for characters and most props: 64×64 pixels.  
- Nearest-neighbor filtering only (no linear filtering on sprites).  
- All characters use Y-billboard so they remain upright under the orthographic camera.  
- Character art (player and enemies) is generated and assembled according to the mandatory pipeline defined in **Section 19**.  
- Required player states at minimum: idle, walk, attack (per weapon), special (per weapon), gathering (mining/woodcutting), death, “Dispel”.  
- Each weapon requires its own paper-doll equip appearance and associated animations.  
- Male and female player characters MUST maintain full animation parity.  
- Male and female characters each require a complete, dedicated voice-over set of equal scope.  
- Player and enemy animations use exactly 8 directions matching the Character Bible layout.  
- All directional variants of the same animation state MUST contain exactly the same number of frames.  
- Wall height, tile size (1 unit = 64 px), and depth-sorting SHOULD produce correct layering. Arbitrary popping MUST be avoided wherever possible, but it is not a hard failure if a small amount remains after best-effort sorting.  
- Buildings in Placeholdia MUST have actual depth and realistic dimensions.  
- Lighting, fog color/density, and void plane MUST create a clear visual contrast between the warmer Placeholdia hub and the colder, darker dungeon floors.  
- Consciousness-transfer VFX on dungeon enter and wake-up VFX on return to Placeholdia are required presentation beats.

**Credit Splash → Title Sequence**  
- Existing timing may be used as a baseline.  
- The credit line MUST be modified so that the word “Proudly” is crossed out and the word “Shamelessly” is written above it in a graffiti style. The final readable phrase is “Shamelessly Vibecoded with Grok.” The graffiti treatment MUST look intentional and vandalized.

**Placeholder Policy**  
The only assets considered final are:  
- The designer’s profile picture  
- Official Grok / xAI logos and related assets  

Every other sprite, animation, tileset, prop, UI graphic, music track (except the identified “Bitter” reference), and sound effect is placeholder and MUST be replaced or massively updated before the demo is considered shippable.

---

### 15. Save / Persistence / Technical
**Save System**  
- Save data is stored in browser `user://` (or equivalent platform-appropriate location).  
- A primary save file and a backup of the last successfully loaded save MUST both be maintained.  
- If the primary save is missing, corrupted, or fails to parse, the game automatically falls back to the backup. If both fail, a fresh dungeon delver is created.  
- Save data MUST persist across sessions and include at minimum:  
  - Permanent XP and levels for all eleven skills  
  - Banked gold  
  - Banked resources (ore, wood, etc.)  
  - The three forged holds for every equipment slot  
  - Unlocked deepest floor  
  - Selected character type (male / female)  
  - Camera zoom and HUD scale settings  
  - Aim-line on/off state and opacity  
  - Any other player settings and debug overrides that should persist  

**Restock-on-Return**  
If the player returns to Placeholdia with gold or consumables below configurable thresholds, a limited free restock of basic food and potions is granted.

**Debug Profiles**  
Named debug profiles (unlimited) are saved to files by default and persist across live-path sessions. Archives builds use the default values that existed at the moment of archiving.

**Automated Playtest Saves**  
The Automated Playtest / AI Player system maintains two completely independent save files that never interact with the player’s normal save data:  
1. Fresh-start save – repeatedly cleared by the system.  
2. Progressed save – contains full skill progression and can be reset to a fixed default progressed state.  
Both are stored under isolated paths and follow the same primary + backup safety rules.

**Presentation Switcher**  
The live / classic_2d / art_experiment switcher and the Archives browser MUST ship in the final demo. Selecting “Play” always launches the live presentation path. The Archives list also includes **`full_3d_pass`** (on-screen label **Full 3D Pass**). This system exists to support the Patreon development narrative and MUST not be removed.

**Web Export Requirements**  
- MUST run in modern browsers.  
- MUST NOT require special COOP/COEP headers or other non-standard server configuration to function on GitHub Pages or equivalent static hosting.

**Performance**  
- Consistent 60 FPS minimum on target hardware at all times. Higher frame rates are allowed and desirable.  
- Frame time and memory usage MUST remain stable even on the deepest floors with full enemy and particle load.  

**Renderer**  
Compatibility renderer is preferred for the shippable build if it does not break the web export. Mobile renderer may be retained only if required for web stability.

---

### 16. Balancing, Feel & Polish Targets
**Time Targets**  
- A brand-new player SHOULD be able to achieve their first successful extraction in 5–10 minutes.  
- A competent player SHOULD be able to reach and clear floor 6 in roughly 5–10 hours of total play. This is a feel target, not a hard cap.  
- Skilled play SHOULD support significantly longer continuous runs.

**Death & Learning Curve**  
- A competent player SHOULD reach consistent clears of the early loop within roughly 20–30 total dives. Exact number is a feel target, not a hard metric.  
- Death MUST always feel like a fair consequence of player decisions or execution rather than randomness or hidden information.

**Difficulty Progression**  
- Difficulty scales with floor number and with each completed 5-floor cycle.  
- The jump from floor 1 to later floors MUST be noticeable but not punitive.  

**Visible Power Gain**  
After one successful extraction and return to Placeholdia the player MUST be able to clearly notice either:  
- a few permanent skill levels, or  
- at least one new usable piece of forged gear  
(or both). This is a required psychological reward. Concrete proxy: the change MUST be visible on the hub screens without external guidance.

**Weapon Balance**  
The three weapons (Great Axe, Lightning Staff, Longbow) MUST remain balanced with one another so that no single weapon type is clearly stronger. The Automated Playtest system actively monitors and supports this constraint.

**Accessibility (Mandatory)**  
- Full control rebinding for gamepad and keyboard/mouse.  
- Independent HUD scale control.  
- Aim-line toggle and opacity.  
- Gamepad-first design with valid initial focus on every menu.  
- These features are required for the demo ship. Additional accessibility options may be added but are not mandatory.

**Polish Bar**  
Every system that appears in the demo is considered production / Gold. No “temp” or “programmer art will do” exceptions are allowed for systems that ship. Placeholder assets are permitted only under the explicit policy in the Audio/Visual section and MUST be replaced before release.  
Player-facing UI and HUD MUST be dungeon-themed. Default / unskinned engine controls MUST NOT appear on the playable path. The secret debug menu is exempt.

The Automated Playtest / AI Player system (secret debug menu) exists to generate telemetry and recommended configurations from the capped set in Section 13 so the demo can meet the targets above without a parallel simulation stack or an unbounded metrics product.

---

### 17. Edge Cases & Failure Modes
**“Dispel” or Death on Floor 1 with Empty Bag**  
- Full recap screen is still shown.  
- The exact flavor line “They lived just to die. What a waste.” MUST appear.  
- All normal XP-drain and permanent-fragment logic still executes (even if values are zero).

**Bag Full**  
- When the player walks over any loot while the bag is at capacity, the item is not picked up.  
- A clear toast is displayed.  
- The item remains on the ground and can be picked up later if space is made.

**Death or “Dispel” During Gathering / Dash / Special**  
- All actions are immediately interrupted.  
- The appropriate death or “Dispel” animation sequence begins with no residual movement, gathering hits, or i-frames carrying over.

**Multiple Clerks / Shops**  
- Hard limit: maximum one Ghost Shop per floor.  
- Hard limit: maximum three clerks total per floor.  
- Generation MUST respect these caps.

**Save Corruption or Missing Save**  
- Primary save is attempted first.  
- On any failure to load or parse, the game silently falls back to the backup of the last successfully loaded save.  
- If the backup also fails, a completely fresh dungeon delver is created.  
- No partial or corrupted data is ever presented to the player.  
- The same primary + backup rules apply independently to the two Automated Playtest save files.

**Locked Stairs / Boss Door**  
- Stairs are inaccessible while the Floor Guardian or Gate Master is alive.  
- They remain behind the visible boss door.  
- Once the boss is defeated the door opens and the stairs become usable.  
- No additional toast is required beyond the door state itself; the visual lock is sufficient.

**Tool Type Lock**  
- Once a tool type (pickaxe or hatchet) is selected at loadout, the player cannot equip the other type during that run even if one is found.

**Artifact Sets**  
- Set bonuses only count artifacts currently carried or equipped in the active run.  
- Artifacts are never extractable and are lost on death or “Dispel”.

**Secret Debug Sequence**  
- The shoulder-button sequence MUST be performed exactly as specified.  
- No feedback is given on partial or failed attempts so that regular players remain unaware of the menu’s existence.  
- Opening the menu is the only confirmation of success.

**Automated Playtest Interruption**  
- Any running or queued automated playthrough can be interrupted at any time.  
- All telemetry and run data collected up to the interruption point are preserved.

**Other Failure Modes**  
- Attempting to use a potion or food when none is equipped/available produces a clear toast and no effect.  
- Attempting to use food of the same type while its heal-over-time is still running does not consume another item.  
- Attempting to forge without sufficient resources produces a clear failure message and no consumption of partial materials.  
- All confirmation prompts (“Dispel”, Delete Save, major extractions, character switch, etc.) MUST be cancellable and MUST NOT be triggerable by accident with a single button press.

---

### 18. Implementation Phases for Grok Build (Hard-Gated)
This document is the authoritative specification for the demo of *What Dwells Below*.

A fresh Grok Build instance MUST:

1. First create a fully isolated archive of the current project state following the exact rules in Section 20, stored as **`full_3d_pass`** (on-screen label **Full 3D Pass**). This archive becomes the next selectable build in the Archives browser.  
2. Then implement a clean, from-scratch live path that satisfies every requirement in this GDD.

**Core Construction Rules**  
- The live path is a clean rewrite. MUST NOT extend, refactor, or reuse runtime code, scenes, scripts, autoloads, or architectural patterns from the pre-archive live codebase.  
- Design the live path from the ground up around the orthographic Camera3D system (Section 4).  
- The live path MUST never share runtime code, scenes, scripts, or global state with any archived build.  
- Treat every numeric value as tunable and expose it in the secret debug menu.  
- Prefer simple, readable, production-quality implementations over clever legacy workarounds.  
- All player and enemy character art MUST follow the mandatory pipeline in Section 19.  
- Male and female player characters with full animation parity and complete peer voice-over sets, the three-weapon system, hit-based mining and woodcutting, eleven skills, blue rarity (boss-only), named monsters, enemy bases, quest system, artifact collections/sets, aim-line indicator, Controls Billboard, Floor Crystal loadout, idle/pressure spawns, food vs potion distinction, enter/wake VFX, and gamepad-first UI with initial focus are mandatory.  
- The secret debug menu (including profile Save/Load, Automated Playtest / AI Player system) MUST ship at production quality but remain hidden behind the documented shoulder-button sequence.  
- Automated Playtest hooks MUST live in the same systems the player uses. Telemetry is limited to the Section 13 cap.  
- Animation Browser controls belong in the first secret-debug implementation; the full viewer is required at Demo-Complete, not in early phases.  
- Player-facing UI MUST be dungeon-themed. Default / unskinned controls are allowed only in the secret debug menu.  
- Production / Gold quality is required for every system that ships. Placeholders are allowed only under the explicit policy in Section 14.

**Gated Implementation Phases (Hard Blockers)**  
Advance only after exit criteria are met, self-verified, and progress is reported to the User.

**Phase 1 – Foundation**  
New project scaffolding + Camera3D + input + basic player movement/animation states (Section 19 sprites, 8 directions) for both male and female characters.  
*Exit criteria*: Player can move, face 8 directions, and idle/walk with Y-billboard at 60 FPS. Depth sorting SHOULD be correct under implied real-world positions, with popping avoided wherever possible. Report to User.

**Phase 2 – Core Combat**  
Three weapons with basic + LT specials, Dash, target-lock, crits, Adrenaline Rush, full attack telegraphs, aim-line indicator, proper depth sorting and juice.  
*Exit criteria*: All three weapons fully playable with telegraphs and active indicators; 60 FPS; all values exposed in debug. Report to User.

**Phase 3 – Dungeon Structure**  
Dungeon generation + boss doors + locked stairs + Floor Guardians / Gate Master + enemy bases.  
*Exit criteria*: Repeating 5-floor loop generates, bosses spawn behind doors, stairs lock/unlock correctly. Report to User.

**Phase 4 – Enemies**  
≥12 types, variety, named monsters, flee event, telegraphs, AI including leash / drop-pursuit and idle / pressure spawns.  
*Exit criteria*: At least 5 types per floor, named monsters appear, flee event triggers, all telegraphs readable, enemies drop pursuit at leash range, idle/pressure spawns function outside safe rooms. Report to User.

**Phase 5 – Gathering & Interactables**  
Hit-based mining and woodcutting, breakables, and all interactables (including expanded Artifact sources).  
*Exit criteria*: Nodes function with correct hit timing and rewards; all listed interactables present and usable. Report to User.

**Phase 6 – Progression Systems**  
Inventory, equipment (including tool type lock), food vs potion rules, forged holds, extraction/clerks, anvil, Floor Crystal loadout, quest system, artifact collections/sets (exactly eight).  
*Exit criteria*: Full inventory/extraction/forge/quest/artifact loop works; loadout opens from the Floor Crystal; eight sets with progressive bonuses; food HoT and potion instant heal behave as specified. Report to User.

**Phase 7 – UI & Debug**  
Full HUD (including food HoT indicator), pause menu (three tabs + character switch + aim-line controls + “Dispel” Avatar), secret debug menu (profiles + Automated Playtest Medium bar + Animation Browser *entry*), recap screen with XP drain sequence. Player-facing UI uses dungeon theming.  
*Exit criteria*: All UI elements present, gamepad-first with initial focus, no unskinned player-facing UI, secret menu accessible only via sequence, Medium-bar Automated Playtest functional using the Section 13 telemetry cap, Animation Browser control present and focusable (stub allowed). Report to User.

**Phase 8 – Persistence & Hub**  
Save / load with backup + isolated save paths for archives and for the two autoplay saves. Placeholdia hub layout (buildings with real depth) including Controls Billboard, Floor Crystal loadout, consciousness-transfer enter VFX, and wake-up return sequence.  
*Exit criteria*: Save/load + backup works; hub complete with all listed interactables and depth; enter/wake presentation beats play; Archives switcher functional including `full_3d_pass`. Report to User.

**Phase 9 – Final Polish & Verification**  
Final audio pass (including Bitter loop rule and linked masters), placeholder replacement, no default UI on the playable path, Archives browser verification, full Animation Browser viewer, full Demo-Complete Checklist self-audit, 60 FPS under load, Success Criterion simulation.  
*Exit criteria*: Checklist fully satisfied including the complete Animation Browser; report final verification results to User and await confirmation before declaring complete.

---

### 19. Mandatory Player Sprite & Paper-Doll Generation Pipeline
This section is mandatory for any Grok Build instance.  
It exists because pure image-generation models (including Grok Imagine) have consistent, well-documented limitations with multi-frame consistency, identity drift, spatial layout in grids, and pixel-perfect output. The pipeline below is the most reliable process currently achievable after extensive testing.

All character art (player and enemies) MUST follow this pipeline. Props may use a simplified stills-only variant.  
Male and female player characters MUST each have their own locked Character Bible and MUST maintain full animation parity so that weapon paper-doll layers and animations function on either without special per-gender tweaks.  
Player and enemy animations use exactly 8 directions matching the Character Bible layout.

#### 19.0 Goals & Non-Negotiables
- One locked Character Bible per character type (male and female) is the single source of truth for identity, proportions, palette, and style.
- Identity drift, anti-aliasing, magenta spill, foot sliding, scale inconsistency, and extra limbs/props are hard failures.
- All final frames MUST be true pixel art on an integer grid after cleanup (nearest-neighbor only).
- Prefer fewer high-quality, readable frames over many mediocre ones. The engine can hold or simple-tween if needed.
- Generate and fully clean one complete directional set (idle + walk at minimum) as a proof before scaling to all directions and states.
- Final engine resolution target: 128×128 canvases (recommended for detail and alignment). Nearest-neighbor downscale to 64×64 is permitted only if required by import settings; document the choice. Base resolution in Section 14 remains 64×64 for world units, but sprite assets ship at 128×128 unless otherwise specified.
- Use **game-centric direction names** exclusively: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right. These match the orthographic camera, Y-billboard, and 8-directional aim system.
- All directional variants of the same animation state for a given character MUST contain exactly the same number of frames.

#### 19.1 Character Bible
Create and lock **one primary 3×3 Character Bible** on a solid pure magenta (#FF00FF) background for each character type (male and female).

**Strict cell layout (do not swap, reverse rows, reverse columns, or move any figure):**  
(See Appendix C for the full prompt template and exact cell descriptions.)

Requirements:  
- Clean limited-palette pixel-art style.  
- All eight full-body views in neutral standing pose (no weapons, no action props).  
- Consistent silhouette height and foot baseline across all full-body cells.  
- Extract and lock the exact palette used.  

This single image is the primary design reference for all subsequent generations of that character type.

A visual reference of **cell positioning and presentation quality** can be found at:  
`assets/sprites/player/gdd_reference_bible.jpg`

**Important:** That file is **not** a locked art style and is **not** the desired final look. It exists only to show Bible layout (3×3 cell placement, full-body framing, face close-up in the center) and a quality bar for silhouette readability. Grok Build MUST generate Character Bibles and animation frames from scratch. Do not treat the reference image as an input asset to edit or extend, and do not copy its surface style as a requirement.

Final styling is intentionally unset before lock. Grok Build MAY propose new visual options so long as they satisfy the rest of this GDD (readable 64×64 / 128×128 pixel-grid output after cleanup, 8-direction Bible layout, male/female parity, Y-billboard, nearest-neighbor, limited palette after lock, no anti-aliasing in shipping frames). Generate 2–4 distinct style candidates per gender, then lock the best Bible pair and palettes as usual.

**After lock:** `bible_locked_male.png` / `bible_locked_female.png` (plus palettes) force the look. Every later generation — directional stills, animation frames, paper-doll layers, video fill-in — MUST match the locked Bible. Soft identity language applies only after that lock. If a Bible must be regenerated after lock, match the locked Bible. A new style is allowed only if the User explicitly agrees to re-lock.

Treat the locked Bibles as immutable unless the User authorizes a re-lock. Store them as:  
`assets/sprites/player/bible_locked_male.png`  
`assets/sprites/player/bible_locked_female.png`  
(+ locked palettes).

**Note on reliability:** Single-pass 3×3 generation currently produces the highest identity consistency. Chained image-edits from a single anchor introduce cumulative off-model drift and should be avoided for the Bible itself. If layout errors persist after 3–4 attempts, fall back to generating the eight full-body views + face individually (using soft identity language against the chosen style, then against the locked Bible once it exists) and compositing them deterministically with a script.

**Background color:** Grok often paints near-magenta instead of pure `#FF00FF` (example: `#EE22DD` and other hot pinks / violets). Treat saturated magenta / hot-pink / violet backdrop as keyable background. Range-key it, despill fringes, then write remaining background pixels to exact `#FF00FF`. Do not key skin, scarf, metal, or other on-model pinks. If a range catch eats character pixels, tighten the range and retry.

**Square the Bible before any 3×3 split:** A generated Bible MAY not be a perfect square and MAY include extra margin. Hug the **grid**, not the silhouettes. Outer-cell magenta padding stays in the sprites; only leftover canvas outside the 3×3 is cut.

Do not crop to the union bounding box of the eight bodies. That throws away the padding that belongs inside each cell.

Instead, recover the intended grid and crop to that:
1. Range-key the background so figures are separable.  
2. Find the eight full-body figures (ignore the center face close-up for lattice fitting if it sits on a different scale).  
3. Take each figure’s center. Fit them to a 3×3 lattice. Horizontal pitch = average distance between neighboring column centers. Vertical pitch = average distance between neighboring row centers.  
4. Cell size = the larger of those two pitches. Using the larger pitch keeps short-axis padding instead of clipping it.  
5. The crop square is **3 × cell size**, centered on the lattice origin (the center cell).  
6. That square MUST include the magenta padding around the outer figures. It MUST NOT include random extra canvas beyond one grid-cell of margin.  
7. Do not stretch or linearly scale to force a square. Crop only.  
8. If centers do not form a readable 3×3 (skewed rows, missing figure, overlapping cells), discard and regenerate the Bible. Do not guess.

After that square exists, split into nine **equal** cells.

#### 19.2 Generation Hierarchy (ordered by reliability)
Always work **one direction + one action at a time**. Never hard-code exact frame counts. Never generate full multi-direction strips in one pass.

**Priority order:**

1. **Image-to-video (highest reliability for locomotion)**  
   Use whenever available. Default seed is a **spliced single still**, not the full Bible sheet. Extract frames, then curate 4–8 clean ones.

2. **Individual classic key poses**  
   Contact → Down → Passing → Up (and any needed extremes). Generate one pose at a time against the locked Bible.

3. **Short in-place horizontal strip**  
   Use the prompt template style from Appendix C, adapted for the specific action and single direction.

4. **Forbidden**  
   Full multi-direction strips, hard frame-count demands, or multi-action sheets in one generation.

**How to extract a splice from the locked Bible**  
The locked Bible is a perfect 3×3 grid after the square-crop above. Treat it as nine equal cells. Do not use the center cell as an animation seed (that cell is the face close-up only).

| Cell | Contents |
|---|---|
| Top-left | Up-Left full-body |
| Top-center | Up full-body |
| Top-right | Up-Right full-body |
| Middle-left | Left full-body |
| Center | Face close-up — **not an animation seed** |
| Middle-right | Right full-body |
| Bottom-left | Down-Left full-body |
| Bottom-center | Down full-body |
| Bottom-right | Down-Right full-body |

Extraction / seed order:
1. Range-key + despill background; flatten leftover background to `#FF00FF`.  
2. Square-crop the 3×3 block using the lattice method in §19.1.  
3. Split into nine equal cells.  
4. Crop the one full-body cell that matches the facing being generated.  
5. Keep the magenta background on that crop. Do not redraw, rescale with filtering other than nearest-neighbor, or composite extra cells into the default seed.  
6. Use that crop as the I2V first frame / identity lock.  
7. If a later clean directional still already exists for that facing, that still MAY be used instead of re-cropping the Bible.

**When to use the seed**  
- Default for every Image-to-Video attempt: **one spliced still** of the needed facing.  
- Do **not** start with the full 3×3 sheet.

**Fallback to the full Bible (allowed)**  
Switch to the full locked Bible (optionally plus extra cropped cells) only if:
- single-still I2V fails on-model / motion checks after the normal retry budget, or  
- the clip clearly needs identity from more than one facing (examples: a turn, a direction-change, an attack that reads the body from two angles).

Even in fallback, prompts MUST still name the primary facing. After video extract, every frame still goes through §19.6 cleanup.

**Soft identity language (mandatory in every prompt after Bible lock):**  
“Keep the same overall character design, face, hair, armor, green scarf, proportions, palette, and sprite style from the Bible. Do not redesign, repaint, recolor, simplify, smooth, or invent new details.”

That language means the **locked** Bible, not the reference JPG.

Generate one full cardinal direction (Down + Left + Right + Up) completely before deriving diagonals. Horizontal flip is acceptable for opposite sides when the design is mostly symmetric; asymmetric details (green scarf, etc.) MUST be corrected or regenerated.

#### 19.3 Required Player States
Minimum required states (from Sections 5 and 14):  
idle, walk, attack (per weapon), special (per weapon), gathering (mining/woodcutting), death, “Dispel”.

Prioritize idle + walk first. Animation playback speeds remain tunable.  
Full parity between male and female is required for every state and every weapon.  
The same frame-count rule applies to every animation state.

#### 19.4 Paper-Doll / Equipment Layers
Generate each equipment piece (especially the three weapons) against a **single clean base-body frame** from the correct direction (not the full Bible).  
Use the same soft identity language, range-keyed magenta background flattened to `#FF00FF`, and cleanup rules.  
Weapon paper-doll layers MUST work correctly on both male and female base bodies.

#### 19.5 Post-Generation Viability Analysis & Video Fill-In
After the initial animation-generation phase, Grok Build MUST automatically analyze the collected sprite-frame pool for every animation state and every direction.

The analysis MUST verify:  
- Sufficient frames exist in the “passing” / leg-crossover stage of the cycle.  
- Generated frames correctly show both legs and arms crossing (forwards/backwards or in-front/behind) as required for natural locomotion and action.  
- All directional variants of the same animation state contain exactly the same number of frames.

If any requisite frames are missing or incorrect, Grok Build shall:  
1. Use the locked Character Bible(s) as the identity and style reference.  
2. Prefer Image-to-Video seeded from a single spliced Bible cell or a single clean directional still of the needed facing, following §19.2.  
3. Generate a short video of the required animation using a motion-focused prompt that explicitly requests the missing passing/crossover frames and correct limb crossing.  
4. Extract candidate frames from the video.  
5. Run every extracted frame through the full mandatory cleanup pipeline (range-key magenta + despill + flatten to `#FF00FF`, crop + padding, nearest-neighbor scale to target canvas, foot-baseline lock, palette quantize, anti-aliasing removal, etc.).  
6. Integrate the new frames into the pool provided they remain on-model.

Fall back to the full Bible only under the §19.2 fallback conditions.  
Maximum practical retries follow the existing generation hierarchy (2–3 Image-to-Video attempts before falling back).  
If video-extracted frames still fail the on-model / crossing checks, note the failure, continue the build using the available animations, and at completion inform the user of the failure together with a suggestion for manual cleanup.

#### 19.6 Mandatory Cleanup & Normalization Pipeline
All AI-generated frames (including those extracted from video) **MUST** pass through cleanup before use in the game.

Recommended tools:  
- Existing project scripts in `tools/`  
- Or Aseprite + DeAI PixelKit / Pixel Refiner / Alpha Remover  
- Or equivalent browser tools

**Required cleanup tasks (in order):**  
1. Range-key saturated magenta / hot-pink / violet background around `#FF00FF`. Apply despill for any fringe. Flatten remaining background pixels to exact `#FF00FF`. Do not key on-model pinks.  
2. Crop to content bounding box + fixed transparent padding.  
3. Nearest-neighbor scale/fit to exact target canvas (128×128 recommended).  
4. Center horizontally.  
5. **Lock feet to a common baseline Y** across all frames of a cycle.  
6. Quantize / lock to the Bible palette.  
7. Eliminate anti-aliasing, sub-pixel noise, and ghosting.  
8. For video/strip sources: even frame selection, skip settling frames, validate loop.  
9. Trim to the exact frame count needed by the engine (ensuring directional parity).  
10. Output individual frames or engine-ready sheets + simple manifest (frame size, count, fps, pivot/anchor).

#### 19.7 Success Criteria & Failure Recovery
A generation is acceptable only if it meets **all** of the following after cleanup:  
- Readable silhouette at target size.  
- Correct facing and pose intent.  
- No extra limbs, props, or invented details.  
- No palette drift from the locked Bible.  
- No background remnants or magenta spill.  
- Consistent scale and foot baseline with the Bible and sibling frames.  
- Integer pixel edges, no anti-aliasing.  
- Correct limb crossing and sufficient passing-stage frames.  
- Identical frame counts across all directions of the same animation state.

**Recovery decision tree:**  
- Fail after 2–3 retries of the current method → drop one level in the Generation Hierarchy.  
- Persistent identity or scale failure → return to Bible and re-lock if necessary (only with User approval if style would change).  
- Video fill-in still fails checks → note failure, proceed with available frames, inform user at end of build for manual cleanup.  
- Log the failure mode.

(See Appendix D for the full Summary Reliability Table.)

This is the most reliable pipeline currently achievable with Grok Imagine and related tools for the player characters (and enemies) of *What Dwells Below*. Follow it exactly. Deviations require explicit justification and re-validation under the orthographic camera + Y-billboard + nearest-neighbor filtering.

---

### 20. Archived Builds System (Standalone Snapshots)
The Archives system (classic_2d, art_experiment, full_3d_pass, and any future historical builds) exists solely to support the Patreon development narrative and let players experience the game **exactly as it was at specific points in development**.

**Core Rule (Non-Negotiable):**  
Every archived build MUST be a **completely standalone, self-contained version of the game**.  

- An archived build MUST NOT share runtime code, scenes, scripts, autoloads, or global state with the live (main) path.  
- The live path MUST never be required to maintain compatibility with, or be limited by, any archived code.  
- Conversely, loading an archived build MUST never pull in or be altered by any live/current code.  

If either of the above occurs, the archive no longer represents the historical state and the live game becomes artificially constrained by legacy requirements. Both outcomes are forbidden.

#### Technical Requirements
1. **Isolation**  
   - Each archived build lives in its own self-contained folder under `archives/` (e.g. `archives/classic_2d/`, `archives/art_experiment/`, `archives/full_3d_pass/`).  
   - These folders contain (or point to) a complete, frozen Godot project snapshot, including all scenes, scripts, assets, and project settings as they existed at the moment of archiving.  
   - No `#ifdef`, feature flags, or runtime conditionals that allow live code to reach into an archive (or vice versa) are permitted.

2. **Launch Behaviour**  
   - Selecting an archived build from the Archives browser MUST launch that snapshot as an independent instance (or fully replace the current main scene / project context).  
   - Selecting “Play” from the main menu or any live UI **always** launches the current live path.  
   - There is no “hybrid” mode in which live and archived systems run simultaneously or share state.

3. **Creating a New Archive**  
   - To create a new historical snapshot:  
     1. Freeze the current live project state.  
     2. Copy the entire relevant project contents into a new dated or named folder under `archives/`.  
     3. Remove any live-only systems that did not exist at that point in time.  
     4. Verify the archived build runs completely independently and produces the exact experience of that moment.  
   - The archive created at the start of this GDD contract MUST use the id **`full_3d_pass`** (on-screen label **Full 3D Pass**) and MUST NOT overwrite `classic_2d` or `art_experiment`.  
   - The newly created archive becomes the next selectable build in the Archives browser.  
   - Once archived, the snapshot is immutable. Future live changes MUST never be back-ported into it.  
   **Verification (MUST)**: After creation, launch the archive independently and confirm zero shared runtime elements with the live path. Report result to User.

4. **Presentation Switcher Integration**  
   - The existing presentation switcher (live / classic_2d / art_experiment) plus the Archives browser remains.  
   - classic_2d and art_experiment are treated as the first two archived builds. `full_3d_pass` is the third archived build (the previous live path at GDD handover). All three MUST obey the same standalone rules above.  
   - The switcher is only a launcher; it does not keep multiple versions loaded or share state.

5. **Save Data**  
   - Each archived build uses its own isolated save path (or a clearly versioned prefix) so progress in an old build cannot affect or be affected by the live save.

#### Archives Browser UI Layout
The Archives browser is accessed from the Pause Menu → System tab (or equivalent).

**Main Layout**  
- **Left side**: Vertical list of all archived builds by name.  
- **Right side**: Info panel that updates whenever a build is highlighted/selected in the list.

**Info Panel Contents** (updates on highlight)  
- Brief description of the selected build.  
- **Video** button  
  - When pressed, plays the associated video for that build.  
  - Videos do not currently exist.  
  - If no video is available for the selected build, the button is grayed out and disabled.  
- **Documents** button  
  - When pressed, opens a list of documents related to that specific build for the player to view.  
  - If no documents exist for the selected build, the button is grayed out and disabled.  
- **Play** button  
  - Launches the selected archived build (subject to the isolation rules above).

The list and info panel update dynamically when a new archive is added. After the Mandatory Workflow archive step the list MUST include at least classic_2d, art_experiment, and full_3d_pass (Full 3D Pass).

This policy guarantees two things simultaneously:  
1. Players can experience the game exactly as it was at any archived moment.  
2. The main development path remains free of legacy baggage.

Any future archived build MUST follow these rules from the moment it is created.

---

## Appendix A – Suggested Starting Values (All Tunable via Debug Menu)
These are recommended starting points for the clean live implementation.  
Every value **MUST** be exposed in the debug menu and treated as non-final. Consult on demand.

### Movement & Combat
| Parameter                      | Suggested Start | Notes                                              |
|--------------------------------|-----------------|----------------------------------------------------|
| Base move speed                | 4.5             | Feel weighty but responsive                        |
| Dash speed multiplier          | 2.8             | Full i-frames for entire duration                  |
| Dash duration                  | 0.28 s          |                                                    |
| Dash cooldown                  | 1.1 s           |                                                    |
| Special (LT) wind-up           | 0.22 s          | Applies to all weapon specials                     |
| Special recovery               | 0.35 s          |                                                    |
| Great Axe Slam damage multiplier | 1.8×          | vs basic attack                                    |
| Basic attack arc (Great Axe)   | 110°            |                                                    |
| Crit chance                    | 12 %            | Double damage + yellow/magenta colored numbers     |
| Adrenaline kill window         | 4.5 s           |                                                    |
| Adrenaline kill threshold      | 4               |                                                    |

### Gathering (Hit-Based)
| Parameter                      | Suggested Start | Notes                                              |
|--------------------------------|-----------------|----------------------------------------------------|
| Mining hits per node           | 4               | Range 3–5                                          |
| Mining time between hits       | 2.4 s           |                                                    |
| Mining base reward chance      | 65 %            | Scaled by Mining skill + pickaxe                   |
| Woodcutting hits per node      | 8               | Range 6–10                                         |
| Woodcutting time between hits  | 1.2 s           |                                                    |
| Woodcutting base reward chance | ~32 %           | Approximately 50 % lower than mining               |

### Dungeon Generation
| Parameter                      | Suggested Start | Notes                                              |
|--------------------------------|-----------------|----------------------------------------------------|
| Floor grid size                | 48×48 – 64×64   | Must feel expansive                                |
| Fog of war reveal radius       | 5 tiles         | Visited tiles stay revealed                        |
| Max clerks per floor           | 3               |                                                    |
| Ghost shop chance              | ~33 %           | Always in safe room                                |
| Named monster rate             | ~1 every 3 floors |                                                  |
| Flee events per full clear     | Average 2       | With small speed boost on fleeing enemy            |
| Idle / pressure spawn timer    | 20–30 s         | Outside safe rooms; also if no new tiles revealed  |

### Progression & Economy
| Parameter                      | Suggested Start | Notes                                              |
|--------------------------------|-----------------|----------------------------------------------------|
| Bag capacity                   | 28              |                                                    |
| Permanent XP keep rate on death| 15–25 %         | Must feel meaningful after a good run              |
| Shrine damage buff             | +20 % / 45 s    |                                                    |
| Campfire heal                  | 40 % max HP     |                                                    |
| Food HoT total (X)             | 40 HP           | Delivered over Y seconds                           |
| Food HoT duration (Y)          | 8 s             | Same food does not restack                         |
| Potion instant heal (Z)        | 100 % max HP    | Instant; distinct from food                        |

### UI / Feel Targets
| Parameter                      | Suggested Start | Notes                                              |
|--------------------------------|-----------------|----------------------------------------------------|
| Camera zoom range              | 1.0 – 1.75      | Persisted in save                                  |
| Target first-extraction time   | 5–10 min        | New player on gamepad                              |
| Target floor-6 clear time      | 5–10 hours      | Competent player; feel target                      |

All other values (enemy stats, drop rates, forge costs, weapon-specific damage/ranges, quest rewards, leash range, Bitter loop offset timestamp, etc.) should be chosen to support the same feel targets and MUST also be exposed in the debug menu.

---

## Appendix B – Demo-Complete Checklist (True Non-Negotiables)
(Identical to the front-matter checklist for quick reference.)

A build meets the contract only when **all** of the following are true:
- The Success Criterion above is achieved on the clean live path.
- Mandatory Workflow (archive-then-clean-rewrite) has been followed.
- Live path shares no runtime code, scenes, scripts, or global state with any archived build.
- Exactly the eleven skills listed in Section 7.
- Exactly eight artifact sets (run-only).
- Hit-based gathering for mining and woodcutting.
- Repeating 5-floor structure with Floor Guardians (1–4) and Gate Master (5).
- White / green / blue rarity only (blue is boss-only).
- Player animations use exactly 8 directions with full male/female parity. Each character type has its own complete voice-over set.
- Secret debug menu (including Medium-bar Automated Playtest) ships but remains hidden.
- Automated Playtest Medium bar ships, hidden behind the documented sequence, using the capped telemetry set in Section 13 (no open-ended analytics product).
- Secret debug menu includes a focusable Animation Browser entry from Phase 7 onward, and the full Animation Browser viewer ships by Demo-Complete (Phase 9).
- Every shipping system is Production / Gold quality and fully exposed to the debug menu.
- Consistent 60 FPS minimum.
- Solo play only; no co-op scaffolding.
- No systems, skills, rarities, hub upgrades, or meta-progression beyond what this document explicitly requires.

---

## Appendix C – Full Character Bible Prompt Template
(Consult on demand.)

```
Create a single clean image that is a perfect 3×3 Character Bible grid on solid pure magenta #FF00FF background for the [male/female] player character of "What Dwells Below".

Strict cell layout (do not swap, reverse rows, reverse columns, or move any figure):

Top row:
- Top-left: Up-Left full-body, complete head-to-feet, character facing Up-Left, neutral standing
- Top-center: Up full-body, complete head-to-feet, character facing Up (full back view), neutral standing
- Top-right: Up-Right full-body, complete head-to-feet, character facing Up-Right, neutral standing

Middle row:
- Middle-left: Left full-body, complete head-to-feet, character facing Left (left profile), neutral standing
- Exact center: clear head-and-shoulders face close-up of the same character
- Middle-right: Right full-body, complete head-to-feet, character facing Right (right profile), neutral standing

Bottom row:
- Bottom-left: Down-Left full-body, complete head-to-feet, character facing Down-Left, neutral standing
- Bottom-center: Down full-body, complete head-to-feet, character facing Down (front view), neutral standing
- Bottom-right: Down-Right full-body, complete head-to-feet, character facing Down-Right, neutral standing

All eight full-body figures must have identical proportions and silhouette height, feet on the same baseline. Character locked across every cell: rugged human dungeon delver, practical layered leather and metal armor, [short messy dark hair / appropriate female hairstyle], determined expression, bright green scarf around neck, limited muted palette (grays, browns, dark greens, skin tones, metal). Crisp true pixel-art style, integer pixel edges, no anti-aliasing, no smoothing. Do not swap any cells. Do not place the face close-up anywhere except the exact center. No cropping of limbs, no props, no weapons, no text, no numbers, no borders, no grid lines. Perfect even 3×3 grid.
```

---

## Appendix D – Summary Reliability Table
(Consult on demand.)

| Technique                                      | Reliability   | Recommendation                  |
|------------------------------------------------|---------------|---------------------------------|
| Locked 3×3 magenta Character Bible + palette   | High          | Mandatory                       |
| Game-centric direction names (8-dir)           | High          | Use always                      |
| Soft identity language after Bible lock        | High          | Use always after lock           |
| Single-pass 3×3 for the Bible                  | Highest for identity | Preferred for Bible          |
| Spliced single-cell I2V seed                   | Highest       | Default video path              |
| Full-Bible I2V seed                            | Fallback only | Use if single still fails or multi-facing motion is required |
| Image-to-video walk cycles (spliced-still-seeded) | Highest    | Primary path for fill-in        |
| Individual classic key poses                   | High          | Preferred fallback              |
| Lattice square-crop before 3×3 split           | High          | Mandatory before splices        |
| Magenta range-key + flatten to #FF00FF         | High          | Mandatory                       |
| Foot baseline locking in post                  | High          | Mandatory                       |
| Equal frame counts per direction               | High          | Mandatory                       |
| Hard frame-count demands                       | Low           | Avoid                           |
| Full multi-direction strips                    | Very Low      | Forbidden                       |
| Chained image-edits for Bible directions       | Medium-Low    | Avoid (causes drift)            |
| Aseprite / scripted pixel-grid cleanup         | Mandatory     | Always perform                  |

---

## Appendix E – SFX Minimum Required Set
(Consult on demand.)

| SFX | Notes |
|-----|-------|
| Melee hit | |
| Player hurt | Separate male and female VO performances of equal scope |
| Special / Slam impact | |
| Dash | |
| Mining hit | |
| Woodcutting hit | |
| Breakable smash | |
| Item pickup | |
| UI click / confirm / cancel | |
| Level-up | |
| Adrenaline Rush start (warcry) | Separate male and female performances of equal scope |
| Adrenaline Rush loop (woosh / crackle) | |
| Critical hit | |
| Potion use | Instant heal; distinct from food |
| Food use | Heal-over-time start; distinct from potion |
| Deathrattle “hurk” | Separate male and female performances of equal scope |
| Comedic thud (“Dispel”) | |
| Consciousness-transfer (enter dungeon) | Short presentation beat |
| Wake-up (return to Placeholdia) | Short presentation beat |