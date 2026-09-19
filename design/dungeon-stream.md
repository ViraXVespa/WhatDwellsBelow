# Dungeon — streaming

Status: binding design + live snapshot  
Read when: RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo


## Live snapshot — streaming

`dungeon_stream.gd` streams enemy jobs. `dungeon_geo_stream.gd` streams floor/wall MultiMeshes and wall collision the same way so 432×432 stays inside the 60 FPS budget. Chunks draw every floor and facing wall they contain.

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
`stream_all` / `force_all` still force enemy jobs; geometry stays proximity-streamed so smoke does not bake the whole floor.
Jobs whose anchor sits inside an activated crystal’s arrive radius stay `cleared`.
