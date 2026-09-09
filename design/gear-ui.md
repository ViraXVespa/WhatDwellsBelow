# Shared gear board (inventory + loadout)

Status: binding design
Read when: changing pause inventory, Floor Crystal loadout, or gear tooltips
Code: `scripts/ui/gear_board.gd`, `gear_board_build.gd`, `gear_board_floor.gd`, `gear_board_tip.gd`, `gear_board_text.gd`, `gear_board_opts.gd`, `gear_board_stats.gd`, `gear_board_act.gd`, `gear_board_sub.gd`, `gear_board_anvil.gd`, `gear_board_anvil_view.gd`, `gear_icons.gd`, `scripts/ui/menu_pad.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/pause_inv.gd`, `scripts/ui/progress_ui.gd`, `scripts/ui/progress_ui_hub.gd`, `scripts/ui/progress_ui_inv.gd`
See also: `design/inventory.md`, `design/ui.md`, `design/hub.md`, `design/input.md`

Pause Inventory and Floor Crystal Loadout MUST reuse one paper-doll board. Placeholdia inventory (opened outside the dungeon) MUST use the same option sources and apply path as Loadout. Dungeon inventory MAY only swap the current slot with matching bag items.

## Layout

Equipment is not a stack of full-width bars.

- Center column: Head, Body, Legs
- Left of center: Weapon, with Potion under it
- Right of center: Tool, with Food under it
- Further right: paged stats card
- Loadout footer under the doll, centered: `Floor: [−] [selected] [+] (Deepest floor: n)` then **Enter dungeon**
- Dungeon inventory: 7-column bag grid under the doll

Two-item columns (weapon/potion and tool/food) MUST be vertically centered against the three-piece armor column. Slot cells SIZE_EXPAND_FILL across the row so the doll is not packed to one side.

Loadout MUST NOT show a top summary line of weapon / tool / deepest floor. Character switching lives on Pause → System, not on this board.

Floor labels stay on one horizontal line (`AUTOWRAP_OFF`). `−` disables at floor 1. `+` disables at `App.prog.deepest`. Disabled steppers use `FOCUS_NONE` and drop out of the keyboard / gamepad chain. Navigating onto a now-disabled stepper moves focus to the other live stepper, or to **Enter dungeon** if both are dead. From Legs / Food, down lands on `+` when it is live, else `−`. From Potion, down lands on `−` when it is live, else `+`.

Opening the Floor Crystal focuses **Enter dungeon**. Up from there reaches the live floor stepper, then the equipment slots.

## Slot plates

Plates are icon-first. Names and stats live in the flyout, not on the cell.

- Empty head / body / legs / potion / food show a dark imprint of that slot type (`assets/gear/slot_*.png`).
- A filled slot or bag cell shows the item icon (`assets/gear/` keyed from `_src/gear/` through `tools/process_gear_icons.py`).
- Rarity wash is in-engine (white / green / blue). Do not bake rarity into the PNG.
- AT RISK pieces (bank, artifacts, unforged kit that is not a hold or starter) take a red plate border on the board and in the re-equip list. HOLD / starter pieces do not.
- An unseen non-starter option MAY add a `▸` on the parent slot.

## Stats card

Pages, in order:

1. **Bonuses from this kit** — only stats the current equipment actually changes
2. **All combat stats** — damage, defense, max HP, crit
3. **All utility stats** — move, gather
4. **Artifact sets** — pause / dungeon inventory only; omitted on Loadout

The current page name sits in the card header. Navigation chrome is on either side of that title (`Q · LT` left, `RT · E` right), not in a separate bar at the top of the menu. Labels stay horizontal.

The card is display-only. It MUST NOT take keyboard, mouse, or gamepad focus and MUST NOT sit in the focus chain. Pages change only through **Q / LT** and **E / RT**. LB / RB MUST NOT page this card; those bumpers cycle menu tabs when the host has tabs. Mouse click MUST NOT page it.

## Highlight and tooltips

