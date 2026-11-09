# Modular 3D walk proof (Blender + bake)

id: modular-voxel-walk-proof
owner: build
status: open
done-when: Base body (no hair/equipment) created in Blender; default gear (bible equipment + hair) attached as modular pieces; walk animation looks good from all angles and matches current art style/feel; sprites baked with processing that preserves 2D pixel-art vibe; synced side-by-side comparison of current female walk vs new baked result produced and path reported.
resume: python tools/slice.py open art_pipeline --task modular-voxel-walk-proof

## Goal
Create a modular 3D character in Blender (base body + attachable gear) that matches the current character’s look and body dimensions. Animate one walk cycle that looks and feels like the existing art style (sync and model-mismatch issues fixed, everything smoothed out). Bake to 2D sprites with processing that keeps the pixel-art vibe, then produce a side-by-side comparison. This establishes the foundation for future paper-doll equipment and customization.

## Reference workflow (before modeling)

Use `_src/new_bibles/female.png` as the sole character Bible for this task, replacing the older Bibles. Its layout has not been verified; do not apply the legacy nine-cell mapping. Current walk frames remain `assets/sprites/player/female/walk_DIRECTION_N.png` for the comparison only; check their actual order/timing.

The geometry author needs the pixels, not only a text review. Use the supported task-scoped exception in the Build reference guide; this does not change generation or host permissions.

1. Start the task normally with `slice.py start ... --task modular-voxel-walk-proof`.
2. Grant the canonical source directly:
   `python tools/slice.py references grant --task modular-voxel-walk-proof --reason "Blender modeling requires the new female source's proportions and equipment" --path _src/new_bibles/female.png`
3. Read that original with the direct image-read tool. Preserve its path, hash and native dimensions in the comparison notes. Inspect its layout before choosing any details; record half-open source crop coordinates and output dimensions for later crops, without resizing the reference. Grant exact crop or current-walk paths separately if needed. Do not combine old and new Bibles or run the legacy cell exporter on this unverified layout.
   - If it would be better for the task, you can additionally split and key the individual cells and add those individually to the references grant. Either way, be sure not to add the magenta chroma to the model.
4. Inspect the available Blender MCP schema in Vira's Build environment before modeling. Use it for this task; do not route Blender work through Imagine/I2V. Missing MCP access is a setup gap to report, not a reason to invent commands or broaden permissions.
5. Revoke the reference grant when the reference work ends. Geometry hidden by the 2D views still needs explicit design judgment; do not silently invent disputed anatomy or attachment behavior.

## Steps
1. **Base body**  
   Using Blender (MCP available), create an unequipped 3D body (no hair, no equipment) as the modular root. Match the current character’s look and body dimensions. Include attachment sockets for gear and hair.

2. **Default gear**  
   Take the equipment and hair visible on the current female bible character and add them as the default modular pieces attached to the base. Confirm they can be swapped or disabled independently. Different physics or behavior on pieces is allowed where useful.

3. **Animation**  
   One walk cycle only. The assembled character (base + default gear) must look good from all angles needed for visibility. Final animations should look and feel like the current art style—sync and model-mismatch issues fixed, everything smoothed out.

4. **Bake**  
   Bake the animated character to sprites. Apply special processing so the result keeps the 2D pixel-art vibe of the existing assets.

5. **Comparison**  
   Produce a synced side-by-side GIF or short video of the current female walk animations next to the new baked result. Report the output path.

## Done when
- Unequipped base body exists in Blender with attachment points and matching look/dimensions.
- Default gear (bible equipment + hair) is attached and modular.
- Walk animation looks good from all relevant angles and matches current art style/feel (smoothed, sync/model issues fixed).
- Baked sprites preserve the pixel-art look.
- Side-by-side comparison exists and its path is reported.

