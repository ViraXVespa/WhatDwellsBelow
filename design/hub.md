# Placeholdia hub

Status: binding design
Read when: changing camp layout, loadout, or hub interactables
Code: `scripts/world/camp.gd`, `scripts/world/interact.gd`, `scenes/camp.tscn`
See also: `design/inventory.md`, `design/ui.md`

## Required interactables (complete and final list)

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

## Floor Crystal

- The Floor Crystal is the only enter-dungeon interactable in Placeholdia.
- Interacting with it opens the Loadout UI.
- That UI includes: select holds per slot (fallback to starter Great Axe + pickaxe or hatchet + potion if no holds exist), choose starting weapon, choose tool type (pickaxe or hatchet — locked for the entire run), choose starting floor, confirm enter.
- Floor list allows travel only to deeper floors the player has previously reached. It never permits travel backward.
- Interaction and confirmation MUST be clear and cancellable (no single-press accidental enter).
- On confirmed enter, play a **consciousness-transfer VFX** before the dungeon loads. This is a short presentation beat, not a story cutscene.
- Visual presentation MUST be clean, TV-readable, dungeon-themed, and consistent with the other hub / dungeon UIs.

## Return / wake-up

- After recap from death or “Dispel”, arriving back in Placeholdia MUST play a short **wake-up sequence**.
- This is a presentation beat (animation + VFX/SFX), not a mandatory dialogue tree or cutscene.

## Anvil

- Full forge flow: analyze item → first forge (consumes gold + ore + root) → subsequent re-forges at reduced cost.
- Maximum three holds per equipment slot.
- Smithing skill influences time, cost, and quality of output.
- UI MUST be clean, TV-readable, dungeon-themed, and consistent with the other interaction UIs.

## Vendor Stall

- Purchases ore for gold.
- Sells basic food and potions.

## Dumpster

- Pure flavor object only.
- Retains its current text. No inventory interaction, dialogue tree, or gameplay effect.

## Guild / quest access

- Accessible via the guild (Receptionist area or Notice Board).
- Presents three different random quests for the player to choose from.
- Only one quest may be active at a time.
- After each delve the available quests are randomly re-generated (the currently active unfinished quest is preserved).
- Example quest types include: defeat X of enemy type Y, extract X ore in a single run, retrieve an item from floor X (quest item spawns only while active), or vanquish a specific named enemy (locks that named enemy as the only one that can appear until completed).
- Rewards include XP in random skills, unowned equipment pieces, gold, and other desirable items.

## Controls Billboard

- Interactable object in Placeholdia, distinct from the guild notice board and the Welcome banner.
- On interact, shows a TV-readable list of the current game controls.
- The list MUST reflect the player’s active bindings (including any rebinds from the System tab).
- Gamepad bindings are the primary listing; keyboard / mouse equivalents are shown as well.
- Flavor text around the list is allowed; the control list itself MUST stay accurate.
- Close with the normal menu Back / B pattern.
- Dungeon-themed / hub-themed player-facing UI. No default unskinned panel.
- In-world label copy MAY be invented at implementation time.

## “Welcome to Placeholdia!” Banner

- The text MUST be printed and clearly visible directly on the banner itself.
- It MUST NOT be implemented as an interactable object or as floating text above a blank banner.

## Hub audio / atmosphere

- Warm, slightly hopeful and lightly comedic stand-in music and ambient sound are acceptable until final assets. Lighting and mood MUST contrast with the darker dungeon.

## Live snapshot

`App.play_from_menu()` / `enter_dungeon()` show the loading overlay while hub or dungeon assets come in. See `design/ui.md`.