- Opening the menu MUST leave the flyout hidden until the player hovers a slot, moves highlight with keyboard/gamepad, or activates the already-focused slot. Loadout first focus is **Enter dungeon**, so the flyout stays hidden until a slot is highlighted.
- Highlight (focus or mouse hover) shows a flyout next to that control, not a label under the slot. On the main board the flyout sits to the right of the plate (flips left if it would clip). On the re-equip list the flyout sits under the icon: top-left a few pixels below the center of the icon’s bottom edge.
- The flyout MUST only anchor to a control that has an item key. Back, Close, tab buttons, and empty bag cells hide it.
- Leaving every slot with the mouse hides the flyout. Keyboard / d-pad highlight MUST show it again without requiring a mouse pass first.
- Changing pause tabs hides the flyout. Returning to Inventory restores it only if it was visible when the player left. Paging the stats card hides it.
- First-open layout MUST wait until the plate has a real on-screen rect so the flyout does not land on the bottom edge.
- **Y** cycles tooltip detail: off → current item stats → forge preview (then back to off). Artifacts, food, and potions have no forge preview.
- White starters on a slot or in the re-equip list MUST resolve to the implied weapon/tool (or the item stored on the button). They MUST NOT read as empty when an icon is showing.

## Re-equip list

**A** / confirm on a slot opens a modal list for that slot.

- Chevron (`▸`) on the parent slot if a new non-starter option appeared since that list was last opened.
- Options are icon plates in a horizontal row, not text rows.
- Dungeon list: currently equipped item (if any) plus bag items for that slot. Tool bag rows MUST match the run’s tool type.
- Placeholdia / Loadout list: equipped, starters, unlocked starters, holds, then non-white bank items. No white duplicates. Bank / unforged kit pieces are marked **AT RISK** in the flyout and with a red border. Holds are marked **HOLD**.
- Left / Right stay on the option row (re-equip and Anvil Analyze / Forge lists). Down (or Right off the last option) reaches Back. Up from Back returns to the last option that had focus, not always the first. The host MUST NOT swallow Left / Right while that list is open.
- Selecting the equipped row unequips it when the slot allows. Weapon, tool, and starter pieces stay on the slot.
- **B** / Esc / Back closes only the list. The parent menu stays open. Focusing Back hides the flyout.
- Opening another slot replaces the open list.

## Slot actions

| Input | Effect |
|-------|--------|
| A / confirm | Open re-equip (slot) or apply the highlighted list row. On **Enter dungeon**, enter the selected floor. |
| B / Esc / Back | Close list if open, otherwise close the menu |
| X tap | Drop (dungeon floor only) |
| X hold | Destroy |
| Y | Cycle tooltip off / current / forge preview |
| Q / LT | Previous stats page |
| E / RT | Next stats page |
| LB / RB | Pause tabs only (Inventory / Skills / System). Ignored on Loadout / Anvil / Placeholdia boards that have no tabs. |

Weapon and tool cannot be dropped, destroyed, or emptied. Mouse click MUST NOT advance stats pages (left click is also the attack bind).

**Enter dungeon** is a single confirm. Closing the menu with B / Esc cancels. B on the re-equip list MUST NOT enter the dungeon.

## Focus and pause

Both hosts MUST pause the tree while open so Esc cannot fall through. While the list is open, background controls lose focus. Clicks and confirm on list rows MUST reach those buttons; the host MUST NOT mark every event handled just because the list is open. Anvil Analyze / Forge lists use the same wrap (items Left/Right, Back below, Up from Back to the last item). Teardown of the list is deferred so a row is not freed mid-`pressed`.

## Live snapshot — scripts

- `menu_pad.gd` — shared confirm / back / tab / stats-page classifiers
- `gear_board.gd` — board facade: doll layout, bag grid, pending kit apply
- `gear_board_build.gd` — title, stats card, slot / bag cell widgets
- `gear_icons.gd` — icon paths, rarity fill, risk border
- `gear_board_floor.gd` — loadout floor row, stepper disable / neighbors, Enter-first focus
- `gear_board_tip.gd` — flyout host and placement. `ui.tab` may be a string (`analyze` / `forge`) on Anvil; placement MUST NOT `int()` that field
- `gear_board_text.gd` — slot / item labels, tooltip copy; option lists via `gear_board_opts.gd`
- `gear_board_stats.gd` — paged stats card copy
- `gear_board_act.gd` — drop / destroy / paging / enter / input
- `gear_board_sub.gd` — re-equip list open/close and apply / unequip
- `gear_board_anvil.gd` — analyze / forge apply; footer via `gear_board_anvil_view.gd`
- Pause tab 1 (Inventory) and `progress_ui` loadout/inv both call `Board.build`
