# Dungeon — streaming

Status: binding design + live snapshot  
Read when: RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo


## Live snapshot — streaming

`dungeon_stream.gd` streams enemy jobs. `dungeon_geo_stream.gd` streams floor/wall MultiMeshes and wall collision the same way so 432×432 stays inside the 60 FPS budget. Chunks instance gen's published floor solid, span ribbon, and BoxShape recipe. Stream does not derive a wall. Floor planes and wall BoxShapes on a slant follow outline_spans. Do not merge 4-connected cells into a stair lip the polyline already closed. Wall collision is BoxShape on void that touches that bounded solid, not a 1 m slab and not a second staircase.

| Constant | Cells | Meaning |
|----------|-------|---------|
| `STREAM_IN` | 28 | Pending enemy job becomes live |
| `STREAM_OUT` | 42 | Live job despawns if not in combat |
| `CHUNK` | 32 | Geometry job size |
| `RING_IN` / `RING_OUT` | 1 / 2 | Geo chunks kept around the player |
| `PER_FRAME` | 3 | Neighbor geo chunks built per follow (9 on a long tick) |

Job states: `pending`, `live`, `cleared`. Do not stream out an enemy the player is fighting.
Geometry jobs never go `cleared`; they sleep back to `pending`.
Only chunks that contain a floor cell, or a wall adjacent to a floor, are queued.
`CHUNK`, `RING_IN`, and `RING_OUT` stay coarse 1 m. A chunk queues if it holds any fine floor from solid, or a span facing that floor. Streamed collision is that span-bounded fine solid inside the chunk, not a 1 m box the polyline vacated and not a 4-connected stair past the ribbon.
`stream_all` / `force_all` still force enemy jobs; geometry stays proximity-streamed so smoke does not bake the whole floor.
Jobs whose anchor sits inside an activated crystal’s arrive radius stay `cleared`.
