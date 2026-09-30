# Placeholdia Hub Bake

Status: binding design  
Read when: hub light, roofs, camp shot, wow pass  
Code: `scripts/graphics/light_rt.gd` (`HUB_SUB`, `_hub_make_rt`, `_hub_paint_day`, `_hub_stamp_skirt`, `save_hub_bake`), `scripts/graphics/wrap_shader.gd`, `scripts/world/camp_build.gd`, `scripts/world/camp_build_mesh.gd`, `scripts/world/camp_layout.gd`, `scripts/debug/shot_tool.gd`, `assets/baked/hub_light.png`, `tools/run_bake_camp.ps1`

The hub ships a baked light RT. Offline bake quality is the look lock. Runtime `camp_light` milliseconds are not. Ortho-down is the judge. Roofs read through lid shade, tile grain, and a sun-away dirt blob, not a fake gable triangle.

## Lock
- Shipped atlas: `res://assets/baked/hub_light.png` from `LightRt.save_hub_bake`.
- Prove bake: `bake_camp: rt=` at least `1088x1024`, `sub=16`, `shadow_px` not 0.
- Prove shot: `python tools/run_shots.py --mode web --scene camp --hud 0 --zoom 0.38`. `_arm_capture` must call `_apply_pose` again so settle cannot keep the play crop.
- Playtest frame still matters (stall, hall, dumpster, receptionist). The 0.38 postcard is how we judge roofs and puddles.

## Look
- Yard atlas paints a warm sun disc plus a small crystal bump by hand at `HUB_SUB`. Do not send hub through `Stamp.paint`.
- Cream field `Color(0.98, 0.96, 0.93)` is the floor under the sun, not the finished picture.
- Building interiors are not written. Lids own their shade. Dirt owns the yard.
- Puddles are sun-away rounded blobs (`away` +X+Z) with a short contact ring. No dark rectangle under the footprint.
- Finish and save use the same skirt. Then one 3x3 blur.
- Hall and wing lids are one south-falling shed. WrapShader multiplies russet by a ridge-to-eave wrap (`shade_lo` at the north ridge, `shade_hi` at the south eave). Tile `uv_scale` uses surface fall length.
- Stall tarp is a 9x7 cloth with small rumple and one sheet of `plaza_tarp.png`. No lid wrap term on the cloth.
- Wing stays taller and has no awning. Hall keeps the awning.
- Tilt is optional beauty. It is not the proof.

## Allowed
- `HUB_SUB` 16 or higher. Raise it when puddles look stair-stepped.
- Soft puddles. Spend bake time.
- Ground stays unshaded times `light_tex`.
- One EnvKit on Camp only.

## Do not
- Do not change dungeon `Stamp.SUB`.
- Do not occupancy-march walls.
- Do not add a second EnvKit.
- Do not lift the whole yard with `_hub_lift_dark`.
- Do not fake a second roof AABB so the postcard grows a triangle.
- Do not treat live-main load-time as the hub look cap. Leftover hitch is `camp_enter` and player/spots, not the atlas.
- Do not let `camera_rig.apply_zoom` run while `warm_hold` is on.
- Do not trust a plus-only crop. Wide 0.38 plus the playtest frame.

## Process
1. Edit mesh / lid wrap / dirt skirt.
2. `tools/check_load_graph.py` then `run_godot_import_check.ps1`. Fail on COMPILE.
3. `run_bake_camp.ps1`. Fail on `clean=false`, `shadow_px=0`, or a 272x256 atlas.
4. Camp shot at zoom 0.38 with pose-at-capture.
5. Judge roofs and puddles on that PNG. Then playtest hub to dungeon at 60 fps before fade.
