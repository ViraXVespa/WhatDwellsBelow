# Placeholdia Hub Bake

Status: binding design
Read when: hub light, roofs, camp shot, wow pass
Code: `scripts/graphics/light_rt.gd` (`HUB_SUB`, `_hub_make_rt`, `_hub_finish_yard`, `save_hub_bake`), `scripts/world/camp_build.gd`, `scripts/world/camp_build_mesh.gd`, `scripts/world/camp_layout.gd`, `scripts/debug/shot_tool.gd`, `assets/baked/hub_light.png`, `tools/run_bake_camp.ps1`

The hub ships a baked light RT. Offline bake quality is the look lock. Runtime `camp_light` milliseconds are not.

## Lock
- Shipped atlas: `res://assets/baked/hub_light.png` from `LightRt.save_hub_bake`.
- Prove bake: `bake_camp: rt=` at least `1088x1024`, `sub=16`, `shadow_px` not 0.
- Prove shot: `python tools/run_shots.py --mode web --scene camp --hud 0 --zoom 0.38`. `_arm_capture` must call `_apply_pose` again so settle cannot keep the play crop.
- Playtest frame still matters (stall, hall, dumpster, receptionist). The 0.38 postcard is how we judge roofs and puddles.

## Allowed
- `HUB_SUB` 16 or higher. Raise it when puddles look stair-stepped.
- Hub RT path is `_hub_make_rt` plus building skirts. Do not send hub through `Stamp.paint`. That blit is dungeon `SUB` 4 and will shrink the atlas to 272x256.
- Pitched hall/wing roofs parented to the building bodies. Rumpled stall tarp on the stall body.
- Wing taller than the hall window. No wing awning over the receptionist. Hall keeps its awning.
- Roof-aware and wall-aware skirts. Soft puddles. Spend bake time.
- Warm field tint in the atlas. Ground stays unshaded times `light_tex`.
- One EnvKit on Camp only.

## Do not
- Do not change dungeon `Stamp.SUB`.
- Do not occupancy-march walls.
- Do not add a second EnvKit.
- Do not lift the whole yard with `_hub_lift_dark`.
- Do not treat live-main load-time as the hub look cap. Leftover hitch is `camp_enter` and player/spots, not the atlas.
- Do not let `camera_rig.apply_zoom` run while `warm_hold` is on.
- Do not trust a plus-only crop. Wide 0.38 plus the playtest frame.

## Process
1. Edit mesh / layout / skirt.
2. `tools/check_load_graph.py` then `run_godot_import_check.ps1`. Fail on COMPILE.
3. `run_bake_camp.ps1`. Fail on `clean=false`, `shadow_px=0`, or a 272x256 atlas.
4. Camp shot at zoom 0.38 with pose-at-capture.
5. Judge roofs and puddles on that PNG. Then playtest hub to dungeon at 60 fps before fade.
