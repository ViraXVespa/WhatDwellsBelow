# Skills, XP, and combat level

Status: binding design + live snapshot
Read when: changing XP, HUD level text, forging, or enemy scaling vs the player
Code: `scripts/data/progress.gd`, `scripts/app.gd`, `scripts/ui/hud.gd`, `scripts/ui/pause_menu.gd`, `scripts/data/balance.gd`, `scripts/combat/threat.gd`
See also: `design/combat.md`, `design/enemies.md`, `design/ui.md`, `design/tunables.md`

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

## Weapon-specific XP rules

- Great Axe attacks grant Great Axe XP + Strength XP.
- Lightning Staff melee attacks grant Strength XP + Staff XP.
- Lightning Staff special attacks grant Magic XP + Staff XP.
- Longbow attacks (both basic and special) grant Ranged XP + Longbow XP.

## Kill XP

- Defeating an enemy grants weapon + partner-style XP (existing split of `xp_per_kill`).
- The same kill ALSO grants Hitpoints XP and Defense XP. This stacks on top of Defense-from-being-hit and Hitpoints-from-heal.
- Live starting kill grants: `xp_kill_hp` = 3.0 and `xp_kill_def` = 3.0 (adrenaline applies). That is about one-third of a primary weapon / partner skill’s typical per-kill XP (half of `xp_per_kill` plus hit XP).

## Combat level

- Three style scores are tracked. Each is the **average** of four equally weighted skills, not a 1:1 sum:
  - Melee = (Great Axe + Strength + Defense + Hitpoints) / 4
  - Magic = (Staff + Magic + Defense + Hitpoints) / 4
  - Ranged = (Longbow + Ranged + Defense + Hitpoints) / 4
- One skill level therefore adds +0.25 to that style’s combat level before rounding.
- Calibration: if the two skills of the highest style are 11 and Hitpoints and Defense are also 11, Combat Level is 11.
- Global Combat Level is the highest of the three style scores.
- The HUD displays the player’s highest (global) Combat Level as a rounded integer.
- If the currently equipped weapon’s style Combat Level is lower than the highest, that style level is shown in parentheses next to it (e.g. Level 14 (Magic 11)).

## Skill effects (high-level)

- Great Axe, Staff, Longbow, Strength, Magic, and Ranged: increase damage dealt with the corresponding style or weapon (with possible differential scaling on specials).
- Defense & Hitpoints: increase survivability.
- Mining: improves reward chance and effectiveness with the hit-based mining system.
- Woodcutting: improves reward chance and effectiveness with the hit-based woodcutting system.
- Smithing: reduces forge cost/time and improves output at the anvil.

## Visible power gain after one good run

After a single successful extraction and return to Placeholdia the player MUST be able to notice either:
- a few permanent skill levels, or
- at least one new piece of usable forged gear (or both).

This is a required feel target. Concrete proxy: after one successful run the permanent skill levels or new forged item MUST be visible on the hub loadout/skills screens without external guidance.

## Live snapshot — player CL formulas (`progress.gd`)

```
score(wpn, sty) = (lv(wpn) + lv(sty) + lv(def) + lv(hp)) / 4
melee_f  = score(axe, str)
magic_f  = score(staff, mag)
ranged_f = score(bow, rng)
combat_f = max(melee_f, magic_f, ranged_f)
style_f  = melee_f | magic_f | ranged_f from the equipped weapon
HUD ints = max(1, round(those scores))
```

Example: lv 11 / 11 / 11 / 11 → combat 11.
Fragment rate is `App.bal.xp_keep` (live 0.20). Adrenaline multiplies run XP in `add_run_xp`.

## Live snapshot — enemy combat level

Enemies carry a combat level used to scale fights against the player. Keys live in `balance.gd` and MUST stay in the secret debug menu.

Player CL is now ~1/4 of the old sum-of-four-skills value, so floor span and per-CL enemy stat rates were retuned to keep same-floor raw stats in the same ballpark. Per-level damage factors are softer because one new CL is four old skill-levels.

| Key | Live default | Role |
|-----|--------------|------|
| `enemy_cl_per_floor` | 5 | Expected enemy CL gained per floor |
| `enemy_cl_end_pct` | 0.86 | How close a typical enemy sits to the floor target |
| `enemy_cl_jitter` | 1 | Random CL noise |
| `enemy_cl_dmg` / `enemy_cl_gear_dmg` | 0.072 / 0.048 | Per-CL damage |
| `enemy_cl_hp` / `enemy_cl_gear_hp` | 0.040 / 0.064 | Per-CL HP |
| `enemy_cl_def` / `enemy_cl_gear_def` | 1.6 / 1.2 | Per-CL defense |
| `cl_dealt_up` / `cl_dealt_down` | 1.075 / 0.925 | Outgoing damage vs CL delta |
| `cl_received_up` / `cl_received_down` | 0.925 / 1.075 | Incoming damage vs CL delta |
| `cl_xp_up` / `cl_xp_down` | 1.1 / 0.9 | XP vs CL delta |
| `cl_style_weight` | 0.5 | Style-mismatch weight |
| `xp_kill_hp` / `xp_kill_def` | 3.0 / 3.0 | Extra HP / Defense XP per kill |