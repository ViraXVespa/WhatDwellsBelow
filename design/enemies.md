# Enemies

Status: current plan
Read when: roster, AI, pressure
Code: `scripts/combat/enemy.gd` (facade, `class_name EnemyHost`) + `scripts/combat/enemy/`, `scripts/combat/roster.gd` (code map row Enemies; gdhealth group `enemies`)

This file is the door. Open the Job-table sibling only when that row matches.

Enemy types, behavior and drops. Hits, cover, projectiles, threat and floating numbers are combat code that enemy code calls; combat code does not call enemy code. Numbers live in the tunables gate (tunables-world, tunables-combat).

| Job | Open |
|-----|------|
| monster variety, suggested roles, named monsters, new enemy type | `design/enemies-roster.md` |
| wind-up telegraphs, leash range, flee reinforcements, idle spawns | `design/enemies-ai.md` |
| durability, corpse cleanup, kill drops, boss chest | `design/enemies-loot.md` |
