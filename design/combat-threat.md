# Combat — level and threat

Status: current plan
Read when: rank multipliers, CL budget, one-shot guard
Code: `scripts/combat/threat.gd`, `scripts/data/progress_combat/`

## Combat level and threat

- Each floor spans a fixed band of combat levels, and each floor starts where the last ended (band width: tunables-world).
- Enemy CL walk and pack HP: enemies (`Threat.level_at`).
- Rank multipliers are shallow (values: tunables-world). A player a few levels above an enemy MUST NOT one-shot it. A player a few levels below MUST still take real hits.
- Axe basic damage stays low enough that the player does not outpace the floor-1 HP table (tunables-combat).
- Clearing every budgeted enemy on floor 1 of a fresh run SHOULD land the player near the floor-1 combat-level target (tunables-world). That budget is rooms + capped ambushes + capped pressure waves. Level-ups MUST feel like they prepared the player for the next stretch of the same floor, not like they deleted it.
- Ambush and pressure kills grant XP. Wave count is capped per floor (`pressure_waves`, `ambush_cap`) so that target stays measurable.
