# Unit: Ghost shop

Status: queued unit  
Read when: pawn counter, snack prices  

- Shot: flow `dungeon-gate-shop`, state shop (`python tools/shots.py flow --job ui.ghost_shop`).
- Icons: snack, artifacts, and pawn rows use the vendor shelf (light row, ink words, icon on the right). Rebuild with `python tools/media.py shop-icons`.
- Icon grid: `scripts/ui/item_board.gd` (icon + caption + tip + on_pick; a missing icon is an error). Icons: `scripts/ui/gear_icons.gd`.
- Surface sections and files: routes.yaml `unit_docs` and `unit_files` (the unit card prints them).
- Frame work follows the ui style doc.
