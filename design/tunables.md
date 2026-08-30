# Tunables

Status: suggested starts + live snapshot
Read when: changing feel, gen size, economy, or debug defaults
Code: `scripts/data/balance.gd`, `scripts/data/tunables.gd`
See also: the topic file for the system you are changing

These are recommended starting points for the current live implementation.
Every value **MUST** be exposed in the debug menu and treated as non-final.
Suggested starts came from the old GDD Appendix A.
Live defaults are what `balance.gd` / `tunables.gd` ship today.
If you change a live default, update this table in the same slice.

## Camera / presentation (`tunables.gd`)

| Key | Live |
|-----|------|
| `CAM_PITCH` | -58 |
| `CAM_HEIGHT` | 14 |
| `LOOK_LIFT` | 0.42 |
| `ZOOM_MIN` / `ZOOM_MAX` | 1.0 / 1.75 |
| `TILE` / `PX` | 1.0 / 64 |
| `BITTER_LOOP_DEFAULT` | 15.52 |
| `PATREON_URL` | https://www.patreon.com/cw/ViraXVespa |
| `ARCHIVE_ID_FULL_3D` | full_3d_pass |
| `ARCHIVE_LABEL_FULL_3D` | Full 3D Pass |

## Movement and combat

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Base move speed | 4.5 | 4.5 | Feel weighty but responsive |
| Dash speed multiplier | 2.8 | 2.8 | Full i-frames for entire duration |
| Dash duration | 0.28 s | 0.28 | |
| Dash cooldown | 1.1 s | 1.1 | |
| Special (LT) wind-up | 0.22 s | 0.22 | Applies to all weapon specials |
| Special recovery | 0.35 s | 0.35 | |
| Attack move mult | — | 0.45 | |
| Great Axe Slam damage multiplier | 1.8× | 1.8 | vs basic attack |
| Basic attack arc (Great Axe) | 110° | 110 | |
| Axe damage / range / rate | — | 18 / 1.85 / 1.7 | |
| Axe LOS | tunable | false | |
| Slam radius / stagger / boss stagger | — | 2.2 / 0.85 / 0.35 | |
| Staff damage / range / arc / rate | — | 9 / 1.2 / 80 / 2.2 | |
| Staff special damage / radius | — | 24 / 2.15 | |
| Bow damage / range / proj speed / rate | — | 14 / 8 / 14 / 1.9 | |
| Bow LOS | tunable | true | |
| Bow special count / cone / range / dmg | 5 arrows | 5 / 50° / 6.5 / 10 | |
| Crit chance | 12 % | 0.12 | Double damage + yellow/magenta numbers |
| Crit mult | 2× | 2.0 | |
| Adrenaline kill window | 4.5 s | 4.5 | |
| Adrenaline kill threshold | 4 | 4 | |
| Adrenaline speed / XP stack / timeout | — | 1.35 / 0.15 / 4.5 | |
| Knockback / hitstop | — | 3.4 / 0.055 | |
| Player max HP | — | 100 | |
| Hurt i-frame | — | 0.35 | |
| Defense k | — | 100 | diminishing returns |
| Aim-line on / opacity / width | on | true / 0.85 / 0.08 | |
| Aim-line use weapon range / length | — | true / 4.0 | |

## Gathering (hit-based)

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Mining hits per node | 4 | 4 | Range 3–5 |
| Mining time between hits | 2.4 s | 2.4 | |
| Mining base reward chance | 65 % | 0.65 | Scaled by Mining skill + pickaxe |
| Woodcutting hits per node | 8 | 8 | Range 6–10 |
| Woodcutting time between hits | 1.2 s | 1.2 | |
| Woodcutting base reward chance | ~32 % | 0.32 | Approximately 50 % lower than mining |
| Skill gather / tool gather | — | 0.02 / 0.03 | per level / tool quality |
| Mine nodes / wood nodes | — | 18 / 14 | |
| Break count / gold / orb | — | 24 / 0.55 / 0.35 | |
| Orb heal | — | 18 | |
| Crack HP | 8 | 8 | |

