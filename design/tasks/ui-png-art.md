# Generated PNG art for flat code-drawn UI

id: ui-png-art
owner: build
status: open
done-when: high rows have art in game, med/low rows done or dropped by Vira; Vira has seen before/after shots
resume: Read design/tasks/ui-png-art.md and start with the High rows (crystal background first)

## Source
Bot screenshot survey of grok-build-w7 on 2026-10-11, judging where code-drawn UI looks flat. Not user requests, except the crystal background (hers). Ref shots are not committed (box: /workspace/png-survey/shots). Overlapping items went to ui-quest-board-posters, ui-receptionist-tutorial, ui-recap-skills-style, inventory-consumables, metal-hud-mana.

## Items (element: now -> art; spec; priority)
- Crystal background, floor + loadout crystal, shared by the teleport network (her request): flat pale-cyan fill inside the baked frame -> a proper crystal-interior graphic; panel-size opaque or 9-slice 128. High. Frame studs stay with crystal-frame-pink (blocked on rekey-assets); pick colours that fit the rekeyed gem, and do not touch the studs here. Refs camp-npc-panels_04-loadout.png, dungeon-map-crystal_02-crystal-root.png.
- Crystal buttons + floor -/+ stepper: flat teal bars, tiny squares -> crystal-cut button 9-slice 96x32 x2 states, arrows 32x32. Med. Same refs.
- Slot tiles (inventory, anvil, crystal loadout, extract): outlined boxes, the empty bag reads like a spreadsheet -> one inset socket 9-slice 64x64 (normal/selected/empty), tinted per screen. High. Refs camp-pause-pages_10-pause-inventory.png, camp-anvil-tabs_01-tab.png, dungeon-gate-shop_01-extract.png.
- Title: text title, flat dark box, outlined buttons -> logo ~900x200 transparent, panel 9-slice 128, button 9-slice 96x32 x3 states. High. Ref title-menu_01-title-card.png.
- Loading screen: beige box, two-tone bar -> plaque 9-slice 128, bar trough + fill 9-slice 64x16. High. Ref camp-overlays_01-loader.png.
- Pause book tabs, list buttons, checkboxes: flat beige boxes -> bookmark tab 9-slice 96x40 x2, checkbox 24x24 on/off. Med. Ref camp-pause-pages_01-settings-gameplay.png.
- Large map frame: borderless black square -> bezel 9-slice 128. Med. Ref dungeon-map-crystal_01-large-map.png.
- Minimap bezel: plain brown border -> 9-slice 128. Med. Ref dungeon-hud-states_01-hud-default.png.
- "Bonuses from this kit" panel: dark flat box -> inset plaque 9-slice 96. Low.
- Controls sign: flat black fill, plain Leave -> chalkboard 512x512 tileable, chalk button 9-slice. Low. Ref camp-billboard-controls_01-controls.png.
- Tooltips: dark box, 1 px outline -> inked frame with tail 9-slice 48. Low. Ref camp-gear-popups_01-loadout-tip.png.
- World labels (VENDOR, ENTRANCE CRYSTAL): bare outlined text -> small banner 9-slice 96x32. Low.

## Keep code
Settings and rebind rows, XP rows, stat lists, resource chips, toasts. Gear icons and pad glyphs are already PNG.

## Not shot
Journal page, gear board, teleport network list, fs_gate (no flows).
