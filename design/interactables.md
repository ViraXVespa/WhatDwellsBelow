# Interactables and world objects

Status: current plan
Read when: gathering swings, shops, shrines, puzzles, extract-wells
Code: `scripts/world/interact.gd` (facade) + `scripts/world/interact/`, `scripts/world/gather/`, `scripts/world/breakable.gd`, `scripts/world/pickup.gd` (code map row Interactables; gdhealth group `interactables`)

This file is the door. Open the Job-table sibling only when that row matches.

Objects the player walks up to and acts on: gathering nodes, breakables, pickups, chests, shrines, the campfire, puzzle pieces, gates, stairs, floor crystals. Other code spawns them through `interact.gd`, `breakable.gd`, `pickup.gd`, `floor_crystal.gd`, `gather/gather_node.gd` or the shared timing in `gather/rules.gd`, never a helper in `interact/`. Where they are placed, locks, and the stair rule: dungeon.

| Job | Open |
|-----|------|
| mining nodes, wood nodes, pickaxe rewards | `design/interactables-gather.md` |
| pots and barrels, HP orbs, smash sound | `design/interactables-breakables.md` |
| pull levers, cracked walls, treasure caches, paired gatework | `design/interactables-puzzles.md` |
| microwave housing, pawned goods, blessing buff, campfire sit | `design/interactables-fixtures.md` |
| descend glyph, waypoint beacons, clear-area text, readable labels | `design/interactables-prompts.md` |
