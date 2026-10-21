# Anvil tabs, slot actions, focus, live scripts

Status: current plan  
Read when: Analyze Forge bumpers, verbs, deferred teardown, script map  

## Anvil tabs

- Analyze / Forge tabs sit in the Anvil footer.
- The current tab is **highlighted**, not disabled. Match the pause tab: deeper paper and an ink underline (`anvil_view` paint-on).
- LB / RB (and the on-screen tab glyphs) cycle Analyze ↔ Forge.
- Switching tabs rebuilds the board and clears the forge draft (type, rarity, level, locks, pending roll, in-flight job). It does not call a missing helper to do that rebuild — the host `_rebuild_anvil` + `_show` path is the refresh.
- `ui.tab` may be a string (`analyze` / `forge`) on Anvil; `tip.gd` placement MUST NOT `int()` that field.

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
