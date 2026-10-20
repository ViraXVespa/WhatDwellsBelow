# Dungeon — gates, stairs, fog

Status: current plan  
Read when: PREPARE plaque, extraction clerks, stair hold, reveal disk

## Boss / guardian rules

- Each Floor Guardian and the Gate Master spawns behind a special boss door that the player can see and prepare in front of.
- Stairs remain locked until the guardian / Gate Master is defeated.
- On death the boss drops a chest containing guaranteed equipment (including the possibility of blue rarity) plus one Artifact.

## Fog of war

- Reveal is a small disk around the player (radius: tunables-world). Visited tiles stay revealed for the run.
- Reveal disk, visited tiles, map occupancy, and boss-door freed cells stay coarse 1 m tiles.
- 3D floor, wall, and prop meshes are not gated on fog. Streaming draws complete nearby chunks.
- Large map overlay (View button) shows discovered tiles and important markers while the game continues running. Markers on unseen tiles stay hidden (`need_seen`).
- Large map starts at fit-to-frame. Zoom and pan live in `map_act.gd` (wheel / pinch / look-mode RS). World camera zoom is unchanged. Bindings: input and ui.

## Extraction Gate limits

- Maximum one ghost shop per floor.
- A fixed number of Extraction Gates per floor (`max_clerks`: tunables-world).
- Gate rooms MUST be spread across the floor. Spacing starts wide and relaxes step by step until enough candidate rooms are marked (tunables-world). If the floor has fewer legal rooms, every legal room is marked.

Mail-legal goods and one-use visit rules: inventory.meta and interactables.

## Stairs

- Stairs only permit travel deeper.
- Stairs are locked behind boss until the guardian / Gate Master is killed.
- Stairs remain the only way to push `prog.deepest` to a floor the player has not yet reached.

Prompt / confirm copy: interactables.

## Boss doors and enter cover

- Boss doors show “PREPARE”, open on interact (linked doors together), free their cells and read “OPEN”. Stairs still wait for the boss kill.
- `scenes/foundation.tscn` is the combat sandbox / smoke host, not the player hub.
- Enter dungeon covers on the Floor Crystal press, waits until that cover has presented, then saves and changes scene; it fades in shortly after the floor is ready (tunables-economy).
- Floor boot stays light: gear UI, crystal UI and the large map load on first use; props, ambushes and extra crystals stream in on the pulse inside `STREAM_IN`. The Floor Guardian is a stream job.
- Map dump and Placeholdia → Dungeon timing smokes: debug-smokes.
