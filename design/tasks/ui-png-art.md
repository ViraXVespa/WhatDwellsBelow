# Generated PNG art for flat code-drawn UI

id: ui-png-art
owner: build
status: open
done-when: all in-game menu locations feel polished, complete, unified, and professional.
resume: python tools/slice.py open ui.style --task ui-png-art
units: mockups, crystal
done: none

## Source
Bot screenshot survey of grok-build-w7 on 2026-10-11, judging where code-drawn UI looks flat. Not user requests, except the crystal background (hers).

## Intent
The goal of this task is to update all of the menus to be high-quality, professional feeling UIs instead of the current amateur/placeholder feels of many UI locations. This will likely be accomplished by generating high-quality assets from which to compose the menus rather than the comparatively limited programmatically created UIs we're currently using. The existing UIs should be considered layout/style baselines to be improved upon by this task. The areas listed in this task should not be considered to be an exhaustive or up-to-date list of areas that require a rework. It's just a list of starting areas that have been collected to give an outline of the kinds of areas that need to be addressed to reach the professional look we're going for. Final results should have all relevant interactable areas of the UI displayed entirely within their menus (where possible) and should be free of any stretched textures, repeating seams, and disjointed layouts. All UI locations outside of the pause journal should maintain the pixel art style of the game and should feel like a unified system. The current implementation uses a variety of different styles and appearances with differing levels of polish and quality.

## Process / Review

Follow the start-card ORDER: baseline shot + restate before any generation or edit.
Shot review: `grok-build.md` Pictures rule (`shots.py review` when text is enough, `shots.py show` when you need the image).
Unit 1, mockups: one 16:9 starting mockup per major screen (title, pause inventory, loadout, vendor, ghost shop, death recap, receptionist, crystal/teleport, journal pages, HUD, camp HUD bar, extract/gate). The title background and journal UI are style references only, not edit sources. Layout and content come from the current shots and `ui-ux-audit.md`. Talk screens use new NPC bust views; the receptionist uses her new design. Show the first three for approval, then do the rest. Generate each with `python tools/media.py grok --kind ui --aspect 16:9 --dest-name mockups/<screen>.png --out design/refs/ui-png-art --brief "..."` (lands in `design/refs/ui-png-art/mockups/`); later units build to them.
Unit 2 works the crystal UI only. Deliver before/after shots and inform that the unit is done.
Finish the task in one session when it fits; unfinished work keeps its notes in this task. Vira says when a new session is needed.

## Style
Locked look: `design/ui-style.md` Generated art look (read first every session; `--kind ui` stages it). 9-slice rules as listed per row. Load `imagine-isolated` before any image generation.

## Items

 (element: now -> art; spec; priority)
- Receptionist portrait in the receptionist UI: currently a placeholder/drawing. Replace with the live receptionist character art (assets/sprites/npcs/receptionist.png or the current bust source) so the UI portrait updates automatically when the character art changes. Uses her new design (young goth/metal guild clerk, `hub-guild.md`). High.
- Talk UIs (receptionist, vendor, ghost shop): may use new generated portrait or bust views drawn from the NPC's sprite art, not only the in-game sprite.
- Crystal background, floor + loadout crystal, shared by the teleport network (her request): code-baked frame with a flat pale-cyan fill -> a NEW generated crystal frame plus crystal-interior graphic, replacing the baked crystal frame (9-slice 128; interior panel-size opaque or 9-slice 128). The pink studs go away with the old frame. Once the new art is wired in, delete the old `assets/ui/frames/crystal/` PNGs and their drawing code (`crystal_art.gd`, the crystal part of `tools/bake.py frames`) after `rg` shows nothing else uses them. High. Refs [camp-npc-panels_04-loadout](../refs/ui-png-art/camp-npc-panels_04-loadout.jpg), [dungeon-map-crystal_02-crystal-root](../refs/ui-png-art/dungeon-map-crystal_02-crystal-root.jpg).
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
- Camp HUD bar: flat dark strip of plain text (bank, verbs, talk hint) -> framed plaque 9-slice 96 with resource chips. Med. Ref [camp-hud-bar](../refs/ui-png-art/camp-hud-bar.jpg).
- World labels (VENDOR, ENTRANCE CRYSTAL): bare outlined text -> small banner 9-slice 96x32. Low.

## Keep code
Settings and rebind rows, XP rows, stat lists, resource chips, toasts. Gear icons and pad glyphs are already PNG.

## Not shot
None. Gear board: `camp-gear-board` plus the inventory, anvil and popup flows. Journal pages, the teleport network and fs_gate are now shot (`camp-receptionist-menu`, `dungeon-map-crystal`, `fs-gate`).

## UX audit
2026-10-20 gamepad-first audit of every shot menu: 31 issues (H 5, M 17, L 9), one line each with a ref link, tagged [art] (the items above cover it) or [ux] (layout work): [ui-ux-audit.md](../ui-ux-audit.md).

## Small screens
Phone 844x390 @3 (`shots.py textsize --gate`, 10 CSS px minimum). New art and layouts must allow 10 CSS px text there. No decisions made here.
- Controls billboard: its 14 rows do not fit at a readable size; needs two columns or a taller board.
- Fixed-art boards cap their text (frame skin `TEXT_CAP`): quest board 7.2 px, vendor 9.0, dumpster 9.8, anvil 9.4 (CSS px, smallest on the board). Vendor rows overlap the red jar.
- Portrait phones: decide whether to support them (today a rotate-to-landscape screen).
- Allowances to remove from `tools/data/text-size.json` `allow` when the art lands: `^camp-npc-panels/(vendor|quest-board|dumpster)$` 7, `^camp-billboard-controls/` 7, `^camp-(anvil-tabs|gear-popups)/(tab|anvil-)` 9.
