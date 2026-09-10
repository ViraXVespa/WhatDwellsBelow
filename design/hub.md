# Placeholdia Hub Summary

**Status:** Binding design
**Read when:** Changing camp layout, loadout, or hub interactables
**Code:** `scripts/world/camp.gd` (facade), `scripts/world/camp_build.gd` (ground, guild, roofs), `scripts/world/camp_view.gd` (fence), `scripts/world/interact.gd`, `scripts/world/interact_fx.gd`, `scripts/combat/dummy.gd`, `scripts/app_flow.gd`, `scripts/ui/loader.gd`, `scenes/camp.tscn`
**See also:** `design/inventory.md`, `design/ui.md`, `design/gear-ui.md`, `design/combat.md`

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

### Anvil
- Shared gear board with **Analyze** and **Forge** tabs.
- **Analyze:** Pick forgeable piece (bag, bank, equipped). Confirming destroys it. Starters excluded. Remains persist on `App.prog.analyzed` until forged.
- **Forge:** Use analyzed remains + holds. First forge costs gold + ore + root, writes hold (permanent). Re-forge at reduced cost. Max 3 holds per slot.
- Smithing skill affects time, cost, quality.
- UI reuses gear board doll, flyout, stats card, slot list. Footer: workbench + tabs.
- UI: clean, TV-readable, dungeon-themed, consistent.
- Live camp position: down and left of the vendor stall’s southwest corner (`21.2, 0, 11.4`).

**Usage:**
1. Analyze tab → A on slot → pick non-starter → confirm. Piece gone; remains shown.
2. Forge tab → A on slot → pick remains → confirm cost. Hold appears.
3. Holds re-forged from Forge tab only.

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
- Opaque-sprite occupancy like dungeon enemies.
- No knockback. Refills at 0 HP.
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
- The mesh stays hidden until `update_line` turns it on. The default 1×1 cream box MUST NOT flash under the loader.

### Fence / play area
- Post-and-rail fence on all four edges of the current ground slab (`camp_view.gd`).
- Collision matches the rails so the player cannot leave the yard.
- Grass tiles continue past the slab (`GRASS_PAD`) so the world does not drop to empty outside the fence.

### Hub Audio / Atmosphere
- Warm, hopeful, lightly comedic music and ambience (stand-in until final assets).
- Lighting/mood contrasts with darker dungeon.

### Live Snapshot
- `App.play_from_menu()` / `enter_dungeon()` use loading overlay for hub/dungeon assets (`design/ui.md`).
- After camp is ready, the overlay status is `Warming things up for you...`. That beat runs player walk/idle frames and a dummy `move_and_slide` so the first stick in the yard does not hitch. The dim goes fully opaque for that beat. There is no empty “The square holds.” hold.
- Player body and adrenaline aura stay hidden until they have a real texture / non-zero alpha.
- Hub ground: grass outside the yard, one packed-dirt fill, cobble-tinted path (`plaza_grass` / `plaza_ground` / `plaza_path`). No scattered dark dirt patches.
- Buildings are 3D boxes with `plaza_wall` sides, a `plaza_roof` top plane, and a south-face facade sprite fitted to the box (`min` of width/height pixel size).
- Roof planes use world-space UVs. The tile samples `plaza_roof.png` from y=10 to height−5 so the baked cap and footer do not repeat.
- South eave is `ROOF_EAVE` (0.42). Guild hall and wing are separate roof planes (L-shape, wing raised 0.01 to avoid z-fight).
- Welcome banner text is pixel letters on the cloth, two lines: `WELCOME TO` / `PLACEHOLDIA!`.

**Anvil Details:** Shared gear board (`scripts/ui/gear_board.gd`) in `mode="anvil"` with tabs from `scripts/ui/gear_board_anvil.gd`. Remains on `App.prog.analyzed`. Forge writes holds via `scripts/data/progress_town.gd`.
