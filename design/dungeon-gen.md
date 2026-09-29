# Dungeon — generation and placement

Status: binding design + live snapshot  
Read when: maze carve, hall segments, size rebalance ledger, accidental jogs, angled halls, deadend termini


## Overall structure

- Floors follow a repeating 5-floor pattern that continues indefinitely until the player dies.
- Floors 1–4 each contain one Floor Guardian.
- Floor 5 contains the Gate Master.
- After floor 5 the sequence repeats with escalated difficulty.
- There is no hard maximum depth; death is the only cap.
- Combat-level bands and the floor-1 CL 17 budget: combat.

## Map generation

Grid size, room count, room size ranges, and connection algorithm (MST + extra loops) are fully tunable.
Target: floors MUST feel expansive enough to support a 5–10 minute first successful extraction for a new player and longer skilled runs, but rooms and combat MUST be dense enough that the player is not wandering empty halls for long stretches.

Halls are 2–4 tiles wide. Width 3 is the mode. A connection is a segment plus width. Cardinal connections stay a winding span on the 1 m grid; width still changes at `hall_w_interval` on those. After carve, clean one-tile teeth and accidental stair-steps. Keep intentional maze jogs. An off-axis corridor is rare: snap the room-to-room segment to 27 / 33 / 45 only when it sits within `angled_snap_deg` and the cardinal dogleg is at least `angled_vs_dogleg_min` tiles longer. Cap those halls with `angled_corridor_max` and short corner cuts with `corner_chord_max`. The cleaned 1 m grid is the maze. Angled pieces are packets on top of it, not a floor-wide rim.

`gen.gd` uses the requested room count. Extra winding loops use the full `gen_extra_loops` value. Dead-end spurs scale with room count.

## Maze carve and angled pieces

The 1 m FLOOR/WALL grid is the maze: rooms, connection endpoints, hall-width budget, doors, stairs, prop snaps, ambush anchors, fog, minimap, crystal separation, stream chunk index, default walk, default collision, and default floor/wall skin. Room rectangles stay unpadded and axis-aligned. Do not pad rooms so they merge through a 1 m wall.

Silhouette order is fixed. Carve the 1 m grid. Clean one-tile teeth and accidental stair-steps. Do not fillet or jag the whole rim. Do not author both rims as a floor-wide polyline and rasterize that as walk truth. Do not merge every room and hall into one hull (`Geometry2D.merge_polygons` / `_union_all`) and fill that. Floor-wide `outline_fillet_frac` and `outline_jag_frac` are unused. Jag-as-wear is a shader concern, not a rim operator.

An angled piece is a closed packet for one rare off-axis hall or short corner chord: a floor band, the two long wall runs, and collision hulls that match that mesh. Brick and torch mounts on that piece read its runs. Walk, lights, and snaps inside the piece follow the packet, not a second staircase of 1 m boxes under the pretty wall. Outside the piece, occupancy is the cleaned grid. `outline_fine_m` is piece-bake resolution only. Do not keep a floor-wide fine solid as a second dungeon. Do not ship a floor-wide trace-then-repair loop as the silhouette.

Live gen may still publish floor-wide outline_spans until the source slice. This page is the contract that slice implements. Do not author arches or modular kits. One brick sheet stays a volume concern; this job does not add a second rock sheet.

## Key object placement

Placement rules and probabilities for crystal, stairs, Extraction Gates, mining nodes, wood nodes, breakables, shrine, campfire, ghost shop, puzzle elements, chests, and enemy bases are fully tunable.
Safe rooms (Extraction Gate, ghost shop, puzzle) MUST remain enemy-free.

Dead-end termini (leaf rooms with one exit, plus 1-neighbor hall cells) are recorded in `data.deadends`. A terminus gets a convenience crystal only when the spur walk to the nearest multi-exit room is at least `crystal_deadend_len`, it clears `crystal_deadend_sep` from spawn, and it clears `crystal_min_sep` from every already-placed crystal.

## Enemy bases

- Procedural room type containing at least one chest.
- Heavily guarded (`base_guards`).
- Intended to be challenging unless the player is over-levelled for the current floor.

Normal combat rooms pack `room_pack` enemies. Streaming keeps that count inside budget on a 432 map. Enemy jobs inside `STREAM_IN` activate at most `SPAWN_PER_TICK` per stream tick (`SPAWN_BOOT` on the first floor tick). `stream_all` / smoke still dumps the floor.

## Safe rooms

- Extraction Gate rooms, ghost shop rooms, and puzzle rooms are always enemy-free.
- Idle / pressure spawn rules: enemies.

## Ambushes and pressure

- Ambush anchors are hallway cells outside rooms, spaced by `ambush_spacing`, capped at `ambush_cap` per floor.
- Each ambush job packs `ambush_pack_min`–`ambush_pack_max` enemies.
- Pressure / idle / no-reveal wave cap: `pressure_waves` per floor. CL 17 budget: combat. BFS hallway spawn: enemies.

## Live snapshot — size rebalance

| Key | Live |
|-----|------|
| `gen_w` / `gen_h` | 432 / 432 |
| `gen_rooms` | 64 |
| `gen_room_min` / `gen_room_max` | 5 / 9 |
| `gen_extra_loops` | 8 |
| `hall_w_min` / `hall_w_mode` / `hall_w_max` | 2 / 3 / 4 |
| `hall_w_interval` | 10 |
| `fog_radius` | 5 |
| `room_pack` | 3 |
| `base_guards` | 5 |
| `ambush_cap` | 40 |
| `ambush_spacing` | 10 |
| `ambush_pack_min` / `ambush_pack_max` | 1 / 2 |
| `pressure_waves` | 3 |
| `max_clerks` | 3 |
| `ghost_shop_chance` | 0.33 |
| `crystal_min_sep` | 56 |
| `crystal_clear_r` | 12 |
| `crystal_arrive_r` | 8 |
| `crystal_extra_max` | 6 |
| `crystal_place_chance` | 0.50 |
| `crystal_deadend_sep` | 32 |
| `crystal_cl_band` | 2 |
| `crystal_deadend_len` | 28 |
| `outline_fine_m` | 0.25 (piece bake only) |
| `outline_fillet_frac` | 0.40 live / 0 law |
| `outline_jag_frac` | 0.35 live / 0 law |
| `angled_corridor_max` | 4 |
| `corner_chord_max` | 8 |
| `angled_deg` | 27 / 33 / 45 |
| `angled_snap_deg` | 6 |
| `angled_vs_dogleg_min` | 12 |

`gen.gd` clamps to minimum 24×24 and at least 6 rooms.
Boss room is farthest from spawn that still meets `_min_boss_sep = max(16, max(w,h) * 0.5)`.
cycle_of(n)     = (n - 1) / 5
loop_index(n)   = ((n - 1) % 5) + 1
is_gate_master  = loop_index == 5
