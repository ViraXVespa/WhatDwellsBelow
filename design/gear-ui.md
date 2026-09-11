# Shared gear board (inventory + loadout + anvil)

Status: binding design  
Read when: changing pause inventory, Floor Crystal loadout, Anvil menus, or gear tooltips  
Code: `scripts/ui/gear_board.gd`, `gear_board_build.gd`, `gear_board_floor.gd`, `gear_board_tip.gd`, `gear_board_text.gd`, `gear_board_opts.gd`, `gear_board_stats.gd`, `gear_board_act.gd`, `gear_board_sub.gd`, `gear_board_anvil.gd`, `gear_board_anvil_view.gd`, `gear_board_anvil_forge.gd`, `gear_icons.gd`, `scripts/ui/menu_pad.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/pause_inv.gd`, `scripts/ui/progress_ui.gd`, `scripts/ui/progress_ui_hub.gd`, `scripts/ui/progress_ui_inv.gd`  
See also: `design/inventory.md`, `design/ui.md`, `design/hub.md`, `design/input.md`, `design/handoff-anvil.md`

Pause Inventory and Floor Crystal Loadout MUST reuse one paper-doll board. Placeholdia inventory (opened outside the dungeon) MUST use the same option sources and apply path as Loadout. Dungeon inventory MAY only swap the current slot with matching bag items. The Anvil reuses the same doll, flyout, stats card, and slot plates.

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

Opening the Floor Crystal focuses **Enter dungeon**. Up from there reaches the live floor stepper, then the equipment slots.

## Slot plates

Plates are icon-first. Names and stats live in the flyout, not on the cell.

- Empty head / body / legs / potion / food show a dark imprint of that slot type (`assets/gear/slot_*.png`).
- A filled slot or bag cell shows the item icon (`assets/gear/` keyed from `_src/gear/` through `tools/process_gear_icons.py`).
- Rarity wash is in-engine (white / green / blue). Do not bake rarity into the PNG.
- AT RISK pieces (bank, unforged kit that is not a hold or starter) take a red plate border on the board and in the re-equip list. HOLD / starter pieces do not. Artifacts are dungeon-only and are not tagged AT RISK.
- An unseen non-starter option MAY add a `▸` on the parent slot.
- On the Anvil, Potion and Food plates are disabled. They MUST NOT open a submenu.

## Stats card

Pages, in order:

1. **Bonuses from this kit** — only stats the current equipment actually changes
2. **All combat stats** — damage, defense, max HP, crit chance, crit damage, attack speed, attack range, health on hit / kill
3. **All utility stats** — movement speed, gather speed / power / yield
4. **Artifact sets** — pause / dungeon inventory only; omitted on Loadout and Anvil

The current page name sits in the card header. Navigation chrome is on either side of that title (`Q · LT` left, `RT · E` right), not in a separate bar at the top of the menu. Labels stay horizontal.

The card is display-only. It MUST NOT take keyboard, mouse, or gamepad focus and MUST NOT sit in the focus chain. Pages change only through **Q / LT** and **E / RT**. LB / RB MUST NOT page this card; those bumpers cycle menu tabs when the host has tabs. Mouse click MUST NOT page it.

## Highlight and tooltips

- Opening the menu MUST leave the flyout hidden until the player hovers a slot, moves highlight with keyboard/gamepad, or activates the already-focused slot. Loadout first focus is **Enter dungeon**, so the flyout stays hidden until a slot is highlighted.
- Highlight (focus or mouse hover) shows a flyout next to that control, not a label under the slot. On the main board the flyout sits to the right of the plate (flips left if it would clip). On the re-equip list the flyout sits under the icon: top-left a few pixels below the center of the icon’s bottom edge.
- The flyout MUST only anchor to a control that has an item key. Close, tab buttons, empty bag cells, and Anvil Potion / Food plates hide it.
- Leaving every slot with the mouse hides the flyout. Keyboard / d-pad highlight MUST show it again without requiring a mouse pass first.
- Changing pause tabs or Anvil tabs hides the flyout. Returning to Inventory restores it only if it was visible when the player left. Paging the stats card hides it.
- First-open layout MUST wait until the plate has a real on-screen rect so the flyout does not land on the bottom edge.
- **Y** cycles tooltip detail: off → current item stats → forge preview (then back to off). Artifacts, food, and potions have no forge preview.
- White starters on a slot or in the re-equip list MUST resolve to the implied weapon/tool (or the item stored on the button). They MUST NOT read as empty when an icon is showing.

## Re-equip and Anvil submenus

**A** / confirm on a live slot opens a modal for that slot.

Shared chrome (inventory, loadout, and Anvil):

- The parent board’s control strip MUST NOT change while the submenu is open.
- The submenu MUST draw its own tooltip strip with the controls for that window.
- There is no **Back** button. B / Esc / the submenu strip’s cancel verb closes only the submenu. The parent menu stays open.
- Opening another slot replaces the open submenu.

Inventory / loadout list:

