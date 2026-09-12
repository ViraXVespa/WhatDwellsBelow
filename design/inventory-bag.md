# Bag and equipment

Status: binding design
Read when: bag, equipment slots, food vs potion
See also: `design/inventory.md`, `design/inventory-gear.md`, `design/inventory-meta.md`, `design/inventory-live.md`, `design/gear-ui.md`, `design/hub.md`, `design/skills.md`, `design/doc-refactor.md`, `design/README.md`

## Bag

- Fixed capacity (current value 28).
- When the bag is full, any new loot the player walks over cannot be picked up. A toast is shown and the item remains on the ground.

## Equipment slots

- Weapon — required; cannot be emptied, dropped, or destroyed. Types in this slot: Great Axe, Staff, Longbow.
- Tool (pickaxe **or** hatchet — only one kind may be selected per run at loadout and is locked for the entire run). Required; cannot be emptied, dropped, or destroyed.
- Potion — dedicated charged equipment slot (not a stack)
- Food — dedicated quick-use slot; maximum 20 of one food type may be brought into a run
- Head
- Body
- Legs

Item level applies to every equipment slot. Potion and food item-level details are deferred.

Food discovered inside the dungeon MUST be equipped to be used with the quick button, but may also be consumed directly from the inventory UI. Potion and food have distinct visual and audio feedback when used.

Shared pause / loadout / anvil presentation is specified in `design/gear-ui.md`.

## Food vs potion (locked distinction)

- **Potion:** Equipment, not a stack. Each potion has charges (per run), a cooldown, and other item stats. Use consumes a charge, not a stack count. Unequipping is allowed. The default starter potion has two charges; charges refill at the start of a run rather than behaving like “Potion x2” in the bag.
- **Food:** Heal-over-time. Restores a total of X HP smoothly over Y seconds (X and Y tunable). Food remains the stacked consumable.
- While a food effect is active, a HUD indicator MUST show that food is ticking.
- Using the same food type again while its effect is active does NOT stack and does NOT consume another item until the current effect ends.
- Using a different food type while an effect is active cancels the current effect, consumes the new item, and starts the new food’s effect.
- Potion and food MUST remain audibly and visually distinct.

