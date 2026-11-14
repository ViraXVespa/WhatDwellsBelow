# Modular 3D walk proof (Blender + bake)

id: modular-voxel-walk-proof
owner: build
status: open
done-when: Base body (no hair/equipment) created in Blender as a conventional modular mesh; front view matches the Bible front cell; side view produces a true 1:1 overlay against the Bible side cell (stride foot included); after approval, freely re-posed for walk; default gear later attached as modular pieces; walk animation looks good from all angles and matches current art style/feel; sprites baked with processing that preserves 2D pixel-art vibe; synced side-by-side comparison of current female walk vs new baked result produced and path reported.
resume: python tools/slice.py open art_pipeline --task modular-voxel-walk-proof

## Goal
Create a conventional modular 3D character in Blender (base body first, then attachable gear) that matches the current character’s look and body dimensions. The body must first match the Bible front cell, then be posed so the side view produces a true 1:1 overlay against the Bible side cell (including the stride foot). After that match is approved, freely re-pose it for animation. Animate one walk cycle that looks and feels like the existing art style. Bake to 2D sprites with processing that keeps the pixel-art vibe, then produce a side-by-side comparison. This establishes the foundation for future paper-doll equipment and customization.

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
1. **Base body (front lock)**  
   Using Blender (MCP available), create an unequipped conventional modular 3D body (no hair, no equipment) as the modular root. Match the front silhouette, proportions, and key landmarks to the Bible front cell under the existing registration. Include attachment sockets for gear and hair.

2. **Side 1:1 match**  
   Pose or adjust the same mesh so the side view produces a true 1:1 overlay against the Bible side cell, including the stride/offset foot. Do not force feet together or ignore the stride during this verification step. Output comparison stills.

3. **Approval gate**  
   Stop for user review of the front + side 1:1 match. Only after the body reads as her proceed.

4. **Free re-pose + default gear**  
   After approval, freely re-pose the body (clean A-pose or as needed). Then take the equipment and hair visible on the current female bible character and add them as the default modular pieces attached to the base. Confirm they can be swapped or disabled independently.

5. **Animation**  
   One walk cycle only. The assembled character (base + default gear) must look good from all angles needed for visibility. Final animations should look and feel like the current art style—sync and model-mismatch issues fixed, everything smoothed out.

6. **Bake**  
   Bake the animated character to sprites. Apply special processing so the result keeps the 2D pixel-art vibe of the existing assets.

7. **Comparison**  
   Produce a synced side-by-side GIF or short video of the current female walk animations next to the new baked result. Report the output path.

## Done when
- Unequipped conventional modular base body exists in Blender with attachment points.
- Front view matches the Bible front cell.
- Side view produces a true 1:1 overlay against the Bible side cell (stride foot included).
- After approval, body can be freely re-posed.
- Default gear (bible equipment + hair) is attached and modular.
- Walk animation looks good from all relevant angles and matches current art style/feel.
- Baked sprites preserve the pixel-art look.
- Side-by-side comparison exists and its path is reported.

## Notes from Vira
- This is a unique task, so a lot of the standard slice protocols won't apply to this work. You also don't have to stop for compact breaks. Just continue through the work until the task is done and auto-compact will hit when it hits.
- If/after everything gets approved, land the model sources under `_src/sources/models` and the new walk animation frames in the relevant `assets` location.
- Prior pure-voxel / ellipsoid / disc / tube construction and the voxelizer CLI both failed (alien results and eldritch horrors). The locked approach is a conventional modular mesh: front-match first, then pose for true 1:1 side overlay (stride included), then free re-pose after approval. Start with body only.
- Since there is no documentation for this workflow, it may be helpful for you to take notes about how to accomplish similar tasks in the future. If this workflow is viable and the results are approved, we will be using this same workflow for generating new art and animations for all of the enemies in the game, so you'll want to update the design docs with usage and workflow documentation if I approve the work.
- `blender` has been added to the system path, so you can easily launch it via a shell command whenever needed without having to manually locate the Blender executable.

## Current state
The base body does not read as the character. On 2026-11-09 the user called the latest mesh an alien and stopped the sculpt. Status stays open. Do not animate, add hair, paint frame colors, rekey, or land sources until a later body reads as her.

Resume next from the refined plan: conventional modular mesh, front lock first, then side 1:1 pose match (stride foot included) for comparison. The live file is `_src/wip/modular-voxel-walk/female-modular.blend`. One script builds it: `_src/wip/modular-voxel-walk/build_female.py`. Blender is on PATH. Use the user's live Blender window and the Blender MCP. Do not start `blender --background`.

What is on disk:

- Bible `_src/new_bibles/female.png`, sha256 `69ca2f5da6e79d8228f457b10a702fd1bc1aedba099fe2fdeb7f6c790090ada8`, 768×768. Layout was measured. Do not apply the legacy nine-cell map.
- Keying is `media.py sprites matte` (`imglib.matte.key`) on the full plate, then crop. No resize before the key. Keyed plate and cells are under `_src/wip/modular-voxel-walk/keyed/` and `cells/`. Color correction stays deferred. Clothes will be separate pieces.
- Previous mesh (voxel-style) failed identity check. New work uses conventional modular mesh under the refined front-then-side-1:1 plan.
- Joints and measurements from prior session remain useful for registration but the construction method has changed.

## Approach (locked)
1. Build conventional modular body whose front matches the Bible front cell (silhouette, proportions, landmarks).
2. Pose/adjust the same mesh so the side view is a true 1:1 overlay of the Bible side cell, including the stride foot.
3. Output comparison stills and stop for approval.
4. Only after approval: free re-pose, add modular gear, animate walk, bake with pixel-art processing, produce side-by-side.
