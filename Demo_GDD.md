# Grok Build Contract (Read First)

**Version**: 1.5 – Archive-then-Clean-Rewrite (Respec Integrated + Debug QA + Artifact Sets + 8-Dir Sprites)  
**Authority**: This document is the single source of truth.

### Mandatory Workflow for Any Fresh Grok Build Instance

1. **Archive the current build first**  
   Follow Section 20 exactly. Create a new fully standalone snapshot under `archives/` that captures the project state as it exists at the moment this GDD is handed over. This snapshot becomes the next selectable build in the Archives browser / presentation switcher and is preserved as a historical museum piece. Do not modify the live path while creating the archive.

2. **Then rewrite the live path from scratch**  
   After the archive is complete and verified as isolated, implement the entire playable demo as a clean new live codebase.  
   - Do **not** extend, patch, or carry forward the previous live code, scenes, scripts, or architectural decisions.  
   - The previous pure-2D design philosophy and its accumulated compromises are retired.  
   - The new live path must be designed from the ground up around the orthographic Camera3D system described in Section 4 (fixed ~–58° pitch, proper depth sorting that respects implied real-world positions, paper-doll sprites, readable 64×64 art, 8-directional facing, etc.).

3. **Preserve the Archives system and presentation switcher**  
   The three-mode switcher (live / classic_2d / art_experiment) plus the Archives browser must ship. Selecting “Play” always launches the new clean live path. classic_2d and art_experiment (and any future archives, including the one created in step 1) remain completely isolated standalone snapshots per Section 20.

### Hard Constraints & Scope (Non-Negotiable)

See **Section 2** for the complete In-Scope list, Explicit Non-Goals, Design Pillars, and Acceptance Criteria.  
Additional non-negotiables: Solo play only; exactly the eleven skills listed in Section 7; white, green, and blue rarity only (blue is boss-only); repeating 5-floor structure with Floor Guardians (1–4) and Gate Master (5); hit-based gathering system for both mining and woodcutting; Artifact collections / sets required (exactly eight, see Section 8); player animations use exactly 8 directions (matching the Character Bible layout); all numeric values exposed and tunable in the secret debug menu; Production / Gold quality on every system that ships; consistent 60 FPS minimum on target hardware; no co-op scaffolding left active in the live path; no systems, skills, rarities, hub upgrades, or meta-progression beyond what this document explicitly requires; the secret debug menu (including Save/Load profiles, Automated Playtest / AI Player system with weapon-balance awareness, telemetry, impact coefficients, baseline coefficients, and recommended configurations) must ship but remains hidden behind the documented input sequence.

### Success Criterion

A first-time player on a couch with a gamepad can reach a successful extraction in 5–10 minutes without external guidance, understand the core risk/reward of extraction vs. death, and experience the permanent progression feedback on the recap screen — all at stable 60 FPS — using only the new clean live path.

### How to Use This Document

- Treat every requirement in Sections 1–17 and 19 as mandatory design intent for the new live implementation.  
- Section 19 (sprite pipeline) is non-negotiable for all character art and includes post-generation viability analysis + video-fill fallback.  
- Section 20 governs Archives isolation and must be obeyed.  
- The public repository supplies reusable assets and the Archives infrastructure. It is **not** a code base to extend for the live path.  
- The secret debug / Automated Playtest system is a shipping feature (behind the input sequence) and must be implemented to production quality.  
All previously open design questions are closed. Do not invent additional systems or reopen settled decisions.

---

**What Dwells Below — Demo Game Design Document**  
(Compiled from all locked decisions + final sprite pipeline + full respec)

---

### 1. Overview & Vision

**Game Title**  
What Dwells Below

**One-line Public Description**  
(Use the exact wording currently on the public GitHub Pages / title screen; treat it as locked unless later changed.)

**Core Fantasy**  
You are a diver employed by a shadowy guild. You repeatedly descend into a shifting underground complex from a temporary surface camp called Placeholdia, fight, gather, and attempt to extract resources and gear. Death loses almost everything you were carrying; successful extraction banks permanent progress. The surface is slightly absurd and hopeful; the depths are dangerous and increasingly hostile.

**Demo Goal**  
A complete, production-ready vertical slice that can ship as a free demo. Every system included must be polished enough that the identical code can carry forward into the full game with only content and expansion added on top.

**Primary Loop**  
1. Placeholdia hub  
2. Loadout selection (including character type, starting weapon, and tool type)  
3. Enter dungeon at chosen floor  
4. Explore, fight, gather, interact  
5. Extract via clerk or die / voluntarily Dispel  
6. Recap screen  
7. Return to hub with permanent gains (or losses)

---

### 2. Scope, Pillars, Non-Goals & Acceptance Criteria

**In-Scope for Demo (must be fully implemented and polished)**  
- Solo play only  
- Placeholdia hub with all listed interactables (including quest access via the guild and buildings with actual depth)  
- Procedural dungeon floors in a repeating 5-floor structure that continues indefinitely until death  
- Floor Guardians (floors 1–4) and Gate Master (floor 5) with boss doors and locked stairs  
- Complete combat system (Great Axe, Lightning Staff, Longbow, weapon-specific specials on LT, Dash, target-lock, critical hits, Adrenaline Rush) with clear range telegraphs and active-attack indicators on every attack  
- Aim-line indicator (tunable, dungeon-only, System-tab toggle + opacity, persisted)  
- Hit-based gathering system for both mining (pickaxe) and woodcutting (hatchet)  
- Eleven skills (Great Axe, Staff, Longbow, Strength, Magic, Ranged, Defense, Hitpoints, Mining, Woodcutting, Smithing) with permanent XP fragments  
- Inventory, equipment slots (including single Tool slot locked to one type per run), forged holds (max 3 per slot), extraction via clerks  
- Artifact collections / sets (exactly eight sets, run-only, bonuses displayed under descriptions)  
- Male and female player characters (selectable on first load, switchable later from pause menu) with full animation parity, separate female VOs, and exactly 8 directional animations  
- Ghost shop, shrine, campfire, breakables, puzzle elements, stairs, floor crystal  
- Named monsters, enemy bases, and expanded enemy variety (≥12 normal types, ≥5 types per floor)  
- Quest system (3 random choices, 1 active at a time)  
- Full HUD, pause menu (with System tab containing aim-line controls), all interaction UIs, recap screen  
- Secret debug / balance menu (shoulder-button sequence) containing all tunable values, profile Save/Load, and the Automated Playtest / AI Player system  
- Save / load with backup, presentation switcher + Archives, 60 FPS minimum  
- Debug menu that exposes every balance and generation value  
- Gamepad-first design for all controls, gameplay, and interfaces (every menu opens with valid initial focus)

**Explicit Non-Goals (must not appear)**  
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

---

### 3. Core Fantasy & Lore (Demo-Visible Only)

**Player Role**  
The player character is a diver working for an unnamed guild that operates out of the temporary surface settlement Placeholdia. The guild’s purpose is the recovery of resources, artifacts, and knowledge from the shifting underground complex known only as “Below.” Most divers do not return.