- Chevron (`▸`) on the parent slot if a new non-starter option appeared since that list was last opened.
- Options are icon plates in a horizontal row, not text rows.
- Dungeon list: currently equipped item (if any) plus bag items for that slot. Tool bag rows MUST match the run’s tool type.
- Placeholdia / Loadout list: equipped, starters, unlocked starters, holds, then non-white bank items. No white duplicates. Bank / unforged kit pieces are marked **AT RISK** in the flyout and with a red border. Holds are marked **HOLD**.
- Left / Right stay on the option row. The host MUST NOT swallow Left / Right while that list is open.
- Selecting the equipped row unequips it when the slot allows. Weapon, tool, and starter pieces stay on the slot.

Anvil Analyze submenu:

- Only AT RISK green/blue pieces for that slot. No holds, starters, whites, artifacts, potions, or food.
- Confirming the highlighted piece **destroys it immediately** and writes the forge book. Do not close, reopen, and require a second select.
- Warning copy uses warning colorization: `WARNING: Analyzing an item permanently destroys the item in exchange for the ability to Forge new equipment with its equipment traits.`
- Strip verbs: analyze / close.

Anvil Forge submenu (one window, not a second pick list of remnants):

- Type row when the slot has more than one type (weapon, tool). Armor skips it.
- Rarity buttons: Green / Blue. A rarity is disabled until that type+rarity has been analyzed. The selected rarity is highlighted like a Pause tab, not disabled.
- Item-level stepper, clamped to the max analyzed level for that type.
- Lock-trait toggles for analyzed affixes only. Green: 1 lock. Blue: 2. A lock consumes a bonus slot and multiplies cost.
- Cost + wait preview. Forge confirm spends materials and starts the short craft beat.
- If holds for that type are full: keep the old holds, list replace targets plus discard-new. Discard does not refund.
- Whites and duplicate remnants MUST NOT appear here.
- Strip verbs: set / forge (or replace / keep when a new roll is waiting) / close.

## Anvil tabs

- Analyze / Forge tabs sit in the Anvil footer.
- The current tab is **highlighted**, not disabled. Match Pause Inventory / Skills / System tab styling (`gear_board_anvil_view` paint-on).
- LB / RB (and the on-screen tab glyphs) cycle Analyze ↔ Forge.
- Switching tabs rebuilds the board and clears the forge draft (type, rarity, level, locks, pending roll). It does not call a missing helper to do that rebuild — the host `_rebuild_anvil` + `_show` path is the refresh.

## Slot actions

| Input | Effect |
|-------|--------|
| A / confirm | Open re-equip or Anvil submenu (slot), apply the highlighted list row, or confirm Forge. On **Enter dungeon**, enter the selected floor. |
| B / Esc | Close submenu if open, otherwise close the menu. No Back button. |
| X tap | Drop (dungeon floor only) |
| X hold | Destroy |
| Y | Cycle tooltip off / current / forge preview |
| Q / LT | Previous stats page |
| E / RT | Next stats page |
| LB / RB | Pause tabs on Pause. Anvil tabs on Anvil. Ignored on Loadout / Placeholdia boards that have no tabs. |

Weapon and tool cannot be dropped, destroyed, or emptied. Mouse click MUST NOT advance stats pages (left click is also the attack bind). Anvil Potion / Food MUST NOT accept A.

**Enter dungeon** is a single confirm. Closing the menu with B / Esc cancels. B on a submenu MUST NOT enter the dungeon.

## Focus and pause

Both hosts MUST pause the tree while open so Esc cannot fall through. While the submenu is open, background controls lose focus. Clicks and confirm on submenu rows MUST reach those buttons; the host MUST NOT mark every event handled just because the submenu is open. Teardown of the submenu is deferred so a row is not freed mid-`pressed`.

## Live snapshot — scripts

- `menu_pad.gd` — shared confirm / back / tab / stats-page classifiers
- `gear_board.gd` — board facade: doll layout, bag grid, pending kit apply; Anvil disables potion / food
- `gear_board_build.gd` — title, stats card, slot / bag cell widgets
- `gear_icons.gd` — icon paths, rarity fill, risk border
- `gear_board_floor.gd` — loadout floor row, stepper disable / neighbors, Enter-first focus
- `gear_board_tip.gd` — flyout host and placement. `ui.tab` may be a string (`analyze` / `forge`) on Anvil; placement MUST NOT `int()` that field
- `gear_board_text.gd` — slot / item labels, tooltip copy; option lists via `gear_board_opts.gd`
- `gear_board_stats.gd` — paged stats card copy
- `gear_board_act.gd` — drop / destroy / paging / enter / input
- `gear_board_sub.gd` — re-equip and Anvil Analyze lists; Forge tab hands the body to `gear_board_anvil_forge.gd`
- `gear_board_anvil.gd` — Analyze apply; tab cycle
- `gear_board_anvil_view.gd` — Analyze / Forge tab chrome and short footer copy
- `gear_board_anvil_forge.gd` — Forge configurator (`fill`, `start`, `finish`, `hint_parts`)
- Pause tab 1 (Inventory) and `progress_ui` loadout/inv/anvil all call `Board.build`
