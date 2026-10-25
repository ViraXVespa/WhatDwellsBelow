extends "res://scripts/data/balance/vars_economy.gd"

## The one lookup point for balance vars (Balance extends this). Defaults live per system, one file per
## design/tunables*.md doc, chained by `extends`: vars_main (tunables.md) <- vars_combat (tunables-combat.md)
## <- vars_world (tunables-world.md) <- vars_economy (tunables-economy.md). Each key lives in exactly one file;
## `docs.py tunable add|set|range` pick the file. Enemy stats are in enemies.gd.