**Surface vs. Depths Tone**  
- Placeholdia is safe, temporary, slightly absurd, and mildly hopeful. Flavor text, the dumpster, the notice board, and the ghost shop reinforce a light, irreverent tone.  
- The dungeon is dangerous, reactive, and oppressive. Lighting, enemy density, audio, and recap copy grow darker with depth.  
- The contrast is intentional and must be preserved.

**Information the Player Receives**  
No mandatory intro cutscene or long exposition is required. The player learns the fantasy through:  
- Short environmental flavor text on signs and the notice board.  
- Receptionist and clerk lines (kept minimal).  
- Recap screen titles, subtitles, and special case lines (including verge and empty-run variants).  
- The mechanical consequences of death versus successful extraction.  

**Specific Locked Flavor**  
- Empty floor-1 death/dispel recap must include the line: “They lived just to die. What a waste.”  
- Credit splash must show the word “Proudly” crossed out and the word “Shamelessly” written above it in graffiti style so the phrase reads as vandalized: “Shamelessly Vibecoded with Grok.”  
- The dungeon music track is titled “Bitter” (YouTube and Spotify links provided by the designer). No other track requires named external linking at this time.

---

### 4. Platforms, Camera, Presentation & Input

**Target Platforms**  
- PC (primary)  
- Web export that runs in modern browsers without requiring special COOP/COEP headers  
- Design must remain fully readable and playable from couch distance on a television (future Xbox / console consideration)

**Camera (Live 3D Path)**  
- Orthographic Camera3D  
- Fixed pitch approximately –58°  
- Camera height and ortho size calculated so that 64×64 sprites remain clearly readable  
- Player-adjustable zoom range 1.0–1.75 (persisted in save)  
- Separate independent HUD scale setting  
- Look-at point offset slightly above the player origin  
- Depth sorting must correctly respect implied real-world positions of the player, enemies, walls, and props (no arbitrary front/back popping)

**Presentation Switcher**  
The demo must ship with the existing three-mode switcher (live / classic_2d / art_experiment) plus the Archives system. This is required for the Patreon development narrative. Selecting “Play” always launches the live path.

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

All controls, gameplay, and interfaces must be designed with a gamepad-first intent. Every menu must open with a valid initial focus already set so the player can immediately navigate and select using only the gamepad (no requirement to first highlight an element with the mouse).

**Aim-Line Indicator**  
- Simple opaque visual indicator that extends outward from the player in the direction they are facing/aiming.  
- Appearance and length are fully tunable (default style inspired by Heroes of Hammerwatch and similar games; length may optionally scale toward the farthest point the currently equipped weapon can hit).  
- Always visible while the player is inside the dungeon; never visible in Placeholdia.  
- Always draws the full configured distance (does not respect line-of-sight or stop at walls).  
- Toggleable on/off and with an independent opacity slider in the System tab of the pause menu.  
- On/off state and opacity are persisted with the player profile.  
- Fully functional with both gamepad and keyboard/mouse aiming (parity required).

**Input – Keyboard / Mouse (Fully Featured Fallback)**  
All gamepad actions must have keyboard/mouse equivalents. Mouse aim + hold-LMB for attack is the default mouse scheme. Rebinding of all actions is required.

**Renderer**  
Prefer the Compatibility renderer for the final shippable build if it does not compromise the web export. Mobile renderer is acceptable only if required for web stability.

---

### 5. Player Avatar, Movement & Controls

**Character Selection**  
- On first load the player chooses a male or female character.  
- The character type may be switched later from the pause menu.  
- Both character types must be fully animated and kept in parity so that all weapon paper-doll appearances and animations function correctly on either without special per-gender tweaks.  
- Separate voice-over sets are required for the female character.

**Movement**  
All numeric values (base speed, dash speed, dash duration, dash cooldown, special cooldown, special radius, etc.) are fully tunable via the debug menu and must never be hard-coded as final.  

- Dash grants complete invulnerability frames for its entire duration and leaves a clear trail VFX.  
- Movement must feel responsive and weighty on both gamepad and keyboard.

**Collision & Body**  
- Prefer collision that matches the actual art silhouette / paper-doll bounds rather than a simple cylinder.  
- The player must correctly depth-sort against walls, props, enemies, and other world objects using a system that respects implied real-world positions.  

**Facing & Animation System**  
- 8-directional facing derived from aim direction using smooth radial detection (not movement direction). Directions exactly match the Character Bible layout: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right.  
- Character art is generated and assembled according to the mandatory pipeline in **Section 19**.  
- Required player states at minimum: idle, walk, attack (per weapon), special (per weapon), gathering (mining/woodcutting), death, dispel.  
- Each weapon requires its own paper-doll equip appearance and associated animations.  
- Male and female player characters must maintain full animation parity.  
- All directional variants of the same animation state must contain exactly the same number of frames.

---

### 6. Combat Feel & Numbers

**Weapon System**  
The player may equip one of three weapons: Great Axe, Lightning Staff, or Longbow.  
Starting weapon is selected in the loadout. Mid-run weapon changes are performed by equipping from the pause-menu inventory.  
Each weapon has its own paper-doll appearance and full set of animations.  
Specials for all weapons are activated with LT.  
All player attacks (basic and special) must clearly telegraph their range and provide a visible indication that the attack is currently active.

**Great Axe**  
- Basic attack: Hold-to-attack (RT / LMB). Continues automatically while held. Arc and range are tunable. A single swing can hit multiple enemies inside the arc. Line-of-sight requirement is tunable. Damage application must be synchronized to the correct animation frame.  
- Special (Slam): Short wind-up and recovery. Higher damage multiplier than a basic attack (exact value tunable). Applies a readable stagger (shorter duration against Floor Guardians and the Gate Master). Produces dedicated ground-crack VFX.

**Lightning Staff**  
- Basic attack: Hold-to-attack (RT / LMB). Weak melee strikes that continue automatically while held. Range and arc are shorter and lower-damage than the Great Axe (exact values tunable). A single strike can hit multiple enemies inside its arc. Line-of-sight requirement is tunable. Damage application must be synchronized to the correct animation frame.  
- Special: AoE lightning bolt that strikes a targeted area. Possesses a distinct short wind-up. Damage, radius, and any secondary effects are tunable. Must clearly telegraph the affected area and show when the bolt is active.

**Longbow**  
- Basic attack: Hold-to-attack (RT / LMB) fires long-range single-target projectiles that continue automatically while held. Range, projectile speed, and fire rate are tunable. Line-of-sight requirement is tunable. Damage application must be synchronized to the correct animation / projectile frame.  
- Special: Fires 5 arrows in a cone in front of the player (functions as an AoE attack). Possesses a distinct short wind-up. Cone angle, range, arrow count behaviour, and damage are tunable. Must clearly telegraph the cone area and show when the arrows are active.

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
- Must keep killing to maintain the state.

**Defense**  
- Uses a diminishing-returns formula (exact formula tunable).  
- Armor pieces contribute defense and may carry minor secondary stats.

**Target-lock**  
See Section 4 for full behavior.

Floating damage numbers show integer values only, appear briefly, then disappear.  
All damage values, multipliers, cooldowns, periods, radii, and scaling rates are exposed in the debug menu.

---

### 7. Skills, XP, Progression & Combat Level

