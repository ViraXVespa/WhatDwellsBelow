# Move actor lighting and marks fully to the GPU with a shared pool

id: actor-lit-gpu
owner: build
status: open
done-when: actor sprites and ground marks sample the baked light texture on the GPU, the CPU sample_xz path is gone from the hot frame, a shared mark pool is in use, static props no longer carry ActorLit, sole/quad data is precomputed at load, User confirms the look, gates pass
resume: python tools/slice.py open graphics --task actor-lit-gpu

## Background
`scripts/graphics/actor_lit.gd` attaches a child node to lit actors. Every frame its `_process` calls `LightRt.sample_xz` (CPU bilinear on the light Image: up to 4 `get_pixel` + lerp) solely to set `spr.modulate`. The mark meshes do not even receive that sample; they get other shader parameters.

This duplicates work the ground/wall shaders already do (or will do after the light-sample simplification) by reading `light_tex` on the GPU. It also allocates and updates `MARK_N = 3` MeshInstance3D nodes per actor every frame, whether or not the actor is near a light.

Currently bound on:
- Player (`player_setup.gd`)
- Dummy (`dummy.gd`)
- Vendor (camp spot)
- Every enemy (`enemy_ready.gd`)

Sole positions are already baked (`actor_soles.json` via `soles.gd`). Runtime still recomputes pin/lift math and builds quad meshes on the fly.

## Required outcome
1. Sprite tint comes from a GPU sample of `light_tex` (same UV approach the ground shader uses). No per-frame CPU `sample_xz`.
2. Ground marks also sample on the GPU (or are driven by a shared GPU path). No CPU light read for them.
3. Shared mark pool:
   - Starts with 6 nodes.
   - Light volumes (or equivalent spatial triggers) set a dirty flag only when an actor inside them moves.
   - Actor enters a light volume → take a mark node from the pool (create a new one only if the pool is empty).
   - Actor exits → return the node to the pool.
   - Stationary actors outside lights cost nothing.
4. Remove ActorLit from the vendor and the dummy (they do not move and do not need dynamic marks).
5. Precompute remaining sole offsets and cache quad meshes during load so none of that work occurs during gameplay frames.
6. Updates are move-only or dirty-flag driven.

## Visual acceptance
- Sprite lighting and ground marks must match the current look (User confirms).
- Entering/leaving light may have at most a one-frame pop; no persistent errors, no marks left behind, no missing marks on moving actors.
- Static vendor and dummy must not look broken after ActorLit removal (static tint or no extra lighting is fine).

## Dependencies / order
The ground/wall shader should already be using a cheap hardware sample (shader-light-sample task). This task can proceed in parallel if the GPU sample function is stable, but final visual sign-off is easier after that simplification lands.

## Prove
- Import / gd-load checks.
- Before/after shots of player, an enemy, and the hub statics.
- Confirm in the debugger or logs that `sample_xz` is no longer called per frame for actors.
- User confirmation of look and mark behavior.
