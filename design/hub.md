# Placeholdia Hub Summary

**Status:** Binding design
**Read when:** Changing camp layout, loadout, or hub interactables
**Code:** `scripts/world/camp.gd`, `scripts/world/interact.gd`, `scripts/combat/dummy.gd`, `scenes/camp.tscn`
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

### Return / Wake-up
- After death or “Dispel”, play short **wake-up sequence** (animation + VFX/SFX).

### Anvil
- Shared gear board with **Analyze** and **Forge** tabs.
- **Analyze:** Pick forgeable piece (bag, bank, equipped). Confirming destroys it. Starters excluded. Remains persist on `App.prog.analyzed` until forged.
- **Forge:** Use analyzed remains + holds. First forge costs gold + ore + root, writes hold (permanent). Re-forge at reduced cost. Max 3 holds per slot.
- Smithing skill affects time, cost, quality.
- UI reuses gear board doll, flyout, stats card, slot list. Footer: workbench + tabs.
- UI: clean, TV-readable, dungeon-themed, consistent.

**Usage:**
1. Analyze tab → A on slot → pick non-starter → confirm. Piece gone; remains shown.
2. Forge tab → A on slot → pick remains → confirm cost. Hold appears.
3. Holds re-forged from Forge tab only.

### Vendor Stall
- Buys ore for gold.
- Sells basic food and potions.

### Dumpster
- Flavor object only. No interaction or gameplay effect.

### Guild / Quest Access
- Via Receptionist area or Notice Board.
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

### Test Dummy
- Striking dummy (`DummyS` / `scripts/combat/dummy.gd`) for testing.
- Opaque-sprite occupancy like dungeon enemies.
- No knockback. Refills at 0 HP.
- Dark ground pad allowed for telegraph readability.
- Sandbox object, not interactable like Floor Crystal / Anvil.

### Hub Audio / Atmosphere
- Warm, hopeful, lightly comedic music and ambience (stand-in until final assets).
- Lighting/mood contrasts with darker dungeon.

### Live Snapshot
- `App.play_from_menu()` / `enter_dungeon()` use loading overlay for hub/dungeon assets (`design/ui.md`).

**Anvil Details:** Shared gear board (`scripts/ui/gear_board.gd`) in `mode="anvil"` with tabs from `scripts/ui/gear_board_anvil.gd`. Remains on `App.prog.analyzed`. Forge writes holds via `scripts/data/progress_town.gd`.
