# Session plan

Same-worktree continuity after a compact. Not a task file and not a survey handoff.
Write the four sections above the marker in the same turn a fact lands. Trim the gathered half to this unit once the working set is known, before the first edit.
`python tools/slice.py plan --refresh` rebuilds the gathered half and erases that trim. Use it only when the gather is stale.
On a post-compact turn, read this file first. Do not re-run the lookups it still holds.

## Outcome

A Blender unequipped female base with default bible gear walks one cycle, bakes to pixel-art sprites, and a synced side-by-side against `assets/sprites/player/female/walk_*` exists with its path reported.

The still comes first, and the still is the base mannequin. No frame colors are painted on it. No hair until the body reads. One script builds the jointed voxel body. Part widths come from the keyed-cell spans, the same way the thighs were matched. The boot span is not part of the shin.

## Open questions

- The body does not hold. On 2026-11-09 the user called the latest mesh an alien. Resume from the task's Current state section and this plan. No hair, gear, or walk until a later body reads as her.

## Changed files

- `_src/wip/modular-voxel-walk/cells/*.png` (native 256 crops, not resized)
- `_src/wip/modular-voxel-walk/keyed/plate.png` (staged matte of the full 768 plate)
- `_src/wip/modular-voxel-walk/keyed/{down,up,left,right}.png` (256 crops of that plate key)
- `_src/wip/modular-voxel-walk/build_female.py`
- `_src/wip/modular-voxel-walk/female-modular.blend`
- `tools/lib/shots/shot_crop.py` (`--spans`, `--overlay`)
- `design/tools-shots.md` (the crop bullet names `--spans` and `--overlay`)

## Latest results

- Decision: live Blender only, and the doll is one script run. Blender executes `build_female.py`. No hand placement in the editor.
- Plate removal is `media.py sprites matte` (`imglib.matte.key`). Key the 768 plate, then crop. No resize before the key. Color correction stays deferred.
- Bible sha256 `69ca2f5da6e79d8228f457b10a702fd1bc1aedba099fe2fdeb7f6c790090ada8`, 768×768. Cells are 256. Front/back/left/right are the keyed crops.
- Rest pose is an A-pose. Both legs share one depth (the side cell's long foot is a stride and is not copied). The elbow is a real joint: upper arm, forearm, hand. Frame pixels are not painted on the body.
- The two measurement reviews did not write a script. Inline Python is blocked there, so they zoomed strips with `review_local.py` until the turn cap. Widths come from `python tools/shots.py crop PNG --spans [--step N] [--bg HEX]`. A registered translucent reference is `shots.py crop MODEL --overlay REF --scale S --anchor-ref X,Y --anchor-model X,Y`. Crop selftest passed.
- Registration used for these stills: keyed sole row y244 lands on render y561, cell x128 lands on front x255.5 and side x256, scale 346/232. Reference opacity 0.45.
- Latest build: base mannequin only. Head 31269, Neck 1327, Chest 61161, Pelvis 18458, and both sides of upper arm 5240, forearm 2134, hand 448, thigh 38164, shin 8899, and foot 2166. No hair. Saved `_src/wip/modular-voxel-walk/female-modular.blend`.
- Front overlay, same registration: cheek row y250 is 64 px against the face 68 px. Jaw y266 is 29 px. Throat y282 is 24 px. Shoulder cap y314 is 118 px against the reference outer 110 px, and y330 the arms are already separate around a 54 px chest. Bust row y346 chest is 59 px against the sleeve-gap torso 56 px. Thighs y442–y458 match the pants (41/41 then 35/35). Knee y474 is 32/34 against pants 30/31. Calf y490 is 25/24 inside the boot 39/38.
- Side overlay: face front at y250 is on the reference face. Bust front at y346 is about 4 voxels behind the jacket surface, and the belly is behind that. Knee front at y474 matches the reference front. The calf is inside the boot. Hands are a palm, four fingers, and an outer thumb.
- `apply_review_style` is off in the window. Front and side review PNGs were written with it on, then the window was restored to flat skin and the closer 3/4. Tight crops used for the check: `tight3-head-front.png`, `tight3-head-side.png`, `tight3-side-body.png`, `tight3-hands.png`.
- Not animated. Next, only after a later body reads as her: hair and gear, then one 8-frame walk at 8 fps, the pixel bake, and the side-by-side. No source landing until approval.
- Branch `grok-build-w11` was fast-forwarded to `75ad1847` before this save. This plan is copied to `_src/wip/modular-voxel-walk/session-plan.md` because the worktree root copy is gitignored.
- `review-shots/blender-front.png` and `blender-side.png` match the saved mesh. `blender-back.png` and `blender-three-quarter.png` are older and do not.

<!-- gathered -->

### Identity

- door: art_pipeline
- job: (none)
- task: modular-voxel-walk-proof
- area: female modular voxel body, default gear, one walk, sprite bake, side-by-side
- mode: task (continue until done; do not stop for a job survey or a compact break)
- systems: none (no live scripts this unit)
- task doc: design/tasks/modular-voxel-walk-proof.md (read whole)
- door fact already in hand: design/art-pipeline.md says this approved Blender proof follows its own modeling/bake steps, keeps identity and comparison requirements, and is not an I2V job. Player and enemy animations use 8 directions. Do not open the other art_pipeline job docs.

### Keep

- `_src/new_bibles/female.png` — sole character bible. Layout unverified. Do not apply the legacy nine-cell map. Do not mix old bibles. No magenta chroma on the model. Record path, hash, native size, and half-open crop boxes before any resize.
- `assets/sprites/player/female/walk_DIRECTION_N.png` — current walk, comparison only. Order and timing not checked yet.
- Key only if cells are split: `tools/media.py sprites key` or `matte` (`tools/lib/imglib/matte.py`). Do not write a new keyer.
- Blender is on PATH. Use the Blender MCP. Do not route this through Imagine or I2V.
- After approval only: model sources under `_src/sources/models`, new walk frames in the female walk `assets` location, and design-doc workflow notes if she approves.
- Revoke the reference grant when reference work ends.
