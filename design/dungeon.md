# Dungeon generation and floors

Status: binding design + live snapshot  
Read when: gen, streaming, guardian doors, fog, crystals
Code: `scripts/dungeon/gen.gd`, `scripts/world/dungeon.gd`, `dungeon_boot.gd`, `dungeon_stream.gd`, `dungeon_geo_stream.gd`, `dungeon_map_act.gd`, `dungeon_props.gd`, `boss_door.gd`, `crystal_net.gd`, `crystal_place.gd`, `floor_crystal.gd`  


This file is the door. Open the Job-table sibling only when that row matches.

Gen keeps the 1 m grid for rooms, halls, placement, fog, and chunk index. Hall connections are segments plus width. Room footprints stay rectangles. Gen authors both rims as polylines, fillets and jags those vertices, folds collinear runs, then rasterizes that polyline into solid. outline_spans is that polyline, not a trace of the raster. Collision is BoxShape on that solid. Volume skins the provided spans. Stream instances the published recipe. Buffer occupancy reads solid only. No consumer invents a second silhouette.

| Job | Open |
|-----|------|
| authored polylines, hall segments, size rebalance ledger, walkable solid, fillet jag, bake from rims, deadend termini | `design/dungeon-gen.md` |
| PREPARE plaque, extraction clerks, stair hold, reveal disk | `design/dungeon-gates.md` |
| transport decades, warp silence, spur length | `design/dungeon-crystals.md` |
| RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo | `design/dungeon-stream.md` |
