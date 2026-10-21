# UI UX audit (ui-png-art)

Status: record
Read when: working the ui-png-art task or any menu layout, focus or prompt change

## 2026-10-20, grok-build-w8 shots
Gamepad-first check of the shot flows. H/M/L severity; [art] = the PNG items above cover it, [ux] = layout/UX work. Refs live in `refs/ui-png-art/`.
- All: H text floor is 14 px (flows assert `min_font` 14); most copy is 14-18 px at 1080p, under the ~24 px couch norm and smaller on web. [ux]
- All: H focus is pink on the crystal, extract and gate (slot outline, button underline) but gold on the title (FIXED: crystal skin glow token now gold; crystal_art studs stay with the art task); one focus style, no pink. [art+ux]
- All: M prompt bars sit inside the panel, under it as unlabelled icons, or in the screen corner (crystal); one place, always labelled. [ux]
- All: M FIXED pickers open beside their slot, clamped on-screen (loadout, anvil, inventory; gate confirm is a centred modal). [ux]
- All: M fit content without scrolling where possible (size panels, columns/grids, or tabs/pages); scroll cues are the fallback for truly variable-length lists. [art][ux]
- All: M six panel looks (parchment, book, crystal, teal gate, blue shop, green journal). [art]
- All: M fixed-width tabs and buttons barely fit English (vendor header FIXED: shrinks to fit); no localization headroom. [ux]
- [Pause](refs/ui-png-art/camp-pause-pages_01-settings-gameplay.jpg): M right page 80-90% empty; Patreon, Main Menu and Quit show one line, no button. [ux]
- Pause: M sliders show no value (volumes, zoom, HUD scale, aim opacity). [ux]
- [Pause controls](refs/ui-png-art/camp-pause-pages_04-settings-controls.jpg): M FIXED scroll cue (list still cut at Food);  empty second binding is a bare dash. [ux]
- [Pause skills](refs/ui-png-art/camp-pause-pages_09-pause-skills.jpg): M twelve identical dense rows with full-width bars; hard to scan. [ux]
- [Pause quest](refs/ui-png-art/camp-pause-pages_12-pause-quest.jpg): L one card on an empty page; no empty-state text. [ux]
- Pause: L category focus is a small ">" and a slightly darker row. [art]
- [Inventory](refs/ui-png-art/camp-pause-pages_10-pause-inventory.jpg): M 28 identical empty bag cells read as a spreadsheet. [art]
- Inventory: L bonus values are right-aligned in pause, inline in camp and anvil. [ux]
- [Anvil](refs/ui-png-art/camp-anvil-tabs_01-tab.jpg): L FIXED slot tooltip covered the "Bonuses from this kit" header (now above the slot). [ux]
- [Vendor](refs/ui-png-art/camp-npc-panels_01-vendor.jpg): H hanging decor covers the header and blurb; the 4th row is cut (FIXED: scroll cue). [art+ux]
- Vendor, quest board, dumpster: M prompts are unlabelled icons under the panel. [ux]
- [Receptionist](refs/ui-png-art/camp-receptionist-menu_01-menu-open.jpg): M menu fills the top 15% of an empty panel; FIXED camp HUD bar hidden while camp menus are open. [ux]
- [Journal pages](refs/ui-png-art/camp-receptionist-menu_04-page-forging.jpg): M own frame (green, lined, bookmark over the edge); tiny screenshot and text. [art+ux]
- [Teleport local](refs/ui-png-art/dungeon-map-crystal_03-crystal-local.jpg): M black map void, tiny map, no legend. [ux]
- [Teleport floors](refs/ui-png-art/dungeon-map-crystal_04-crystal-floors.jpg): L disabled row only lighter. [art]
- [Extract](refs/ui-png-art/dungeon-gate-shop_01-extract.jpg): M bag row cut at the panel bottom (FIXED: scroll cue). [ux]
- [Gate dialog](refs/ui-png-art/dungeon-gate-popups_02-gate-pick.jpg): L confirm is a centred modal over the panel (not a slot picker; kept). [ux]
- [Ghost shop](refs/ui-png-art/dungeon-gate-shop_02-shop.jpg): H FIXED gold focus ring on rows (4 px, glow); scroll cue for the clipped Leave row. [ux]
- [Recap](refs/ui-png-art/camp-recap_01-recap.jpg): H XP lists run under the Continue bar; footer text overlaps it; Continue shown twice (FIXED: the A glyph sits on the Continue button; no separate chip). [ux]
- [Camp HUD bar](refs/ui-png-art/camp-hud-bar.jpg): M flat dark strip of small plain text; no art, verbs read as a run-on line. [art+ux]
- [HUD](refs/ui-png-art/dungeon-hud-states_01-hud-default.jpg): M tiny labels on a busy dashed frame; toast is bare small yellow text. [art+ux]
- [Large map](refs/ui-png-art/dungeon-map-crystal_01-large-map.jpg): M off-centre black square, no frame or legend. [art+ux]
- [Holds](refs/ui-png-art/camp-overlays_02-wake-hold.jpg): L flat full-screen beige or cyan fill with outlined text. [art]
- [Archives](refs/ui-png-art/camp-overlays_04-archives.jpg): L FIXED scroll cue on the cut list; disabled buttons nearly invisible (FIXED: title skin off face/edge/word raised). [ux]
- [Controls sign](refs/ui-png-art/camp-billboard-controls_01-controls.jpg): L FIXED glyphs share one column width, so "Dash" lines up. [ux]
- [Updates](refs/ui-png-art/title-menu_02-title-updates.jpg): M FIXED agent notes moved under `## Agent` in the changelog files; agent-only releases dropped; 0.7.2 bullets reworded for players. [ux]
- Gear board: covered by `camp-inventory`, `camp-pause-inventory`, `camp-anvil-tabs`, `camp-gear-popups` (board, slot focus, tips, pickers); `camp-gear-board` adds the stocked kit and the stats pages, which starter-kit shots never show.
- [Gear board stocked](refs/ui-png-art/camp-gear-board_01-board.jpg): M rarity reads only as a thin coloured edge; the red edge on helm and bag body looks like an error state. [art+ux]
- Gear board stats pages: L "All combat stats" lists every stat with "—" for none; "Artifact sets" is one line on an empty card. [ux]
- Gear board: L while paging the stats card (RT) the weapon slot keeps its gold focus; nothing marks the card as the active part. [ux]