## Dungeon generation

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Floor grid size | 48×48 – 64×64 | **216×216** | Live rebalance; must still feel expansive |
| Rooms | — | 36 | |
| Room min / max | — | 5 / 9 | |
| Extra loops | — | 8 | MST + extra loops |
| Fog of war reveal radius | 5 tiles | 5 | Visited tiles stay revealed |
| Max clerks per floor | 3 | 3 | |
| Ghost shop chance | ~33 % | 0.33 | Always in safe room |
| Named monster rate | ~1 every 3 floors | 3 | |
| Flee events per full clear | Average 2 | 2 | Small speed boost on fleeing enemy |
| Idle / no-reveal timers | 20–30 s | 24 / 22 | Outside safe rooms |
| Pressure count / radius / cd | — | 3 / 5 / 18 | |
| Stream in / out (cells) | — | **28 / 42** | `dungeon_stream.gd` |

## Enemies and combat level

| Key | Live default |
|-----|--------------|
| `leash_range` | 9 |
| `hunt_duration` | 1.8 |
| `reaggro_cd` | 0.6 |
| `aggro_range` | 7.5 |
| `flee_speed_mult` | 1.45 |
| `flee_hp_frac` | 0.4 |
| `flee_run_time` | 1.15 |
| `flee_help` | 2 |
| `boss_hp_mult` | 8 |
| `cycle_hp` | 0.2 |
| `base_guards` | 8 |
| `room_pack` | 3 |
| `named_scale` / `named_hp` / `named_dmg` | 1.28 / 1.8 / 1.35 |
| `windup_melee` / `windup_ranged` / `windup_mage` | 0.42 / 0.38 / 0.55 |
| `enemy_recover` | 0.35 |
| `enemy_proj_speed` | 9 |
| `enemy_cl_per_floor` | 5 |
| `enemy_cl_end_pct` | 0.86 |
| `enemy_cl_jitter` | 1 |
| `enemy_cl_dmg` / `enemy_cl_gear_dmg` | 0.072 / 0.048 |
| `enemy_cl_hp` / `enemy_cl_gear_hp` | 0.040 / 0.064 |
| `enemy_cl_def` / `enemy_cl_gear_def` | 1.6 / 1.2 |
| `cl_dealt_up` / `cl_dealt_down` | 1.075 / 0.925 |
| `cl_received_up` / `cl_received_down` | 0.925 / 1.075 |
| `cl_xp_up` / `cl_xp_down` | 1.1 / 0.9 |
| `cl_style_weight` | 0.5 |
| `xp_kill_hp` / `xp_kill_def` | 3.0 / 3.0 |

## Progression and economy

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Bag capacity | 28 | 28 | |
| Food bring max | 20 | 20 | |
| Permanent XP keep rate on death | 15–25 % | **0.20** | Must feel meaningful after a good run |
| Kill HP XP / kill Defense XP | — | **3.0 / 3.0** | On top of hit/heal XP; ~1/3 of a combat skill’s typical per-kill XP |
| Shrine damage buff | +20 % / 45 s | 0.2 / 45 | |
| Campfire heal | 40 % max HP | 0.4 | |
| Food HoT total (X) | 40 HP | 40 | Delivered over Y seconds |
| Food HoT duration (Y) | 8 s | 8 | Same food does not restack |
| Potion instant heal (Z) | 100 % max HP | 100 | Instant; distinct from food |
| Forge gold / ore / root / time | — | 18 / 6 / 2 / 2 | |
| Snack cost / heal | 25 g | 25 / 22 | |
| Artifact cost | — | 40 | |
| Pawn gold | — | 8 | |

## UI / feel targets

| Parameter | Suggested start | Notes |
|-----------|-----------------|-------|
| Camera zoom range | 1.0 – 1.75 | Persisted in save |
| Target first-extraction time | 5–10 min | New player on gamepad |
| Target floor-6 clear time | 5–10 hours | Competent player; feel target |
| FPS | 60 minimum | Higher allowed |

All other values (enemy stats, drop rates, remaining forge fields, weapon-specific leftovers, quest rewards, leash-adjacent keys, Bitter loop offset timestamp, etc.) should be chosen to support the same feel targets and MUST also be exposed in the debug menu.