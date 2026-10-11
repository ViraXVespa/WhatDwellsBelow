# Ghost shop item icons

id: ui-ghost-shop-icons
title: Ghost shop icons matching consumable board
owner: build
status: open
done-when: artifacts, pawn list and snacks use icons in the same visual language as the vendor consumable board; Vira has seen the shop
area: ui
door: ui
job: ghost_shop
units: ui.ghost_shop
done:

Your first command, before any file read or memory topic: python tools/start_build_slice.py --door ui --job ghost_shop --from-task ui-ghost-shop-icons

## Intent
Icons for artifacts, the pawn list, and snacks. Same visual treatment as the lighter consumable board used by the vendor.

## Files
- scripts/ui/progress_ui/shop.gd: rebuild_shop
- gear_icons.gd or equivalent icon path
