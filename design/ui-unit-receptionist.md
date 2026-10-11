# Unit: Guild receptionist

Status: queued unit  
Read when: talk cycle, ask topics  

- Shot: flow `camp-receptionist-menu`, state menu-open (`python tools/run_shot_flow.py --job ui.receptionist`).
- Task: task `ui-receptionist-tutorial` (Talk + Ask?). It supersedes the old "just say Hi" ruling.
- Own entry: `open_receptionist()` / mode `receptionist` / `ui_hub.rebuild_receptionist` (today it still shows the quest list; replace that body).
- Talk: `scripts/data/talk_lines.gd` (lines by NPC id in `LINES`, en.po keys `talk.receptionist.NN`, seen tracking and hub-entry advance done, saved as `talk`).
- Ask? screenshots: `tools/tutorial_shots.json` names the flow frame per topic; `tutorial_shots.py --run` stages them for `assets/ui/tutorial/`.
- Surface sections and files: routes.yaml `unit_docs` and `unit_files` (the unit card prints them).
- Frame work follows the ui style doc.
