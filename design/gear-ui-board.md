# Gear board layout and plates

Status: binding design  
Read when: armor columns, plate icons, rarity wash, stepper neighbors  


## Layout

Equipment is not a stack of full-width bars.

- Center column: Head, Body, Legs
- Left of center: Weapon, with Potion under it
- Right of center: Tool, with Food under it
- Further right: paged stats card
- Loadout footer under the doll, centered: `Floor: [−] [selected] [+] (Deepest floor: n)` then **Enter dungeon**
- Dungeon inventory: 7-column bag grid under the doll
- Anvil footer: bank + carried gold / ore / wood, then a short Analyze or Forge status line. Do not list holds on Analyze. Do not list every analyzed remnant on Forge.

Two-item columns (weapon/potion and tool/food) MUST be vertically centered against the three-piece armor column. Slot cells SIZE_EXPAND_FILL across the row so the doll is not packed to one side.

Loadout MUST NOT show a top summary line of weapon / tool / deepest floor. Character switching lives on Pause → System, not on this board.

Floor labels stay on one horizontal line (`AUTOWRAP_OFF`). `−` disables at floor 1. `+` disables at `App.prog.deepest`. Disabled steppers use `FOCUS_NONE` and drop out of the keyboard / gamepad chain. Navigating onto a now-disabled stepper moves focus to the other live stepper, or to **Enter dungeon** if both are dead. From Legs / Food, down lands on `+` when it is live, else `−`. From Potion, down lands on `−` when it is live, else `+`.

The Floor Crystal dungeon-level picker and the Anvil item-level / quantity pickers MUST share `scripts/ui/step_row.gd` so disable, spacing, and neighbor retargeting stay one design.

Opening the Floor Crystal focuses **Enter dungeon**. Up from there reaches the live floor stepper, then the equipment slots.

## Slot plates

Plates are icon-first. Names and stats live in the flyout, not on the cell.

- Empty head / body / legs / potion / food show a dark imprint of that slot type (`assets/gear/slot_*.png`).
- A filled slot or bag cell shows the item icon (`assets/gear/` keyed from `_src/gear/` through `tools/process_gear_icons.py`).
- Rarity wash is in-engine (white / green / blue). Do not bake rarity into the PNG.
- AT RISK pieces (bank, unforged kit that is not a hold or starter) take a red plate border on the board and in the re-equip list. HOLD / starter pieces do not. Artifacts are dungeon-only and are not tagged AT RISK.
- An unseen non-starter option MAY add a `▸` on the parent slot.
- On the Anvil, Potion and Food plates are disabled. They MUST NOT open a submenu.
