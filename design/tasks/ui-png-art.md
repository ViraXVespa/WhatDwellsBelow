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

Follow the start-card ORDER. The session `slice.py open` started gathers the shared context (this task, `ui-style.md`, `ui-ux-audit.md`) and `/fork`s. It does not shoot or open pictures. `/fork` does not finish gather. The peer that builds a unit gathers only that unit's frames with `shots.py review` (text only; do not `read_file` a PNG or JPG) and gathers earlier sessions' committed and uncommitted changes with `python tools/find.py changed`. A later fork does the same.
Shot review: `grok-build.md` Pictures rule (`shots.py review` for the text, `shots.py show` when she should see the image).
Unit 1, mockups: edit the live shot of each major screen (title, loadout, vendor, ghost shop, death recap, receptionist, crystal/teleport, HUD, camp HUD bar, extract/gate). The pause menu is not a mockup. It stays as it is. A shell is the frame, the panel material, and the empty interior. No buttons, slots, lists, icons, prompts, or words. Code draws those later. The title background and journal UI are style references only, not edit sources. A world prop may be a second reference so the object survives. Call: `python tools/media.py grok --kind ui --edit --copy <live shot> --dest-name mockups/<screen>.png --out design/refs/ui-png-art --brief "..."` (lands in `design/refs/ui-png-art/mockups/`). Do not pass `--aspect` on an edit. Without `--edit`, one `--copy` plus `--aspect` redraws a new picture and treats the copy as a loose reference. The closer plates are the title and loadout edits below. Other screens wait. Later units build to the edited plates.
Unit 2 works the crystal UI only. Deliver before/after shots and inform that the unit is done.
Finish the task in one session when it fits; unfinished work keeps its notes in this task. Vira says when a new session is needed.

## Style
Locked look: `design/ui-style.md` Generated art look (read first every session; `--kind ui` stages it). 9-slice rules as listed per row. Load `imagine-isolated` before any image generation.

Her note, 2026-10-27, revised the same day: mockups are shell studies. Preserving the controls was crowding the art. Do not paint controls into a mockup. No buttons, slots, lists, icons, prompts, or words. The picture is the frame, the panel material, and the empty interior where the menu will sit. Code draws the controls later. The pause menu stays as it is. A menu that comes from a world sprite takes that sprite, or its `_src` source, as a `--copy` reference so the prop and its base survive. That sprite is a detail reference. The result is the empty shell. Do not run a second `shots.py review` on a still the generator already returned. Prove sheets scale the larger frame down to the smaller one (`tools/lib/imglib/compare.py` `compose_group` fits every frame to the smallest one).

## Handoff (2026-10-27, mockups unit)

Vira: the `--edit` results are much closer to what she wants. Work from these. They still need fine tuning. Do not go back to `image_gen` redraws.

Next session, first, before any new image:
1. Expand the Generated art look lines in `design/ui-style.md`. That section is the only style text `--kind ui` stages, and the four lines are not enough for the finish. She corrects the words before another image.
2. Add any other routes or configurations the fine tuning needs on `media.py grok` (`tools/lib/media/run_isolated_grok.py`, catalog row in `design/tools-media.md`). The call that worked is `--kind ui --edit --copy <live shot>` with no `--aspect`.

Closer plates (edit of the live shot, controls cleared, layout kept):
- Title: `design/refs/ui-png-art/mockups/title-edit.png` from `design/refs/ui-png-art/title-menu_01-title-card.jpg`. Sheet: `_logs/prove-view/ui-png-art-edits/01-title.png`.
- Loadout: `design/refs/ui-png-art/mockups/loadout-edit.png` from `design/refs/ui-png-art/camp-npc-panels_04-loadout.jpg`. Sheet: `_logs/prove-view/ui-png-art-edits/02-crystal.png`.

Not the target:
- `mockups/title-shell.png` and `mockups/loadout-shell.png` are redraws. The job had been told to `image_gen`.
- `mockups/title-text.png` (same picture as `mockups/title.png`) is the earlier filled title. `mockups/loadout.png` is the earlier filled crystal.
- Logo, not placed: `mockups/logo.png`.
- Pause: `mockups/pause-inventory.png` is discarded. Do not redesign the pause menu.

Resume command, from this worktree: `grok -r 01a17fde-814d-7873-a7b8-3b881ebc4b1a --fork-session`.

## Items

 (element: now -> art; spec; priority)
- Receptionist portrait in the receptionist UI: currently a placeholder/drawing. Replace with the live receptionist character art (`assets/sprites/npcs/receptionist.png`, the bust source in `hub-guild.md`) so the UI portrait updates automatically when the character art changes. High.
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

## UX audit
2026-10-20 gamepad-first audit of every shot menu: 31 issues (H 5, M 17, L 9), one line each with a ref link, tagged [art] (the items above cover it) or [ux] (layout work): [ui-ux-audit.md](../ui-ux-audit.md).

## Small screens
Phone 844x390 @3 (`shots.py textsize --gate`, 10 CSS px minimum). New art and layouts must allow 10 CSS px text there.
- Controls billboard: its 14 rows do not fit at a readable size; needs two columns or a taller board.
- Fixed-art boards cap their text (frame skin `TEXT_CAP`): quest board 7.2 px, vendor 9.0, dumpster 9.8, anvil 9.4 (CSS px, smallest on the board). Vendor rows overlap the red jar.
- In-play HUD art (minimap bezel, camp HUD bar) also meets the gate's `cover` cap (`tools/data/text-size.json`: dungeon 0.111, camp 0.073 of the frame).
- Portrait phones: decide whether to support them (today a rotate-to-landscape screen).
- Allowances to remove from `tools/data/text-size.json` `allow` when the art lands: `^camp-npc-panels/(vendor|quest-board|dumpster)$` 7, `^camp-billboard-controls/` 7, `^camp-(anvil-tabs|gear-popups)/(tab|anvil-)` 9.
