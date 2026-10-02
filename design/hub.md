# Placeholdia Hub Summary

Status: binding design  
Read when: Placeholdia, camp benches
Code: `scripts/world/camp.gd` (facade, `@tool` preview), `scripts/world/camp/layout.gd` (script-default pose / eave / UV; scene exports override), `scripts/world/camp/warm.gd` (Title → Play GPU frame), `scripts/world/camp_build.gd` (ground, guild, realize), `scripts/world/camp_build/mesh.gd` (roofs, tarp, awning), `scripts/world/camp_build/roof.gd`, `scripts/world/camp/camp_view.gd` (fence), `scripts/world/camera_rig.gd`, `scripts/world/interact.gd`, `scripts/world/interact/interact_fx.gd`, `scripts/combat/dummy.gd`, `scripts/app/app_flow.gd`, `scripts/ui/loader.gd`, `scenes/camp.tscn`  


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
- `Layout` on `scenes/camp.tscn` is the pose hook. `ensure_tree()` creates the spot and roof children from script defaults. Scene exports override eave, UV, and box size. An empty `Layout` is valid. `Generated` is a runtime bucket. Play clears it and runs the helpers so Title and shots show the same town. Do not pack `Generated` into the scene.

## Camp entry events

Every way the player reaches Placeholdia (there is no Continue button on the title; Title has Play, the other entry is the dungeon). Code: `scripts/app/app_flow.gd`, `scripts/world/camp.gd`, `scripts/ui/recap/recap_flow.gd`.

| Event | Path | Wake block in `camp.gd` (`wake_pending`: wake VFX, `roll_quests(true)`, `restock()`) |
|---|---|---|
| Title → Play | `title.gd _play` → `App.play_from_menu` → `go_camp` | skipped (`wake_pending` is false); saved quests and shop stock load as they were |
| Run ends (death or “Dispel”; extraction only banks items) | `App.end_run` / `finish_end` → recap → its **Continue** button → `recap_flow.finish` sets `wake_pending` → `go_camp` | runs: new quest offers, shop restock, wake-up sequence |
| Run ends with no recap node | `app_run.finish_end` → `go_camp` | skipped (fallback only) |
| Pause → Main Menu → Title → Play | same as Title → Play | skipped |

"Each time the delver re-enters Placeholdia" therefore means either every row (hook in `camp.gd` setup) or only the run-end row (hook beside `roll_quests`); pick one in the design before building a per-entry feature.

This file is the door. Open the Job-table sibling only when that row matches.

| Job | Open |
|-----|------|
| consciousness-transfer VFX, Dispel wake-up, deepest row | `design/hub-crystal.md` |
| ore-for-gold stall, dumpster flavor, plaza_tarp host | `design/hub-benches.md` |
| receptionist bust, notice errands, welcome cloth | `design/hub-guild.md` |
| striking dummy, Label3D priorities, post-rail fence, hopeful ambience, warmup overlay | `design/hub-yard.md` |
| baked light RT, gable lids, contact puddles, HUB_SUB | `design/hub-bake.md` |
