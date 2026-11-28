# Enemies — durability, death and drops

Status: current plan
Read when: durability, corpse cleanup, kill drops, boss chest
Code: `scripts/combat/enemy/enemy_hit.gd` (damage taken, death, `roll_drops`), `enemy_present.gd`, `scripts/combat/threat.gd`, `scripts/debug/drop_stage.gd`

## Combat level and durability

Floor band, rank-multiplier feel, and the floor-1 CL 17 budget: combat. Live keys: the tunables gate.

- Enemy CL is walked from spawn travel distance (`Threat.level_at`).
- Base HP lives in `enemies.gd` and holds the values. Packs MUST take more than one swing.

## Death presentation

1. Play death animation.
2. Drop loot (XP, gold, possible gear / Artifact).
3. Body disappears cleanly.

No lingering corpses required.

## Loot

- XP and gold amounts scale with floor and role.
- Gear drop chance and rarity (white / green / blue) are tunable.
- Walk-over pickups (gold coins, HP orb, mana orb) each roll their own chance per kill, so a kill can drop nothing (`enemy_hit.gd` `roll_drops`, tunables-combat Enemy drops). Bosses always drop gold. `scripts/debug/drop_stage.gd` stages them (flow `dungeon-pickups`) and the P3 smoke prints a 1000-kill `drop_sim`.
- Floor Guardians and Gate Master always drop the special chest (guaranteed equipment that may include blue rarity + one Artifact) in addition to normal drops.
