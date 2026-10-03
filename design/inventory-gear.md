# Gear rules and crafting

Status: binding design  
Read when: gear rules, item level, affixes, analyze, duplicates, forge, whites, options source  


## Gear rules

- White, green, and blue rarity appear in the demo.
- Blue items have improved stats over green items and are obtainable only from bosses (Floor Guardians and Gate Master).
- Stats take effect immediately.
- Weapon and tool paper-doll overlays: art_pipeline §19.2.4. Armor and other gear may remain stats-only.
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

**Salvage spare gear** lives on the Gameplay settings page. Default **off**. When on, a **Keep bars** block appears with two sliders:

- **Finish at least** — minimum Quality to keep a duplicate (range 0.50–1.00).
- **Fortune at least** — minimum Luck to keep a duplicate (range 0.75–1.25).

A duplicate that meets **either** bar (Finish **or** Fortune) is kept. A duplicate that misses both is broken down for smithing XP. A new trait, a higher item level, or a luck roll that beats the book is never a duplicate and is never salvaged by this toggle.

## Forge

The forge configurator, craft queue, locks, cost and results screen: `inventory-forge.md` (opened when working on the Forge).

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
