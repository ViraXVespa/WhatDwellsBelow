# Placeholdia Hub Bake

Status: current plan  
Read when: hub light, roofs, camp shot, wow pass  
Code: `scripts/graphics/light_rt.gd` (`HUB_SUB`), `scripts/graphics/light_rt/hub_bake.gd` (`_hub_make_rt`, `_hub_paint_day`, `_hub_render`, `_load_baked`, `save_hub_bake`, `HUB_BAKE_STAMP`), `scripts/graphics/light_rt/hub_cast.gd` (`_hub_stamp_skirt`), `scripts/graphics/light_rt/hub_shadow.gd` (`_hub_mesh_shadows`), `scripts/app/app_bake.gd` (`--wdb-bake-camp`: realizes the Layout camp in memory and adds it to the scene tree before baking), `scripts/graphics/wrap_shader.gd`, `scripts/world/camp_build.gd`, `scripts/world/camp_build/mesh.gd`, `scripts/world/camp/layout.gd`, `assets/baked/hub_light.png`, `tools/run_bake_camp.py`, `tools/check_hub_bake.py`

The hub light is baked only: the game never renders it. Offline bake quality is the look lock. Runtime `camp_light` milliseconds are not. Ortho-down at play zoom is the judge. Roofs read through lid shade and tile grain. The yard reads through a shadow projected from the real hall, wing, stall, and awning meshes. Height sets the length. Hall and wing are real gables. The stall tarp is pitched over the counter. Collision comes from those meshes.
- Building collision is the live wall, gable, awning, and stall-pitch meshes. Do not put the player on a box lid.

