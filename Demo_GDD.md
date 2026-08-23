**What Dwells Below — Demo Game Design Document**  
**Version 1.1**  
(Compiled from all locked decisions + final sprite pipeline)

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
2. Loadout selection  
3. Enter dungeon at chosen floor  
4. Explore, fight, gather, interact  
5. Extract via clerk or die / voluntarily Dispel  
6. Recap screen  
7. Return to hub with permanent gains (or losses)

**Success Definition for a New Player**  
A first-time player on a couch with a gamepad can reach a successful extraction in 5–10 minutes without external guidance and understand the core risk/reward of extraction vs. death.

---

### 2. Scope, Pillars, Non-Goals & Acceptance Criteria

**In-Scope for Demo (must be fully implemented and polished)**  
- Solo play only  
- Placeholdia hub with all listed interactables  
- Procedural dungeon floors in a repeating 5-floor structure that continues indefinitely until death  
- Floor Guardians (floors 1–4) and Gate Master (floor 5) with boss doors and locked stairs  
- Complete combat system (Great Axe, Slam, Dash, target-lock, critical hits, Adrenaline Rush)  
- New hit-based mining system  
- Six skills (Great Axe, Strength, Defense, Hitpoints, Mining, Smithing) with permanent XP fragments  
- Inventory, equipment slots, forged holds (max 3 per slot), extraction via clerks  
- Ghost shop, shrine, campfire, breakables, puzzle elements, stairs, floor crystal  
- Full HUD, pause menu (with debug/balance page), all interaction UIs, recap screen  
- Save / load with backup, presentation switcher + Archives, 60 FPS minimum  
- Debug menu that exposes every balance and generation value  

**Explicit Non-Goals (must not appear)**  
- Co-op / multiplayer / split-screen  
- Any skill beyond the six listed  
- Blue or higher rarity loot  
- Hub upgrades, currency sinks beyond vendor/anvil, or meta progression systems  
- Stealth, mounts, fishing, or other side systems  
- Story cutscenes or mandatory dialogue trees beyond short flavor lines  

**Design Pillars**  
1. Combat is readable, weighty, and juiced (telegraphs, hit-stop, knockback, crits, Adrenaline Rush).  
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

**What the Player Does Not Need to Know**  
Origin of the guild, the true nature of the entity that “dwells below,” the fate of previous divers, or any larger world lore beyond what is directly visible in Placeholdia and the first several floors.

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
- RT: Hold-to-attack  
- LT: Slam  
- A: Interact  
- B: Dash  
- D-pad Up: Use equipped potion  
- D-pad Left: Use equipped food  
- Menu / Start: Pause  
- View / Back: Toggle large map overlay (game continues running underneath)  
- LB / RB: Cycle tabs inside menus  

**Input – Keyboard / Mouse (Fully Featured Fallback)**  
All gamepad actions must have keyboard/mouse equivalents. Mouse aim + hold-LMB for attack is the default mouse scheme. Rebinding of all actions is required.

**Renderer**  
Prefer the Compatibility renderer for the final shippable build if it does not compromise the web export. Mobile renderer is acceptable only if required for web stability.

---

### 5. Player Avatar, Movement & Controls

**Movement**  
All numeric values (base speed, dash speed, dash duration, dash cooldown, slam cooldown, slam radius, etc.) are fully tunable via the debug menu and must never be hard-coded as final.  

- Dash grants complete invulnerability frames for its entire duration and leaves a clear trail VFX.  
- Slam has a distinct short wind-up and recovery, deals increased damage relative to a normal attack, applies a readable stagger (shorter duration against Floor Guardians and the Gate Master), and produces a ground-crack VFX.  
- Movement must feel responsive and weighty on both gamepad and keyboard.

**Collision & Body**  
- Prefer collision that matches the actual art silhouette / paper-doll bounds rather than a simple cylinder.  
- The player must correctly depth-sort against walls, props, enemies, and other world objects using a system that respects implied real-world positions.  

**Facing & Animation System**  
- 16-directional facing derived from aim direction using smooth radial detection (not movement direction).  
- Character art is generated and assembled according to the mandatory pipeline in **Section 21**.  
- Required player states at minimum: idle, walk, attack, slam, mining, death, dispel.  
- Animation playback speeds are tunable.

