# Unit: Ghost shop

Status: queued unit  
Read when: pawn counter, snack prices  

- Shot: flow `dungeon-gate-shop`, state shop (`python tools/run_shot_flow.py --job ui.ghost_shop`).
- Task: task `ui-ghost-shop-icons`. It matches the vendor consumable board, so `inventory-consumables` lands first.
- Icon grid: `scripts/ui/item_board.gd` (icon + caption + tip + on_pick; a missing icon is an error). Icons: `scripts/ui/gear_icons.gd`.
- Surface sections and files: routes.yaml `unit_docs` and `unit_files` (the unit card prints them).
- Frame work follows the ui style doc.
