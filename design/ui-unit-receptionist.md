# Unit: Guild receptionist

Status: queued unit  
Read when: talk cycle, ask topics  

- Shot: flow `camp-receptionist-menu`, state menu-open (`python tools/shots.py flow --job ui.receptionist`).
- Task: task `ui-receptionist-tutorial` (Talk + Ask?). It supersedes the old "just say Hi" ruling.
- Own entry: `open_receptionist()` / mode `receptionist` (Talk and Ask?) and mode `guide` (one How-to-Play page). Body: `scripts/ui/progress_ui/receptionist.gd`.
- Talk: `scripts/data/talk_lines.gd`. `talk.receptionist.01` is the once-only first line. `02`–`11` rotate on hub entry. Saved as `talk`.
- Ask?: `scripts/data/tutorial_pages.gd`. `tools/data/tutorial_shots.json` names the flow frame per topic; `shots.py tutorial --run` stages them for `assets/ui/tutorial/`.
- Surface sections and files: routes.yaml `unit_docs` and `unit_files` (the unit card prints them).
- Frame work follows the ui style doc.
