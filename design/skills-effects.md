# Skills — effects and power gain

Status: current plan
Read when: survivability, smith craft beat, noticeable power
Code: `scripts/data/progress_combat/stat.gd` (damage mult, gear stats), `scripts/data/progress_forge.gd` + `scripts/data/progress_forge/`

## Skill effects (high-level)

- Great Axe, Staff, Longbow, Strength, Magic, and Ranged: increase damage dealt with the corresponding style or weapon (with possible differential scaling on specials).
- Defense & Hitpoints: increase survivability.
- Mining: improves reward chance and effectiveness with the hit-based mining system.
- Woodcutting: improves reward chance and effectiveness with the hit-based woodcutting system.
- Smithing: anvil only.
  - Shortens the forge craft beat when smithing is at or above the configured item level; lengthens it when below.
  - Nudges forge Quality up when smithing ≥ item level, down when smithing is below.
  - Applies a small cost discount (`forge_smith_disc` per smith level above 1).
  - Does not change dungeon drop rolls.

## Visible power gain after one good run

After a single successful extraction and return to Placeholdia the player MUST be able to notice either:
- a few permanent skill levels, or
- at least one new piece of usable forged gear (or both).

This is a required feel target. Concrete proxy: after one successful run the permanent skill levels or new forged item MUST be visible on the hub loadout/skills screens without external guidance.