## Lock
- No runtime render. `prepare_hub` loads `res://assets/baked/hub_light.png` (from disk in the editor, from the imported texture in an export) and checks it: file present, size equals the Layout (`tw*HUB_SUB` by `th*HUB_SUB`, 1088x1024 today), and `HUB_BAKE_STAMP`. Any miss is a hard error (`_fatal`: `push_error` then `OS.crash`) that names the cause and the rebake steps. There is no fallback, so a missing or stale bake breaks the hub on purpose.
- Stamp: `HUB_BAKE_STAMP` (`hub_bake.gd`) is the first 16 hex of the SHA-256 of the png's RGBA8 pixels, printed by the bake as `stamp=`. Current bake: `2db52d08a413a31c`.
- One render, bake only: `_hub_render` on a fresh field-filled image, saved by `LightRt.save_hub_bake`: day gradient (`_hub_paint_day`), soft skirts for the props (`hub_cast.gd`, plus the tarp lid at the near shade), then the mesh shadows (`hub_shadow.gd`), then one 3x3 blur. No second paint, no fill, no second blur.
- Mesh shadows: every visible, shadow-casting `MeshInstance3D` and building `Sprite3D` under the camp is projected triangle by triangle onto the ground along `HubCast.AWAY` (+X +Z, the actor blobs' direction) at `HubCast.REACH` metres per metre of height; a point on the ground stays put, so walls and posts join their shadow. Shade comes from the caster height at each pixel (`HubCast.shade_at`: near shade at the base, tip shade at the top), the same numbers as the skirts. Each pixel keeps the darker of what is there and the new shade, so shadows never stack. A body's parts share one top. Skipped: meshes with shadows off (fence rails and posts), ground planes, anything under 0.2 m tall, and the footprint of each body's ground parts (roofs sample the atlas there). The camp must be in the tree (`app_bake.gd`) so global transforms are valid.
- Any change to the hub light code (`hub_bake`, `hub_cast`, `hub_shadow`), `HUB_SUB`, or the Layout boxes, size, awnings or crystal needs a rebake and a new stamp in the same commit. A stale png fails `python3 tools/check_hub_bake.py` (run by `run_build_gate.py --batch`) and crashes the hub.
- Rebake: `python3 tools/run_bake_camp.py` (not headless). It must print `RESULT PASS`, `shadow_px` not 0 and `stamp=<hex>`. Review the shots (`run_shots.py --scene camp --hud 0 --mode build`), paste the stamp into `HUB_BAKE_STAMP`, commit png and stamp together, run `check_hub_bake.py`.
- Shipped atlas is the png only. `scenes/camp.tscn` must not embed a second copy.
- Prove bake: `bake_camp: rt=` at least `1088x1024`, `sub=16`, `shadow_px` not 0 (`run_bake_camp.py` fails any bake with 0, headless or not) and `stamp=` printed. The tool picks a display itself (`shot-tool.md` Display). `shadow_px` not 0 is a pipeline check, not a look pass.
- Prove shot: `python3 tools/run_shots.py --mode web --scene camp --hud 0 --zoom 0.69`. The runner stitches the `tools/shot-recipes.json` poses into one paste. `_arm_capture` must call `_apply_pose` again so settle cannot keep the play crop.
- Play zoom 0.69 is how we judge roofs and puddles (stall, hall, dumpster, receptionist). The 0.38 postcard is the wide frame only.

## Look
- Yard atlas paints a warm sun disc plus a small crystal bump by hand at `HUB_SUB`. Do not send hub through `Stamp` (`light_stamp.gd`).
- Cream field `Color(0.98, 0.96, 0.93)` is the floor under the sun, not the finished picture.
- Building interiors are not written. Roofs, awnings, and the stall tarp sample `light_tex`. Dirt owns the yard.
- Shadows fall the way the player blob does (`HubCast.AWAY`, +X +Z). Do not invent a second sun or a different vector. Building shadows come from the meshes (see Lock); props are `_hub_yard_boxes` blobs; actors carry their own blob. The edge is the one 3x3 blur. No skirt smear. No shed AABB.
- Hall and wing lids are two-slope gables, not a south-falling shed. WrapShader russet is the lid color, matching the awning red, not the sun disc. Each slope runs from the ridge to its eave. `shade_hi` stays high enough that the eave is still tile. Tile `uv_scale` uses the slope length.
- Stall tarp is a pitched sheet over the counter, high enough to cover the goods, one sheet of `plaza_tarp.png`. No lid wrap term on the cloth. A small rumple is not the pitch.
- Hall and wing are only as tall as their face art. Both awnings hang off the south roof edge and cover the painted shingle band. Roofs stop at the wall edge.
- Angled frames are part of the proof. The recipe is `tools/shot-recipes.json`: play, hall eave, stall front, stall side, one boot, one paste.

## Allowed
- `HUB_SUB` 16 or higher. Raise it when puddles look stair-stepped.
- Mesh shadows from the live camp. Spend bake time.
- Ground, roofs, awnings, and the stall tarp sample `light_tex`.
- One EnvKit on Camp only. It must not second-light a lid.

## Do not
- Do not change dungeon `Stamp.SUB`.
- Do not occupancy-march walls.
- Do not add a second EnvKit.
- Do not fake a shed in place of the gable.
- Do not treat live-main load-time as the hub look cap. Leftover hitch is `camp_enter` and player/spots, not the atlas.
- Do not let `camera_rig.apply_zoom` run while `warm_hold` is on.
- Do not trust a plus-only crop. Judge zoom 0.69, then the stitched recipe.
- Do not embed the atlas in `scenes/camp.tscn`.
- Do not pack `Generated` as a shipped town. `run_bake_camp.py` realizes it in memory, rebakes `hub_light.png`, and never rewrites `camp.tscn`. Awning shadow boxes read the Layout depth per building.
- Lids sample the hub atlas, not a second light.

## Process
1. Edit mesh / lid wrap / dirt skirt.
2. `tools/check_load_graph.py` then `run_godot_import_check.py`. Fail on COMPILE.
3. `run_bake_camp.py`. Fail on `clean=false`, `shadow_px=0`, or a 272x256 atlas.
4. Camp shot at zoom 0.69. The paste is the recipe strip, pose applied on the camera that renders.
5. Judge roofs and puddles on the 0.69 PNG. The wide frame is not the look pass. Then playtest hub to dungeon at 60 fps before fade.

The prove command stays here. The shot tool is not this job.
