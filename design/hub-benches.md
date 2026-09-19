# Hub — Anvil, vendor, dumpster

Status: binding design  
Read when: ore-for-gold stall, dumpster flavor, plaza_tarp host


## Anvil
- Shared gear board with **Analyze** and **Forge** tabs. Current tab is highlighted like Pause tabs, not disabled.
- Potion and Food slots are disabled on this board.
- Footer is short: bank + carried gold / ore / wood, plus one status line. Analyze does not list holds. Forge does not list every remnant.
- Submenus keep the parent control strip and draw their own strip. No Back button. Binding UI: gear_ui. Binding item / roll rules: inventory → inventory.gear.

Live camp position: down and left of the vendor stall’s southwest corner (`21.2, 0, 11.4`).

Live scripts: board `scripts/ui/gear_board/gear_board.gd` in `gear_mode="anvil"`; tabs `gear_board_anvil.gd` + `gear_board_anvil_view.gd`; forge body `gear_board_anvil_forge.gd`; ledger `scripts/data/progress_forge.gd` + `affixes.gd` + `gear_roll.gd`. `progress_town.gd` still owns extract / quests / analyze-destroy wrapper.

## Vendor Stall
- Buys ore for gold.
- Sells basic food and potions.
- 3D stall box with `stall.png` south face and a `plaza_tarp` top plane (one canvas sheet; guild roofs stay `plaza_roof`).

## Dumpster
- Flavor object only. No interaction or gameplay effect.
