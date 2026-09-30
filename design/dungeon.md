# Dungeon generation and floors

Status: binding design + live snapshot  
Read when: gen, streaming, guardian doors, fog, crystals
Code: `scripts/dungeon/gen.gd`, `scripts/world/dungeon.gd`, `dungeon_boot.gd`, `dungeon_stream.gd`, `dungeon_geo_stream.gd`, `dungeon_map_act.gd`, `dungeon_props.gd`, `boss_door.gd`, `crystal_net.gd`, `crystal_place.gd`, `floor_crystal.gd`  


This file is the door. Open the Job-table sibling only when that row matches.

Gen keeps the 1 m grid as the maze: rooms, halls, placement, fog, and chunk index. Hall connections are segments plus width. Room footprints stay rectangles. Carve the grid first. Clean one-tile teeth and accidental stair-steps. Do not fillet or jag the whole rim. A small set of connections may become angled pieces (27 / 33 / 45) when that path beats a long cardinal dogleg. Those pieces are first-class packets: floor band, slanted walls, and collision hulls that match the mesh. Everything else stays 1 m faces and 1 m boxes. Volume skins 1 m faces by default and ribbons only on angled pieces. Stream instances that recipe. Buffer occupancy reads the cleaned grid plus piece hulls. No consumer builds a floor-wide second silhouette.

Floor ready builds the map image and binds it to the HUD well. The overlay starts hidden; map_view only toggles it.

| Job | Open |
|-----|------|
| maze carve, hall segments, size rebalance ledger, accidental jogs, angled halls, deadend termini | `design/dungeon-gen.md` |
| PREPARE plaque, extraction clerks, stair hold, reveal disk | `design/dungeon-gates.md` |
| transport decades, warp silence, spur length | `design/dungeon-crystals.md` |
| RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo | `design/dungeon-stream.md` |

