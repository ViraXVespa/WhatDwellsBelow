# Dungeon generation and floors

Status: binding design + live snapshot
Read when: changing gen, floor flow, streaming, boss doors, or fog
Code: `scripts/dungeon/gen.gd`, `scripts/world/dungeon.gd`, `dungeon_stream.gd`, `dungeon_props.gd`, `boss_door.gd`
See also: `design/enemies.md`, `design/interactables.md`, `design/tunables.md`

## Overall structure

- Floors follow a repeating 5-floor pattern that continues indefinitely until the player dies.
- Floors 1–4 each contain one Floor Guardian.
- Floor 5 contains the Gate Master.
- After floor 5 the sequence repeats with escalated difficulty.
- There is no hard maximum depth; death is the only cap.

## Map generation

Grid size, room count, room size ranges, and connection algorithm (MST + extra loops) are fully tunable.
Target: floors MUST feel expansive enough to support a 5–10 minute first successful extraction for a new player and longer skilled runs. Starting values should be chosen to achieve this feel on the Camera3D live path.

## Key object placement

Placement rules and probabilities for crystal, stairs, clerks, mining nodes, wood nodes, breakables, shrine, campfire, ghost shop, puzzle elements, chests, and enemy bases are fully tunable.
Safe rooms (clerk, ghost shop, puzzle) MUST remain enemy-free.

## Enemy bases

- Procedural room type containing at least one chest.
- Heavily guarded by a large number of enemies.
- Intended to be challenging unless the player is over-levelled for the current floor.

## Safe rooms

- Clerk rooms, ghost shop rooms, and puzzle rooms are always enemy-free.
- Idle / pressure spawns MUST NOT occur inside safe rooms.

## Boss / guardian rules

- Each Floor Guardian and the Gate Master spawns behind a special boss door that the player can see and prepare in front of.
- Stairs remain locked until the guardian / Gate Master is defeated.
- On death the boss drops a chest containing guaranteed equipment (including the possibility of blue rarity) plus one Artifact.

## Fog of war

- Reveal radius starts at a 5-tile baseline.
- Visited tiles remain revealed for the duration of the run.
- Large map overlay (View button) shows discovered tiles and important markers while the game continues running.

## Clerk limits

- Maximum one ghost shop per floor.
- Maximum three clerks total per floor.

## Stairs and crystal

- Both only permit travel deeper.
- Stairs are locked behind the boss door until the guardian is killed.

## Live snapshot — size rebalance

Suggested appendix start was 48×48–64×64. Live `balance.gd` after Dungeon Size Rebalance:

| Key | Live |
|-----|------|
| `gen_w` / `gen_h` | 216 / 216 |
| `gen_rooms` | 36 |
| `gen_room_min` / `gen_room_max` | 5 / 9 |
| `gen_extra_loops` | 8 |
| `fog_radius` | 5 |
| `max_clerks` | 3 |
| `ghost_shop_chance` | 0.33 |

`gen.gd` clamps to minimum 24×24 and at least 6 rooms.
Boss room is farthest from spawn that still meets `_min_boss_sep = max(16, max(w,h) * 0.5)`.
cycle_of(n)     = (n - 1) / 5
loop_index(n)   = ((n - 1) % 5) + 1
is_gate_master  = loop_index == 5


## Live snapshot — streaming

`dungeon_stream.gd` keeps large floors inside the 60 FPS budget.

| Constant | Cells | Meaning |
|----------|-------|---------|
| `STREAM_IN` | 28 | Pending job becomes live |
| `STREAM_OUT` | 42 | Live job despawns if not in combat |

Job states: `pending`, `live`, `cleared`. Do not stream out an enemy the player is fighting.

## Live snapshot — boss doors

`boss_door.gd`: collision + “PREPARE” label; interact opens; linked doors open together; door tweens up, disables collision, frees grid cells, label becomes “OPEN”. Stairs still wait for `App.notify_boss_dead()`.

`scenes/foundation.tscn` is the combat sandbox / smoke host, not the player hub.