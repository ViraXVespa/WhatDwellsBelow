# Inventory, gear, artifacts, extraction

Status: binding design  
Read when: changing bag, equipment, food, potions, artifacts, Extraction Gates, or the anvil  
Code: `scripts/data/progress.gd`, `scripts/data/progress_gear.gd`, `scripts/data/progress_gear_req.gd`, `scripts/data/progress_extract.gd`, `scripts/data/progress_make.gd`, `scripts/data/progress_forge.gd`, `scripts/data/affixes.gd`, `scripts/data/gear_roll.gd`, `scripts/data/gear_rules.gd`, `scripts/data/catalog.gd`, `scripts/ui/gear_board/gear_board.gd`, `scripts/ui/gear_board/gear_board_text.gd`, `scripts/ui/gear_board/gear_board_act.gd`, `scripts/ui/gear_board/gear_board_anvil.gd`, `scripts/ui/gear_board/gear_board_anvil_view.gd`, `scripts/ui/gear_board/gear_board_anvil_forge.gd`, `scripts/ui/gear_board/gear_board_sub.gd`, `scripts/ui/step_row.gd`  
See also: `design/gear-ui.md`, `design/skills.md`, `design/ui.md`, `design/hub.md`, `design/tunables.md`, `design/art-pipeline.md`, `design/handoff-anvil.md`

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

## Gear rules

- White, green, and blue rarity appear in the demo.
- Blue items have improved stats over green items and are obtainable only from bosses (Floor Guardians and Gate Master).
- Stats take effect immediately.
- Weapons and tools require paper-doll **overlay layers** composited onto shared unarmed body animations. Do not require a full baked character animation set per weapon. Armor and other gear may remain stats-only.
- The player may maintain up to three forged **holds per type per slot**. Great Axe holds do not share a cap with Staff holds. Pickaxe and hatchet are separate.
- Forged holds always return to Placeholdia on death or “Dispel”, even if the item was dropped on the floor.
- All unextracted resources and any non-forged items still in the bag are lost on death or “Dispel”.
- Weapon and tool MUST remain equipped at all times.

## Item level

- Every piece of equipment has an item level that scales its stats.
- Dungeon drops: item level equals the combat level of the enemy that dropped it, or the area combat level if there is no specific enemy.
- Forged pieces: item level is a player-configured option. It changes potential stats and forge cost. The stepper is the shared horizontal control in `scripts/ui/step_row.gd` (same layout as the Floor Crystal dungeon-level picker): minus, value, plus, disable at the ends. It is clamped to the highest item level already analyzed for that type.
- Higher rarity (white → green → blue) raises the base value of each affix before quality and luck.

## Affixes

Affixes live in `scripts/data/affixes.gd` as a data table so new ids can be added later without rewriting roll code.

**Primary (implicit, always present)**

| Slot | Primary |
|------|---------|
| Weapon | Damage |
| Head / body / legs | Defense |
| Tool | Gather Speed |

**Combat bonus pool** (weapons and armor): Defense, Damage, Health, Crit Chance, Crit Damage, Movement Speed, Attack Speed, Attack Range, Health on Hit, Health on Kill.

**Tool bonus pool** (non-combat): Gather Power, Yield Chance. Expand this list in `affixes.gd` when new gather traits are invented.

Rules:

- No duplicate affix id on the same item.
- Damage or Defense MAY roll as a bonus affix even when it is already the primary. That is not a duplicate.
- White: primary only. No bonus rolls. Quality is fixed at 0.5. Luck is fixed at 0.75. Whites are not part of Analyze / Forge.
- Green: primary plus 1 bonus from the slot family pool.
- Blue: primary plus 2 bonuses from the slot family pool.
- Values are rolled, not stamped as identical set stats. Two greens of the same template MUST be allowed to differ.
- Dungeon roll: `{base(level, rarity)} * Quality * Luck` where Quality is `Random(0.5, 1.0)` and Luck is `Random(0.75, 1.25)`.
- Percent affixes keep fractional values. Flat affixes may show as ints when they land on a whole number.
- Combat and the kit card read only the `affixes` rows when that list is present. Leftover flat keys on old saves (`atk_range`, `crit_chance`, `hp_on_hit`, and the old `crit` / `spd` / `gather` aliases) MUST NOT apply and MUST NOT appear on the card. `Roll.stamp` wipes those keys before writing a new roll.
- Combat keys: `dmg`, `def`, `hp`, `crit_chance`, `crit_dmg`, `move_spd`, `atk_spd`, `atk_range`, `hp_on_hit`, `hp_on_kill`. Tools: `gather_spd`, `gather_pow`, `yield_chance`.

## Analyze

- The only analyzable pieces are **AT RISK** green or blue items (bank or unforged kit that would be lost on death / Dispel).
- Holds MUST NOT appear in the Analyze list and MUST NOT be analyzable.
- Starters, whites, artifacts, potions, and food MUST NOT be analyzable.
- Artifacts are dungeon-only. They are not AT RISK and need no AT RISK tag.
- Opening the Analyze submenu and picking a piece **is** the confirm. There is no second confirm dialog. The piece is destroyed immediately and the book updates.
- Analyzing permanently unlocks, for that **type and rarity**:
  - the piece’s item level (book keeps the max)
  - each stat-modifier category on the piece
  - the maximum luck seen on those modifiers
- Whites are never manually analyzed. If a white with a higher item level than the current starter of that template is extracted, raise the starter’s item level and matching stats.