**Mining / Stationary Actions**  
The old channel bar system is fully replaced by the new hit-based mining rules (see Interactables). While mining the player must remain stationary.

**Death & Dispel Avatar Sequences**  
Both sequences lock all player input and share the deathrattle VO “hurk”.  

- **Death**: Player slowly drops to their knees, collapses to the ground, blood pool forms. Camera hangs on the body, then fades out from the edges toward the player.  
- **Dispel**: Player draws a knife and performs a ritual motion while still standing, plays the deathrattle, then the normal death animation plays at accelerated speed ending with a comedic thud. Same camera treatment.  

After the animation completes the screen fades to black and the recap screen appears. Exact fade timings are tunable.

---

### 6. Combat Feel & Numbers

**Basic Attack (Great Axe)**  
- Hold-to-attack (RT / LMB). Continues automatically while held.  
- Arc and range are tunable.  
- A single swing can hit multiple enemies inside the arc.  
- Line-of-sight requirement is tunable.  
- Damage application must be synchronized to the correct animation frame.  
- Floating damage numbers show integer values only, appear briefly, then disappear.

**Critical Hits**  
- Deal double damage.  
- Target receives a white flash.  
- Floating text “CRIT!” appears.  
- This is the minimum required implementation; additional juice may be added later.

**Slam**  
- Activated with LT.  
- Possesses its own short wind-up and recovery.  
- Damage multiplier is higher than a basic attack (exact value tunable).  
- Applies stagger.  
- Produces dedicated ground-crack VFX.

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

All damage values, multipliers, cooldowns, periods, radii, and scaling rates are exposed in the debug menu.

---

### 7. Skills, XP, Progression & Combat Level

**Skills Included in the Demo**  
- Great Axe  
- Strength  
- Defense  
- Hitpoints  
- Mining  
- Smithing  

These six are mandatory. Additional skills may be added later but are out of scope for the demo.

**XP Gain & Permanent Progression**  
- All XP curves, per-level multipliers, and the permanent keep-rate on death/dispel are fully tunable via the debug menu.  
- During a run the player accumulates “run XP” in each skill.  
- On death or voluntary Dispel, only a small fragment of that run XP is kept permanently.  
- The recap screen must contain a clear visual sequence that shows the run XP values draining down to the permanent fragment amounts, after which the new permanent XP totals and resulting levels are displayed.

**Combat Level**  
- A weighted combination of the combat-related skills (exact weights tunable).  
- Displayed on the HUD as a distinct element.

**Skill Effects (High-Level)**  
- Great Axe & Strength: increase damage dealt (with possible differential scaling on Slam).  
- Defense & Hitpoints: increase survivability.  
- Mining: improves reward chance and effectiveness with the hit-based mining system.  
- Smithing: reduces forge cost/time and improves output at the anvil.  

Exact formulas are treated as tunable suggestions only.

**Visible Power Gain After One Good Run**  
After a single successful extraction and return to Placeholdia the player must be able to notice either:  
- a few permanent skill levels, or  
- at least one new piece of usable forged gear (or both).  

This is a required feel target.

---

### 8. Inventory, Gear, Extraction & Mailing

**Bag**  
- Fixed capacity (current value 28, fully tunable).  
- When the bag is full, any new loot the player walks over cannot be picked up. A toast is shown and the item remains on the ground.

**Equipment Slots**  
- Weapon  
- Tool (pickaxe)  
- Potion (dedicated quick-use slot)  
- Food (dedicated quick-use slot; maximum 20 of one food type may be brought into a run)  
- Head  
- Body  
- Legs  

Food discovered inside the dungeon must be equipped to be used with the quick button, but may also be consumed directly from the inventory UI. Potion and food have distinct visual and audio feedback when used.

**Gear Rules**  
- Only white and green rarity appear in the demo.  
- Stats take effect immediately.  
- No paper-doll visual layers are required for different gear pieces in the demo (stats-only is acceptable).  
- The player may maintain up to three forged “holds” per equipment slot.  
- Forged holds always return to Placeholdia on death or Dispel, even if the item was dropped on the floor.  
- All unextracted resources and any non-forged items still in the bag are lost on death or Dispel.

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
- Receptionist area (minimal or flavor-only)  
- Loadout Station  