Skills Included in the Demo  
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
- All XP curves, per-level multipliers, and the permanent keep-rate on death/dispel are fully tunable via the debug menu.  
- During a run the player accumulates “run XP” in each skill.  
- On death or voluntary Dispel, only a small fragment of that run XP is kept permanently.  
- The recap screen must contain a clear visual sequence that shows the run XP values draining down to the permanent fragment amounts, after which the new permanent XP totals and resulting levels are displayed.

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
- If the currently equipped weapon’s style Combat Level is lower than the highest, that style level is shown in parentheses next to it (e.g. CL 14 (Magic 11)).  
- Exact weights and formulas remain fully tunable.

**Skill Effects (High-Level)**  
- Great Axe, Staff, Longbow, Strength, Magic, and Ranged: increase damage dealt with the corresponding style or weapon (with possible differential scaling on specials).  
- Defense & Hitpoints: increase survivability.  
- Mining: improves reward chance and effectiveness with the hit-based mining system.  
- Woodcutting: improves reward chance and effectiveness with the hit-based woodcutting system.  
- Smithing: reduces forge cost/time and improves output at the anvil.  

Exact formulas are treated as tunable suggestions only.

Visible Power Gain After One Good Run  
After a single successful extraction and return to Placeholdia the player must be able to notice either:  
- a few permanent skill levels, or  
- at least one new piece of usable forged gear (or both).  

This is a required feel target.

---

### 8. Inventory, Gear, Extraction & Mailing

**Bag**  
- Fixed capacity (current value 28, fully tunable).  
- When the bag is full, any new loot the player walks over cannot be picked up. A toast is shown and the item remains on the ground.

**EquipmentSlots**  
- Weapon  
- Tool (pickaxe **or** hatchet — only one kind may be selected per run at loadout and is locked for the entire run)  
- Potion (dedicated quick-use slot)  
- Food (dedicated quick-use slot; maximum 20 of one food type may be brought into a run)  
- Head  
- Body  
- Legs  

Food discovered inside the dungeon must be equipped to be used with the quick button, but may also be consumed directly from the inventory UI. Potion and food have distinct visual and audio feedback when used.

**Gear Rules**  
- White, green, and blue rarity appear in the demo.  
- Blue items have improved stats over green items and are obtainable only from bosses (Floor Guardians and Gate Master).  
- Stats take effect immediately.  
- Weapons require paper-doll visual layers and associated animations. Armor and other gear may remain stats-only.  
- The player may maintain up to three forged “holds” per equipment slot.  
- Forged holds always return to Placeholdia on death or Dispel, even if the item was dropped on the floor.  
- All unextracted resources and any non-forged items still in the bag are lost on death or Dispel.

**Artifacts & Collections**  
- Artifacts are obtained from the Ghost Shop, boss chests, and (optionally) dead-end or trap-room chests.  
- Artifacts cannot be extracted via clerks; they function as run-only items and are lost on death or Dispel.  
- Artifacts with similar effects are grouped into collections (sets). The demo contains exactly eight distinct sets.  
- Typical set size is 2–3 artifacts; one or two sets may contain 4–5 artifacts.  
- Collecting multiple artifacts from the same set grants additional set bonuses. Bonuses begin at 2 pieces and may require higher thresholds depending on set size.  
- Set bonuses are progressive and are invented by Grok Build at implementation time to remain consistent with existing artifact power level (designer may adjust later).  
- Active set bonuses are displayed beneath the normal artifact descriptions in the relevant UI.  
- Set pieces count toward bonuses while carried or equipped in the current run.

**Extraction / Mailing**  
- Performed exclusively through clerks.  
- The interface must present a clear list of items that can be sent back to the surface.  
- Once extracted, items and gold are safe.  
- Clerk types: one gather specialist and one misc specialist per floor, with a chance of Packmule Patty as an additional clerk. Maximum three clerks total on any floor.

**Vendor Restock**  
If the player returns to Placeholdia with insufficient resources, a limited free restock of basic food and potions is granted (exact thresholds and gold costs tunable).

---

### 9. Placeholdia Hub (Exact Contents & Behavior)

**Required Interactables (complete and final list)**  
- Floor Crystal  
- Anvil  
- Vendor Stall  
- Dumpster  
- Guild Signs / Notice Board  
- Receptionist area / Guild (quest access)  
- Loadout Station  
- “Welcome to Placeholdia!” banner  

Layout may be adjusted freely for aesthetics and usability. Existing flavor text may be lightly revised if any line feels awkward or forced.  
All buildings must have actual depth and realistic 3D dimensions (not flat 2D sprites) so they feel solid under the orthographic Camera3D and avoid sorting / z-axis issues. Reference feel: the city area of *Heroes of Hammerwatch 2*.

**Floor Crystal**  
- Allows travel only to deeper floors the player has previously reached.  
- Never permits travel backward.  
- Interaction must be clear and confirmation-safe.

**Anvil**  
- Full forge flow: analyze item → first forge (consumes gold + ore + root) → subsequent re-forges at reduced cost.  
- Maximum three holds per equipment slot.  
- Smithing skill influences time, cost, and quality of output.  
- UI must be clean, TV-readable, and themed consistently with the dungeon.

**Vendor Stall**  
- Purchases ore for gold.  
- Sells basic food and potions.  
- All prices are tunable via the debug menu.

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

**Loadout Station**  
- Allows selection from the three holds in each slot (with fallback to starter Great Axe + pickaxe or hatchet + potion if no holds exist).  
- Starting weapon and tool type (pickaxe or hatchet) are chosen here; tool type is locked for the entire run.  
- Floor selection and “Enter Dungeon” confirmation.  
- Visual presentation requires a complete pass to become clean and TV-readable.

**“Welcome to Placeholdia!” Banner**  
- The text must be printed and clearly visible directly on the banner itself.  
- It must not be implemented as an interactable object or as floating text above a blank banner.

**Hub Audio / Atmosphere**  
Warm, slightly hopeful and lightly comedic stand-in music and ambient sound are acceptable until final assets. Lighting and mood must contrast with the darker dungeon.

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
Target: floors must feel expansive enough to support a 5–10 minute first successful extraction for a new player and longer skilled runs. Starting values should be chosen to achieve this feel on the new Camera3D live path.

**Key Object Placement**  
Placement rules and probabilities for crystal, stairs, clerks, mining nodes, wood nodes, breakables, shrine, campfire, ghost shop, puzzle elements, chests, and enemy bases are fully tunable.  
Safe rooms (clerk, ghost shop, puzzle) must remain enemy-free.

**Enemy Bases**  
- Procedural room type containing at least one chest.  
- Heavily guarded by a large number of enemies.  
- Intended to be challenging unless the player is over-levelled for the current floor.

**Safe Rooms**  
- Clerk rooms, ghost shop rooms, and puzzle rooms are always enemy-free.

**Boss / Guardian Rules**  
- Each Floor Guardian and the Gate Master spawns behind a special boss door that the player can see and prepare in front of.  
- Stairs remain locked until the guardian / Gate Master is defeated.  
- On death the boss drops a chest containing guaranteed equipment (including the possibility of blue rarity) plus one Artifact.

