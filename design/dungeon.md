# Dungeon generation and floors

Status: binding design + live snapshot  
Read when: gen, streaming, guardian doors, fog, crystals
Code: `scripts/dungeon/gen.gd`, `scripts/world/dungeon.gd`, `dungeon_boot.gd`, `dungeon_stream.gd`, `geo_stream.gd`, `map_act.gd`, `dungeon_props.gd`, `boss_door.gd`, `net.gd`, `crystal_place.gd`, `floor_crystal.gd`

This file is the door. Open the Job-table sibling only when that row matches.

Occupancy is the maze. Carve the 1 m grid first. Rooms stay rectangles. Halls are segments plus width. Clean one-tile teeth and accidental stair-steps. Unused stone stays uncarved. Extra loops that fail hug clearance are skipped, not welded. There is no floor-wide rim.

Publish is one-way. Gen writes hall runs. Stream instances that recipe. Volume skins provided runs. Buffer reads cleaned occupancy and hangs lights on interior faces. Outline bake lives on the gen job. Stream does not invent a lip. Volume does not extract a silhouette.

Floor ready builds the map image and binds it to the HUD well. The overlay starts hidden; map_view only toggles it.

| Job | Open |
|-----|------|
| maze carve, hall segments, size rebalance ledger, accidental jogs, deadend termini, unused stone, hug clearance, outline spans | `design/dungeon-gen.md` |
| PREPARE plaque, extraction clerks, stair hold, reveal disk | `design/dungeon-gates.md` |
| transport decades, warp silence, spur length | `design/dungeon-crystals.md` |
| RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo, clip-free chunk instance | `design/dungeon-stream.md` |
