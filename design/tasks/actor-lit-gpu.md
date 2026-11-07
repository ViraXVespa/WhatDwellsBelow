# Handoff: graphics

id: actor-lit-gpu
owner: build
status: open
done-when: actor sprites and ground marks sample the baked light texture on the GPU, the CPU sample_xz path is gone from the hot frame, a shared mark pool is in use, static props no longer carry ActorLit, sole/quad data is precomputed at load, User confirms the look, gates pass
resume: python tools/slice.py open graphics --task actor-lit-gpu
area: graphics
door: graphics
job: graphics.actor
from: survey session (id unknown) in C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-graphics-20261107-1257
Your first command, before any file read or memory topic: python tools/slice.py start --door graphics --job graphics.actor --from-task actor-lit-gpu
The survey is done and the answers below stand; ask again only what Open questions lists or what a discovery changes. Review only this unit's baselines/references; direct image reads need the explicit task grant.

## Task (her words)
Move actor lighting and marks fully to the GPU with a shared pool.

`scripts/graphics/actor_lit.gd` attaches a child node to lit actors. Every frame its `_process` calls `LightRt.sample_xz` (CPU bilinear on the light Image: up to 4 `get_pixel` + lerp) solely to set `spr.modulate`. The mark meshes do not even receive that sample; they get other shader parameters.

This duplicates work the ground/wall shaders already do (or will do after the light-sample simplification) by reading `light_tex` on the GPU. It also allocates and updates `MARK_N = 3` MeshInstance3D nodes per actor every frame, whether or not the actor is near a light.

Currently bound on:
- Player (`player_setup.gd`)
- Dummy (`dummy.gd`)
- Vendor (camp spot)
- Every enemy (`enemy_ready.gd`)

Sole positions are already baked (`actor_soles.json` via `soles.gd`). Runtime still recomputes pin/lift math and builds quad meshes on the fly.

Required outcome, in her words:
1. Sprite tint comes from a GPU sample of `light_tex` (same UV approach the ground shader uses). No per-frame CPU `sample_xz`.
2. Ground marks also sample on the GPU (or are driven by a shared GPU path). No CPU light read for them.
3. Shared mark pool: starts with 6 nodes. Light volumes (or equivalent spatial triggers) set a dirty flag only when an actor inside them moves. Actor enters a light volume, take a mark node from the pool (create a new one only if the pool is empty). Actor exits, return the node to the pool. Stationary actors outside lights cost nothing.
4. Remove ActorLit from the vendor and the dummy (they do not move and do not need dynamic marks).
5. Precompute remaining sole offsets and cache quad meshes during load so none of that work occurs during gameplay frames.
6. Updates are move-only or dirty-flag driven.

Visual acceptance, in her words: sprite lighting and ground marks must match the current look (User confirms). Entering or leaving light may have at most a one-frame pop; no persistent errors, no marks left behind, no missing marks on moving actors. Static vendor and dummy must not look broken after ActorLit removal (static tint or no extra lighting is fine).

## Q0 answers so far
- result look: match the current sprite tint and ground marks
- reference: the current game. No new art
- out of bounds, incl. frames or layouts already built: new art; graphics.env, graphics.ground quilts, graphics.volume, and a radiance-buffer rewrite. Dynamic marks stay off the vendor and the dummy

## Her decisions
- First group is actor-lit-gpu, on graphics.actor.
- The required outcome in Task (her words) stands: GPU `light_tex` sample for sprites and marks, no per-frame CPU `sample_xz` on the hot frame, shared mark pool starting at 6, light-volume dirty updates, ActorLit off the vendor and the dummy, sole offsets and quad meshes precomputed at load, move-only or dirty-flag updates.
- Visual bar: match the current look. At most a one-frame pop when an actor enters or leaves light. Vendor and dummy may keep a static tint or no extra lighting.