**Fog of War**  
- Reveal radius starts at a 5-tile baseline (fully tunable).  
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
- Enemies must have varied attack patterns, movement types (hopping, walking, flying, etc.), and appearances so they feel distinct in combat.  
- Palette swaps and stat swaps between floors are used to increase perceived variety.

**Roles Present in Demo**  
- Bruiser (melee)  
- Ranged  
- Tank  

Floor Guardians (floors 1–4) and the Gate Master (floor 5) use the Tank role as a base with elevated stats, unique telegraphs if desired, and the special spawn/door/chest rules already defined.

**Named Monsters**  
- Appear randomly at a rate of roughly once every 3 floors.  
- Slightly larger variants of their normal counterparts.  
- Name is randomly generated via a syllable-combination and randomization system.  
- Name appears beneath the enemy model in yellow text with a thin black border.  
- Each named monster receives a few stronger variants of the normal enemy’s attacks (example for ranged: three projectiles at the normal rate, or two projectiles at a faster rate).  
- When a “vanquish specific named enemy” quest is active, that exact named monster (name and type locked on quest acceptance) is the only named monster that can appear until the quest is completed.

**Attack Telegraphs & Feel**  
- All enemy attacks must have clear, readable wind-ups.  
- Melee (Bruiser / Tank): visible wind-up pose → lunge. Direction locks at the start of the wind-up.  
- Ranged: visible draw / charge pose → projectile release. Direction locks on draw.  
- All telegraphs respect line-of-sight.  
- Exact timings, lunge speeds, and ranges are tunable.

**AI Behavior**  
Enemies require line-of-sight to begin attacking or chasing.  
When LOS is lost they may briefly hunt the last-seen position, then return to idle.  
Implement clean steering, separation, and stuck-handling appropriate for the orthographic Camera3D live path. All related values are tunable.  
Flee event occurs an average of 2 times per floor on a full clear: after the group has taken sufficient damage, the fastest enemy in the encounter flashes a clear “!” overhead, receives a small but noticeable speed boost, and flees to spawn reinforcements. No other telegraph is required beyond the “!”.

**Death Presentation**  
1. Play death animation.  
2. Drop loot (XP, gold, possible gear / Artifact).  
3. Body disappears cleanly.  

No lingering corpses required.

**Loot**  
- XP and gold amounts scale with floor and role (tunable).  
- Gear drop chance and rarity (white / green / blue) are tunable.  
- Floor Guardians and Gate Master always drop the special chest (guaranteed equipment that may include blue rarity + one Artifact) in addition to normal drops.

All base HP, damage, speed, scaling per floor, and drop rates are exposed in the debug menu.

---

### 12. Interactables & World Objects

**Mining Nodes**  
- Nodes have a small number of hits (baseline 3–5, tunable).  
- Player approaches and interacts; gathering animation plays while stationary.  
- Every 2.4 seconds (tunable) the node takes one hit and a reward is rolled immediately.  
- Reward chance and quality are influenced by Mining level, pickaxe quality, and node type.  
- No progress bar is shown.  
- Node is destroyed after its hit count is exhausted.

**Wood Nodes**  
- Nodes have a higher number of hits (baseline 4–8, tunable).  
- Player approaches and interacts; gathering animation plays while stationary.  
- Every 1.6 seconds (tunable) the node takes one hit and a reward is rolled immediately.  
- Successful gather rate is approximately 50 % lower than mining nodes.  
- Reward chance and quality are influenced by Woodcutting level, hatchet quality, and node type.  
- No progress bar is shown.  
- Node is destroyed after its hit count is exhausted.

**Breakables (Pots / Barrels)**  
- Destroyed on a single player hit.  
- Chance to drop gold and/or an HP orb (walk-over pickup).  
- Exact chances and amounts tunable.  
- Clear smash VFX and SFX required.

**Clerks**  
- Provide the extraction / mailing interface.  
- Dialogue is minimal; the main interaction is a clean, TV-readable list of items the player can send back to the surface.  
- Maximum three clerks per floor.

**Ghost Shop**  
- Appears on approximately one in three floors (tunable).  
- Always in a safe room.  
- Sells 2–4 Artifacts (player may buy a maximum of two per visit).  
- Sells snacks at a fixed price (baseline 25 g, tunable).  
- Allows pawning of gear for a very low return.  
- Uses a distinct hopeful-but-eerie voice style (implementation may be text + SFX for the demo).  
- Distinct ghost / shopkeep sprite required.

**Shrine**  
- On interaction grants a temporary damage buff (+20 % baseline, 45 s duration, both tunable).  
- Buff must appear on the HUD with a visible timer.  
- One use per floor.

**Campfire**  
- One-sit heal (exact amount tunable).  
- Safe interaction.

**Artifact Chests, Pressure Plates, Levers, Gates, Cracked Walls**  
- Puzzle elements are never required for progression and never appear on the critical path to stairs.  
- Cracked walls have higher HP than normal breakables (suggested start: 8, fully tunable).  
- Dead-end chests and trap-room chests may optionally contain Artifacts in addition to normal loot.

**Stairs & Floor Crystal**  
- Both only allow travel deeper.  
- Stairs remain locked behind the boss door until the Floor Guardian or Gate Master is defeated.  
- Interaction prompts must be clear and confirmation-safe where appropriate.

All numeric values (hit counts, timers, heal amounts, spawn chances, etc.) are tunable via the secret debug menu.

---

### 13. UI / HUD / Menus / Recap

**HUD – Gauntlet Strip (mandatory elements and behavior)**  
The HUD is a persistent horizontal strip that must remain visible at all times during dungeon play and must be readable from couch distance on a 1080p television.

Required elements (no more, no less unless later expanded by debug):  
- Player portrait  
- HP bar with numeric value  
- Potion quick-slot icon + cooldown sweep / numeric cooldown  
- Dash cooldown indicator  
- Special (LT) cooldown indicator  
- Level (highest global Combat Level; if the equipped weapon’s style level is lower it appears in parentheses, e.g. `Level 14 (Magic 11)`)  
- Current gold  
- Current ore / wood  
- Current floor number (e.g. “F3”)  
- Shrine buff icon + remaining time (appears only while active)  
- Boss / Floor Guardian / Gate Master HP bar (appears only while the boss is alive and in range / engaged)  

Bag-fullness indicator is explicitly removed and must not appear.  
All cooldowns must show both a visual fill/sweep and be understandable at a glance. Exact pixel positions, colors, and sizes are left to implementation so long as the information hierarchy is preserved and the strip does not obscure critical gameplay.

**Pause Menu**  
Opened with Menu / Start / Esc. Freezes gameplay.  
Every menu (including this one) must open with valid initial focus so it is immediately navigable by gamepad.

Exactly three tabs, navigable with LB/RB or equivalent:  
1. Inventory – full bag grid, equipment slots, ability to use/consume/drop/equip (including mid-run weapon changes). Active artifact set bonuses are shown beneath each artifact’s normal description.  
2. Skills – list of the eleven skills with current level, XP bar to next level, and permanent XP total.  
3. System – must contain every one of the following:  
   - Master / Music / SFX volume sliders  
   - Camera zoom slider (1.0–1.75)  
   - HUD scale slider  
   - Aim-line toggle and opacity slider  
   - Presentation mode switcher + Archives browser  
   - Control rebinding screen  
   - Character type switch (male / female)  
   - Patreon link  
   - “Delete Save Data” with confirmation  
   - Dispel Avatar button with strong confirmation prompt  

