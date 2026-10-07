# Unit: Floor-crystal loadout

Status: queued unit  
Read when: enter-dungeon footer, weapon tool choice  

- Shot: flow `camp-npc-panels`, state loadout (`python tools/run_shot_flow.py --job ui.loadout`).
- Ruling: a drawn crystal front from the hub prop `assets/sprites/props/crystal.png` (cyan gem on a dark stone pedestal, pink stones at the front corners). The world sprite stays the prop. The gear board stays.
- Surface sections and files: routes.yaml `unit_docs` and `unit_files` (the unit card prints them).
- Frame work follows the ui style doc.
