# Combat — hits and crits

Status: current plan
Read when: opaque coverage, glancing blows, crit roll, damage numbers, diminishing defense
Code: `scripts/combat/cover.gd` (facade) + `cover/` (`cover_hit.gd` texel masks and arrow tips, `geom.gd` fan and disk, `cover_shape.gd` sprite geometry), `combat.gd` (crit roll, LOS), `float_num.gd`, `hp_bar.gd`, `dummy.gd`, `player_hit/hit_core.gd`

## Hit coverage

Hits are not cylinder-vs-origin tests. Live registration uses opaque sprite occupancy against the attack volume (`Cover` in `scripts/combat/cover.gd`).

- Occupancy is the opaque texels of the target `Sprite3D` (player, enemy, dummy, or breakable). Transparent pixels MUST NOT register.
- Axe and staff basics: the ground fan must overlap those opaque samples on screen. Any opaque overlap is a hit.
- Damage scale is how *planted* the contact is, not how much of the body was covered. Center / start of the fan is full damage. Falloff exists only toward the far tip of the telegraph (`cover_full`, `cover_edge_mult`).
- Crits MAY roll only on a planted contact (coverage at the full-damage band). Glancing contacts MUST NOT crit.
- Floating numbers: integer damage, hold briefly, then fade. Glance numbers are smaller and dimmer. The number and its dark outline MUST sort in front of the target sprite and its health bar.
- Breakables use the same occupancy test. Any connected hit breaks them.
- The Placeholdia dummy uses the same occupancy test. It MUST NOT take knockback. At 0 HP it refills instead of despawning.

## Critical hits

- Deal double damage.
- Target receives a white flash.
- Floating damage number is shown in yellow + magenta (no additional “CRIT!” text).
- Crits require a planted coverage contact. This is required behavior, not extra juice.

## Defense

- Uses a diminishing-returns formula (exact formula tunable).
- Armor pieces contribute defense and may carry minor secondary stats.

Floating damage numbers show integer values only, hold, then fade.
