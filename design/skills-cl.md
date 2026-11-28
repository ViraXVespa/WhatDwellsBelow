# Skills — combat level

Status: current plan
Read when: style averages, highest-style rounding, calibration example
Code: `scripts/data/progress_combat/xp_curve.gd` (levels), `scripts/data/progress.gd` (CL scores), `scripts/ui/hud.gd`

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
- Dungeon item level uses enemy / area combat level. That item level is what Analyze stores and what Forge can configure up to.

Enemy floor band and CL 17 budget: combat. Enemy walk / pack HP: enemies. Live keys: the tunables gate.

## Player CL formulas (`progress.gd`)

score(wpn, sty) = (lv(wpn) + lv(sty) + lv(def) + lv(hp)) / 4  
melee_f  = score(axe, str)  
magic_f  = score(staff, mag)  
ranged_f = score(bow, rng)  
combat_f = max(melee_f, magic_f, ranged_f)  
style_f  = melee_f | magic_f | ranged_f from the equipped weapon  
HUD ints = max(1, round(those scores))

Example: lv 11 / 11 / 11 / 11 → combat 11.  
Fragment rate is `App.bal.xp_keep` (live 0.20). Adrenaline multiplies run XP once, in `add_run_xp`; the stack (`adrenaline_xp_stack` per kill) is capped at `adrenaline_xp_max` (2.0).

Player CL is ~1/4 of the sum of the four skills. Floor span and per-CL enemy rates live in the tunables gate so same-floor raw stats stay in the same ballpark.
