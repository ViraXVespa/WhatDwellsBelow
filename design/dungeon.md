# Dungeon generation and floors

Status: binding design + live snapshot
Read when: changing gen, floor flow, streaming, boss doors, fog, or crystals
Code: `scripts/dungeon/gen.gd`, `scripts/world/dungeon.gd`, `dungeon_boot.gd`, `dungeon_stream.gd`, `dungeon_geo_stream.gd`, `dungeon_map_act.gd`, `dungeon_props.gd`, `boss_door.gd`, `crystal_net.gd`, `crystal_place.gd`, `floor_crystal.gd`
See also: `design/enemies.md`, `design/interactables.md`, `design/ui.md`, `design/tunables.md`

## Overall structure

- Floors follow a repeating 5-floor pattern that continues indefinitely until the player dies.
- Floors 1–4 each contain one Floor Guardian.
- Floor 5 contains the Gate Master.
- After floor 5 the sequence repeats with escalated difficulty.
- There is no hard maximum depth; death is the only cap.
- Combat-level bands are 20 levels per floor: floor 1 is CL 1–20, floor 2 is 21–40, and so on (`enemy_cl_per_floor`).

## Map generation

Grid size, room count, room size ranges, and connection algorithm (MST + extra loops) are fully tunable.
Target: floors MUST feel expansive enough to support a 5–10 minute first successful extraction for a new player and longer skilled runs, but rooms and combat MUST be dense enough that the player is not wandering empty halls for long stretches.

Halls are carved 2–4 tiles wide. Width 3 is the mode. Width changes at `hall_w_interval` steps along a winding path.

`gen.gd` uses the requested room count. Extra winding loops use the full `gen_extra_loops` value. Dead-end spurs scale with room count.

## Key object placement

Placement rules and probabilities for crystal, stairs, Extraction Gates, mining nodes, wood nodes, breakables, shrine, campfire, ghost shop, puzzle elements, chests, and enemy bases are fully tunable.
Safe rooms (Extraction Gate, ghost shop, puzzle) MUST remain enemy-free.

Dead-end termini (leaf rooms with one exit, plus 1-neighbor hall cells) are recorded in `data.deadends`. Each terminus that clears `crystal_deadend_sep` gets a floor crystal so the player can leave the spur without walking the whole branch back.

## Enemy bases

- Procedural room type containing at least one chest.
- Heavily guarded (`base_guards`).
- Intended to be challenging unless the player is over-levelled for the current floor.

Normal combat rooms pack `room_pack` enemies. Streaming keeps that count inside budget on a 432 map.

## Safe rooms

- Extraction Gate rooms, ghost shop rooms, and puzzle rooms are always enemy-free.
- Idle / pressure spawns MUST NOT occur inside safe rooms.

## Boss / guardian rules

- Each Floor Guardian and the Gate Master spawns behind a special boss door that the player can see and prepare in front of.
- Stairs remain locked until the guardian / Gate Master is defeated.
- On death the boss drops a chest containing guaranteed equipment (including the possibility of blue rarity) plus one Artifact.

## Fog of war

- Reveal radius starts at a 5-tile baseline disk. Visited tiles stay revealed for the run.
- 3D floor, wall, and prop meshes are not gated on fog. Streaming draws complete nearby chunks.
- Large map overlay (View button) shows discovered tiles and important markers while the game continues running. Markers on unseen tiles stay hidden (`need_seen`).
- Large map starts at fit-to-frame. Zoom and pan live in `dungeon_map_act.gd` (wheel / pinch / look-mode RS). World camera zoom is unchanged. Bindings: `design/input.md` and `design/ui.md`.

## Extraction Gate limits

- Maximum one ghost shop per floor.
- Exactly three Extraction Gates per floor (tunable cap `max_clerks`, default 3).
- Gate rooms MUST be spread across the floor (minimum separation 28 cells).

## Stairs

- Stairs only permit travel deeper.
- Stairs are locked behind the boss door until the guardian / Gate Master is killed.
- Stairs remain the only way to push `prog.deepest` to a floor the player has not yet reached.

## Floor crystals

- Each floor places the entrance crystal at spawn plus extra crystals in combat rooms.
- At most one crystal per combat-level band (`Threat.level_at` from walk-distance to the entrance). A band is not required to receive a crystal.
- Extra crystals MUST keep a tunable minimum separation from the entrance and from each other.
- Dead-end crystals ignore the per-band cap. They still honor `crystal_deadend_sep`.
- Layout lives in `crystal_place.gd`. Bind, warp, silence, and menus live in `crystal_net.gd`.
- The entrance crystal is bound on arrival. Any other crystal is unbound until the player clears enemies in its area (`crystal_clear_r`) and interacts.
- Bound crystals open the transport menu. They do not descend.
- Local Transport Network unlocks when at least two crystals on the current floor are bound. Selecting a bound crystal teleports the player there and silences nearby spawn jobs.
- Floor Transport Network unlocks when `prog.deepest` is greater than the current floor. It lists every reached floor. If more than ten floors are reachable, the list is grouped by decades (1–10, 11–20, …). The current floor is disabled. Unreached floors in a decade folder stay disabled.
- Floor hops land at the destination floor’s entrance crystal. Boss-defeated state is remembered per floor for the current run.
- Activated crystals stay enemy-free at `crystal_arrive_r` so a hop does not drop the player into a pack.

## Ambushes and pressure

- Ambush anchors are hallway cells outside rooms, spaced by `ambush_spacing`, capped at `ambush_cap` per floor.
- Each ambush job packs `ambush_pack_min`–`ambush_pack_max` enemies.
- Pressure / idle / no-reveal waves are capped at `pressure_waves` per floor so the CL 17 XP budget stays static.
- Ambush, reinforcement, and pressure spawns use BFS on the floor graph (`walkable_near`). They MUST appear in the connected hallway the player is standing in, not in an adjacent hall cut off by a wall.

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
| `crystal_extra_max` | 4 |
| `crystal_place_chance` | 0.62 |
| `crystal_deadend_sep` | 18 |

`gen.gd` clamps to minimum 24×24 and at least 6 rooms.
Boss room is farthest from spawn that still meets `_min_boss_sep = max(16, max(w,h) * 0.5)`.
cycle_of(n)     = (n - 1) / 5
loop_index(n)   = ((n - 1) % 5) + 1
is_gate_master  = loop_index == 5

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

## Live snapshot — boss doors

`boss_door.gd`: collision + “PREPARE” label; interact opens; linked doors open together; door tweens up, disables collision, frees grid cells, label becomes “OPEN”. Stairs still wait for `App.notify_boss_dead()`.

`scenes/foundation.tscn` is the combat sandbox / smoke host, not the player hub.