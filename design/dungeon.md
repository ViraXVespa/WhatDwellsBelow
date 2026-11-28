# Dungeon generation and floors

Status: current plan  
Read when: gen, streaming, guardian doors, fog, crystals
Code: `scripts/dungeon/`, `scripts/world/dungeon.gd` + `scripts/world/dungeon/`, `scripts/world/dungeon_geo.gd` + `scripts/world/dungeon_geo/`, `scripts/world/dungeon_props.gd` + `scripts/world/dungeon_props/`, `scripts/world/dungeon_stream.gd` + `scripts/world/dungeon_stream/`, `scripts/world/crystal/`, `scripts/world/floor_crystal.gd`, `scripts/world/wall_rects.gd`, `scripts/world/boss_door.gd` (code map row Dungeon; gdhealth group `dungeon`)

Reach-in rule: the dungeon scene places actors, props and lights; the systems it places never load dungeon code. The crystal net and the crystal screen reach the map through `dungeon.gd` methods (`refresh_map_marks`, `map_note_player`, `map_attach`); a floor crystal opens its screen with `App.open_crystal`. Helpers never load their own facade.

This file is the door. Open the Job-table sibling only when that row matches.

Occupancy is the maze. Carve the 1 m grid first. Rooms stay rectangles. Halls are segments plus width. Clean one-tile teeth and accidental stair-steps. Unused stone stays uncarved. Extra loops that fail hug clearance are skipped, not welded. There is no floor-wide rim.

Publish is one-way. Gen writes hall runs. Stream instances that recipe. Volume skins provided runs. Buffer reads cleaned occupancy and hangs lights on interior faces. Outline bake lives on the gen job. Stream does not invent a lip. Volume does not extract a silhouette.

Floor ready builds the map image and binds it to the HUD minimap. Map view is hidden, mini, or full. Mini is the default, and it hides while the full map is open.

| Job | Open |
|-----|------|
| maze carve, hall segments, size rebalance ledger, accidental jogs, deadend termini, unused stone, hug clearance, outline spans | `design/dungeon-gen.md` |
| PREPARE plaque, extraction clerks, stair hold, reveal disk | `design/dungeon-gates.md` |
| transport decades, warp silence, spur length | `design/dungeon-crystals.md` |
| RING_IN chunks, STREAM_OUT despawn, PER_FRAME geo, clip-free chunk instance | `design/dungeon-stream.md` |