The full debug / balance menu is **no longer** present in the Pause Menu.

**Secret Debug / Balance Menu**  
Accessed only by the following input sequence (gamepad): all four shoulder buttons (RT + RB + LT + LB) must go from pressed → released → pressed → released within a 1.5-second window. The 1.5-second timer resets after the first release so a full 1.5 seconds remains for the second press-and-release.  
The menu opening itself is the sole confirmation that the sequence succeeded.  
This menu contains:  
- Every previously available debug / balance page (all numeric values exposed and tunable)  
- Debug profile Save / Load / Delete / Rename system (unlimited named profiles, free naming/renaming, saved to files by default, persist across live-path sessions)  
- Automated Playtest / AI Player system (see dedicated subsection below)  
- All other content that was formerly under Pause → System that is not listed above

**Automated Playtest / AI Player System (inside Secret Debug Menu)**  
- Replicates natural human gameplay as closely as practical, allowing intentional sub-optimality.  
- Selects different loadouts at the start of runs; deep in-run equipment swapping is not required.  
- Uses two completely independent save files (never the player’s normal save):  
  1. Fresh-start save – repeatedly cleared so every test begins clean.  
  2. Progressed save – contains full progression in all eleven skills; can be reset to a fixed default progressed state.  
- Weapon-aware: actively works to keep Great Axe, Lightning Staff, and Longbow balanced so no single weapon is clearly stronger.  
- Records run history together with the exact variable configuration used.  
- Collects comprehensive telemetry (baseline list generated by Grok Build at implementation; includes at minimum total gameplay time, time in vs. out of combat, near-death events, and additional metrics useful for balance).  
- Calculates per-variable impact coefficients (breakdown of effect on every telemetry metric plus an overall difficulty value primarily tied to run duration) separately for the fresh-start and progressed saves.  
- Ships with deduced baseline impact coefficients generated at build time; these are refined by real telemetry.  
- Presents ideal values as fly-out information when a variable is highlighted: one ideal for the fresh-start save (tuned toward first-extraction goals) and one ideal for the progressed save (tuned toward later GDD constraints).  
- Offers three recommended configurations per save type (one most-ideal to meet spec + two close alternatives). The player may further edit any recommended configuration before applying it. This flow is visible only inside the secret debug menu.  
- Supports accelerated, background, and headless runs. Unlimited queued runs; any run is interruptible without loss of already-collected telemetry.  
- The entire system ships in the public demo but remains hidden behind the secret input sequence.

**Extraction / Clerk UI**  
- Opens on interact with any clerk.  
- Shows a clear, scrollable list of every item currently in the player’s bag and equipped slots that can be extracted.  
- Player can select individual items or use a “Send All” option.  
- Confirmation step required before items are removed from the run and marked as banked.  
- Must be fully usable with gamepad only and readable from couch distance.

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
- Select holds per slot (fallback to starters), choose starting weapon, choose tool type (pickaxe or hatchet — locked for the run), choose starting floor, confirm enter.  
- Visual presentation must be rebuilt to the same clean, dungeon-themed, TV-readable standard as the other interaction UIs.

**Quest UI**  
- Accessible from the guild in Placeholdia.  
- Displays three random quests.  
- Clear accept / decline flow.  
- Active quest status visible where appropriate.

**Recap Screen (mandatory sequence)**  
Triggered on every death or Dispel.  
1. Display run statistics.  
2. Play a clear visual sequence that shows each skill’s run XP value draining down to the permanent fragment amount.  
3. After the drain completes, display the new permanent XP totals and the resulting levels.  
4. Show gold and items successfully extracted (if any).  
5. Title / subtitle variants according to performance, including verge states.  
6. Special case: death or Dispel on floor 1 with an empty bag must include the exact flavor line “They lived just to die. What a waste.”

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
- The primary dungeon music track is the piece titled “Bitter”. The designer has supplied the authoritative YouTube and Spotify links; these must be referenced in the project for attribution and replacement.  
- Exact loop offset, volume, and fade behavior are tunable.  
- Hub music may be any warm, slightly hopeful, lightly comedic stand-in until final assets are created.  
- Credit line “Bitter — ViraXVespa” must appear on the title screen and in the pause menu where appropriate.

**SFX – Minimum Required Set**  
- Melee hit  
- Player hurt  
- Special / Slam impact  
- Dash  
- Mining hit  
- Woodcutting hit  
- Breakable smash  
- Item pickup  
- UI click / confirm / cancel  
- Level-up  
- Adrenaline Rush start (warcry)  
- Adrenaline Rush loop (woosh / crackle)  
- Critical hit  
- Potion use  
- Food use  
- Deathrattle “hurk” (separate male and female performances)  
- Comedic thud (Dispel)  

Additional short UI, weapon-specific, and ambient sounds may be added. All volumes are controlled by the SFX slider.

**Visual & Art Rules**  
- Base resolution for characters and most props: 64×64 pixels.  
- Nearest-neighbor filtering only (no linear filtering on sprites).  
- All characters use Y-billboard so they remain upright under the orthographic camera.  
- Character art (player and enemies) is generated and assembled according to the mandatory pipeline defined in **Section 19**.  
- Required player states at minimum: idle, walk, attack (per weapon), special (per weapon), gathering (mining/woodcutting), death, dispel.  
- Each weapon requires its own paper-doll equip appearance and associated animations.  
- Male and female player characters must maintain full animation parity.  
- Player and enemy animations use exactly 8 directions matching the Character Bible layout.  
- All directional variants of the same animation state must contain exactly the same number of frames.  
- Wall height, tile size (1 unit = 64 px), and depth-sorting must produce correct layering with no arbitrary popping.  
- Buildings in Placeholdia must have actual depth and realistic dimensions.  
- Lighting, fog color/density, and void plane must create a clear visual contrast between the warmer Placeholdia hub and the colder, darker dungeon floors.

**Credit Splash → Title Sequence**  
- Existing timing may be used as a baseline.  
- The credit line must be modified so that the word “Proudly” is crossed out and the word “Shamelessly” is written above it in a graffiti style. The final readable phrase is “Shamelessly Vibecoded with Grok.” The graffiti treatment must look intentional and vandalized.

**Placeholder Policy**  
The only assets considered final are:  
- The designer’s profile picture  
- Official Grok / xAI logos and related assets  

Every other sprite, animation, tileset, prop, UI graphic, music track (except the identified “Bitter” reference), and sound effect is placeholder and must be replaced or massively updated before the demo is considered shippable.

---

### 15. Save / Persistence / Technical

**Save System**  
- Save data is stored in browser `user://` (or equivalent platform-appropriate location).  
- A primary save file and a backup of the last successfully loaded save must both be maintained.  
- If the primary save is missing, corrupted, or fails to parse, the game automatically falls back to the backup. If both fail, a fresh diver is created.  
- Save data must persist across sessions and include at minimum:  
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
If the player returns to Placeholdia with gold or consumables below configurable thresholds, a limited free restock of basic food and potions is granted. Exact thresholds and costs are tunable.

