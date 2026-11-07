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

## Notes
If/after everything gets approved, land the sources under `_src/sources/models`.
