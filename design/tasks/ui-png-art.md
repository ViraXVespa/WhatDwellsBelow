# Generated PNG art for flat code-drawn UI

id: ui-png-art
owner: build
status: open
done-when: all in-game menu locations feel polished, complete, and professional.
resume: python tools/open_slice.py ui.style --task ui-png-art

## Source
Bot screenshot survey of grok-build-w7 on 2026-10-11, judging where code-drawn UI looks flat. Not user requests, except the crystal background (hers). Overlapping items went to ui-quest-board-posters, ui-receptionist-tutorial, ui-recap-skills-style, inventory-consumables, metal-hud-mana.

## Intent
The goal of this task is to update all of the menus to be high-quality, professional feeling UIs instead of the current amateur/placeholder feels of many UI locations. This will likely be accomplished by generating high-quality assets from which to compose the menus rather than the comparatively limited programmatically created UIs we're currently using. The existing UIs should be considered layout/style baselines to be improved upon by this task. The areas listed in this task should not be considered to be an exhaustive or up-to-date list of areas that require a rework. It's just a list of starting areas that have been collected to give an outline of the kinds of areas that need to be addressed to reach the professional look we're going for. Final results should have all relevant interactable areas of the UI displayed entirely within their menus (where possible) and should be free of any stretched textures, repeating seams, and disjointed layouts.

## Items (element: now -> art; spec; priority)
- Crystal background, floor + loadout crystal, shared by the teleport network (her request): flat pale-cyan fill inside the baked frame -> a proper crystal-interior graphic; panel-size opaque or 9-slice 128. High. Frame studs stay with crystal-frame-pink (blocked on rekey-assets); pick colours that fit the rekeyed gem, and do not touch the studs here. Refs [camp-npc-panels_04-loadout](../refs/ui-png-art/camp-npc-panels_04-loadout.jpg), [dungeon-map-crystal_02-crystal-root](../refs/ui-png-art/dungeon-map-crystal_02-crystal-root.jpg).
- Crystal buttons + floor -/+ stepper: flat teal bars, tiny squares -> crystal-cut button 9-slice 96x32 x2 states, arrows 32x32. Med. Same refs.
- Slot tiles (inventory, anvil, crystal loadout, extract): outlined boxes, the empty bag reads like a spreadsheet -> one inset socket 9-slice 64x64 (normal/selected/empty), tinted per screen. High. Refs [camp-pause-pages_10-pause-inventory](../refs/ui-png-art/camp-pause-pages_10-pause-inventory.jpg), [camp-anvil-tabs_01-tab](../refs/ui-png-art/camp-anvil-tabs_01-tab.jpg), [dungeon-gate-shop_01-extract](../refs/ui-png-art/dungeon-gate-shop_01-extract.jpg).
- Title: text title, flat dark box, outlined buttons -> logo ~900x200 transparent, panel 9-slice 128, button 9-slice 96x32 x3 states. High. Ref [title-menu_01-title-card](../refs/ui-png-art/title-menu_01-title-card.jpg).
- Loading screen: beige box, two-tone bar -> plaque 9-slice 128, bar trough + fill 9-slice 64x16. High. Ref [camp-overlays_01-loader](../refs/ui-png-art/camp-overlays_01-loader.jpg).
- Pause book tabs, list buttons, checkboxes: flat beige boxes -> bookmark tab 9-slice 96x40 x2, checkbox 24x24 on/off. Med. Ref [camp-pause-pages_01-settings-gameplay](../refs/ui-png-art/camp-pause-pages_01-settings-gameplay.jpg).
- Large map frame: borderless black square -> bezel 9-slice 128. Med. Ref [dungeon-map-crystal_01-large-map](../refs/ui-png-art/dungeon-map-crystal_01-large-map.jpg).
- Minimap bezel: plain brown border -> 9-slice 128. Med. Ref [dungeon-hud-states_01-hud-default](../refs/ui-png-art/dungeon-hud-states_01-hud-default.jpg).
- "Bonuses from this kit" panel: dark flat box -> inset plaque 9-slice 96. Low.
- Controls sign: flat black fill, plain Leave -> chalkboard 512x512 tileable, chalk button 9-slice. Low. Ref [camp-billboard-controls_01-controls](../refs/ui-png-art/camp-billboard-controls_01-controls.jpg).
- Tooltips: dark box, 1 px outline -> inked frame with tail 9-slice 48. Low. Ref [camp-gear-popups_01-loadout-tip](../refs/ui-png-art/camp-gear-popups_01-loadout-tip.jpg).
- World labels (VENDOR, ENTRANCE CRYSTAL): bare outlined text -> small banner 9-slice 96x32. Low.

## Keep code
Settings and rebind rows, XP rows, stat lists, resource chips, toasts. Gear icons and pad glyphs are already PNG.

## Not shot
Journal page, gear board, teleport network list, fs_gate (no flows).
