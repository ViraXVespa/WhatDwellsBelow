# Placeholdia Hub Bake

Status: current plan  
Read when: hub light, roofs, camp shot, wow pass  
Code: `scripts/graphics/light_rt.gd` (`HUB_SUB`), `scripts/graphics/light_rt/hub_bake.gd` (`_hub_make_rt`, `_hub_paint_day`, `_hub_render`, `_load_baked`, `save_hub_bake`, `HUB_BAKE_STAMP`), `scripts/graphics/light_rt/hub_cast.gd` (`AWAY`, `REACH`, tarp lid), `scripts/graphics/light_rt/hub_props.gd` (`lamp_glow`, `overlay_dbg`), `camp_build.gd` (`mark_props`: yard props use the live ActorLit mark, not the bake), `scripts/world/camp/lamps.gd` (guild lantern flames, group `hub_lamp`), `scripts/graphics/light_rt/hub_shadow.gd` (`_hub_mesh_shadows`), `scripts/graphics/light_rt/hub_roof.gd` (roof receivers), `scripts/graphics/light_rt/hub_blur.gd` (`_blur_hub`), `scripts/app/app_bake.gd` (`--wdb-bake-camp`: realizes the Layout camp in memory and adds it to the scene tree before baking), `scripts/graphics/wrap_shader.gd`, `scripts/world/camp_build.gd`, `scripts/world/camp_build/mesh.gd`, `scripts/world/camp/layout.gd` + `layout_spec.gd` (every box, lamp and glow number), `assets/baked/hub_light.png`, `tools/bake.py camp`, `tools/bake.py check`

The hub light is baked only: the game never renders it. Offline bake quality is the look lock. Runtime `camp_light` milliseconds are not. Ortho-down at play zoom is the judge. Roofs read through lid shade and tile grain. The yard reads through a shadow projected from the real hall, wing, stall, and awning meshes. Height sets the length. Hall and wing are real gables. The stall tarp is pitched over the counter. Collision comes from those meshes.
- Building collision is the live wall, gable, awning, and stall-pitch meshes. Do not put the player on a box lid.

