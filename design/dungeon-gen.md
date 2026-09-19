# Dungeon — generation and placement

Status: binding design + live snapshot  
Read when: MST loops, deadend termini, hall widths, size rebalance ledger


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

Halls are carved 2–4 tiles wide. Width 3 is the mode. Width changes at `hall_w_interval` steps along a winding path.

`gen.gd` uses the requested room count. Extra winding loops use the full `gen_extra_loops` value. Dead-end spurs scale with room count.

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

`gen.gd` clamps to minimum 24×24 and at least 6 rooms.
Boss room is farthest from spawn that still meets `_min_boss_sep = max(16, max(w,h) * 0.5)`.
cycle_of(n)     = (n - 1) / 5
loop_index(n)   = ((n - 1) % 5) + 1
is_gate_master  = loop_index == 5
