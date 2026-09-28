# Dungeon — generation and placement

Status: binding design + live snapshot  
Read when: authored polylines, hall segments, size rebalance ledger, walkable solid, fillet jag, bake from rims, deadend termini


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

Halls are 2–4 tiles wide. Width 3 is the mode. A connection is a segment plus width, not a cell sausage that later pretends to be a line. A connection that moves on both axes is a diagonal band around that segment (rare perpendicular jog), not a per-tile staircase. Cardinal connections stay a winding span; width still changes at `hall_w_interval` on those. Carve may stamp 1 m cells for placement and pathing. That stamp is not the wall.

`gen.gd` uses the requested room count. Extra winding loops use the full `gen_extra_loops` value. Dead-end spurs scale with room count.

## Off-grid outline

The 1 m FLOOR/WALL grid stays the logical map: rooms, connection endpoints, hall-width budget, doors, stairs, prop snaps, ambush anchors, fog, minimap, crystal separation, and stream chunk index. Silhouette order is fixed. Author both rims as polylines from hall segments and room rectangles. Fillet and jag are vertex operations on those polylines (`outline_fillet_frac`, `outline_jag_frac`). Do not merge every room and hall into one hull (`Geometry2D.merge_polygons` / `_union_all`) and fill that. Rasterize each room rectangle and each hall band on its own. Room rectangles stay unpadded and axis-aligned. Do not jag the merged outline. Do not retune the three outline fractions to hide a merge. Room rectangles are unpadded and stay axis-aligned. Do not pad rooms so they merge through a 1 m wall. Do not jag the union hull; jag only hall-band edges, and not in this pass. Fillet only hall turns and hall-room joins. Do not retune the three outline fractions to hide a merge. Fold joins collinear runs. Then OR-fill each authored polygon into solid at `outline_fine_m`. outline_spans is the solid/void perimeter after those fills. solid is that raster. Walk, collision, lights, and snaps that need occupancy read solid: floor mesh, `is_floor_cell`, enemy and stream-job landing, BoxShape, and buffer occupancy. Brick and torch mounts read outline_spans. Do not push every room and hall loop as brick. Do not keep a second staircase occupancy. Do not enlarge 1 m FLOOR or shrink spans as separate knobs to close a hole. Fix the authored rim, then rasterize once.

Room interiors stay solid. A hall keeps its segment width; corners may only gain solid in the void. Jag is vertex plateaus on authored rims, not a raster nibble of a 1 m stamp. Collision is BoxShape on void that touches solid. Do not emit a 1 m slab per span. Do not ship a trace-then-repair loop (stair spans, tooth strip, burn toward ribbon) as the silhouette. The live tree may still invert this order until the source pass. This page is the contract that pass implements.

Do not ship a shader nibble on 1 m faces as the silhouette. Do not author arches or modular kits. One brick sheet stays a volume concern; this job does not add a second rock sheet.

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
| `outline_fine_m` | 0.25 |
| `outline_fillet_frac` | 0.40 |
| `outline_jag_frac` | 0.35 |

`gen.gd` clamps to minimum 24×24 and at least 6 rooms.
Boss room is farthest from spawn that still meets `_min_boss_sep = max(16, max(w,h) * 0.5)`.
cycle_of(n)     = (n - 1) / 5
loop_index(n)   = ((n - 1) % 5) + 1
is_gate_master  = loop_index == 5