Layout may be adjusted freely for aesthetics and usability. Existing flavor text may be lightly revised if any line feels awkward or forced.

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

**Loadout Station**  
- Allows selection from the three holds in each slot (with fallback to starter Great Axe + pickaxe + potion if no holds exist).  
- Floor selection and “Enter Dungeon” confirmation.  
- Current functionality is correct; visual presentation requires a complete pass to become clean and TV-readable.

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
- Grid size, room count, room size ranges, and connection algorithm (MST + extra loops) are treated as tunable starting points.  
- Current values produce floors that feel too small; generation must be tuned upward so floors feel expansive and support the 5–10 minute first-extraction target and longer skilled runs.

**Key Object Placement**  
Current placement rules and probabilities for crystal, stairs, clerks, mining nodes, breakables, shrine, campfire, ghost shop, puzzle elements, and chests are the starting point and are fully tunable.  

**Safe Rooms**  
- Clerk rooms, ghost shop rooms, and puzzle rooms are always enemy-free.

**Boss / Guardian Rules**  
- Each Floor Guardian and the Gate Master spawns behind a special boss door that the player can see and prepare in front of.  
- Stairs remain locked until the guardian / Gate Master is defeated.  
- On death the boss drops a chest containing two guaranteed green equipment pieces plus one Artifact.

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

**Roles Present in Demo**  
- Bruiser (melee)  
- Ranged  
- Tank  

Floor Guardians (floors 1–4) and the Gate Master (floor 5) use the Tank role as a base with elevated stats, unique telegraphs if desired, and the special spawn/door/chest rules already defined.

**Attack Telegraphs & Feel**  
- All enemy attacks must have clear, readable wind-ups.  
- Melee (Bruiser / Tank): visible wind-up pose → lunge. Direction locks at the start of the wind-up.  
- Ranged: visible draw / charge pose → projectile release. Direction locks on draw.  
- All telegraphs respect line-of-sight.  
- Exact timings, lunge speeds, and ranges are tunable.

**AI Behavior**  
- Enemies require line-of-sight to begin attacking or chasing.  
- When LOS is lost they may briefly hunt the last-seen position, then return to idle.  
- Standard steering, separation, and stuck-handling logic from the current implementation is the baseline (tunable).  
- Rare flee event (approximately once every three floors): after the group has taken sufficient damage, the fastest enemy in the encounter flashes a clear “!” overhead and flees to spawn reinforcements. No other telegraph is required beyond the “!”.

**Death Presentation**  
1. Play death animation.  
2. Drop loot (XP, gold, possible gear / Artifact).  
3. Body disappears cleanly.  

No lingering corpses required.

**Loot**  
- XP and gold amounts scale with floor and role (tunable).  
- Gear drop chance and rarity (white / green only) are tunable.  
- Floor Guardians and Gate Master always drop the special chest (two guaranteed green equipment pieces + one Artifact) in addition to normal drops.

All base HP, damage, speed, scaling per floor, and drop rates are exposed in the debug menu.

---

### 12. Interactables & World Objects

**Mining Nodes (New System – Replaces Old Channel Bar)**  
- Nodes have a small number of hits (baseline 3–5, tunable).  
- Player approaches and interacts; mining animation plays while stationary.  
- Every 2.4 seconds (tunable) the node takes one hit and a reward is rolled immediately.  
- Reward chance and quality are influenced by Mining level, pickaxe quality, and node type.  
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
- New ghost / shopkeep sprite required.

**Shrine**  
- On interaction grants a temporary damage buff (+20 % baseline, 45 s duration, both tunable).  
- Buff must appear on the HUD with a visible timer.  
- One use per floor.

**Campfire**  
- One-sit heal (exact amount tunable).  
- Safe interaction.

**Artifact Chests, Pressure Plates, Levers, Gates, Cracked Walls**  
- Retain current behaviors as the baseline.  
- Puzzle elements are never required for progression and never appear on the critical path to stairs.  
- Cracked walls have higher HP than normal breakables (baseline 8, tunable).

