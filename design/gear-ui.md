# Shared gear board (door)

Status: current plan  
Read when: gear-board, doll slots, flyouts, Anvil card
Code: `scripts/ui/gear_board.gd` (facade) + `scripts/ui/gear_board/`, `scripts/ui/gear_icons.gd` (code map row Gear UI; gdhealth group `gear_ui`). Hosts: `scripts/ui/progress_ui.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/pause_inv/inv_view.gd` (UI row)  

Reach-in rule: callers outside `gear_board/` use the facade only (build, refresh, tips, enter, close_sub, tick_x, input_tick, handle_event, swallowing, anvil_cycle_tab, forge_*). The board reaches its host through host methods (`place_gear_tip`, `inv_send_bag`, `inv_send_slot`, `inv_add_resource_row`, `inv_add_send_all`), never into `progress_ui/` helpers.

Pause Inventory and Floor Crystal Loadout MUST reuse one paper-doll board. Placeholdia inventory (opened outside the dungeon) MUST use the same option sources and apply path as Loadout. Dungeon inventory MAY only swap the current slot with matching bag items. The Anvil reuses the same doll, flyout, stats card, and slot plates.

This file is the door. Open the Job-table sibling only when that row matches.

| Job | Open |
|-----|------|
| armor columns, plate icons, rarity wash, stepper neighbors | `design/gear-ui-board.md` |
| kit deltas, combat totals, hover highlight, Y preview | `design/gear-ui-stats.md` |
| re-equip lists, submenu chrome | `design/gear-ui-reequip.md` |
| Analyze Forge bumpers, verbs, deferred teardown, background focus | `design/gear-ui-chrome.md` |
