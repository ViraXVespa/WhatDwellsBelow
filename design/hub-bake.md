# Placeholdia Hub Bake

Status: binding design  
Read when: hub light, roofs, camp shot, wow pass  
Code: `scripts/graphics/light_rt.gd` (`HUB_SUB`, `_hub_make_rt`, `_hub_paint_day`, `_hub_stamp_skirt`, `save_hub_bake`), `scripts/graphics/wrap_shader.gd`, `scripts/world/camp_build.gd`, `scripts/world/camp_build_mesh.gd`, `scripts/world/camp_layout.gd`, `scripts/debug/shot_tool.gd`, `assets/baked/hub_light.png`, `tools/run_bake_camp.ps1`

The hub ships one baked light RT. Offline bake quality is the look lock. Runtime `camp_light` milliseconds are not. Ortho-down at play zoom is the judge. Roofs read through lid shade and tile grain. The yard reads through a shadow projected from the real hall, wing, stall, and awning boxes. Height sets the length. Not a fake gable triangle.

## Lock
- Shipped atlas: `res://assets/baked/hub_light.png` from `LightRt.save_hub_bake`.
- Shipped atlas is the png only. `scenes/camp.tscn` must not embed a second copy.
- Prove bake: `bake_camp: rt=` at least `1088x1024`, `sub=16`, `shadow_px` not 0. `shadow_px` not 0 is a pipeline check, not a look pass.
- Prove shot: `python tools/run_shots.py --mode web --scene camp --hud 0 --zoom 0.69` and the same call at `--zoom 0.38`. `_arm_capture` must call `_apply_pose` again so settle cannot keep the play crop.
- Play zoom 0.69 is how we judge roofs and puddles (stall, hall, dumpster, receptionist). The 0.38 postcard is the wide frame only.

## Look
- Yard atlas paints a warm sun disc plus a small crystal bump by hand at `HUB_SUB`. Do not send hub through `Stamp.paint`.
- Cream field `Color(0.98, 0.96, 0.93)` is the floor under the sun, not the finished picture.
- Building interiors are not written. Lids own their shade and do not sample `light_tex`. Dirt owns the yard.
- Shadows use `actor_lit.gd` `SUN_AWAY` `Vector2(0.406138, 0.913811)` and `HUB_STRETCH` 0.72. Do not invent a second sun. Project the live boxes along that fall. Feather the edge. No skirt smear.
- Finish and save use the same skirt. Then one 3x3 blur.
- Hall and wing lids are one south-falling shed. WrapShader russet is the lid color, matching the awning red, not the sun disc. Ridge-to-eave wrap uses `shade_lo` at the north ridge and `shade_hi` at the south eave. `shade_hi` stays high enough that the eave is still tile. Tile `uv_scale` uses surface fall length.
- Stall tarp is a 9x7 cloth with small rumple and one sheet of `plaza_tarp.png`. No lid wrap term on the cloth.
- Wing stays taller and has no awning. Hall keeps the awning.
- Tilt is optional beauty. It is not the proof.

## Allowed
- `HUB_SUB` 16 or higher. Raise it when puddles look stair-stepped.
- Projected shadows from the live boxes. Spend bake time.
- Ground stays unshaded times `light_tex`. Lids do not.
- One EnvKit on Camp only. It must not second-light a lid.

## Do not
- Do not change dungeon `Stamp.SUB`.
- Do not occupancy-march walls.
- Do not add a second EnvKit.
- Do not lift the whole yard with `_hub_lift_dark`.
- Do not fake a second roof AABB so the postcard grows a triangle.
- Do not treat live-main load-time as the hub look cap. Leftover hitch is `camp_enter` and player/spots, not the atlas.
- Do not let `camera_rig.apply_zoom` run while `warm_hold` is on.
- Do not trust a plus-only crop. Judge zoom 0.69, then the 0.38 postcard.
- Do not embed the atlas in `scenes/camp.tscn`.
- Do not pack `Generated` as a shipped town.
- Do not multiply a lid by `light_tex` or by EnvKit ambient.

## Process
1. Edit mesh / lid wrap / dirt skirt.
2. `tools/check_load_graph.py` then `run_godot_import_check.ps1`. Fail on COMPILE.
3. `run_bake_camp.ps1`. Fail on `clean=false`, `shadow_px=0`, or a 272x256 atlas.
4. Camp shot at zoom 0.69, then 0.38, with pose-at-capture.
5. Judge roofs and puddles on the 0.69 PNG. The wide frame is not the look pass. Then playtest hub to dungeon at 60 fps before fade.
