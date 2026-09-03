# Inventory, gear, artifacts, extraction

Status: binding design  
Read when: changing bag, equipment, food, potions, artifacts, Extraction Gates, or the anvil  
Code: `scripts/data/progress.gd`, `scripts/data/progress_gear.gd`, `scripts/data/progress_extract.gd`, `scripts/data/progress_make.gd`, `scripts/data/gear_rules.gd`, `scripts/data/catalog.gd`, `scripts/ui/gear_board.gd`, `scripts/ui/gear_board_text.gd`, `scripts/ui/gear_board_act.gd`  
See also: `design/gear-ui.md`, `design/skills.md`, `design/ui.md`, `design/hub.md`, `design/art-pipeline.md`

## Bag

- Fixed capacity (current value 28).
- When the bag is full, any new loot the player walks over cannot be picked up. A toast is shown and the item remains on the ground.

## Equipment slots

- Weapon — required; cannot be emptied, dropped, or destroyed
- Tool (pickaxe **or** hatchet — only one kind may be selected per run at loadout and is locked for the entire run). Required; cannot be emptied, dropped, or destroyed
- Potion — dedicated charged equipment slot (not a stack)
- Food — dedicated quick-use slot; maximum 20 of one food type may be brought into a run
- Head
- Body
- Legs

Food discovered inside the dungeon MUST be equipped to be used with the quick button, but may also be consumed directly from the inventory UI. Potion and food have distinct visual and audio feedback when used.

Shared pause / loadout presentation is specified in `design/gear-ui.md`.

## Food vs potion (locked distinction)

- **Potion:** Equipment, not a stack. Each potion has charges (per run), a cooldown, and other item stats. Use consumes a charge, not a stack count. Unequipping is allowed. The default starter potion has two charges; charges refill at the start of a run rather than behaving like “Potion x2” in the bag.
- **Food:** Heal-over-time. Restores a total of X HP smoothly over Y seconds (X and Y tunable). Food remains the stacked consumable.
- While a food effect is active, a HUD indicator MUST show that food is ticking.
- Using the same food type again while its effect is active does NOT stack and does NOT consume another item until the current effect ends.
- Using a different food type while an effect is active cancels the current effect, consumes the new item, and starts the new food’s effect.
- Potion and food MUST remain audibly and visually distinct.

## Gear rules

- White, green, and blue rarity appear in the demo.
- Blue items have improved stats over green items and are obtainable only from bosses (Floor Guardians and Gate Master).
- Stats take effect immediately.
- Weapons and tools require paper-doll **overlay layers** composited onto shared unarmed body animations. Do not require a full baked character animation set per weapon. Armor and other gear may remain stats-only.
- The player may maintain up to three forged “holds” per equipment slot.
- Forged holds always return to Placeholdia on death or “Dispel”, even if the item was dropped on the floor.
- All unextracted resources and any non-forged items still in the bag are lost on death or “Dispel”.
- Weapon and tool MUST remain equipped at all times.

## White items and starters

- A selectable starter (Great Axe, Lightning Staff, Longbow, Pickaxe, Hatchet, default potion) MUST NOT be stored in the bank and MUST NOT be forged.
- If a starter is extracted / sent up, convert it to smithing XP. Do not create a second copy in storage.
- A white item that is not already a starter becomes a starter the first time it is sent up, without an anvil step. Later extracts of that template convert to smithing XP instead of entering storage.
- Unequipping in Placeholdia MUST NOT treat the piece as a world drop and MUST NOT convert it to smithing XP.

## Where options come from

- **Dungeon inventory:** equipped piece (if any) plus bag items of that slot. No bank, holds, or extra starters.
- **Placeholdia inventory and Floor Crystal loadout:** equipped piece, built-in starters, unlocked starters, holds, then non-white bank items. White bank copies are omitted so they cannot duplicate a starter.
- Bank pieces and other unforged kit taken below are shown as **AT RISK** (lost on death or Dispel unless mailed). Holds show **HOLD**.

## Artifacts and collections

- Artifacts are obtained from the Ghost Shop, boss chests, and (optionally) dead-end or trap-room chests.
- Artifacts cannot be extracted via Extraction Gates; they function as run-only items and are lost on death or “Dispel”.
- Artifacts with similar effects are grouped into collections (sets). The demo contains exactly eight distinct sets.
- Typical set size is 2–3 artifacts; one or two sets may contain 4–5 artifacts.
- Collecting multiple artifacts from the same set grants additional set bonuses. Bonuses begin at 2 pieces and may require higher thresholds depending on set size.
- Set bonuses are progressive and are invented by Grok Build at implementation time.
- Artifact set bonuses should feel like a natural addition to the items that make up the set. For example, if a set is made up of two items that increase health regeneration, the set bonus could provide an additional boost to health regen or a matching bonus to mana regen.
- For 2–3 piece sets, the bonus should be roughly equal in power to the bonus from an individual piece of the set.
- For larger sets, the bonuses should feel more powerful as more items in the collection are gathered.
- Active set bonuses are displayed beneath the normal artifact descriptions in the relevant UI.
- Set pieces count toward bonuses while carried or equipped in the current run.

## Extraction / mailing

- Performed exclusively through Extraction Gates.
- The interface MUST present a clear list of items that can be sent back to the surface.
- Once extracted, items and gold are safe.
- Three Extraction Gates per floor. Any gate can mail any extractable goods. Each gate is one-use after a visit that mailed something.

## Vendor restock

If the player returns to Placeholdia with insufficient resources, a limited free restock of basic food and potions is granted.

## Live snapshot — catalog sets

Live set ids: `cinder`, `tide`, `root`, `ash`, `spark`, `bone`, `veil`, `iron`.

| Pieces | Set | Family |
|--------|-----|--------|
| cinder_ember, cinder_coil | cinder | damage |
| tide_pearl, tide_scale | tide | HP |
| root_knot, root_charm, root_seed | root | gathering |
| ash_mask, ash_bell, ash_cloak | ash | defense |
| spark_lens, spark_wire | spark | crit |
| bone_ring, bone_splint, bone_tooth | bone | HP |
| veil_shard, veil_thread, veil_coin, veil_hush | veil | speed |
| iron_seal, iron_nail, iron_link, iron_plate, iron_heart | iron | defense |

Pause inventory uses a 7-column bag grid and shows gold / ore / wood / cap.