## Duplicates (salvage on extract)

Whites on extract still follow the starter path in White items and starters. They are not this toggle.

A mailed green/blue piece is a **duplicate** only when all of the following are true:

- Its item level is **not greater than** the highest analyzed item level of that type (any rarity).
- Every affix on it already exists in the book for that type **and rarity**.
- None of its per-affix luck rolls **beat** the book luck for that affix (incoming luck is not greater than stored luck). Use `>=` on the book side: if the book already has luck greater than or equal to this piece, that affix is not new.

**Salvage spare gear** lives on the Gameplay settings page. Default **off**. When off, duplicates stay in the bank as a second copy.

When on, a **Keep bars** block appears with two sliders:

- **Finish at least** — minimum Quality to keep a duplicate (range 0.50–1.00).
- **Fortune at least** — minimum Luck to keep a duplicate (range 0.75–1.25).

A duplicate that meets **either** bar (Finish **or** Fortune) is kept. A duplicate that misses both is broken down for smithing XP. A new trait, a higher item level, or a luck roll that beats the book is never a duplicate and is never salvaged by this toggle.

## Forge

- The player picks rarity (green or blue). A rarity is available only after at least one piece of that type+rarity has been analyzed. White chests MUST NOT appear.
- Weapon and tool slots show a **type selector** in the same submenu (Great Axe / Staff / Longbow, Pickaxe / Hatchet). Armor slots have one type and skip the row.
- Item level uses the shared `step_row` stepper from 1 to the max analyzed level for that type.
- **Quantity** uses the same stepper, 1–9. Cost and wait scale with quantity. Each finished piece grants smithing XP even if the player later discards the roll.
- Output luck uses the analyzed peak for that type+rarity: `min = max(0.75, peak - 0.25)`, `max = peak`. Per-affix book luck is used when present.
- Quality still starts as `Random(0.5, 1.0)`, then is nudged up if smithing level is at or above the configured item level, and down if smithing is below it.
- By default the bonus pool is every affix already analyzed for that type+rarity (plus Damage / Defense as allowed extras). The player may **lock** analyzed traits only. Green: 1 lock. Blue: 2 locks. A lock consumes one bonus slot and multiplies cost.
- Cost: armor is gold + ore. Weapons and tools are gold + ore + wood. No root. Locks raise the bill sharply. Smithing level applies a small discount.
- Duration is a short craft beat per piece, scaled by smithing level vs the item level being forged. A progress bar shows the current piece. Back during the bar **stops the queue**. Pieces already finished go to the results screen. The unfinished piece is dropped. Materials already spent are not refunded.
- Materials spend from carried gold/ore/wood first, then the bank.
- New rolls do **not** auto-enter holds. After the batch (or after a mid-queue cancel that finished at least one piece) the player sees a **results screen**.
- Results use inventory icon cells and the same flyout / Y stats as the bag. Current holds for that type start selected. The player may pick up to three pieces from the combined hold + new list. Confirm writes only that type’s holds and leaves other types in the same slot alone. “Keep old holds” dumps the new rolls.

## White items and starters

- White is starter-only. It has no role in the Analyze / Forge flow and MUST NOT appear as a forge remnant or white chest in the Forge UI.
- A selectable starter (Great Axe, Lightning Staff, Longbow, Pickaxe, Hatchet, default potion) MUST NOT be stored in the bank and MUST NOT be forged.
- If a starter is extracted / sent up, convert it to smithing XP. Do not create a second copy in storage.
- A white item that is not already a starter becomes a starter the first time it is sent up, without an anvil step. Later extracts of that template convert to smithing XP, unless the new white has a higher item level — then the starter’s level is raised.
- Unequipping in Placeholdia MUST NOT treat the piece as a world drop and MUST NOT convert it to smithing XP.
- Stale saves that still contain white remnants in anvil lists MUST be ignored by Analyze / Forge filters.

## Where options come from

- **Dungeon inventory:** equipped piece (if any) plus bag items of that slot. No bank, holds, or extra starters.
- **Placeholdia inventory and Floor Crystal loadout:** equipped piece, built-in starters, unlocked starters, holds, then non-white bank items. White bank copies are omitted so they cannot duplicate a starter.
- Bank pieces and other unforged kit taken below are shown as **AT RISK** (lost on death or Dispel unless mailed). Holds show **HOLD**.
- **Anvil Analyze:** AT RISK green/blue for that slot only. Footer does not list holds.
- **Anvil Forge:** configurator for types already in `forge_book`. Footer does not list every remnant the player has ever analyzed.

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
- Duplicate green/blue extracts follow **Salvage spare gear**. Whites follow the starter path.

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

## Live snapshot — required slots

`Gear.ensure_required_slots` runs after new-progress `reset_meta`, save `from_meta`, and recap `lose_unextracted`. An empty or invalid weapon or tool slot takes the selected hold when `hold_pick` is in range for that slot; otherwise it takes the current starter (`pick_weapon` / `tool_type`). Head, body, legs, potion, and food are not filled by this path. `begin_run_loadout` uses the same weapon/tool rule so hub and dungeon match.

Forge ledger lives on `App.prog.forge_book`, keyed `slot:type:rarity`. Legacy `analyzed` remnants migrate into that book once and then clear. Load also runs `Rules.normalize_prog` so pre-affix saves pick up item level, Finish, Fortune, and capped affix rows.
