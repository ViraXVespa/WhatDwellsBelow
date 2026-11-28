# Enemies — AI and spawns

Status: current plan
Read when: wind-up telegraphs, leash range, flee reinforcements, idle spawns
Code: `scripts/combat/enemy/enemy_ai.gd` (states, LOS, leash, flee), `enemy_move.gd` (steering, separation), `enemy_atk.gd` (wind-up, strike, shots), `sep_grid.gd`; spawns: `scripts/world/dungeon/dungeon_pack.gd`, `scripts/world/dungeon_stream/`

## Attack telegraphs and feel

- All enemy attacks MUST have clear, readable wind-ups.
- Melee (Bruiser / Tank): visible wind-up pose → lunge. Direction locks at the start of the wind-up.
- Ranged: visible draw / charge pose → projectile release. Direction locks on draw.
- Mage / other non-melee styles: visible charge / cast pose → readable area or projectile. Direction or target locks at the start of the telegraph.
- All telegraphs respect line-of-sight.

## AI behavior

Enemies require line-of-sight to begin attacking or chasing.  
When LOS is lost they may briefly hunt the last-seen position, then return to idle.  
Enemies MUST also drop pursuit if the distance to the player exceeds a tunable leash range, even if they still have LOS. After dropping pursuit they return to idle / their post. This exists so a player who is overwhelmed can flee combat instead of being chased indefinitely.  
Exact leash distance, hunt duration after lost LOS, and re-aggro rules are tunable via the secret debug menu.  
Implement clean steering, separation, and stuck-handling appropriate for the orthographic Camera3D live path.  
Flee event occurs an average of 2 times per floor on a full clear: after the group has taken sufficient damage, the fastest enemy in the encounter flashes a clear “!” overhead, receives a small but noticeable speed boost, and flees to spawn reinforcements. No other telegraph is required beyond the “!”.

Reinforcements, ambushes, and pressure spawns use BFS on gen's bake walkable floor. They MUST appear in the connected hallway the player is standing in, not in an adjacent hall cut off by a wall, and not in void the ribbon closed. This job reads the bake. It does not retune carve. Placement caps stay with dungeon gen.

## Idle / pressure spawns

If the player remains idle too long outside a safe room, or stops revealing new map area for a tunable duration, additional enemies MUST spawn around the player.

- MUST NOT spawn inside safe rooms (Extraction Gate, ghost shop, puzzle).
- Idle timer, no-reveal timer, spawn count, and spawn radius are tunable via the secret debug menu.
- Wave count is capped per floor (`pressure_waves`) so the CL 17 XP budget in combat stays static.
- Ambush and pressure kills grant XP. That is why the cap exists.
- Purpose: the dungeon stays reactive if the player camps or stalls exploration, without becoming an infinite XP farm.