**Debug Profiles**  
Named debug profiles (unlimited) are saved to files by default and persist across live-path sessions. Archives builds use the default values that existed at the moment of archiving.

**Automated Playtest Saves**  
The Automated Playtest / AI Player system maintains two completely independent save files that never interact with the player’s normal save data:  
1. Fresh-start save – repeatedly cleared by the system.  
2. Progressed save – contains full skill progression and can be reset to a fixed default progressed state.  
Both are stored under isolated paths and follow the same primary + backup safety rules.

**Presentation Switcher**  
The live / classic_2d / art_experiment switcher and the Archives browser must ship in the final demo. Selecting “Play” always launches the live presentation path. This system exists to support the Patreon development narrative and must not be removed.

**Web Export Requirements**  
- Must run in modern browsers.  
- Must not require special COOP/COEP headers or other non-standard server configuration to function on GitHub Pages or equivalent static hosting.

**Performance**  
- Consistent 60 FPS minimum on target hardware at all times. Higher frame rates are allowed and desirable.  
- Frame time and memory usage must remain stable even on the deepest floors with full enemy and particle load.  
- All performance-related budgets are subject to the secret debug menu where applicable.

**Renderer**  
Compatibility renderer is preferred for the shippable build if it does not break the web export. Mobile renderer may be retained only if required for web stability.

---

### 16. Balancing, Feel & Polish Targets

**Time Targets**  
- A brand-new player should be able to achieve their first successful extraction in 5–10 minutes.  
- Skilled play should support significantly longer continuous runs.

**Death & Learning Curve**  
- A competent player should reach consistent clears of the early loop within roughly 20–30 total dives. Exact number is a feel target, not a hard metric.  
- Death must always feel like a fair consequence of player decisions or execution rather than randomness or hidden information.

**Difficulty Progression**  
- Difficulty scales with floor number and with each completed 5-floor cycle.  
- The jump from floor 1 to later floors must be noticeable but not punitive.  
- Exact HP, damage, density, and elite weighting curves are fully tunable.

**Visible Power Gain**  
After one successful extraction and return to Placeholdia the player must be able to clearly notice either:  
- a few permanent skill levels, or  
- at least one new usable piece of forged gear  
(or both). This is a required psychological reward.

**Weapon Balance**  
The three weapons (Great Axe, Lightning Staff, Longbow) must remain balanced with one another so that no single weapon type is clearly stronger. The Automated Playtest system actively monitors and supports this constraint.

**Accessibility (Mandatory)**  
- Full control rebinding for gamepad and keyboard/mouse.  
- Independent HUD scale control.  
- Aim-line toggle and opacity.  
- Gamepad-first design with valid initial focus on every menu.  
- These features are required for the demo ship. Additional accessibility options may be added but are not mandatory.

**Polish Bar**  
Every system that appears in the demo is considered production / Gold. No “temp” or “programmer art will do” exceptions are allowed for systems that ship. Placeholder assets are permitted only under the explicit policy in the Audio/Visual section and must be replaced before release.  

The Automated Playtest / AI Player system (secret debug menu) exists to continuously generate telemetry and recommended configurations that help the demo meet the above targets.

---

### 17. Edge Cases & Failure Modes

**Dispel or Death on Floor 1 with Empty Bag**  
- Full recap screen is still shown.  
- The exact flavor line “They lived just to die. What a waste.” must appear.  
- All normal XP-drain and permanent-fragment logic still executes (even if values are zero).

**Bag Full**  
- When the player walks over any loot while the bag is at capacity, the item is not picked up.  
- A clear toast is displayed.  
- The item remains on the ground and can be picked up later if space is made.

**Death or Dispel During Gathering / Dash / Special**  
- All actions are immediately interrupted.  
- The appropriate death or Dispel animation sequence begins with no residual movement, gathering hits, or i-frames carrying over.

**Multiple Clerks / Shops**  
- Hard limit: maximum one Ghost Shop per floor.  
- Hard limit: maximum three clerks total per floor.  
- Generation must respect these caps.

**Save Corruption or Missing Save**  
- Primary save is attempted first.  
- On any failure to load or parse, the game silently falls back to the backup of the last successfully loaded save.  
- If the backup also fails, a completely fresh diver is created.  
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
- Artifacts are never extractable and are lost on death or Dispel.

**Secret Debug Sequence**  
- The shoulder-button sequence must be performed exactly as specified.  
- No feedback is given on partial or failed attempts so that regular players remain unaware of the menu’s existence.  
- Opening the menu is the only confirmation of success.

**Automated Playtest Interruption**  
- Any running or queued automated playthrough can be interrupted at any time.  
- All telemetry and run data collected up to the interruption point are preserved.

**Other Failure Modes**  
- Attempting to use a potion or food when none is equipped/available produces a clear toast and no effect.  
- Attempting to forge without sufficient resources produces a clear failure message and no consumption of partial materials.  
- All confirmation prompts (Dispel, Delete Save, major extractions, character switch, etc.) must be cancellable and must not be triggerable by accident with a single button press.

---

### 18. Implementation Notes for Grok Build

This document is the authoritative specification for the demo of *What Dwells Below*.

A fresh Grok Build instance must:

1. First create a fully isolated archive of the current project state following the exact rules in Section 20. This archive becomes the next selectable build in the Archives browser.  
2. Then implement a clean, from-scratch live path that satisfies every requirement in this GDD.

**Core Construction Rules**  
- The live path is a clean rewrite. Do not extend, refactor, or reuse runtime code, scenes, scripts, autoloads, or architectural patterns from the pre-archive live codebase.  
- Design the live path from the ground up around the orthographic Camera3D system (Section 4).  
- The live path must never share runtime code, scenes, scripts, or global state with any archived build.  
- Treat every numeric value as tunable and expose it in the secret debug menu.  
- Prefer simple, readable, production-quality implementations over clever legacy workarounds.  
- All player and enemy character art must follow the mandatory pipeline in Section 19.  
- Male and female player characters with full animation parity, the three-weapon system, hit-based mining and woodcutting, eleven skills, blue rarity (boss-only), named monsters, enemy bases, quest system, artifact collections/sets, aim-line indicator, and gamepad-first UI with initial focus are mandatory.  
- The secret debug menu (including profile Save/Load, Automated Playtest / AI Player system) must ship at production quality but remain hidden behind the documented shoulder-button sequence.  
- Production / Gold quality is required for every system that ships. Placeholders are allowed only under the explicit policy in Section 14.