## Chosen surfaces, in order
- actor-lit-gpu on graphics.actor (this session's unit): GPU light sample, shared mark pool, ActorLit off the vendor and dummy, sole and quad data precomputed at load
- Player sprite and marks in the hub yard (flow camp-feet-px)
- One enemy sprite and marks (flow camp-mark-matrix)
- Hub vendor and combat dummy after ActorLit removal (flow vendor-stall, plus the camp dummy)

## Ledger
Decisions I made that were yours: mapped the task she named onto door graphics, job graphics.actor, area graphics. She chose the task, and the door has no unit queue.
Assumptions carried from memory or docs: sole rows are already baked (`scripts/data/actor_soles.json`, `Soles.warm`); play does not scan sticker pixels for those rows. Character Sprite3D stickers stay unshaded and take light from the light-RT multiply.
Also changed: none

## Baselines for the chosen surface
none. Every flow from `shots.py flow --survey` is band never shot, so this survey took no stills. Shoot before the change, then again after, on the same setup: camp-feet-px (player idle at zoom 8, marks off and on); camp-mark-matrix (player kinds and enemy types, idle walk attack); dungeon-marks (floor 1 seed 42, wall torch nearest the goblin-bat ambush); vendor-stall (stall, posts, front face, foot light). The camp dummy has no flow of its own; shoot it with the hub statics.

## Files and functions to touch
scripts/graphics/actor_lit.gd: _tint, _process, _tick, _lay, bind. `_tint` sets `spr.modulate` from `LightRt.sample_xz`.
scripts/graphics/light_rt.gd: sample_xz. CPU bilinear. Debug checkers also call it; the hot-frame ban is the actor path.
scripts/graphics/actor_lit/lit_k.gd: MARK_N, SHADE. `MARK_N` is 3 marks per actor today. `SHADE` already samples `light_tex` when `sun_cancel` is on. The shared pool starts at 6 and replaces the per-actor nodes.
scripts/graphics/ground_shader.gd: TAP_BODY, shader. `TAP_BODY` is the ground UV tap (`light_origin`, `light_span`, `textureLod`). Sprite tint uses that approach. `shader-light-sample` is not an open task.
scripts/graphics/actor_lit/soles.gd: warm, _soles
scripts/graphics/actor_lit/place.gd: _place
scripts/graphics/actor_lit/slots.gd: _sync_slot
scripts/world/player/player_setup.gd: ready
scripts/combat/enemy/enemy_ready.gd: ready
scripts/combat/dummy.gd: _ready
scripts/world/camp.gd: _step_spot_vendor

## Did not work
- Did not work: `python tools/shots.py flow --flow camp-feet-px,camp-mark-matrix,dungeon-marks,vendor-stall --baseline _logs/actor-lit-before` (`_logs/shot-flow/20261107-142828-shot-flow.txt`). camp-mark-matrix and vendor-stall passed. camp-feet-px stopped on plant_feet `missed flat` (idle_down soles are level). dungeon-marks stopped on walls_planted `missed: lit 0.940 behind-wall 0.765 ambient 0.741 worst 0.794 (n 18961/33)`, the same numbers as the before shot. Wall lighting stays on graphics.volume.
- Did not work: `python tools/gate.py build --batch` (`_logs/build-gate/20261107-143042-build-gate.txt`) failed only the sole stamp, `934132e15a2707c5` != recomputed `69e1e86544b5a793`. The table was the Week 10 bake; the refactorer moved the scan scripts afterward. `python tools/bake.py soles` (`_logs/bake-soles/20261107-143737-bake-soles.txt`) rewrote the stamp to `69e1e86544b5a793`. 463 rows, 0 coordinate changes.
- Remaining: the User confirms sprite tint and ground marks, including the vendor and the training dummy with ActorLit removed. The still flows do not walk an actor through a light.

## Open questions
none

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

Survey finding: `shader-light-sample` is not an open task. `scripts/graphics/ground_shader.gd` `TAP_BODY` is the cheap `textureLod` tap.

## Prove
- Import / gd-load checks.
- Before/after shots of player, an enemy, and the hub statics.
- Confirm in the debugger or logs that `sample_xz` is no longer called per frame for actors.
- User confirmation of look and mark behavior.
