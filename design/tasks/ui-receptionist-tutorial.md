# Receptionist lore and tutorial system

id: ui-receptionist-tutorial
title: Receptionist as lore/tutorial How-to-Play guide
owner: build
status: open
done-when: Talk cycles the receptionist-dialog lines with seen-tracking on Placeholdia re-entry; Ask? opens a modular How-to-Play covering all systems with static baked screenshots and regeneration tooling; Vira has seen the menu and at least two tutorial pages
area: ui
door: ui
job: receptionist
units: ui.receptionist
done:

Your first command, before any file read or memory topic: python tools/start_build_slice.py --door ui --job receptionist --from-task ui-receptionist-tutorial

## Intent
Replace the shared quest flow. Receptionist is the lore/tutorial system. Talk uses the exact lines from receptionist-dialog.md. Ask? is the complete How-to-Play guide with screenshots.

## Talk (lore)
- Options: Talk and Ask?.
- Talk cycles the lines from design/tasks/receptionist-dialog.md.
- Lines change each time the delver re-enters Placeholdia.
- Seen-tracking: no repeat until the full set has been shown, then it may cycle again.

## Ask? (tutorial)
- Opens submenu “What would you like to know about?”.
- Selecting a topic opens a tutorial page for that system (forging, XP retention, extraction, skills, gear, combat, gathering, loadout, and the rest of the live systems).
- This is the entire How-to-Play guide.
- Modular data: id, title, body, screenshot id/path. New entries are a data addition.
- Static baked screenshots of the relevant UI (anvil, inventory, extract gate, skills page, etc.).
- Tooling to regenerate the baked screenshots when the underlying UI locations change. Easy refresh is required.

## Supersedes
The old “just say Hi” ruling and the shared quest-board branch for the receptionist.

## Files
- scripts/ui/progress_ui/ui_hub.gd
- scripts/ui/progress_ui.gd
- scripts/world/interact/interact_act.gd
- new modular tutorial data + screenshot runner under tools/ or scripts/data/