## Notes from Vira
- This is a unique task, so a lot of the standard slice protocols won't apply to this work. You also don't have to stop for compact breaks. Just continue through the work until the task is done and auto-compact will hit when it hits.
- If/after everything gets approved, land the model sources under `_src/sources/models` and the new walk animation frames in the relevant `assets` location.
- I have no idea how the Blender MCP works or how difficult this modelling task will be. If I were handling this task myself, I would probably chroma key the Front/Back/Left/Right cells from the bible, import them into Blender as flat face placed next to one another (with the Front/Back placed back-to-back in on location and the Left/Right frames intersecting them perpendicularly), and then I would extrude the pixels as voxels until it visibly replicated the bible from all directions. That would require some manual adjustments on the feet positionings on the side views, but I think that would be the optimal route for a human tackling this task. This may or may not be the ideal route for an agent, but I figured I would mention it in case it helps guide you to the ideal approach for completing this work.
- Since there is no documentation for this workflow, it may be helpful for you to take notes about how to accomplish similar tasks in the future. If this workflow is viable and the results are approved, we will be using this same workflow for generating new art and animations for all of the enemies in the game, so you'll want to update the design docs with usage and workflow documentation if I approve the work.
- `blender` has been added to the system path, so you can easily launch it via a shell command whenever needed without having to manually locate the Blender executable.

## Current state
The base body does not read as the character. On 2026-11-09 the user called the latest mesh an alien and stopped the sculpt. Status stays open. Do not animate, add hair, paint frame colors, rekey, or land sources until a later body reads as her.

Resume next week from `_src/wip/modular-voxel-walk/session-plan.md` (the worktree root `session-plan.md` is gitignored). The live file is `_src/wip/modular-voxel-walk/female-modular.blend`. One script builds it: `_src/wip/modular-voxel-walk/build_female.py`. Blender 5.2.3 is on PATH. Use the user's live Blender window and the Blender MCP. Do not start `blender --background`.

What is on disk:

- Bible `_src/new_bibles/female.png`, sha256 `69ca2f5da6e79d8228f457b10a702fd1bc1aedba099fe2fdeb7f6c790090ada8`, 768×768. Layout was measured. Do not apply the legacy nine-cell map.
- Keying is `media.py sprites matte` (`imglib.matte.key`) on the full plate, then crop. No resize before the key. Keyed plate and cells are under `_src/wip/modular-voxel-walk/keyed/` and `cells/`. Color correction stays deferred. Clothes will be separate pieces.
- Saved mesh, flat skin, A-pose, closer three-quarter: Head 31269, Neck 1327, Chest 61161, Pelvis 18458, and both sides of upper arm 5240, forearm 2134, hand 448, thigh 38164, shin 8899, foot 2166.
- Joints: shoulder (30, −2, 162), elbow (31.2, −2, 132), wrist (30.7, −3, 106). Hip x is ±16, hip z 100, knee z 56, ankle z 8. Arms hang. Both feet share one depth. The side cell's long foot is a stride and was not copied.
- `review-shots/blender-front.png` and `blender-side.png` match this mesh. `blender-back.png` and `blender-three-quarter.png` are older and do not.
- `shots.py crop` gained `--spans` and `--overlay`. Selftest passed. `design/tools-shots.md` names both.

How the stills were measured:

Ortho renders are 512×768. Keyed sole row y244 lands on render y561. Cell x128 lands on front x255.5 and side x256. Scale is 346/232 = 1.491379. Opacity 0.45. Viewport background of the stills is `#373737`. Low screen x on the side is the front (−Y). World y = (screen x − 256) / 1.491. Crown z232 is render y216, sole z0 is y561.

`python tools/shots.py crop PNG --spans --bg "#373737"` prints the figure box and row runs. `--overlay` lays the keyed cell over the still. Tight crops (`tight3-*.png`) are the ones that were actually viewed. Full-frame overlays waste context on empty margin. Color-class width measurement was unreliable. Connected opaque runs and the overlay edge report are the measurements that worked. Two isolated review sessions did not write a measurement script. They zoomed until the turn cap.

What the last overlay measured:

These numbers describe the alien mesh. Matching them did not make her.

- Front cheek row y250: model 64 px, reference face 68 px. Jaw y266 is 29 px. Throat y282 is 24 px.
- Shoulder cap y314: model 118 px, reference outer 110 px. At y330 the arms are separate around a 54 px chest. Bust row y346: model chest 59 px, reference torso between the sleeves 56 px.
- Thighs y442–y458 match the pants (about 41 px, then 35 px). Knee y474 is 32/34 px against pants 30/31. Calf y490 is about 24 px inside the boot spans of 39/38.
- Side face front at y250 sits on the reference face. Bust front at y346 is about 4 voxels behind the jacket surface. Knee front at y474 matches the reference front.

