# Placeholdia Hub Summary

Status: binding design  
Read when: camp benches, Placeholdia interactables
Code: `scripts/world/camp.gd` (facade), `scripts/world/camp_warm.gd` (Title → Play GPU frame), `scripts/world/camp_build.gd` (ground, guild, roofs), `scripts/world/camp_view.gd` (fence), `scripts/world/camera_rig.gd`, `scripts/world/interact.gd`, `scripts/world/interact_fx.gd`, `scripts/combat/dummy.gd`, `scripts/app_flow.gd`, `scripts/ui/loader.gd`, `scenes/camp.tscn`  


## Required Interactables
- Floor Crystal (opens loadout / enter-dungeon UI)
- Anvil
- Vendor Stall
- Dumpster
- Guild Signs / Notice Board
- Receptionist area / Guild (quest access)
- Controls Billboard
- “Welcome to Placeholdia!” banner
- Test dummy (coverage / weapon sandbox)

All buildings must have realistic 3D dimensions (not flat 2D sprites) for solidity under the orthographic Camera3D.

### Floor Crystal
- Only enter-dungeon interactable.
- Opens Loadout UI: select holds per slot (fallback to starter Great Axe + pickaxe or hatchet + potion), choose starting weapon, tool type (pickaxe or hatchet — locked for run), starting floor, **Enter dungeon**.
- Character type set in Pause → Settings → Gameplay.
- Floor row: `Floor: [−] [selected] [+] (Deepest floor: n)`. Only reached floors; `−` dies at 1; `+` dies at deepest.
- First focus: **Enter dungeon**. B / Esc / Close leaves Placeholdia.
- On enter: play **consciousness-transfer VFX** before dungeon loads.
- UI must be clean, TV-readable, dungeon-themed, consistent with other UIs.
- Live camp position: between the combined guild and the vendor stall, on the north–south path (`16.475, 0, 10.2` in `camp.gd`).

### Return / Wake-up
- After death or “Dispel”, play short **wake-up sequence** (animation + VFX/SFX).
- Extract-wake does **not** run the title-Play hub warmup overlay. Do not add one unless the User asks.

### Anvil
- Shared gear board with **Analyze** and **Forge** tabs. Current tab is highlighted like Pause tabs, not disabled.
- Potion and Food slots are disabled on this board.
- Footer is short: bank + carried gold / ore / wood, plus one status line. Analyze does not list holds. Forge does not list every remnant.
- Submenus keep the parent control strip and draw their own strip. No Back button. Binding UI: gear_ui. Binding item / roll rules: inventory → inventory.gear.

Live camp position: down and left of the vendor stall’s southwest corner (`21.2, 0, 11.4`).

Live scripts: board `scripts/ui/gear_board/gear_board.gd` in `gear_mode="anvil"`; tabs `gear_board_anvil.gd` + `gear_board_anvil_view.gd`; forge body `gear_board_anvil_forge.gd`; ledger `scripts/data/progress_forge.gd` + `affixes.gd` + `gear_roll.gd`. `progress_town.gd` still owns extract / quests / analyze-destroy wrapper.

### Vendor Stall
- Buys ore for gold.
- Sells basic food and potions.
- 3D stall box with `stall.png` south face and a `plaza_roof` top plane (same crop shader as the guild).

### Dumpster
- Flavor object only. No interaction or gameplay effect.

### Guild / Quest Access
- One continuous L-shaped guild: main hall + inset east reception wing. Wing back wall is flush with the hall back wall. Wing is slightly smaller than the hall.
- Receptionist is a bust clipped into the painted window of `guild_reception.png` (not standing on the dirt in front of the building). Feet discard below UV.y 0.50 so they stay behind the sill.
- Notice board sits to the right of the combined guild (`16.1, 0, 6.2`).
- Quest access via Receptionist or Notice Board.
- Offers 3 random quests; one active at a time.
- Quests re-generated after each delve (active unfinished quest preserved).
- Quest types: defeat enemies, extract ore, retrieve item, vanquish named enemy (locks enemy spawn).
- Rewards: XP, unowned gear, gold, items.

