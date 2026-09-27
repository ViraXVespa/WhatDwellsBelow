# Dungeon — generation and placement

Status: binding design + live snapshot  
Read when: MST loops, deadend termini, hall widths, size rebalance ledger, fillet raster, walkable solid, void rim, outline, diagonal band, band fold, no jag on band, void teeth


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

Halls are carved 2–4 tiles wide. Width 3 is the mode. A connection that moves on both axes is a diagonal band around the segment (rare perpendicular jog), not a per-tile staircase. Cardinal connections stay a winding span; width still changes at `hall_w_interval` on those.

`gen.gd` uses the requested room count. Extra winding loops use the full `gen_extra_loops` value. Dead-end spurs scale with room count.

## Off-grid outline

The 1 m FLOOR/WALL grid stays the logical map: rooms, MST, hall-width budget, doors, stairs, prop snaps, ambush anchors, fog, minimap, crystal separation, and stream chunk index. After outline, gen writes one silhouette: outline_spans plus a fine bake that is those spans (walk and floor). That bake is the wall. Volume draws it. Stream boxes it. Buffer stamps light and mounts torches on it. Enemies stand on it. Interactables snap to it. Those jobs read the bake; they do not retune carve. Do not keep a second staircase occupancy to burn toward the ribbon.

After carve, gen traces the floor/void boundary and fillets a fraction of convex corners (`outline_fillet_frac`, live 0.40). Jag (`outline_jag_frac`, live 0.35) is 1–3 m plateaus on cardinal halls only, one face, not a sawtooth on both walls. Do not jag a rim that is already a diagonal band. If a band needs irregularity, put it on the span as vertices after the fold. It rasterizes that outline to `outline_fine_m` occupancy (live 0.25). Interior room cells are not eaten. Hall cells are not cleared, so a hall stays at its carved width. Hall corners may only gain solid in the void.
Outline may not leave a lone 1 m tooth on the abyss rim. Gen already stores `outline_spans` as a thin rim polyline (any heading). Fold both rims of a band (2x1 / 3x2 / 1x1) into one span each. Short axis-aligned stair spans on a band rim are a defect. After the fold, the fine bake is those spans. Short axis-aligned stair spans on a band rim are a defect. A width change may flare on the diagonal; a short step on one rim only is fine when that jump is cleaner. Collision stays BoxShape on void that touches that bake. Do not emit a 1 m slab per span. Do not retune `outline_fine_m`, fillet, jag, or `carve_winding`. Prove: both walls of a slant follow their rims; the shell is closed; feet stop on the brick; no stair rim on a band.

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
