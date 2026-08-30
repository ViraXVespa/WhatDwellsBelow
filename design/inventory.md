# Inventory, gear, artifacts, extraction

Status: binding design
Read when: changing bag, equipment, food, potions, artifacts, clerks, or the anvil
Code: `scripts/data/progress.gd`, `scripts/data/catalog.gd`, `scripts/ui/pause_menu.gd`
See also: `design/skills.md`, `design/ui.md`, `design/hub.md`

## Bag

- Fixed capacity (current value 28).
- When the bag is full, any new loot the player walks over cannot be picked up. A toast is shown and the item remains on the ground.

## Equipment slots

- Weapon
- Tool (pickaxe **or** hatchet — only one kind may be selected per run at loadout and is locked for the entire run)
- Potion (dedicated quick-use slot)
- Food (dedicated quick-use slot; maximum 20 of one food type may be brought into a run)
- Head
- Body
- Legs

Food discovered inside the dungeon MUST be equipped to be used with the quick button, but may also be consumed directly from the inventory UI. Potion and food have distinct visual and audio feedback when used.

## Food vs potion (locked distinction)

- **Potion:** Instant heal of Z HP (Z tunable; may be a full heal if Z is set to max HP). Effect applies immediately on use.
- **Food:** Heal-over-time. Restores a total of X HP smoothly over Y seconds (X and Y tunable).
- While a food effect is active, a HUD indicator MUST show that food is ticking.
- Using the same food type again while its effect is active does NOT stack and does NOT consume another item until the current effect ends.
- Using a different food type while an effect is active cancels the current effect, consumes the new item, and starts the new food’s effect.
- Potion and food MUST remain audibly and visually distinct.

## Gear rules

- White, green, and blue rarity appear in the demo.
- Blue items have improved stats over green items and are obtainable only from bosses (Floor Guardians and Gate Master).
- Stats take effect immediately.
- Weapons require paper-doll visual layers and associated animations. Armor and other gear may remain stats-only.
- The player may maintain up to three forged “holds” per equipment slot.
- Forged holds always return to Placeholdia on death or “Dispel”, even if the item was dropped on the floor.
- All unextracted resources and any non-forged items still in the bag are lost on death or “Dispel”.

## Artifacts and collections

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

## Extraction / mailing

- Performed exclusively through clerks.
- The interface MUST present a clear list of items that can be sent back to the surface.
- Once extracted, items and gold are safe.
- Clerk types: one gather specialist and one misc specialist per floor, with a chance of Packmule Patty as an additional clerk. Maximum three clerks total on any floor.

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