### Controls Billboard
- Shows TV-readable list of current controls (gamepad primary; keyboard/mouse equivalents).
- Reflects player bindings from Pause → Settings → Controls. Flavor text allowed; list must be accurate.
- Close with Back / B.
- Dungeon-themed / hub-themed UI.

### “Welcome to Placeholdia!” Banner
- Text printed directly on banner, clearly visible.
- Double live size for readability from crystal.
- Not interactable or floating text.
- Centered on the dirt path at `PATH_X` (`16.5, 0, 22.0`). Poles have collision; there is no invisible blocker left/right of the cloth.

### Test Dummy
- Striking dummy (`DummyS` / `scripts/combat/dummy.gd`) for testing.
- Occupancy, no knockback, refill at 0 HP: combat.
- No combat level / `Lv` tag (`combat_lv := 0`).
- Dark ground pad allowed for telegraph readability.
- Sandbox object, not interactable like Floor Crystal / Anvil.
- Centered at the west arm of the cross path (`8.5, 0, PATH_Z + 0.5`).

### Labels
- Hub and dungeon spot labels use `Label3D` with `no_depth_test`, `render_priority = 8`, `outline_render_priority = 7`.
- Fill and outline stay in the same draw order so the black outline does not slip behind the player while the white fill stays in front.
- Labels draw over buildings and props. The aim line is the only world overlay that may sit above them.

### Aim line (hub and dungeon)
- Draws over buildings and props.
- Does not draw on top of the player sprite. Clip + short fade off the player origin (`scripts/combat/aim_line.gd`).
- Hidden-until-`update_line` / no cream-box flash: combat.

### Fence / play area
- Post-and-rail fence on all four edges of the current ground slab (`camp_view.gd`).
- Collision matches the rails so the player cannot leave the yard.
- Grass tiles continue past the slab (`GRASS_PAD`) so the world does not drop to empty outside the fence.

### Hub Audio / Atmosphere
- Warm, hopeful, lightly comedic music and ambience (stand-in until final assets).
- Lighting/mood contrasts with darker dungeon.

### Live Snapshot
- `App.play_from_menu()` / `enter_dungeon()` use loading overlay for hub/dungeon assets (ui).
- Title → Play: `loader.begin()` puts a near-opaque black sheet (`#000000` at alpha `0xFE`) over the viewport for the whole load. The 3D world still draws under it so WebGL can compile and upload. The player must not see the square pop or flicker.
- After camp is ready, the overlay status is `Warming things up for you...`. That beat applies every loaded idle / `idle_to_walk` / walk / `walk_to_idle` frame for all eight facings (batched across frames), one dummy `move_and_slide`, and a short hold on the down idle. The player body stays visible under the sheet. The player position is pinned so the warmup nudge does not walk them across the yard. There is no empty “The square holds.” hold.
- During that same beat, `camp_warm.gd` moves the camera to the yard center and sets `cam.size` wide enough to frame the full slab plus `GRASS_PAD` (stall, guild, banner, outer grass). `ZOOM_MIN` is not wide enough. `App.cam_zoom` is not written. `camera_rig.warm_hold` ignores player `follow` so the physics tick cannot snap zoom back mid-warm.
- Before `loader.finish()`, warmup restores the user’s zoom and follow target, then waits two frames so the reveal uses the saved camera. The player must not see the pulled-back view.
- Extract-wake / `go_camp()` after a run does not call that warmup overlay.
- Player body and adrenaline aura stay hidden until they have a real texture / non-zero alpha on first spawn. Warmup then keeps the body visible under the sheet.
- Hub ground: grass outside the yard, one packed-dirt fill, cobble-tinted path (`plaza_grass` / `plaza_ground` / `plaza_path`). No scattered dark dirt patches.
- Buildings are 3D boxes with `plaza_wall` sides, a `plaza_roof` top plane, and a south-face facade sprite fitted to the box (`min` of width/height pixel size).
- Roof planes use world-space UVs. The tile samples `plaza_roof.png` from y=10 to height−5 so the baked cap and footer do not repeat.
- South eave is `ROOF_EAVE` (0.42). Guild hall and wing are separate roof planes (L-shape, wing raised 0.01 to avoid z-fight).
- Welcome banner text is pixel letters on the cloth, two lines: `WELCOME TO` / `PLACEHOLDIA!`.
