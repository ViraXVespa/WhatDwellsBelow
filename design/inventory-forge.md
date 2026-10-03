# Gear forge flow

Status: binding design  
Read when: working on the Anvil Forge: type selector, item-level and quantity steppers, locks, cost, craft queue, results screen

Rules for forging. Rarity, affix, Analyze, duplicate and starter rules stay on the gear page.

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
