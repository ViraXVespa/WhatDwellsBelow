# Quest notice board posters and Quest tab

id: ui-quest-board-posters
title: Quest board posters plus pause Quest tab
owner: build
status: open
done-when: board shows flavor posters plus three selectable quest posters; selection moves the poster into the new Quest tab (between Inventory and Skills) with poster on one side and info/cancel on the other; refresh rules match the rulings; Vira has seen the board and the tab
resume: python tools/open_slice.py ui.quest_board --task ui-quest-board-posters
door: ui
job: quest_board
units: ui.quest_board

## Intent
Posters instead of buttons. Reference: design/refs/ui-quest-board-posters/quest-board.jpg

## Board
- Variety of small non-selectable flavor posters (decoration).
- Exactly three selectable posters for the current quest offers.
- Selectable posters show a quick visual cue for quest kind.
- Title, reward, progress appear in a tooltip on highlight/focus.

## Selection and Quest tab
- Selecting a quest removes that poster from the board.
- It appears in a new Quest tab in the pause menu, between Inventory and Skills.
- Tab layout: poster on one side, info/options (progress, details, cancel) on the other.

## Refresh
- After complete or cancel: three new options if the player has entered the dungeon since accepting.
- If cancelled before entering the dungeon: the same three options reappear.

## Files
- scripts/ui/progress_ui/ui_hub.gd: rebuild_quest
- scripts/ui/progress_ui.gd: open_quest
- scripts/data/progress_quest/quest_roll.gd
- pause menu Quest tab

## Art survey
- Board backdrop, poster sheet, pin: now a flat cream panel with brown bars. Art gives the intended look (poster_art.gd REQUIRED). Board ~1200x700 opaque; poster ~320x420 transparent, text drawn on; pin 32x32. High. Ref [camp-npc-panels_02-quest-board](../refs/ui-quest-board-posters/camp-npc-panels_02-quest-board.jpg). Ref shots: Bot survey of grok-build-w7 on 2026-10-11.
