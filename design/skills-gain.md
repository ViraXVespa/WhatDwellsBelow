# Skills — XP gain

Status: current plan
Read when: eleven mandatory ids, permanent fragment, hitpoints stacking
Code: `scripts/data/progress_combat/combat_xp.gd` (run XP, adrenaline), `scripts/data/progress_combat/stat.gd` (hit XP), `scripts/data/progress_combat/xp_curve.gd`

## Skills included in the demo

- Great Axe
- Staff
- Longbow
- Strength
- Magic
- Ranged
- Defense
- Hitpoints
- Mining
- Woodcutting
- Smithing

These eleven are mandatory.

Live ids: `axe`, `staff`, `bow`, `str`, `mag`, `rng`, `def`, `hp`, `mine`, `wood`, `smith`.

## XP gain and permanent progression

- During a run the player accumulates “run XP” in each skill.
- On death or voluntary “Dispel”, only a small fragment of that run XP is kept permanently.
- The recap screen MUST contain a clear visual sequence that shows the run XP values draining down to the permanent fragment amounts, after which the new permanent XP totals and resulting levels are displayed.
- Duplicate extracted greens/blues and extra starter-template whites convert to **permanent smithing XP**, not a second stored copy.

## Weapon-specific XP rules

- Great Axe attacks grant Great Axe XP + Strength XP.
- Lightning Staff melee attacks grant Strength XP + Staff XP.
- Lightning Staff special attacks grant Magic XP + Staff XP.
- Longbow attacks (both basic and special) grant Ranged XP + Longbow XP.

## Kill XP

- Defeating an enemy grants weapon + partner-style XP (existing split of `xp_per_kill`).
- The same kill ALSO grants Hitpoints XP and Defense XP. This stacks on top of Defense-from-being-hit and Hitpoints-from-heal.
- Live `xp_kill_hp` / `xp_kill_def` and `xp_per_kill`: the tunables gate (`add_run_xp` applies adrenaline once).
