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
Replace the shared quest flow. Receptionist is the lore/tutorial system. Talk uses the lines listed below. Ask? is the complete How-to-Play guide with screenshots.

## Talk (lore)
- Options: Talk and Ask?.
- Lines change each time the delver re-enters Placeholdia.
- Seen-tracking: no repeat until the full set has been shown, then it may cycle again.

### Lines (verbatim)
- First time? I'm sure you'll figure things out, but I'm here if you need me.
- I tried dungeon delving once, but the transfer back was too much for me.
- We don't know much about the dungeon. The crystal just randomly appeared one day.
- I don't know how you guys handle experiencing death each run without going insane. It's really impressive!
- Some people say the dungeon is a trial sent to us by the gods, but that feels derivative to me.
- This dungeon is technically the property of the lord of this land, but they leave management to us at the Adventurer’s Guild.
- Me? I think the dungeon is some kind of alien artifact that uses the allure of treasure to entice people to enter, then harvests the emotional energy of the suffering of death to power their other technology.
- We don’t know how the extraction gates function. It doesn’t seem to use any kind of magic.
- The dungeon changes every time someone enters… It almost makes it feel like it’s alive.
- There is no “secret cow level”. That’s just a weird rumor. I’ve no idea how it started… Or what a 'level' is…
- Do you ever wonder why enemies drop coins? That's really weird, right? Like… Is their biology economy based or something? Hmm…

## Ask? (tutorial)
- Opens submenu “What would you like to know about?”.
- Selecting a topic opens a tutorial page for that system (forging, XP retention, extraction, skills, gear, combat, gathering, loadout, and the rest of the live systems).
- This is the entire How-to-Play guide.
- Modular data: id, title, body, screenshot id/path. New entries are a data addition.
- Static baked screenshots of the relevant UI (anvil, inventory, extract gate, skills page, etc.).
- Tooling to regenerate the baked screenshots when the underlying UI locations change. Easy refresh is required.

## Files
- scripts/ui/progress_ui/ui_hub.gd
- scripts/ui/progress_ui.gd
- scripts/world/interact/interact_act.gd
- new modular tutorial data + screenshot runner under tools/ or scripts/data/

## Art survey
- Dialog frame + portrait: now the same flat panel as the quest list. Art adds a speech frame and NPC bust. 9-slice 96x96 (24 px margins) transparent; portrait 256x256 transparent. High. Ref [camp-receptionist-menu_01-menu-open](../refs/ui-receptionist-tutorial/camp-receptionist-menu_01-menu-open.jpg). Ref shots: Bot survey of grok-build-w7 on 2026-10-11.