## Lock
- No runtime render. `prepare_hub` loads `res://assets/baked/hub_light.png` (from disk in the editor, from the imported texture in an export) and checks it: file present, size equals the Layout (`tw*HUB_SUB` by `th*HUB_SUB`, 1088x1024 today), and `HUB_BAKE_STAMP`. Any miss is a hard error (`_fatal`: `push_error` then `OS.crash`) that names the cause and the rebake steps. There is no fallback, so a missing or stale bake breaks the hub on purpose.
- Stamp: `HUB_BAKE_STAMP` (`hub_bake.gd`) is the first 16 hex of the SHA-256 of the png's RGBA8 pixels, printed by the bake as `stamp=`. Current bake: `ab9b36b66980d274`.
- One render, bake only: `_hub_render` on a fresh field-filled image, saved by `LightRt.save_hub_bake`: day gradient (`_hub_paint_day`), the stall tarp lid at the near shade (`Layout.stall_lid`: tarp plus posts), then the mesh shadows (`hub_shadow.gd`), then a warm pool under each `hub_lamp`, then one 3x3 blur that never mixes a footprint with the yard (`HubBlur.zones`). No second paint, no fill, no second blur.
- Mesh shadows: every visible, shadow-casting `MeshInstance3D` and building `Sprite3D` under the camp is projected triangle by triangle onto the ground along `HubCast.AWAY` (+X +Z, the actor blobs' direction) at `HubCast.REACH` metres per metre of height; a point on the ground stays put, so walls and posts join their shadow. Shade comes from the caster height at each pixel (`HubCast.shade_at`: near shade at the base, tip shade at the top),. Each pixel keeps the darker of what is there and the new shade, so shadows never stack. A body's parts share one top. Skipped: meshes with shadows off (fence rails and posts), ground planes, anything under 0.2 m tall, and the footprint of each body's ground parts (roofs sample the atlas there). The camp must be in the tree (`app_bake.gd`) so global transforms are valid.
- Roofs: the gable meshes cast like every mesh; a roof triangle shades no lighter than its body's wall top, so the gable outline reads past the walls. A body's own footprint is never written (its roof samples the atlas there); another guild roof's footprint is a receiver (`hub_roof.gd`): shaded where the sun ray clears that roof's surface (eave to ridge, from the Gable bounds), so the hall shades the wing's west roof edge. The fence projects from its post tops (`Layout.fence_shadow_top`: y + post_y + h/2). Roofs, awnings and the tarp are bound to the atlas after they are built (`camp.gd` `_step_stall`: `LightRt.rebind_tree` per `hub_build` body); before 2026-10-24 they were built after the only rebind and sampled nothing.
- Any change to the hub light code (`hub_bake`, `hub_cast`, `hub_shadow`, `hub_roof`, `hub_blur`), `HUB_SUB`, or the `layout_spec.gd` boxes, size, awnings, fence, lamps or crystal needs a rebake and a new stamp in the same commit. `tools/bake.py camp` records the inputs it baked from in `tools/data/hub_bake_inputs.json` (light code hashes, one per `layout_spec.gd` const); `python tools/bake.py check` (run by `gate.py build --batch`) fails on a stale png or on any input changed since the bake (`--record` re-records without a rebake only when the change cannot move the light; say why), and on a lit rim round a footprint (`bake_leak.py`). `bake.py check --rebake` (bot_status `--prove` row `bake_repro`) rebakes from the committed sources and fails unless the stamp matches and `lamp_px` is not 0.
- Rebake: `python tools/bake.py camp` (not headless). It must print `RESULT PASS`, `shadow_px` and `lamp_px` not 0 and `stamp=<hex>`. Review the shots (`shots.py capture --scene camp --hud 0 --mode build`), paste the stamp into `HUB_BAKE_STAMP`, commit png and stamp together, run `bake.py check`.
- Shipped atlas is the png only. `scenes/camp.tscn` must not embed a second copy.
- Shadow off its object? `bake.py camp --overlay` and read the overlay against the shots: a shadow outside its outline or a bright gap inside a red footprint names the box. The overlay is drawn from the Layout via `bake_dbg` lines: lid yellow, footprints red, casters cyan, collision magenta, lamp pools orange, spots white.
- Prove bake: `bake_camp: rt=` at least `1088x1024`, `sub=16`, `shadow_px` not 0 (`bake.py camp` fails any bake with 0, headless or not) and `stamp=` printed. The tool picks a display itself (`shot-tool.md` Display). `shadow_px` not 0 is a pipeline check, not a look pass.
- Prove shot: `python tools/shots.py capture --mode web --scene camp --hud 0 --zoom 0.69`. The runner stitches the `tools/data/shot-recipes.json` poses into one paste. `_arm_capture` must call `_apply_pose` again so settle cannot keep the play crop.
- Play zoom 0.69 is how we judge roofs and puddles (stall, hall, dumpster, receptionist). The 0.38 postcard is the wide frame only.

## Look
- Yard atlas paints a warm sun disc plus a small crystal bump by hand at `HUB_SUB`. Do not send hub through `Stamp` (`light_stamp.gd`).
- Cream field `Color(0.98, 0.96, 0.93)` is the floor under the sun, not the finished picture.
- Building interiors are not written, except each guild roof footprint is scaled per slope by its own sun (`hub_roof.gd slopes`; `bake.py check` FAILs a flat roof, `bake_roof.py`). Roofs, awnings, the stall tarp and the building faces (`face_lit.gd`; `bake.py check --props` FAILs an unbound face, `hub_face_check.gd`) sample `light_tex`. Dirt owns the yard.
- Shadows fall the way the player blob does (`HubCast.AWAY`, +X +Z). Do not invent a second sun or a different vector. Building shadows come from the meshes (see Lock); yard props use the live ActorLit mark; actors carry their own blob. The edge is the one 3x3 blur. No skirt smear. No shed AABB.
- Hall and wing lids are two-slope gables, not a south-falling shed. WrapShader russet is the lid color, matching the awning red, not the sun disc. Each slope runs from the ridge to its eave. `shade_hi` stays high enough that the eave is still tile. Tile `uv_scale` uses the slope length.
- Stall tarp is a pitched sheet over the counter, high enough to cover the goods, one sheet of `plaza_tarp.png`. No lid wrap term on the cloth. A small rumple is not the pitch.
- Hall and wing are only as tall as their face art. Both awnings hang off the south roof edge and cover the painted shingle band. Roofs stop at the wall edge.
- Angled frames are part of the proof. The recipe is `tools/data/shot-recipes.json`: play, hall eave, stall front, stall side, one boot, one paste.

## Allowed
- `HUB_SUB` 16 or higher. Raise it when puddles look stair-stepped.
- Mesh shadows from the live camp. Spend bake time.
- Ground, roofs, awnings, and the stall tarp sample `light_tex`.
- One EnvKit on Camp only. It must not second-light a lid.

## Do not
- Do not change the dungeon `SUB` (`light_stamp/stamp_k.gd`).
- Do not occupancy-march walls.
- Do not add a second EnvKit.
- Do not fake a shed in place of the gable.
- Do not treat live-main load-time as the hub look cap. Leftover hitch is `camp_enter` and player/spots, not the atlas.
- Do not let `camera_rig.apply_zoom` run while `warm_hold` is on.
- Do not trust a plus-only crop. Judge zoom 0.69, then the stitched recipe.
- Do not embed the atlas in `scenes/camp.tscn`.
- Do not pack `Generated` as a shipped town. `bake.py camp` realizes it in memory, rebakes `hub_light.png`, and never rewrites `camp.tscn`.
- Lids sample the hub atlas, not a second light.

## Process
1. Edit mesh / lid wrap / dirt skirt.
2. `tools/check.py load-graph` then `gate.py import`. Fail on COMPILE.
3. `bake.py camp`. Fail on `clean=false`, `shadow_px=0`, or a 272x256 atlas.
4. Camp shot at zoom 0.69. The paste is the recipe strip, pose applied on the camera that renders.
5. Judge roofs and puddles on the 0.69 PNG. The wide frame is not the look pass. Then playtest hub to dungeon at 60 fps before fade.

The prove command stays here. The shot tool is not this job.
