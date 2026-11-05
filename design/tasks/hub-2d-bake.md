# Bake hub visuals to 2D sprites / viewport texture while preserving identical look and feel

id: hub-2d-bake
owner: build
status: open
done-when: the hub’s visible geometry is replaced by baked 2D sprites or a single viewport texture that is visually identical to the current 3D hub; collision and interaction feel identical; no gameplay regressions; User confirms; gates pass
resume: python tools/slice.py open hub --task hub-2d-bake

## Background
The hub (`scripts/world/camp.gd` + `camp_build.gd` and helpers) is built from procedural 3D:
- Ground: PlaneMeshes with ShaderMaterial.
- Walls / buildings: SurfaceTool ArrayMeshes / MeshInstance3D with StandardMaterial3D or shaders.
- Various spot props.

Under the Compatibility renderer on web this is expensive even though the scene is static. The goal is to bake the **visible** result so the running scene draws far less 3D geometry, while the player experience (appearance, lighting, collision, interaction) stays the same.

## Critical constraints
- The baked result must look and feel identical to the current unbaked 3D hub. Same lighting, same proportions, same readability, same interaction prompts and ranges.
- Do **not** leave a full 3D collision mesh “just in case” if a simpler 2D or height-map collision representation can preserve the exact same walkable space and interaction volumes. Prefer the lightest collision that still matches current feel.
- All existing interactables (crystal, anvil, vendor, receptionist, dumpster, billboard, etc.) must continue to work at the same positions and ranges.
- Camera framing, zoom, and any hub-specific lighting must be preserved.

## Required work
- Capture or bake the current hub appearance (viewport texture, pre-rendered sprites, or equivalent) at the quality needed for identical look.
- Replace the live procedural MeshInstance3D drawing with that baked representation.
- Rebuild or simplify collision and interaction areas so movement and “press to interact” feel unchanged.
- Remove or disable the now-unused 3D visual nodes so they no longer cost draw calls.
- Verify on web export as well as editor, because the original problem is phone-browser FPS.

## Visual / feel acceptance
- Side-by-side or before/after comparison must be effectively identical to the User.
- Walking, dashing, and interacting must feel the same.
- No new z-fighting, missing props, or lighting discrepancies.

## Notes
This is independent of the actor-lighting and shader-sample work, but final lighting polish is easier if the cheap light sample is already in place. Large structural change; expect iteration on the bake resolution and collision simplification.