**Stairs & Floor Crystal**  
- Both only allow travel deeper.  
- Stairs remain locked behind the boss door until the Floor Guardian or Gate Master is defeated.  
- Interaction prompts must be clear and confirmation-safe where appropriate.

All numeric values (hit counts, timers, heal amounts, spawn chances, etc.) are tunable via the debug menu.

---

### 13. UI / HUD / Menus / Recap

**HUD – Gauntlet Strip (mandatory elements and behavior)**  
The HUD is a persistent horizontal strip that must remain visible at all times during dungeon play and must be readable from couch distance on a 1080p television.

Required elements (no more, no less unless later expanded by debug or new systems):  
- Player portrait  
- HP bar with numeric value  
- Potion quick-slot icon + cooldown sweep / numeric cooldown  
- Dash cooldown indicator  
- Slam cooldown indicator  
- Combat Level (numeric + small bar or equivalent)  
- Current gold  
- Current ore  
- Current floor number (e.g. “F3”)  
- Shrine buff icon + remaining time (appears only while active)  
- Boss / Floor Guardian / Gate Master HP bar (appears only while the boss is alive and in range / engaged)  

Bag-fullness indicator is explicitly removed and must not appear.  
All cooldowns must show both a visual fill/sweep and be understandable at a glance. Exact pixel positions, colors, and sizes are left to implementation so long as the information hierarchy is preserved and the strip does not obscure critical gameplay.

**Pause Menu**  
Opened with Menu / Start / Esc. Freezes gameplay.

Exactly three tabs, navigable with LB/RB or equivalent:  
1. Inventory – full bag grid, equipment slots, ability to use/consume/drop/equip.  
2. Skills – list of the six skills with current level, XP bar to next level, and permanent XP total.  
3. System – must contain every one of the following:  
   - Master / Music / SFX volume sliders  
   - Camera zoom slider (1.0–1.75)  
   - HUD scale slider  
   - Full debug / balance menu (see New Systems)  
   - Presentation mode switcher + Archives browser  
   - Control rebinding screen  
   - Patreon link  
   - “Delete Save Data” with confirmation  
   - Dispel Avatar button with strong confirmation prompt  

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

**Anvil UI**  
- Shows the three holds for the selected slot.  
- Analyze → First Forge → Re-forge flow with clear cost breakdown (gold, ore, root).  
- Smithing level influence visible.  
- Confirmation on every forge action.

**Loadout UI**  
- Functionality already correct: select holds per slot (fallback to starters), choose starting floor, confirm enter.  
- Visual presentation must be rebuilt to the same clean, dungeon-themed, TV-readable standard as the other interaction UIs.

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
- Critical hits add the text “CRIT!”.  
- Toasts appear for bag-full, level-up, extraction success, and other system events. Short, readable, non-stacking or lightly stacking.

---

### 14. Audio, Visual & Art Constraints

**Music**  
- The primary dungeon music track is the piece titled “Bitter”. The designer has supplied the authoritative YouTube and Spotify links; these must be referenced in the project for attribution and replacement.  
- Exact loop offset, volume, and fade behavior are tunable.  
- Hub music may be any warm, slightly hopeful, lightly comedic stand-in until final assets are created.  
- Credit line “8-Bit — ViraXVespa” must appear on the title screen and in the pause menu where appropriate.

**SFX – Minimum Required Set**  
- Melee hit  
- Player hurt  
- Slam impact  
- Dash  
- Mining hit  
- Breakable smash  
- Item pickup  
- UI click / confirm / cancel  
- Level-up  
- Adrenaline Rush start (warcry)  
- Adrenaline Rush loop (woosh / crackle)  
- Critical hit  
- Potion use  
- Food use  
- Deathrattle “hurk”  
- Comedic thud (Dispel)  

Additional short UI and ambient sounds may be added. All volumes are controlled by the SFX slider.

