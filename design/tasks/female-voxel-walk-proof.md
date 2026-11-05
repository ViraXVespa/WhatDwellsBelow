# Female voxel walk proof (external voxelizer)

id: female-voxel-walk-proof
owner: build
status: open
done-when: Voxelizer submodule built; female quad sheet created; voxel model generated; Blender walk recreated; side-by-side comparison GIF/video produced and path reported
resume: python tools/slice.py open art_pipeline --task female-voxel-walk-proof

# Task: Female voxel walk proof (external voxelizer)

## Goal
Set up the pure-Go CLI voxelizer from https://github.com/ViraXVespa/2d-to-3d-voxelizer-cli as an optional external tool under tools/extern, generate a voxel model from the female character bible frames, recreate a walk animation in Blender that matches the existing female walk, and produce a side-by-side comparison GIF (or video) of the current walk animations vs the new voxel-based ones, in sync.

## Setup the external tool (do this first)
1. Create tools/extern/ if it does not exist.
2. Add the voxelizer as a git submodule so its history stays in its own repo and it is not automatically pulled with the main WhatDwellsBelow repo:
   git submodule add https://github.com/ViraXVespa/2d-to-3d-voxelizer-cli.git tools/extern/2d-to-3d-voxelizer-cli
   git submodule update --init --recursive
3. Confirm the submodule is registered in .gitmodules and that the directory is present. Commit the submodule addition to the main repo (do not commit the voxelizer’s own changes into WDB).
4. Build the CLI (Go is already on PATH):
   cd tools\extern\2d-to-3d-voxelizer-cli
   go build -o voxelizer.exe .
   Verify voxelizer.exe -h works.

## Frame preparation
5. From _src/new_bibles/female.png (3x3 grid on solid magenta background), extract the four directional views needed for quad mode: Left, Front, Right, Back (in that exact order).
6. Key out the magenta background if present.
7. Assemble them into a single horizontal sprite sheet (equal-width frames, centered artwork) that the voxelizer accepts for -mode quad.
8. Save the sheet somewhere convenient for the task (e.g. tools/extern/female_quad.png or a temp dir).

## Voxelize
9. Run the CLI:
   tools\extern\2d-to-3d-voxelizer-cli\voxelizer.exe -input path\to\female_quad.png -mode quad -depth 1.5 -output tools\extern\female_voxel.obj
   Adjust depth if needed for a reasonable result. Confirm .obj + .mtl are written.

## Blender + animation (MCP)
10. Open the .obj in Blender via MCP.
11. Using the existing female walk frames / source videos (up/down/left/right) as reference, recreate a walk cycle that closely matches the current female walk timing and poses. Rig / pose the voxel model as needed so the silhouette and motion read similarly.
12. Render the new walk from the game’s camera angles (or the primary ones used by the current animations) so the frames can be compared directly.

## Comparison output
13. Produce a side-by-side GIF (preferred if easier) or short video that plays the current female walk animations next to the new voxel-based ones, synchronized.
14. Place the comparison file somewhere easy to review (e.g. project root or tools/extern/) and report its path.

## Done when
- Voxelizer is a submodule under tools/extern/2d-to-3d-voxelizer-cli and builds with only Go.
- A quad-mode voxel model has been generated from the female bible frames.
- A walk animation has been created in Blender that resembles the current female walk.
- A synced side-by-side comparison GIF/video exists and its path is reported.
- Any changes to the voxelizer itself remain only in its own repo (not committed into WDB).

## Notes
- Prefer quad mode unless six-sided is clearly better and the top/bottom frames are easy to extract.
- Use existing walk reference material in the repo; do not invent new timing.
- If the voxelizer CLI flags differ slightly from the example above, follow the tool’s actual -h output.
- Keep the main WDB repo clean of the voxelizer’s internal history.
- Commands above use Windows paths and .exe; adjust only if the environment differs.
