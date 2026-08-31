# Shared gear board (inventory + loadout)

Status: binding design  
Read when: changing pause inventory, Floor Crystal loadout, or gear tooltips  
Code: `scripts/ui/gear_board.gd`, `scripts/ui/gear_board_text.gd`, `scripts/ui/gear_board_act.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/pause_inv.gd`, `scripts/ui/progress_ui.gd`, `scripts/ui/progress_ui_hub.gd`, `scripts/ui/progress_ui_inv.gd`  
See also: `design/inventory.md`, `design/ui.md`, `design/hub.md`, `design/input.md`

Pause Inventory and Floor Crystal Loadout MUST reuse one paper-doll board. Placeholdia inventory (opened outside the dungeon) MUST use the same option sources and apply path as Loadout. Dungeon inventory MAY only swap the current slot with matching bag items.

## Layout

Equipment is not a stack of full-width bars.

- Center column: Head, Body, Legs
- Left of center: Weapon, with Potion under it
- Right of center: Tool, with Food under it
- Further right: paged stats card
- Loadout footer under the doll: character, floor −/+, confirm enter
- Dungeon inventory: 7-column bag grid under the doll

Two-item columns (weapon/potion and tool/food) MUST be vertically centered against the three-piece armor column.

## Stats card

Pages, in order:

1. **Bonuses from this kit** — only stats the current equipment actually changes
2. **All combat stats** — damage, defense, max HP, crit
3. **All utility stats** — move, gather
4. **Artifact sets** — pause / dungeon inventory only; omitted on Loadout

The current page name sits in the card header. Navigation chrome is on either side of that title (`Q · LT` left, `RT · E` right), not in a separate bar at the top of the menu. Labels stay horizontal.

## Highlight and tooltips

- Opening the menu MUST leave the flyout hidden until the player hovers a slot, moves highlight with keyboard/gamepad, or activates the already-focused slot.
- Highlight (focus or mouse hover) shows a flyout next to that control, not a label under the slot.
- Leaving every slot with the mouse hides the flyout. Keyboard / d-pad highlight MUST show it again without requiring a mouse pass first.
- The re-equip list uses the same flyout, anchored to the highlighted row. First-open layout MUST wait a frame so the flyout sits beside the row, not against the screen edge.
- **Y** cycles tooltip detail: off → current item stats → forge preview (then back to off). Artifacts, food, and potions have no forge preview.

## Re-equip list

**A** / confirm on a slot opens a modal list for that slot.

- Chevron (`▸`) on the parent slot if a new non-starter option appeared since that list was last opened.
- Dungeon list: currently equipped item (if any) plus bag items for that slot. Tool bag rows MUST match the run’s tool type.
- Placeholdia / Loadout list: equipped, starters, unlocked starters, holds, then non-white bank items. No white duplicates. Bank / unforged kit pieces are marked **AT RISK**. Holds are marked **HOLD**.
- Selecting the equipped row unequips it when the slot allows. Weapon, tool, and starter pieces stay on the slot.
- **B** / Esc / Back closes only the list. The parent menu stays open.
- Opening another slot replaces the open list.

## Slot actions

| Input | Effect |
|-------|--------|
| A / confirm | Open re-equip (slot) or apply the highlighted list row |
| B / Esc / Back | Close list if open, otherwise close the menu |
| X tap | Drop (dungeon floor only) |
| X hold | Destroy |
| Y | Cycle tooltip off / current / forge preview |
| Q / LB | Previous stats page |
| E / RB | Next stats page |

Weapon and tool cannot be dropped, destroyed, or emptied. Mouse click MUST NOT advance stats pages (left click is also the attack bind).

## Focus and pause

Both hosts MUST pause the tree while open so Esc cannot fall through. While the list is open, background controls lose focus. Clicks and confirm on list rows MUST reach those buttons; the host MUST NOT mark every event handled just because the list is open. Teardown of the list is deferred so a row is not freed mid-`pressed`.

## Live snapshot — scripts

- `gear_board.gd` — layout, flyout, hover, pending kit apply
- `gear_board_text.gd` — labels, option lists, tooltip / stats copy
- `gear_board_act.gd` — list open/close, equip/unequip, drop/destroy, paging
- Pause tab 0 and `progress_ui` loadout/inv both call `Board.build`