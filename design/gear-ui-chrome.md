# Anvil tabs, slot actions, focus, live scripts

Status: binding design  
Read when: Analyze Forge bumpers, verbs, deferred teardown, script map  


## Anvil tabs

- Analyze / Forge tabs sit in the Anvil footer.
- The current tab is **highlighted**, not disabled. Match Pause Inventory / Skills / System tab styling (`gear_board_anvil_view` paint-on).
- LB / RB (and the on-screen tab glyphs) cycle Analyze ↔ Forge.
- Switching tabs rebuilds the board and clears the forge draft (type, rarity, level, locks, pending roll, in-flight job). It does not call a missing helper to do that rebuild — the host `_rebuild_anvil` + `_show` path is the refresh.

## Slot actions

| Input | Effect |
|-------|--------|
| A / confirm | Open re-equip or Anvil submenu (slot), apply the highlighted list row, or confirm Forge / keep selected. On **Enter dungeon**, enter the selected floor. |
| B / Esc | Close submenu if open (or stop queue / keep old holds during Forge work / results), otherwise close the menu. No Back button. |
| X tap | Drop (dungeon floor only) |
| X hold | Destroy |
| Y | Cycle tooltip off / current / forge preview |
| Q / LT | Previous stats page |
| E / RT | Next stats page |
| LB / RB | Pause tabs on Pause. Anvil tabs on Anvil. Ignored on Loadout / Placeholdia boards that have no tabs. |

Weapon and tool cannot be dropped, destroyed, or emptied. Mouse click MUST NOT advance stats pages (left click is also the attack bind). Anvil Potion / Food MUST NOT accept A.

**Enter dungeon** is a single confirm. Closing the menu with B / Esc cancels. B on a submenu MUST NOT enter the dungeon.

## Focus and pause

Both hosts MUST pause the tree while open so Esc cannot fall through. While the submenu is open, background controls lose focus. Clicks and confirm on submenu rows MUST reach those buttons; the host MUST NOT mark every event handled just because the submenu is open. Teardown of the submenu is deferred so a row is not freed mid-`pressed`. Rebuilds MUST restore the last Forge control (`forge_focus` / current rarity) and MUST NOT snap to Green when the player is on Blue. Salvage checkbox rebuilds MUST restore focus on that checkbox, not the top of Pause.

## Live snapshot — scripts

- `menu_pad.gd` — shared confirm / back / tab / stats-page classifiers
- `step_row.gd` — shared minus / value / plus stepper (Floor Crystal level, Forge item level, Forge quantity)
- `gear_board.gd` — board facade: doll layout, bag grid, pending kit apply; Anvil disables potion / food
- `gear_board_build.gd` — title, stats card, slot / bag cell widgets
- `gear_icons.gd` — icon paths, rarity fill, risk border
- `gear_board_floor.gd` — loadout floor row, stepper disable / neighbors, Enter-first focus
- `gear_board_tip.gd` — flyout host and placement. `ui.tab` may be a string (`analyze` / `forge`) on Anvil; placement MUST NOT `int()` that field
- `gear_board_text.gd` — slot / item labels, tooltip copy; option lists via `gear_board_opts.gd`
- `gear_board_stats.gd` — paged stats card copy via `gear_stat`
- `gear_board_act.gd` — drop / destroy / paging / enter / input; Forge Back routes to cancel / keep-old
- `gear_board_sub.gd` — re-equip and Anvil Analyze lists; Forge tab hands the body to `gear_board_anvil_forge.gd`
- `gear_board_anvil.gd` — Analyze apply; tab cycle
- `gear_board_anvil_view.gd` — Analyze / Forge tab chrome and short footer copy
- `gear_board_anvil_forge.gd` — Forge configurator, work bar, results pick-three
- Pause tab 1 (Inventory) and `progress_ui` loadout/inv/anvil all call `Board.build`
