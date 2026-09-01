# Dungeon generation and floors

Status: binding design + live snapshot
Read when: changing gen, floor flow, streaming, boss doors, fog, or crystals
Code: `scripts/dungeon/gen.gd`, `scripts/world/dungeon.gd`, `dungeon_boot.gd`, `dungeon_stream.gd`, `dungeon_geo_stream.gd`, `dungeon_props.gd`, `boss_door.gd`, `crystal_net.gd`, `floor_crystal.gd`
See also: `design/enemies.md`, `design/interactables.md`, `design/ui.md`, `design/tunables.md`

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

## Stairs

- Stairs only permit travel deeper.
- Stairs are locked behind the boss door until the guardian / Gate Master is killed.
- Stairs remain the only way to push `prog.deepest` to a floor the player has not yet reached.

## Floor crystals

- Each floor places the entrance crystal at spawn plus extra crystals in combat rooms.
- At most one crystal per combat-level band (`Threat.level_at` from walk-distance to the entrance). A band is not required to receive a crystal.
- Extra crystals MUST keep a tunable minimum separation from the entrance and from each other.
- The entrance crystal is bound on arrival. Any other crystal is unbound until the player clears enemies in its area (`crystal_clear_r`) and interacts.
- Bound crystals open the transport menu. They do not descend.
- Local Transport Network unlocks when at least two crystals on the current floor are bound. Selecting a bound crystal teleports the player there and silences nearby spawn jobs.
- Floor Transport Network unlocks when `prog.deepest` is greater than the current floor. It lists every reached floor. If more than ten floors are reachable, the list is grouped by decades (1–10, 11–20, …). The current floor is disabled. Unreached floors in a decade folder stay disabled.
- Floor hops land at the destination floor’s entrance crystal. Boss-defeated state is remembered per floor for the current run.
- Activated crystals stay enemy-free at `crystal_arrive_r` so a hop does not drop the player into a pack.

## Live snapshot — size rebalance

Suggested appendix start was 48×48–64×64. Live `balance.gd` after geometry streaming:

| Key | Live |
|-----|------|
| `gen_w` / `gen_h` | 432 / 432 |
| `gen_rooms` | 36 |
| `gen_room_min` / `gen_room_max` | 5 / 9 |
| `gen_extra_loops` | 8 |
| `fog_radius` | 5 |
| `max_clerks` | 3 |
| `ghost_shop_chance` | 0.33 |
| `crystal_min_sep` | 56 |
| `crystal_clear_r` | 12 |
| `crystal_arrive_r` | 8 |
| `crystal_extra_max` | 4 |
| `crystal_place_chance` | 0.62 |

`gen.gd` clamps to minimum 24×24 and at least 6 rooms.
Boss room is farthest from spawn that still meets `_min_boss_sep = max(16, max(w,h) * 0.5)`.
cycle_of(n)     = (n - 1) / 5
loop_index(n)   = ((n - 1) % 5) + 1
is_gate_master  = loop_index == 5

## Live snapshot — streaming

`dungeon_stream.gd` streams enemy jobs. `dungeon_geo_stream.gd` streams floor/wall MultiMeshes and wall collision the same way so 432×432 stays inside the 60 FPS budget.

| Constant | Cells | Meaning |
|----------|-------|---------|
| `STREAM_IN` | 28 | Pending job becomes live |
| `STREAM_OUT` | 42 | Live job despawns if not in combat (enemies) / not near player (geo) |
| `CHUNK` | 16 | Geometry job size |
| `PER_TICK` | 8 | Max geo chunks built per stream tick (24 on boot tick) |

Job states: `pending`, `live`, `cleared`. Do not stream out an enemy the player is fighting.
Geometry jobs never go `cleared`; they sleep back to `pending`.
Only chunks that contain a floor cell, or a wall adjacent to a floor, are queued.
`stream_all` / `force_all` still force enemy jobs; geometry stays proximity-streamed so smoke does not bake the whole floor.
Jobs whose anchor sits inside an activated crystal’s arrive radius stay `cleared`.

## Live snapshot — boss doors

`boss_door.gd`: collision + “PREPARE” label; interact opens; linked doors open together; door tweens up, disables collision, frees grid cells, label becomes “OPEN”. Stairs still wait for `App.notify_boss_dead()`.

`scenes/foundation.tscn` is the combat sandbox / smoke host, not the player hub.