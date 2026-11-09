# Dungeon — streaming

Status: current plan  
Read when: RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo, clip-free chunk instance  
Code: `scripts/world/dungeon_geo/geo_stream.gd` (chunk ring: setup, follow, tick, activate_job, sleep_job), `scripts/world/dungeon_geo/stream_clip.gd` (published runs on a chunk: _wall_runs, _clip_span, _faces_on_chunk), `scripts/world/dungeon_geo/stream_emit.gd` (_add_wall_body, _surface_tris, _emit_floors), `scripts/world/wall_rects.gd` (solid_cells, volume_cells; merge for interior floor only), `scripts/world/dungeon_stream.gd` (enemy job ring)

Shared with graphics.volume: in stream_emit.gd, `_emit_shell` and the lip helpers are the volume skin; this job owns the wall body and the chunk lifecycle. Runs come from dungeon.gen; neither job edits them.

## Streaming

Enemy jobs and floor/wall geometry both stream around the player so a whole floor stays inside the 60 FPS budget.

Stream instances gen's published runs as one welded shell per chunk when those runs exist, not only when the outlined flag is set. One StaticBody per chunk uses a concave shape from the wall triangles of that shell. Thickness sits into the solid, flush with the floor edge. There is no per-ribbon BoxShape and no WallRects.merge fallback for wall collision. The shell does not derive a wall, a lip, or a silhouette. Interior floor may stay merged rects. Do not clip 4-connected cells to invent an edge. Do not call WallRects.merge on wall_cells to build a stair lip. Do not merge wall_cells into the body. A chunk with no published runs keeps no wall body. Missing exits stay a gen miss.

Stream radii and chunk sizes: tunables-world, Dungeon generation.

Job states: `pending`, `live`, `cleared`. Do not stream out an enemy the player is fighting.
Geometry jobs never go `cleared`; they sleep back to `pending`.
Only chunks that contain a floor cell, or a wall adjacent to a floor, are queued.
`CHUNK`, `RING_IN`, and `RING_OUT` stay coarse 1 m. A chunk queues if it holds any published floor from solid, or a run facing that floor. Streamed collision is that run-bounded solid inside the chunk.
`stream_all` / `force_all` still force enemy jobs; geometry stays proximity-streamed so smoke does not bake the whole floor.
Jobs whose anchor sits inside an activated crystal’s arrive radius stay `cleared`.

Enter stamp timing is not this job.
