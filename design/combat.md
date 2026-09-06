# Combat

Status: binding design  
Read when: changing weapons, hit detection, dash, lock, juice, or combat-level scaling  
Code: `scripts/combat/combat.gd`, `cover.gd`, `player_hit.gd`, `threat.gd`, `aim_line.gd`, `projectile.gd`, `telegraph.gd`, `float_num.gd`, `dummy.gd`, `scripts/world/player.gd`, `player_combat.gd`  
See also: `design/skills.md`, `design/tunables.md`, `design/art-pipeline.md`, `design/enemies.md`, `design/hub.md`

## Weapon system

The player may equip one of three weapons: Great Axe, Lightning Staff, or Longbow.  
Starting weapon is selected in the loadout. Mid-run weapon changes are performed by equipping from the pause-menu inventory.  
Each weapon has its own paper-doll **overlay** (carry / rest plus attack and special layers). Body locomotion is shared and unarmed. Attack and special use a body clip per weapon class with the weapon layered on top — not a baked full-character animation set per weapon.  
Specials for all weapons are activated with LT.  
All player attacks (basic and special) MUST clearly telegraph their range and provide a visible indication that the attack is currently active.

## Hit coverage

Hits are not cylinder-vs-origin tests. Live registration uses opaque sprite occupancy against the attack volume (`Cover` in `scripts/combat/cover.gd`).

- Occupancy is the opaque texels of the target `Sprite3D` (player, enemy, dummy, or breakable). Transparent pixels MUST NOT register.
- Axe and staff basics: the ground fan must overlap those opaque samples on screen. Any opaque overlap is a hit.
- Damage scale is how *planted* the contact is, not how much of the body was covered. Center / start of the fan is full damage. Falloff exists only toward the far tip of the telegraph (`cover_full`, `cover_edge_mult`).
- Crits MAY roll only on a planted contact (coverage at the full-damage band). Glancing contacts MUST NOT crit.
- Floating numbers: integer damage, hold briefly, then fade. Glance numbers are smaller and dimmer. The number and its dark outline MUST sort in front of the target sprite and its health bar.
- Breakables use the same occupancy test. Any connected hit breaks them.
- The Placeholdia dummy uses the same occupancy test. It MUST NOT take knockback. At 0 HP it refills instead of despawning.

## Great Axe

- Basic attack: Hold-to-attack (RT / LMB). Continues automatically while held. Arc and range are tunable. A single swing can hit multiple enemies inside the fan. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation frame.
- Special (Slam): Short wind-up and recovery. Higher damage multiplier than a basic attack (exact value tunable). Applies a readable stagger (shorter duration against Floor Guardians and the Gate Master). Produces dedicated ground-crack VFX. Uses circular occupancy around the player.

## Lightning Staff

- Basic attack: Hold-to-attack (RT / LMB). Weak melee strikes that continue automatically while held. Range and arc are shorter and lower-damage than the Great Axe (exact values tunable). A single strike can hit multiple enemies inside its fan. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation frame.
- Special: AoE lightning bolt that strikes a targeted area. Possesses a distinct short wind-up. Damage, radius, and any secondary effects are tunable. MUST clearly telegraph the affected area and show when the bolt is active. Uses circular occupancy at the strike point.

## Longbow

- Idle aim: a single straight translucent yellow line at shoulder height, weapon range. Axe and staff keep the ground aim line. Do not stack a second bow telegraph on the idle line. Do not flash the bow path red.
- Basic attack: Hold-to-attack (RT / LMB) fires one arrow that travels along that path. The projectile MUST face travel, sit on the line, and test occupancy on the arrow **head** as it moves (`Cover.hit_shot`). Damage application MUST be synchronized to the projectile, not a ground cone.
- Planted bow hits (high coverage) stop the arrow and deal full scaled damage. A glancing hit MAY continue, MAY strike one more enemy, and MUST reduce remaining damage from the first contact’s coverage. After that second body the arrow despawns.
- Breakables do not stop the arrow and do not reduce its damage.
- Special: fires several arrows in a spread (`bow_special_count`, cone, range tunable). Telegraph is one yellow line per shot, not a filled cone. Each arrow is its own occupancy test and may glance independently.

## Critical hits

- Deal double damage.
- Target receives a white flash.
- Floating damage number is shown in yellow + magenta (no additional “CRIT!” text).
- Crits require a planted coverage contact. This is required behavior, not extra juice.

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

Floating damage numbers show integer values only, hold, then fade.

Live numeric defaults are in `design/tunables.md`.