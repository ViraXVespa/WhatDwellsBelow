# Shared gear board (door)

Status: current plan  
Read when: gear-board, doll slots, flyouts, Anvil card
Code: `scripts/ui/gear_board.gd`, `board_build.gd`, `floor.gd`, `tip.gd`, `board_text.gd`, `opts.gd`, `stats.gd`, `board_act.gd`, `board_sub.gd`, `anvil.gd`, `anvil_view.gd`, `anvil_forge.gd`, `gear_icons.gd`, `step_row.gd`, `scripts/ui/menu_pad.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/pause_inv/inv_view.gd`, `scripts/ui/progress_ui.gd`, `scripts/ui/progress_ui/ui_hub.gd`, `scripts/ui/progress_ui/inv.gd`  


Pause Inventory and Floor Crystal Loadout MUST reuse one paper-doll board. Placeholdia inventory (opened outside the dungeon) MUST use the same option sources and apply path as Loadout. Dungeon inventory MAY only swap the current slot with matching bag items. The Anvil reuses the same doll, flyout, stats card, and slot plates.

This file is the door. Open the Job-table sibling only when that row matches.

| Job | Open |
|-----|------|
| armor columns, plate icons, rarity wash, stepper neighbors | `design/gear-ui-board.md` |
| kit deltas, combat totals, hover highlight, Y preview | `design/gear-ui-stats.md` |
| re-equip lists, submenu chrome | `design/gear-ui-reequip.md` |
| Analyze Forge bumpers, verbs, deferred teardown, script map | `design/gear-ui-chrome.md` |