**Visual & Art Rules**  
- Base resolution for characters and most props: 64×64 pixels.  
- Nearest-neighbor filtering only (no linear filtering on sprites).  
- All characters use Y-billboard so they remain upright under the orthographic camera.  
- Character art (player and enemies) is generated and assembled according to the mandatory pipeline defined in **Section 21**.  
- Required player states at minimum: idle, walk, attack, slam, mining, death, dispel.  
- Wall height, tile size (1 unit = 64 px), and depth-sorting must produce correct layering with no arbitrary popping.  
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
  - Permanent XP and levels for all six skills  
  - Banked gold  
  - Banked resources (ore, etc.)  
  - The three forged holds for every equipment slot  
  - Unlocked deepest floor  
  - Camera zoom and HUD scale settings  
  - Any other player settings and debug overrides that should persist  

**Restock-on-Return**  
If the player returns to Placeholdia with gold or consumables below configurable thresholds, a limited free restock of basic food and potions is granted. Exact thresholds and costs are tunable.

**Presentation Switcher**  
The live / classic_2d / art_experiment switcher and the Archives browser must ship in the final demo. Selecting “Play” always launches the live presentation path. This system exists to support the Patreon development narrative and must not be removed.

**Web Export Requirements**  
- Must run in modern browsers.  
- Must not require special COOP/COEP headers or other non-standard server configuration to function on GitHub Pages or equivalent static hosting.

**Performance**  
- Consistent 60 FPS minimum on target hardware at all times. Higher frame rates are allowed and desirable.  
- Frame time and memory usage must remain stable even on the deepest floors with full enemy and particle load.  
- All performance-related budgets are subject to the debug menu where applicable.

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

**Accessibility (Mandatory)**  
- Full control rebinding for gamepad and keyboard/mouse.  
- Independent HUD scale control.  
- These two features are required for the demo ship. Additional accessibility options may be added but are not mandatory.

**Polish Bar**  
Every system that appears in the demo is considered production / Gold. No “temp” or “programmer art will do” exceptions are allowed for systems that ship. Placeholder assets are permitted only under the explicit policy in the Audio/Visual section and must be replaced before release.

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

**Death or Dispel During Channel / Mining / Dash**  
- All actions are immediately interrupted.  
- The appropriate death or Dispel animation sequence begins with no residual movement, mining hits, or i-frames carrying over.

**Multiple Clerks / Shops**  
- Hard limit: maximum one Ghost Shop per floor.  
- Hard limit: maximum three clerks total per floor.  
- Generation must respect these caps.

**Save Corruption or Missing Save**  
- Primary save is attempted first.  
- On any failure to load or parse, the game silently falls back to the backup of the last successfully loaded save.  
- If the backup also fails, a completely fresh diver is created.  
- No partial or corrupted data is ever presented to the player.

**Locked Stairs / Boss Door**  
- Stairs are inaccessible while the Floor Guardian or Gate Master is alive.  
- They remain behind the visible boss door.  
- Once the boss is defeated the door opens and the stairs become usable.  
- No additional toast is required beyond the door state itself; the visual lock is sufficient.

**Other Failure Modes**  
- Attempting to use a potion or food when none is equipped/available produces a clear toast and no effect.  
- Attempting to forge without sufficient resources produces a clear failure message and no consumption of partial materials.  
- All confirmation prompts (Dispel, Delete Save, major extractions, etc.) must be cancellable and must not be triggerable by accident with a single button press.

---

### 18. New Systems (Additions)

**Debug / Balance Menu**  
Accessible from the System tab of the pause menu.  
Must expose essentially every value that affects game balance or procedural generation. This includes (but is not limited to):  
- All player combat and movement numbers  
- All enemy HP, damage, speed, and scaling values  
- XP rates, keep-rate on death, skill curves  
- Dungeon grid size, room counts, room sizes, connection parameters  
- Spawn weights and rarity for shops, clerks, nodes, breakables, shrines, etc.  
- Adrenaline Rush thresholds and bonuses  
- Food and potion heal values and durations  
- Fog reveal radius  
- Any other numeric or weighted value that designers or future Grok Build instances may need to tune  

Changes made in the debug menu take effect immediately where safe, or on next floor / next run where necessary. Values can be persisted or reset to defaults.

