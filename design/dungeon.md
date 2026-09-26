# Dungeon generation and floors

Status: binding design + live snapshot  
Read when: gen, streaming, guardian doors, fog, crystals
Code: `scripts/dungeon/gen.gd`, `scripts/world/dungeon.gd`, `dungeon_boot.gd`, `dungeon_stream.gd`, `dungeon_geo_stream.gd`, `dungeon_map_act.gd`, `dungeon_props.gd`, `boss_door.gd`, `crystal_net.gd`, `crystal_place.gd`, `floor_crystal.gd`  


This file is the door. Open the Job-table sibling only when that row matches.

Gen keeps the 1 m carve for rooms, MST, halls, and placement. Gen owns the post-carve outline and the walkable solid rasterized from it. Collision and wall faces follow that solid. Volume does not invent the silhouette.

| Job | Open |
|-----|------|
| MST loops, deadend termini, hall widths, size rebalance ledger | `design/dungeon-gen.md` |
| PREPARE plaque, extraction clerks, stair hold, reveal disk | `design/dungeon-gates.md` |
| transport decades, warp silence, spur length | `design/dungeon-crystals.md` |
| RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo | `design/dungeon-stream.md` |
