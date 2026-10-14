# Unit: Death recap

Status: queued unit  
Read when: tally sequence, finale bars  

- Shot: flow `camp-recap`, state recap (`python tools/run_shot_flow.py --job ui.recap`).
- Task: task `ui-recap-skills-style`. The mandatory sequence lives in the run-flow doc (Recap screen section, see `unit_docs`).
- Style source: the pause Skills tab (`scripts/ui/pause_skills.gd`, `scripts/ui/pause_menu/journal_page.gd`); `scripts/ui/journal_spread.gd` puts the same spread on another host. Skill tips already use `scripts/ui/tip_hover.gd`.
- Surface sections and files: routes.yaml `unit_docs` and `unit_files` (the unit card prints them).
- Frame work follows the ui style doc.
