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
- If/after everything gets approved, land the model sources under `_src/sources/models` and the new walk animation frames in the relevant `assets` location.
- I have no idea how the Blender MCP works or how difficult this modelling task will be. If I were handling this task myself, I would probably chroma key the Front/Back/Left/Right cells from the bible, import them into Blender as flat face placed next to one another (with the Front/Back placed back-to-back in on location and the Left/Right frames intersecting them perpendicularly), and then I would extrude the pixels as voxels until it visibly replicated the bible from all directions. That would require some manual adjustments on the feet positionings on the side views, but I think that would be the optimal route for a human tackling this task. This may or may not be the ideal route for an agent, but I figured I would mention it in case it helps guide you to the ideal approach for completing this work.
- Since there is no documentation for this workflow, it may be helpful for you to take notes about how to accomplish similar tasks in the future. If this workflow is viable and the results are approved, we will be using this same workflow for generating new art and animations for all of the enemies in the game, so you'll want to update the design docs with usage and workflow documentation if I approve the work.
- `blender` has been added to the system path, so you can easily launch it via a shell command whenever needed without having to manually locate the Blender executable.