**Adrenaline Rush**  
- Triggers when the player achieves a sufficient number of kills in a short time window (threshold tunable).  
- On activation: play warcry SFX, apply flaming aura VFX to the player.  
- While active:  
  - Increased movement speed  
  - Stacking XP bonus per kill  
  - Continuous wooshing / crackling audio loop  
- No cooldown.  
- The effect has a short timeout that resets on each kill; if the player stops killing, the Rush ends.  
- All numeric values (kill threshold, speed bonus, XP bonus per stack, timeout duration) are tunable.

**Enemy Flee / Reinforcement Event**  
- Occurs approximately once every three floors (tunable frequency).  
- When triggered, the fastest enemy remaining in the current encounter flashes a clear “!” overhead and flees toward the nearest valid spawn location.  
- After a short delay, reinforcements appropriate to the floor arrive.  
- No additional warning beyond the “!” is required.

**Critical Hits**  
- Double damage.  
- Target receives a white flash.  
- Floating text “CRIT!” is displayed.  
- This is the minimum required set; further juice may be added later.

**Food-Over-Time**  
- Food grants a heal-over-time effect rather than an instant full heal.  
- While the effect is active the player sees:  
  - Small floating +HP ticks  
  - A buff icon with remaining duration on the HUD  
- Exact total heal amount, tick rate, and duration are tunable.  
- Potion remains a distinct instant (or different) heal with its own feedback.

**Dispel Quoting & Music Attribution**  
- The only track that requires special named attribution and external links is “Bitter.”  
- All other music may use internal placeholders until final assets are delivered.

---

### 19. Implementation Notes for Grok Build

This document is the authoritative specification for the demo of *What Dwells Below*.  

A fresh instance of Grok Build must be able to recreate the entire playable demo from:  
- This GDD  
- The public repository at https://github.com/ViraXVespa/WhatDwellsBelow (for existing assets, project structure, and reference only)  
- The locked design decisions contained herein  

**Key Construction Rules**  
- Treat every numeric value as tunable and expose it in the debug menu.  
- Prefer extending the existing systems rather than rewriting them.  
- The demo must be solo-only. Any co-op scaffolding that still exists in the repository must be disabled or removed from the live path.  
- All player and enemy character art must follow the mandatory pipeline defined in **Section 21**.  
- The 5-floor repeating loop with Floor Guardians and Gate Master, the new hit-based mining system, Adrenaline Rush, food-over-time, and the full debug menu are mandatory.  
- Production quality is required for every system that ships; placeholders are allowed only under the explicit policy in Section 14.  

**Order of Implementation Suggestion**  
1. Core movement, camera, input, and player animation states  
2. Combat (including crits, Slam, Dash, Adrenaline Rush)  
3. Dungeon generation + boss doors + locked stairs  
4. Enemies + flee event  
5. Mining, breakables, and all interactables  
6. Inventory, extraction, anvil, loadout  
7. HUD, pause menu, debug menu, recap  
8. Save / backup system  
9. Hub layout and polish pass  
10. Final audio pass and placeholder replacement  

**Success Criterion**  
When a new player can enter Placeholdia, dive, fight, mine, extract or die, see the XP drain sequence on the recap, and return with permanent progress — all at a stable 60 FPS — the demo is considered complete under this document.

---

### 20. Document Status

**Version**  
1.1 – Updated with final sprite generation pipeline (Section 21) and consistency fixes across related sections.

**Status**  
All previously open design questions have been resolved.  
This document is ready to be used as the single source of truth for building the demo.

**Next Expected Step**  
Hand this document (plus the repository) to a fresh Grok Build instance and begin implementation, or request the companion Full-Game (non-demo) GDD questions.

**Archived Source Documents**  
The original questionnaire (`GDD_Questions.md`) and additions document (`GDD_Additions.md`) have been moved to `archives/development_documents/` for historical reference. All decisions from those documents have been fully incorporated into this GDD.

---

### 21. Mandatory Player Sprite & Paper-Doll Generation Pipeline

This section is mandatory for any Grok Build instance.  
It exists because pure image-generation models (including Grok Imagine) have consistent, well-documented limitations with side-view walk cycles and multi-frame consistency.

