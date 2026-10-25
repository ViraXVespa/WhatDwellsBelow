# Tunables: combat, gathering, drops and consumables

Status: suggested starts  
Read when: the work changes a movement, combat, gathering, drop or consumable number  

Same table shape and rules as the tunables door; `tools/docs.py tunable get|set|add --key KEY` reads every tunables file.

## Movement and combat

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Base move speed | 4.5 | 4.5 | Feel weighty but responsive |
| Dash speed multiplier | 2.8 | 2.8 | Full i-frames for entire duration |
| Dash duration | 0.28 s | 0.28 | |
| Dash cooldown | 1.1 s | 1.1 | |
| Special (LT) wind-up | 0.22 s | 0.22 | Applies to all weapon specials |
| Special recovery | 0.35 s | 1.5 | Special cooldown (HUD special meter) |
| `special_mana` | - | 20 | - |
| `mana_max` | - | 100 | - |
| `mana_regen` | - | 3 | - |
| Attack move mult | — | 0.45 | |
| Great Axe Slam damage multiplier | 1.8× | 1.8 | vs basic attack |
| Basic attack arc (Great Axe) | 110° | 110 | |
| Axe damage / range / rate | — | **16 / 1.85 / 1.7** | Lowered so packs survive a few swings |
| Axe LOS | tunable | false | |
| Slam radius / stagger / boss stagger | — | 2.2 / 0.85 / 0.35 | |
| Staff damage / range / arc / rate | — | 9 / 1.2 / 80 / 2.2 | |
| Staff special damage / radius | — | 24 / 2.15 | |
| Bow damage / range / proj speed / rate | — | 14 / 8 / 14 / 1.9 | |
| Bow LOS | tunable | true | |
| Bow special count / cone / range / dmg | 5 arrows | 5 / 50° / 6.5 / 10 | Yellow spread lines, not a filled cone |
| Crit chance | 12 % | 0.12 | Planted coverage only; gear adds `crit_chance` |
| Crit mult | 2× | 2.0 | Gear adds `crit_dmg` on top |
| Adrenaline kill window | 4.5 s | 4.5 | |
| Adrenaline kill threshold | 4 | 4 | |
| Adrenaline speed / XP stack / XP max / timeout | — | 1.35 / 0.15 / 2.0 / 4.5 | |
| Knockback / hitstop | — | 3.4 / 0.055 | Dummy ignores knockback |
| Player max HP | — | 100 | |
| Hurt i-frame | — | 0.35 | |
| Defense k | — | 100 | diminishing returns |
| Aim-line on / opacity / width | on | true / 0.85 / 0.08 | Bow line is shoulder height. Mesh hidden until `update_line`. |
| Aim-line use weapon range / length | — | true / 4.0 | Gear `atk_range` extends reach |
| Cover full-band / edge mult | — | 0.18 / 0.35 | Full damage until the last 18% of fan radius |
| Cover columns / alpha | — | 24 / 0.4 | Opaque mask grid |
| Pierce stop | — | 0.85 | Arrow despawns at this coverage. Fixed in `Cover.stops_arrow`, no key |
| Arrow tip radius | — | 0.28 | Head disk. Far hosts skip `hit_shot`. |
| Bow path width | — | 0.12 | Special spread line width |

## Gathering (hit-based)

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Mining hits per node | 4 | 4 | Range 3–5 |
| Mining time between hits | 2.4 s | 2.4 | Tool `gather_spd` shortens interval |
| Mining base reward chance | 65 % | 0.65 | Scaled by Mining skill + pickaxe + `yield_chance` |
| Woodcutting hits per node | 8 | 8 | Range 6–10 |
| Woodcutting time between hits | 1.2 s | 1.2 | |
| Woodcutting base reward chance | ~32 % | 0.32 | Approximately 50 % lower than mining |
| Pressure plate trigger radius | — | 0.7 m | How close the player steps to press it |
| Skill gather / tool gather | — | 0.02 / 0.03 | per level / tool quality |
| Mine nodes / wood nodes | — | 18 / 14 | |
| Break count / gold / orb | — | 24 / 0.55 / 0.35 | |
| Orb heal | — | 18 | |

## Enemy drops

Each kill rolls each pickup on its own (`enemy_hit.gd` `roll_drops`); a kill can drop nothing (~66 % no gold or orb). Bosses skip the gear roll (their chest is separate).

| Key | Live default | Notes |
|-----|--------------|-------|
| `enemy_gold_chance` | 0.25 | Bosses always drop gold. Amount unchanged (`enemy_gold_base` / `_span`) |
| `enemy_orb_chance` | 0.06 | HP orb, heals `orb_heal` |
| `enemy_mana_chance` | 0.06 | Mana orb, same pickup radius as the HP orb |
| `orb_mana` | 25 | Restores mana. A full bar does not take the orb |
| `enemy_gear_chance` + `enemy_gear_floor` × floor | 0.0171 + 0.00286 | ~2 % on floor 1, +0.29 pt per floor (f5 3.1 %, f10 4.6 %) |
| Normal-kill gold amount | old roll ÷ `enemy_gold_chance`, rounded | Keeps expected gold per kill equal to the old 100 % drop (f1 2.0, f2 2.5); bosses keep the old roll + `boss_gold_extra` |
| Pickup radius | 0.55 m (unchanged, `pickup.gd`) | No magnet |
| Crack HP | 8 | 8 | |

## Consumables (secret debug menu, category Consumables)

Hub holds and vendor rolls. Costs stay `vendor_potion_cost`, `vendor_food_cost`, and `vendor_ore_gold`. Stack size per food kind stays `food_bring_max`.

| Key | Default | What it does |
|-----|---------|--------------|
| `potion_hold_max` | 3 | Different potions kept in the hub |
| `potion_charges_min` / `potion_charges_max` | 1 / 4 | Rolled charge count |
| `potion_heal_min` / `potion_heal_max` | 40 / 140 | Rolled heal. The starter still uses `potion_heal` |
| `potion_cd_min` / `potion_cd_max` | 4 / 12 | Rolled cooldown, seconds |
| `potion_speed_min` / `potion_speed_max` | 0 / 6 | Rolled heal time. 0 is instant |
| `potion_bonus_chance` | 0.35 | Chance a roll also grants a short stat bonus |
| `potion_bonus_secs_min` / `potion_bonus_secs_max` | 3 / 6 | How long that bonus lasts |
| `potion_bonus_flat` / `potion_bonus_pct` | 2 / 0.04 | Size of the bonus, flat or percent by the stat |
| `food_kind_max` | 6 | Different food stacks in the hub |
| `food_ration_heal` / `food_ration_secs` / `food_ration_bonus` | 40 / 8 / 1 | Ration heal, seconds, defense |
| `food_ration_mana` | 20 | - |
| `potion_mana` | 40 | - |
| `food_bread_heal` / `food_bread_secs` / `food_bread_bonus` | 28 / 12 / 0.05 | Trail bread heal, seconds, move speed |
| `food_bread_mana` | 15 | - |
| `food_stew_heal` / `food_stew_secs` / `food_stew_bonus` | 56 / 6 / 4 | Root stew heal, seconds, max health |
| `food_stew_mana` | 30 | - |
| `food_moldy_heal` / `food_moldy_secs` / `food_moldy_bonus` | 14 / 8 / 0 | Moldy bread. Weaker than the ration, no bonus |
| `food_moldy_mana` | 8 | - |
