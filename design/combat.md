# Combat

Status: binding design  
Read when: changing weapons, hit detection, dash, lock, juice, or combat-level scaling  
Code: `scripts/combat/combat.gd`, `threat.gd`, `aim_line.gd`, `projectile.gd`, `telegraph.gd`, `scripts/world/player.gd`  
See also: `design/skills.md`, `design/tunables.md`, `design/art-pipeline.md`, `design/enemies.md`

## Weapon system

The player may equip one of three weapons: Great Axe, Lightning Staff, or Longbow.  
Starting weapon is selected in the loadout. Mid-run weapon changes are performed by equipping from the pause-menu inventory.  
Each weapon has its own paper-doll **overlay** (carry / rest plus attack and special layers). Body locomotion is shared and unarmed. Attack and special use a body clip per weapon class with the weapon layered on top — not a baked full-character animation set per weapon.  
Specials for all weapons are activated with LT.  
All player attacks (basic and special) MUST clearly telegraph their range and provide a visible indication that the attack is currently active.

## Great Axe

- Basic attack: Hold-to-attack (RT / LMB). Continues automatically while held. Arc and range are tunable. A single swing can hit multiple enemies inside the arc. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation frame.
- Special (Slam): Short wind-up and recovery. Higher damage multiplier than a basic attack (exact value tunable). Applies a readable stagger (shorter duration against Floor Guardians and the Gate Master). Produces dedicated ground-crack VFX.

## Lightning Staff

- Basic attack: Hold-to-attack (RT / LMB). Weak melee strikes that continue automatically while held. Range and arc are shorter and lower-damage than the Great Axe (exact values tunable). A single strike can hit multiple enemies inside its arc. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation frame.
- Special: AoE lightning bolt that strikes a targeted area. Possesses a distinct short wind-up. Damage, radius, and any secondary effects are tunable. MUST clearly telegraph the affected area and show when the bolt is active.

## Longbow

- Basic attack: Hold-to-attack (RT / LMB) fires long-range single-target projectiles that continue automatically while held. Range, projectile speed, and fire rate are tunable. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation / projectile frame.
- Special: Fires 5 arrows in a cone in front of the player (functions as an AoE attack). Possesses a distinct short wind-up. Cone angle, range, arrow count behaviour, and damage are tunable. MUST clearly telegraph the cone area and show when the arrows are active.

## Critical hits

- Deal double damage.
- Target receives a white flash.
- Floating damage number is shown in yellow + magenta (no additional “CRIT!” text).
- This is the minimum required implementation; additional juice may be added later.

## Dash

- Activated with B.
- Full i-frames for the entire duration.
- Clear trail VFX required.

## Adrenaline Rush

- Triggers after sufficient kills in a short window (exact threshold tunable).
- Effects while active:
  - Increased movement speed
  - Stacking XP bonus
  - Flaming aura on the player
  - Continuous wooshing / crackling sound
- Starts with a warcry.
- No cooldown, but the effect times out if the player stops killing.
- MUST keep killing to maintain the state.

## Defense

- Uses a diminishing-returns formula (exact formula tunable).
- Armor pieces contribute defense and may carry minor secondary stats.

## Combat level and threat

- Each floor spans 20 combat levels: floor 1 is CL 1–20, floor 2 is 21–40, and so on (`enemy_cl_per_floor`).
- Enemy CL is walked from spawn travel distance across that band (`Threat.level_at`).
- Rank multipliers are shallow (`cl_dealt_up` 1.03, `cl_dealt_down` 0.97 and the matching received pair). A player a few levels above an enemy MUST NOT one-shot it. A player a few levels below MUST still take real hits.
- Base enemy HP is about double the pre-retune table so a pack fight lasts more than one swing.
- Axe basic damage is 16 so the player does not outpace that HP table on floor 1.
- Clearing every budgeted enemy on floor 1 of a fresh run SHOULD land the player near combat level 17. That budget is rooms + capped ambushes + capped pressure waves. Level-ups MUST feel like they prepared the player for the next stretch of the same floor, not like they deleted it.
- Ambush and pressure kills grant XP. Wave count is capped per floor (`pressure_waves`, `ambush_cap`) so the CL 17 target stays measurable.

## Target-lock

See `design/input.md` for full behavior.

Floating damage numbers show integer values only, appear briefly, then disappear.

Live numeric defaults are in `design/tunables.md`.