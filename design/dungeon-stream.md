# Dungeon — streaming

Status: current plan  
Read when: RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo, clip-free chunk instance

## Streaming

Enemy jobs and floor/wall geometry both stream around the player so a whole floor stays inside the 60 FPS budget.

Stream instances gen's published runs. Ribbon boxes fire when those runs exist, not only when the outlined flag is set. WallRects.merge collision is fallback for chunks with no runs. It does not derive a wall, a lip, or a silhouette. Floor edge, wall ribbon recipe, and BoxShapes on a slant follow the same published origin, delta, and normal. Interior floor may stay merged rects. Do not clip 4-connected cells to invent an edge. Do not call WallRects.merge on wall_cells to build a stair lip. Wall collision is BoxShape on void that touches that bounded solid, flush with the published run, not a 1 m slab and not a second staircase.

Stream radii and chunk sizes: tunables-world, Dungeon generation.

Job states: `pending`, `live`, `cleared`. Do not stream out an enemy the player is fighting.
Geometry jobs never go `cleared`; they sleep back to `pending`.
Only chunks that contain a floor cell, or a wall adjacent to a floor, are queued.
`CHUNK`, `RING_IN`, and `RING_OUT` stay coarse 1 m. A chunk queues if it holds any published floor from solid, or a run facing that floor. Streamed collision is that run-bounded solid inside the chunk.
`stream_all` / `force_all` still force enemy jobs; geometry stays proximity-streamed so smoke does not bake the whole floor.
Jobs whose anchor sits inside an activated crystal’s arrive radius stay `cleared`.

Enter stamp timing is not this job.
