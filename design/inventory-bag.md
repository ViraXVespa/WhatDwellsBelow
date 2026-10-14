# Bag and equipment

Status: current plan  
Read when: bag, equipment slots, food vs potion  


## Bag

- Fixed capacity (current value 28).
- When the bag is full, any new loot the player walks over cannot be picked up. A toast is shown and the item remains on the ground.

## Equipment slots

- Weapon — required; cannot be emptied, dropped, or destroyed. Types in this slot: Great Axe, Staff, Longbow.
- Tool (pickaxe **or** hatchet — only one kind may be selected per run at loadout and is locked for the entire run). Required; cannot be emptied, dropped, or destroyed.
- Potion — dedicated charged equipment slot (not a stack). The hub holds up to three different potions (`potion_hold_max`). One is equipped and goes Below. They persist like a held weapon and come only from the vendor, plus the starter.
- Food — dedicated quick-use slot. The hub holds up to six kinds (`food_kind_max`). One stack is equipped. Stack size uses `food_bring_max`. The slot may be empty.
- Head
- Body
- Legs

Item level applies to every equipment slot. Potion and food item-level details are deferred.

Food discovered inside the dungeon MUST be equipped to be used with the quick button, but may also be consumed directly from the inventory UI. Potion and food have distinct visual and audio feedback when used.

Shared pause / loadout / anvil presentation is specified in gear_ui.

## Food vs potion (locked distinction)

- **Potion:** Equipment, not a stack. Each potion has charges (per run), a cooldown, a heal amount, and a heal speed. Use consumes a charge, not a stack count. Unequipping is allowed, and the slot stays on the last equipped potion until the player unequips it. The default starter potion has two charges; charges refill at the start of a run rather than behaving like “Potion x2” in the bag. On return to Placeholdia the potion that was equipped at the start of that dive is equipped again. A rolled potion may also carry a short bonus to a stat equipment can modify.
- **Food:** Heal-over-time. Each kind restores its own total of X HP smoothly over Y seconds, plus a small bonus that fits that food (all tunable). Food remains the stacked consumable. On return, a stack that still has servings is equipped again; if the slot came back empty and any stack remains, the next stack is equipped; if none remain, the slot stays empty.
- While a food effect is active, a HUD indicator MUST show that food is ticking.
- Using the same food type again while its effect is active does NOT stack and does NOT consume another item until the current effect ends.
- Using a different food type while an effect is active cancels the current effect, consumes the new item, and starts the new food’s effect.
- Potion and food MUST remain audibly and visually distinct.