Reference spans worth keeping (keyed cell pixels, 1 cell px was treated as 1 voxel): front arms separate from the torso at y96, torso there is 36–41 wide, and the wider rows above that are hair, neckband, and pauldrons. Pants: y148 about 44–45, y164 about 26–27, y180 about 20–21. y196 is the boot (26/25) and is not the shin. Side face skin sits near file x102–116 (world y about −26 to −12). The hair silhouette is much larger than the skull.

Decisions that still hold:

- Live Blender only. One script places the blocks. Hand placement is allowed if it makes her a person. Do not click cubes by hand in bulk, and do not drive the editor one voxel at a time.
- A-pose. Feet together at one depth. Face, when one exists, only on the front of the head.
- One skin color in the window until the body reads. No hair and no frame colors on the live body.
- The green piece is a closed neckband with no scarf tail. The little throat under the jaw was accepted (neck count 1327, about 14 wide). The shoulder mass must not continue that column.
- Hidden interiors, for later: hair interior `#1d130f` / `#0c0708`, neckband green continues under the hair, coat interior darker maroon, palms and unequipped body peach `#e89860`, soles a darker boot brown.
- The down-left cell `cells/r2c2.png` is the strict 3/4 check. It has not had a span pass. `keyed/up.png` has not either.
- Photos are not a pixel-perfect target. The four AI views disagree. Diagonals are checks. Do not build the body by intersecting cards or by lofting a front-pixel column.
- Boots are not on the shin. The jacket outline is not the bare torso. The hair outline is not the skull.

User corrections, in order:

The neck was longer than the forearm and too cylindrical. Arms were detached and too far forward. The upper body was too narrow for an hourglass, the chest was missing, the shoulder line was flat, the pelvis-to-waist join was wrong, the leg widths missed, and the posterior was flat. Block construction was accepted as the right kind of object.

Fifteen pixels was too long for a neck, partly the flat neck muscles. Then the little geo under the head was the right size, and the mountain-shaped neck muscles had to get much shorter. Do not lengthen that throat.

A later note said the legs were close aside from boot geo left on the shin. A later note replaced it: thighs are not triangular enough, calves must be much thinner than thighs, and the boots were hiding that. Do not put the boot width back on the shin.

The neck muscles became a pyramid. Too much jacket and neckband was carved off. The chest missed the frame. The waist snapped thinner than the legs. Posture was off. Then the front width lost the hourglass, and the neck/shoulder mass was still too big.

The shoulder triangle met the inner arm. The hip/waist looked over-carved. The legs stayed one width. The arms were too thick. On the side, the leg slope and posture were wrong, the butt sat in the wrong place, the chest was two balls, and the upper body hung off the front of the hips. The head shape was wrong.

The following mesh (the one saved here) was then called an alien. Span agreement is not a person.

Rejected shapes, do not revive:

Rectangle or power-4 cross sections, a statue loft, T-pose tubes, smooth clay ellipsoids, a side-photo wrap, a front-pixel column loft, a thin slab, a thick-box arm weld, a photo-painted mannequin with tentacle hair, boot-width shins, a pyramid shoulder cone, a tall neckband column, two breast spheres, an inner-arm-only shoulder triangle, a far-back seat blob, or a single egg head with a nose ball.

What this mesh tried:

Short throat. Round shoulder caps on the arm tops, with the chest held to the bust width instead of a triangle out to the outer arm. Bust as a forward disc slope, about 4 voxels inside the jacket. Hip narrower than the earlier plate. Thighs tapered along the pant spans into a forward knee cap. Calf thinner than the thigh, with a small belly, and no boot. Head as a face pad on a rounder cranium, cheek width near the face, plus a nose ridge, chin, and ears. Hands as a palm, four fingers, and an outer thumb.

Coordinates: +X her right, −Y front, +Z up. Parts parent to joint sockets. Limb meshes are built along local +Z. `z_start` below 0 sinks the root into the parent. `apply_review_style(False)` is the flat skin in the window.

Still to do:

Gear and hair as separate socket pieces. One 8-frame walk at `WALK_FPS` 8. A pixel-art bake. A synced side-by-side against `assets/sprites/player/female/walk_DIRECTION_N.png`, and the path reported. After approval only: models under `_src/sources/models`, walk frames in the female walk assets, and design-doc workflow notes. The comparison walk frames were not checked for order or timing.
