# Placeholdia Hub Summary

Status: binding design  
Read when: Placeholdia, camp benches
Code: `scripts/world/camp.gd` (facade), `scripts/world/camp_warm.gd` (Title → Play GPU frame), `scripts/world/camp_build.gd` (ground, guild), `scripts/world/camp_build_mesh.gd` (roofs, tarp, awning), `scripts/world/camp_build_roof.gd`, `scripts/world/camp_view.gd` (fence), `scripts/world/camera_rig.gd`, `scripts/world/interact.gd`, `scripts/world/interact_fx.gd`, `scripts/combat/dummy.gd`, `scripts/app_flow.gd`, `scripts/ui/loader.gd`, `scenes/camp.tscn`  


## Required Interactables
- Floor Crystal (opens loadout / enter-dungeon UI)
- Anvil
- Vendor Stall
- Dumpster
- Guild Signs / Notice Board
- Receptionist area / Guild (quest access)
- Controls Billboard
- “Welcome to Placeholdia!” banner
- Test dummy (coverage / weapon sandbox)

All buildings must have realistic 3D dimensions (not flat 2D sprites) for solidity under the orthographic Camera3D.

This file is the door. Open the Job-table sibling only when that row matches.

| Job | Open |
|-----|------|
| consciousness-transfer VFX, Dispel wake-up, deepest row | `design/hub-crystal.md` |
| ore-for-gold stall, dumpster flavor, plaza_tarp host | `design/hub-benches.md` |
| receptionist bust, notice errands, welcome cloth | `design/hub-guild.md` |
| striking dummy, Label3D priorities, post-rail fence, hopeful ambience, warmup overlay | `design/hub-yard.md` |