**Suggested Order of Implementation (Clean Live Path)**  
1. New project scaffolding + Camera3D + input + basic player movement/animation states (Section 19 sprites, 8 directions) for both male and female characters.  
2. Core combat (three weapons with basic + LT specials, Dash, target-lock, crits, Adrenaline Rush, full attack telegraphs, aim-line indicator) with proper depth sorting and juice.  
3. Dungeon generation + boss doors + locked stairs + Floor Guardians / Gate Master + enemy bases.  
4. Enemies (≥12 types, variety, named monsters, flee event).  
5. Hit-based mining and woodcutting, breakables, and all interactables (including expanded Artifact sources).  
6. Inventory, equipment (including tool type lock), forged holds, extraction/clerks, anvil, loadout, quest system, artifact collections/sets.  
7. Full HUD, pause menu (three tabs + character switch + aim-line controls), secret debug menu (profiles + Automated Playtest system), recap screen with XP drain sequence.  
8. Save / load with backup + isolated save paths for archives and for the two autoplay saves.  
9. Placeholdia hub layout (buildings with real depth) and polish.  
10. Final audio pass, placeholder replacement, and Archives browser verification.

---

### 19. Mandatory Player Sprite & Paper-Doll Generation Pipeline

This section is mandatory for any Grok Build instance.  
It exists because pure image-generation models (including Grok Imagine) have consistent, well-documented limitations with multi-frame consistency, identity drift, spatial layout in grids, and pixel-perfect output. The pipeline below is the most reliable process currently achievable after extensive testing.

All character art (player and enemies) must follow this pipeline. Props may use a simplified stills-only variant.  
Male and female player characters must each have their own locked Character Bible and must maintain full animation parity so that weapon paper-doll layers and animations function on either without special per-gender tweaks.  
Player and enemy animations use exactly 8 directions matching the Character Bible layout.

#### 19.0 Goals & Non-Negotiables

- One locked Character Bible per character type (male and female) is the single source of truth for identity, proportions, palette, and style.
- Identity drift, anti-aliasing, magenta spill, foot sliding, scale inconsistency, and extra limbs/props are hard failures.
- All final frames must be true pixel art on an integer grid after cleanup (nearest-neighbor only).
- Prefer fewer high-quality, readable frames over many mediocre ones. The engine can hold or simple-tween if needed.
- Generate and fully clean one complete directional set (idle + walk at minimum) as a proof before scaling to all directions and states.
- Final engine resolution target: 128×128 canvases (recommended for detail and alignment). Nearest-neighbor downscale to 64×64 is permitted only if required by import settings; document the choice. Base resolution in Section 14 remains 64×64 for world units, but sprite assets ship at 128×128 unless otherwise specified.
- Use **game-centric direction names** exclusively: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right. These match the orthographic camera, Y-billboard, and 8-directional aim system.
- All directional variants of the same animation state for a given character must contain exactly the same number of frames.

#### 19.1 Character Bible

