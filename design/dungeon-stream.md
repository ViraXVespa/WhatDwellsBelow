# Dungeon — streaming

Status: binding design + live snapshot  
Read when: RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo


## Live snapshot — streaming

`dungeon_stream.gd` streams enemy jobs. `dungeon_geo_stream.gd` streams floor/wall meshes and wall collision the same way so a 432 map can stay on budget. Default chunks instance cleaned 1 m floor rects, 1 m wall faces, and matching BoxShapes. Stream does not invent a floor-wide ribbon. An angled piece is instanced as its published packet: band floor, slanted runs, hulls that match that mesh. Do not derive a lip by clipping 4-connected cells on a tile chunk. Live _emit_floor_lip / _clip_cell as the default path is the miss on a maze hall.

| Constant | Cells | Meaning |
|----------|-------|---------|
| `STREAM_IN` | 28 | Pending enemy job becomes live |
| `STREAM_OUT` | 42 | Live job despawns if not in combat |
| `CHUNK` | 32 | Geometry job size |
| `RING_IN` / `RING_OUT` | 1 / 2 | Geo chunks kept around the player |
| `PER_FRAME` | 1 | Neighbor geo chunks built per follow after the current chunk. Boot passes delta 0 so it does not trip a burst. |

Job states: `pending`, `live`, `cleared`. Do not stream out an enemy the player is fighting.
Geometry jobs never go `cleared`; they sleep back to `pending`.
Only chunks that contain a floor cell, or a wall adjacent to a floor, are queued.
`CHUNK`, `RING_IN`, and `RING_OUT` stay coarse 1 m. A chunk queues if it holds a cleaned floor cell, a wall adjacent to floor, or any cell owned by an angled piece. Tile-chunk collision is BoxShape on void that touches that floor. Piece-chunk collision is the packet hull. Do not stream a second staircase under a slanted wall.
`stream_all` / `force_all` still force enemy jobs; geometry stays proximity-streamed so smoke does not bake the whole floor.
Jobs whose anchor sits inside an activated crystal’s arrive radius stay `cleared`.
