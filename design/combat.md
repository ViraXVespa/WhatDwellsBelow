# Combat

Status: current plan
Read when: strikes, hit registration, juice
Code: `scripts/combat/` except the enemy cluster (code map row Combat; gdhealth group `combat`)

This file is the door. Open the Job-table sibling only when that row matches.

Player-side combat: weapons, hit registration on opaque sprite texels, crits, dash, adrenaline and the combat-level feel. Enemy roster, AI and drops live with enemies; enemy code calls into combat code, never the reverse.

All player attacks (basic and special) MUST clearly telegraph their range and provide a visible indication that the attack is currently active. Numbers live in the tunables gate (tunables-combat).

| Job | Open |
|-----|------|
| great axe, lightning staff, longbow arrows, special mana | `design/combat-weapons.md` |
| opaque coverage, glancing blows, crit roll, damage numbers, diminishing defense | `design/combat-hits.md` |
| dash iframes, adrenaline rush, target-lock pointer | `design/combat-moves.md` |
| rank multipliers, CL budget, one-shot guard | `design/combat-threat.md` |