Create and lock **one primary 3×3 Character Bible** on a solid pure magenta (#FF00FF) background for each character type (male and female).

**Strict cell layout (do not swap, reverse rows, reverse columns, or move any figure):**

Top row:  
- Top-left: Up-Left full-body (complete head-to-feet, neutral standing)  
- Top-center: Up full-body (complete head-to-feet, full back view, neutral standing)  
- Top-right: Up-Right full-body (complete head-to-feet, neutral standing)  

Middle row:  
- Middle-left: Left full-body (complete head-to-feet, left profile, neutral standing)  
- Exact center: clear head-and-shoulders face close-up of the same character  
- Middle-right: Right full-body (complete head-to-feet, right profile, neutral standing)  

Bottom row:  
- Bottom-left: Down-Left full-body (complete head-to-feet, neutral standing)  
- Bottom-center: Down full-body (complete head-to-feet, front view, neutral standing)  
- Bottom-right: Down-Right full-body (complete head-to-feet, neutral standing)  

Requirements:  
- Clean limited-palette pixel-art style.  
- All eight full-body views in neutral standing pose (no weapons, no action props).  
- Consistent silhouette height and foot baseline across all full-body cells.  
- Extract and lock the exact palette used.  

This single image is the primary design reference for all subsequent generations of that character type.

A visual reference example of the desired final style and quality can be found at:  
`assets/sprites/player/gdd_reference_bible.jpg`

**Important:** This file is only a style/quality reference. Grok Build must generate the actual Character Bibles and all animation frames from scratch using the rules in this section. Do not treat the reference image as an input asset to be edited or extended.

Generate 2–4 candidates using the prompt template below (adapted for male or female). Lock the best one for each gender and store them as:  
`assets/sprites/player/bible_locked_male.png`  
`assets/sprites/player/bible_locked_female.png`  
(+ locked palettes). Treat the locked Bibles as immutable.

**Best-performing Bible prompt template (adapt gender-specific details as needed):**

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

All eight full-body figures must have identical proportions and silhouette height, feet on the same baseline. Character locked across every cell: rugged human diver, practical layered leather and metal armor, [short messy dark hair / appropriate female hairstyle], determined expression, bright green scarf around neck, limited muted palette (grays, browns, dark greens, skin tones, metal). Crisp true pixel-art style, integer pixel edges, no anti-aliasing, no smoothing. Do not swap any cells. Do not place the face close-up anywhere except the exact center. No cropping of limbs, no props, no weapons, no text, no numbers, no borders, no grid lines. Perfect even 3×3 grid.
```

**Note on reliability:** Single-pass 3×3 generation currently produces the highest identity consistency. Chained image-edits from a single anchor introduce cumulative off-model drift and should be avoided for the Bible itself. If layout errors persist after 3–4 attempts, fall back to generating the eight full-body views + face individually (using soft identity language) and compositing them deterministically with a script.

#### 19.2 Generation Hierarchy (ordered by reliability)

Always work **one direction + one action at a time**. Never hard-code exact frame counts. Never generate full multi-direction strips in one pass.

**Priority order:**

1. **Image-to-video (highest reliability for locomotion)**  
   Use whenever available. Feed the locked Bible (or a single clean directional still) as the first-frame / identity lock. Extract frames, then curate 4–8 clean ones.

2. **Individual classic key poses**  
   Contact → Down → Passing → Up (and any needed extremes). Generate one pose at a time against the Bible.

3. **Short in-place horizontal strip**  
   Use the prompt template style from 19.1, adapted for the specific action and single direction.

4. **Forbidden**  
   Full multi-direction strips, hard frame-count demands, or multi-action sheets in one generation.

**Soft identity language (mandatory in every prompt):**  
“Keep the same overall character design, face, hair, armor, green scarf, proportions, palette, and sprite style from the Bible. Do not redesign, repaint, recolor, simplify, smooth, or invent new details.”

Generate one full cardinal direction (Down + Left + Right + Up) completely before deriving diagonals. Horizontal flip is acceptable for opposite sides when the design is mostly symmetric; asymmetric details (green scarf, etc.) must be corrected or regenerated.

#### 19.3 Required Player States

Minimum required states (from Sections 5 and 14):  
idle, walk, attack (per weapon), special (per weapon), gathering (mining/woodcutting), death, dispel.

Prioritize idle + walk first. Animation playback speeds remain tunable.  
Full parity between male and female is required for every state and every weapon.  
The same frame-count rule applies to every animation state.

#### 19.4 Paper-Doll / Equipment Layers

Generate each equipment piece (especially the three weapons) against a **single clean base-body frame** from the correct direction (not the full Bible).  
Use the same soft identity language, pure magenta background, and cleanup rules.  
Weapon paper-doll layers must work correctly on both male and female base bodies.

#### 19.5 Post-Generation Viability Analysis & Video Fill-In

After the initial animation-generation phase, Grok Build must automatically analyze the collected sprite-frame pool for every animation state and every direction.

The analysis must verify:  
- Sufficient frames exist in the “passing” / leg-crossover stage of the cycle.  
- Generated frames correctly show both legs and arms crossing (forwards/backwards or in-front/behind) as required for natural locomotion and action.  
- All directional variants of the same animation state contain exactly the same number of frames.

If any requisite frames are missing or incorrect, Grok Build shall:  
1. Use the locked Character Bible(s) as the identity and style reference.  
2. Prefer Image-to-Video seeded from a single clean Bible-derived still of the needed direction (or multi-reference with up to several Bible cells).  
3. Generate a short video of the required animation using a motion-focused prompt that explicitly requests the missing passing/crossover frames and correct limb crossing.  
4. Extract candidate frames from the video.  
5. Run every extracted frame through the full mandatory cleanup pipeline (magenta key + despill, crop + padding, nearest-neighbor scale to target canvas, foot-baseline lock, palette quantize, anti-aliasing removal, etc.).  
6. Integrate the new frames into the pool provided they remain on-model.

Maximum practical retries follow the existing generation hierarchy (2–3 Image-to-Video attempts before falling back).  
If video-extracted frames still fail the on-model / crossing checks, note the failure, continue the build using the available animations, and at completion inform the user of the failure together with a suggestion for manual cleanup.

#### 19.6 Mandatory Cleanup & Normalization Pipeline

All AI-generated frames (including those extracted from video) **must** pass through cleanup before use in the game.

Recommended tools:  
- Existing project scripts in `tools/`  
- Or Aseprite + DeAI PixelKit / Pixel Refiner / Alpha Remover  
- Or equivalent browser tools

**Required cleanup tasks (in order):**  
1. Flood-key or chroma-key pure magenta (#FF00FF). Apply despill for any fringe.  
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
- Persistent identity or scale failure → return to Bible and re-lock if necessary.  
- Video fill-in still fails checks → note failure, proceed with available frames, inform user at end of build for manual cleanup.  
- Log the failure mode.

#### 19.8 Summary Reliability Table

| Technique                                      | Reliability   | Recommendation                  |
|------------------------------------------------|---------------|---------------------------------|
| Locked 3×3 magenta Character Bible + palette   | High          | Mandatory                       |
| Game-centric direction names (8-dir)           | High          | Use always                      |
| Soft identity language                         | High          | Use always                      |
| Single-pass 3×3 for the Bible                  | Highest for identity | Preferred for Bible          |
| Image-to-video walk cycles (Bible-seeded)      | Highest       | Primary path for fill-in        |
| Individual classic key poses                   | High          | Preferred fallback              |
| Foot baseline locking in post                  | High          | Mandatory                       |
| Equal frame counts per direction               | High          | Mandatory                       |
| Hard frame-count demands                       | Low           | Avoid                           |
| Full multi-direction strips                    | Very Low      | Forbidden                       |
| Chained image-edits for Bible directions       | Medium-Low    | Avoid (causes drift)            |
| Aseprite / scripted pixel-grid cleanup         | Mandatory     | Always perform                  |

This is the most reliable pipeline currently achievable with Grok Imagine and related tools for the player characters (and enemies) of *What Dwells Below*. Follow it exactly. Deviations require explicit justification and re-validation under the orthographic camera + Y-billboard + nearest-neighbor filtering.

### 20. Archived Builds System (Standalone Snapshots)

The Archives system (classic_2d, art_experiment, and any future historical builds) exists solely to support the Patreon development narrative and let players experience the game **exactly as it was at specific points in development**.

**Core Rule (Non-Negotiable):**  
Every archived build must be a **completely standalone, self-contained version of the game**.  

- An archived build must not share runtime code, scenes, scripts, autoloads, or global state with the live (main) path.  
- The live path must never be required to maintain compatibility with, or be limited by, any archived code.  
- Conversely, loading an archived build must never pull in or be altered by any live/current code.  

If either of the above occurs, the archive no longer represents the historical state and the live game becomes artificially constrained by legacy requirements. Both outcomes are forbidden.

#### Technical Requirements

1. **Isolation**  
   - Each archived build lives in its own self-contained folder under `archives/` (e.g. `archives/classic_2d/`, `archives/art_experiment/`).  
   - These folders contain (or point to) a complete, frozen Godot project snapshot, including all scenes, scripts, assets, and project settings as they existed at the moment of archiving.  
   - No `#ifdef`, feature flags, or runtime conditionals that allow live code to reach into an archive (or vice versa) are permitted.

2. **Launch Behaviour**  
   - Selecting an archived build from the Archives browser must launch that snapshot as an independent instance (or fully replace the current main scene / project context).  
   - Selecting “Play” from the main menu or any live UI **always** launches the current live path.  
   - There is no “hybrid” mode in which live and archived systems run simultaneously or share state.

3. **Creating a New Archive**  
   - To create a new historical snapshot:  
     1. Freeze the current live project state.  
     2. Copy the entire relevant project contents into a new dated or named folder under `archives/`.  
     3. Remove any live-only systems that did not exist at that point in time.  
     4. Verify the archived build runs completely independently and produces the exact experience of that moment.  
   - The newly created archive becomes the next selectable build in the Archives browser.  
   - Once archived, the snapshot is immutable. Future live changes must never be back-ported into it.

4. **Presentation Switcher Integration**  
   - The existing three-mode switcher (live / classic_2d / art_experiment) plus the Archives browser remains.  
   - classic_2d and art_experiment are treated as the first two archived builds and must obey the same standalone rules above.  
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

The list and info panel update dynamically when a new archive is added.

This policy guarantees two things simultaneously:  
1. Players can experience the game exactly as it was at any archived moment.  
2. The main development path remains free of legacy baggage.

Any future archived build must follow these rules from the moment it is created.

---

## Appendix A – Suggested Starting Values (All Tunable via Debug Menu)

These are recommended starting points for the clean live implementation.  
Every value **must** be exposed in the debug menu and treated as non-final.

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
| Woodcutting hits per node      | 6               | Range 4–8                                          |
| Woodcutting time between hits  | 1.6 s           |                                                    |
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

### Progression & Economy

| Parameter                      | Suggested Start | Notes                                              |
|--------------------------------|-----------------|----------------------------------------------------|
| Bag capacity                   | 28              |                                                    |
| Permanent XP keep rate on death| 15–25 %         | Must feel meaningful after a good run              |
| Shrine damage buff             | +20 % / 45 s    |                                                    |
| Campfire heal                  | 40 % max HP     |                                                    |

### UI / Feel Targets

| Parameter                      | Suggested Start | Notes                                              |
|--------------------------------|-----------------|----------------------------------------------------|
| Camera zoom range              | 1.0 – 1.75      | Persisted in save                                  |
| Target first-extraction time   | 5–10 min        | New player on gamepad                              |

All other values (enemy stats, drop rates, forge costs, weapon-specific damage/ranges, quest rewards, etc.) should be chosen to support the same feel targets and must also be exposed in the debug menu.