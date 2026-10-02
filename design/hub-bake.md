# Placeholdia Hub Bake

Status: binding design  
Read when: hub light, roofs, camp shot, wow pass  
Code: `scripts/graphics/light_rt.gd` (`HUB_SUB`), `scripts/graphics/light_rt_hub_bake.gd` (`_hub_make_rt`, `_hub_paint_day`, `save_hub_bake`), `scripts/graphics/light_rt_hub_cast.gd` (`_hub_stamp_skirt`), `scripts/graphics/wrap_shader.gd`, `scripts/world/camp_build.gd`, `scripts/world/camp_build_mesh.gd`, `scripts/world/camp_layout.gd`, `scripts/debug/shot_tool.gd`, `assets/baked/hub_light.png`, `tools/run_bake_camp.ps1`

The hub ships one baked light RT. Offline bake quality is the look lock. Runtime `camp_light` milliseconds are not. Ortho-down at play zoom is the judge. Roofs read through lid shade and tile grain. The yard reads through a shadow projected from the real hall, wing, stall, and awning boxes. Height sets the length. Hall and wing are real gables. The stall tarp is pitched over the counter. Collision comes from those meshes.
- Building collision is the live wall, gable, awning, and stall-pitch meshes. Do not put the player on a box lid.

## Lock
- Shipped atlas: `res://assets/baked/hub_light.png` from `LightRt.save_hub_bake`.
- Shipped atlas is the png only. `scenes/camp.tscn` must not embed a second copy.
- Prove bake: `bake_camp: rt=` at least `1088x1024`, `sub=16`, `shadow_px` not 0. `shadow_px` not 0 is a pipeline check, not a look pass.
- Prove shot: `python tools/run_shots.py --mode web --scene camp --hud 0 --zoom 0.69`. The runner stitches the `design/shot-recipes.json` poses into one paste. `_arm_capture` must call `_apply_pose` again so settle cannot keep the play crop.
- Play zoom 0.69 is how we judge roofs and puddles (stall, hall, dumpster, receptionist). The 0.38 postcard is the wide frame only.

## Look
- Yard atlas paints a warm sun disc plus a small crystal bump by hand at `HUB_SUB`. Do not send hub through `Stamp.paint`.
- Cream field `Color(0.98, 0.96, 0.93)` is the floor under the sun, not the finished picture.
- Building interiors are not written. Roofs, awnings, and the stall tarp sample `light_tex`. Dirt owns the yard.
- Shadows fall with the player blob: down-left, -X +Z. Do not invent a second sun, and do not lock a +X vector over the blob. Project the live meshes and sprites. The stall pitch, awnings, posts, and actors come from the scene, not from boxes. Feather the edge. No skirt smear. No shed AABB.
- Finish and save use the same skirt. Then one 3x3 blur.
- Hall and wing lids are two-slope gables, not a south-falling shed. WrapShader russet is the lid color, matching the awning red, not the sun disc. Each slope runs from the ridge to its eave. `shade_hi` stays high enough that the eave is still tile. Tile `uv_scale` uses the slope length.
- Stall tarp is a pitched sheet over the counter, high enough to cover the goods, one sheet of `plaza_tarp.png`. No lid wrap term on the cloth. A small rumple is not the pitch.
- Hall and wing are only as tall as their face art. Both awnings hang off the south roof edge and cover the painted shingle band. Roofs stop at the wall edge.
- Angled frames are part of the proof. The recipe is `design/shot-recipes.json`: play, hall eave, stall front, stall side, one boot, one paste.

## Allowed
- `HUB_SUB` 16 or higher. Raise it when puddles look stair-stepped.
- Projected shadows from the live boxes. Spend bake time.
- Ground, roofs, awnings, and the stall tarp sample `light_tex`.
- One EnvKit on Camp only. It must not second-light a lid.

## Do not
- Do not change dungeon `Stamp.SUB`.
- Do not occupancy-march walls.
- Do not add a second EnvKit.
- Do not lift the whole yard with `_hub_lift_dark`.
- Do not fake a shed in place of the gable.
- Do not treat live-main load-time as the hub look cap. Leftover hitch is `camp_enter` and player/spots, not the atlas.
- Do not let `camera_rig.apply_zoom` run while `warm_hold` is on.
- Do not trust a plus-only crop. Judge zoom 0.69, then the stitched recipe.
- Do not embed the atlas in `scenes/camp.tscn`.
- Do not pack `Generated` as a shipped town.
- Do not add a second EnvKit. Lids sample the hub atlas, not a second light.

## Process
1. Edit mesh / lid wrap / dirt skirt.
2. `tools/check_load_graph.py` then `run_godot_import_check.ps1`. Fail on COMPILE.
3. `run_bake_camp.ps1`. Fail on `clean=false`, `shadow_px=0`, or a 272x256 atlas.
4. Camp shot at zoom 0.69. The paste is the recipe strip, pose applied on the camera that renders.
5. Judge roofs and puddles on the 0.69 PNG. The wide frame is not the look pass. Then playtest hub to dungeon at 60 fps before fade.