#### 21.1 Character Bible
Create and lock **one primary 3×3 Character Bible** on a solid magenta (#FF00FF) background:

```
NW | N  | NE
W  | Face close-up | E
SW | S  | SE
```

- Clean limited-palette pixel-art style  
- All full-body views in neutral standing pose  
- Center cell = clear head/face close-up  
- This single image is the primary design reference for all subsequent generations

**A reference of what the final primary Character Bible should look like is located at:**  
`assets/sprites/player/gdd_reference_bible.jpg`

#### 21.2 Generation Rules

**Hard constraints that must be followed:**

1. Generate **one direction + one action at a time**.  
2. Never hard-code an exact frame count (“exactly 4 frames”, “exactly 6 frames”, etc.). The model routinely ignores it.  
3. Use soft identity language:  
   “Keep the same overall character design, face, hair, armor, green scarf, and colors from the Bible.”  
4. Prefer generating **individual key poses** (Contact, Passing, Down, Up) over full strips when walk cycles fail.

**Best-performing prompt template (use this or close variants):**

```
Using this 3x3 Character Bible as the strict design reference, create a clean horizontal sprite strip of a simple in-place walk cycle for the player character of “What Dwells Below”.

Direction: pure West (facing left)

Keep the same overall character design, face, hair, armor, green scarf, proportions, palette, and sprite style.
Do not redesign, repaint, recolor, simplify, smooth, or invent new details.

Motion requirements:
- In-place walk cycle (character does not drift)
- Clear alternating left/right stride poses
- Left foot forward while right foot back, then right foot forward while left foot back
- Include proper Passing Position (legs close together or crossing)
- Arms counter-swing opposite the legs
- Do not move both feet together
- Do not keep the legs in a wide stride in every frame

Solid background color #FF00FF (pure magenta)
Fully opaque frames
Crisp pixel-art style, no anti-aliasing, no ghosting
One character only. No scene. No new props. No text. No borders.

Output only the sprite strip.
```

#### 21.3 Walk-Cycle Reality Check
Current pure image models have a strong bias toward “legs-apart” poses and frequently fail to generate proper Passing positions.  
When this occurs:

- Fall back to generating the four classic key poses individually (Contact → Down → Passing → Up).  
- Or use an image-to-video model (WAN, SeedDance, Spriterrific-style tools) which currently produce superior walk cycles, then extract frames.

#### 21.4 Mandatory Cleanup Step (Aseprite or Equivalent)
All AI-generated frames **must** go through a cleanup pass before use in the game:

Recommended tools/scripts:  
- Aseprite + DeAI PixelKit / Pixel Refiner / Alpha Remover  
- Or equivalent browser tools (PixelRefiner, etc.)

Cleanup tasks:  
- Snap to true 64×64 (or target) pixel grid (nearest-neighbor only)  
- Remove magenta background cleanly  
- Quantize / lock palette  
- Eliminate anti-aliasing and sub-pixel noise  
- Align feet / pivots across the strip  
- Trim to exact frame count needed by the engine

Expect this cleanup step. It is currently unavoidable for production-quality results.

#### 21.5 Paper-Doll / Equipment Layers
Generate each equipment piece against a single clean base-body frame from the correct direction.  
Use the same identity language and magenta background.  
Cleanup and registration are still required.

#### 21.6 Summary Table

| Technique                                      | Reliability   | Recommendation          |
|------------------------------------------------|---------------|-------------------------|
| 3×3 magenta Character Bible                    | High          | Mandatory               |
| Soft identity language                         | High          | Use always              |
| “In-place + alternating stride + Passing Position” language | Medium-High | Best current walk prompt |
| Hard frame-count demands                       | Low           | Avoid                   |
| Full multi-direction strips                    | Very Low      | Forbidden               |
| Individual key poses                           | High          | Preferred fallback      |
| Image-to-video walk cycles                     | Highest       | Use when available      |
| Aseprite / pixel-grid cleanup                  | Mandatory     | Always perform          |

This is the most reliable pipeline currently achievable with Grok Imagine and related tools for the player character of *What Dwells Below*.

---