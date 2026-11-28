# Interactables — chests and puzzle rooms

Status: current plan
Read when: pull levers, cracked walls, treasure caches, paired gatework
Code: `scripts/world/interact/interact_act.gd`, `scripts/world/interact/interact_chest.gd`, `scripts/world/interact/interact_fx.gd`; placement `scripts/world/dungeon_props/props_place.gd`

## Artifact chests, pressure plates, levers, gates, cracked walls

- Puzzle elements are never required for progression and never appear on the critical path to stairs.
- Puzzle rooms are safe rooms. Every piece MUST sit on a free floor cell inside that room. Do not use fixed offsets from room center.
- If the room cannot hold the full kit, shrink it. Order: paired gate, then plate **or** lever (never both), then a visible chest, then a hidden chest plus an adjacent cracked wall. Skip a later piece rather than placing outside the room.
- A room gets one activator: a pressure plate **or** a lever, chosen at spawn. Both toggle the paired gate on a rising edge and latch it. Stepping off a plate does not close the gate. Stepping on again toggles it closed.
- Plate prompt verb is “Step the plate”. Lever prompt verb is “Pull lever”.
- Cracked walls take more hits than normal breakables (Crack HP: tunables-combat). Breaking one reveals its linked hidden chest.
- Dead-end chests and puzzle chests may optionally contain Artifacts in addition to normal loot.
- There is no open-chest sprite. A used chest (`chest`, `base_chest`, `puzzle_chest`) fades and tints in place and keeps the “Empty.” prompt for the rest of the floor.

## Puzzle rooms

`props_place.spawn_puzzle` walks clear cells inside the room rectangle and takes what fits. `interact_act.plate_held` stores `pressed` on the plate and only calls `toggle_gates` when the player first steps inside its trigger radius (tunables-combat). `interact_fx.paint_used_chest` sets sprite modulate to a faded brown after open.
