# Unit: Quest notice board

Status: queued unit  
Read when: pinned parchment, offer cutouts  

- Shot: flow `camp-npc-panels`, state quest-board (`python tools/run_shot_flow.py --job ui.quest_board`).
- Her ruling: "notice board should show quest posters instead of buttons."
- Task: task `ui-quest-board-posters` (posters, tips on focus, refresh rules, the pause Quest tab).
- Quest tab: one row in `pause_menu.gd` `TABS` (id, label, builder); flows name tabs by id (`camp-pause-pages` shoots the pause tabs), and the new `pause:quest` state needs a flow shot. Poster tips: `scripts/ui/tip_hover.gd`. A two-sheet layout: `scripts/ui/journal_spread.gd`.
- The receptionist has its own entry now; edits here do not change her menu.
- Surface sections and files: routes.yaml `unit_docs` and `unit_files` (the unit card prints them).
- Frame work follows the ui style doc.
- Poster art is PNG: `assets/ui/posters/board.png`, `poster.png`, `pin.png` (`progress_ui/poster_art.gd` `REQUIRED`; missing = error). Drawn from the request-board reference, not a copy of it. Text is drawn in code on the poster.
