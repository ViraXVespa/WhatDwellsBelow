# Tunables

Status: suggested starts + live snapshot  
Read when: changing feel, gen size, economy, crystals, or debug defaults  
Code: `scripts/data/balance.gd`, `balance_schema.gd`, `balance_enemies.gd`, `balance_migrate.gd`, `scripts/data/tunables.gd`, `scripts/combat/cover.gd`, `scripts/input/touch_pad.gd`  
See also: the topic file for the system you are changing

These are recommended starting points for the current live implementation.  
Every value **MUST** be exposed in the debug menu and treated as non-final.  
Suggested starts came from the old GDD Appendix A.  
Live defaults are what `balance.gd` / `tunables.gd` ship today.  
If you change a live default, update this table in the same slice.

`BAL_REV` is 9. Old saves pick up the dungeon/combat retune through `balance_migrate.gd`.

## Camera / presentation (`tunables.gd`)

| Key | Live |
|-----|------|
| `CAM_PITCH` | -58 |
| `CAM_HEIGHT` | 14 |
| `LOOK_LIFT` | 0.42 |
| `ZOOM_MIN` / `ZOOM_MAX` | 1.0 / 2.5 |
| Default `cam_zoom` | 1.75 |
| `TILE` / `PX` | 1.0 / 64 |
| Default `sprite_filter` | 2 (nearest + mips + aniso) |
| `sprite_mip_sharp` | false (smooth mip blend) |
| `sprite_mip_bias` | 0.0 (stored; Sprite3D has no lod-bias hook yet) |
| `BITTER_LOOP_DEFAULT` | 15.52 |
| `PATREON_URL` | https://www.patreon.com/cw/ViraXVespa |
| `ARCHIVE_ID_FULL_3D` | full_3d_pass |
| `ARCHIVE_LABEL_FULL_3D` | Full 3D Pass |
| Archive catalog | `scripts/data/archive_catalog.json` |
| `TOUCH_TAP_WINDOW` | 0.28 |
| `TOUCH_DEAD` | 0.24 |

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
| Axe damage / range / rate | — | **16 / 1.85 / 1.7** | Lowered so packs survive a few swings |
| Axe LOS | tunable | false | |
| Slam radius / stagger / boss stagger | — | 2.2 / 0.85 / 0.35 | |
| Staff damage / range / arc / rate | — | 9 / 1.2 / 80 / 2.2 | |
| Staff special damage / radius | — | 24 / 2.15 | |
| Bow damage / range / proj speed / rate | — | 14 / 8 / 14 / 1.9 | |
| Bow LOS | tunable | true | |
| Bow special count / cone / range / dmg | 5 arrows | 5 / 50° / 6.5 / 10 | Yellow spread lines, not a filled cone |
| Crit chance | 12 % | 0.12 | Planted coverage only; double damage + yellow/magenta numbers |
| Crit mult | 2× | 2.0 | |
| Adrenaline kill window | 4.5 s | 4.5 | |
| Adrenaline kill threshold | 4 | 4 | |
| Adrenaline speed / XP stack / timeout | — | 1.35 / 0.15 / 4.5 | |
| Knockback / hitstop | — | 3.4 / 0.055 | Dummy ignores knockback |
| Player max HP | — | 100 | |
| Hurt i-frame | — | 0.35 | |
| Defense k | — | 100 | diminishing returns |
| Aim-line on / opacity / width | on | true / 0.85 / 0.08 | Bow line is shoulder height |
| Aim-line use weapon range / length | — | true / 4.0 | |
| Cover full-band / edge mult | — | 0.18 / 0.35 | Full damage until the last 18% of fan radius |
| Cover columns / alpha | — | 28 / 0.4 | Opaque mask grid |
| Pierce stop | — | 0.85 | Arrow despawns at this coverage |
| Arrow tip radius | — | 0.16 | Head disk |
| Bow path width | — | 0.08 | Special spread line width |

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
| Floor grid size | 48×48 – 64×64 | **432×432** | Geo streams like enemies |
| Rooms | — | **64** | Dense enough that empty walks stay short |
| Room min / max | — | 5 / 9 | |
| Extra loops | — | 8 | MST + extra loops |
| Hall width min / mode / max | 2 / 3 / 4 | **2 / 3 / 4** | Mode 3; changes every `hall_w_interval` |
| Hall width interval | 10 | **10** | Tiles along a winding path |
| Hall width min / mode pct | 0.15 / 0.60 | **0.15 / 0.60** | Remainder is max width |
| Fog of war reveal radius | 5 tiles | 5 | Map disk only. 3D chunks are not fog-gated |
| Max Extraction Gates per floor (`max_clerks`) | 3 | 3 | |
| Ghost shop chance | ~33 % | 0.33 | Always in safe room |
| Named monster rate | ~1 every 3 floors | 3 | |
| Flee events per full clear | Average 2 | 2 | Small speed boost on fleeing enemy |
| Idle / no-reveal timers | 20–30 s | 24 / 22 | Outside safe rooms |
| Pressure count / radius / cd | — | 3 / 5 / 18 | |
| Pressure waves per floor | 3 | **3** | Caps idle/pressure XP |
| Ambush cap / spacing | 40 / 10 | **40 / 10** | Hall anchors outside rooms |
| Ambush pack min / max | 1 / 2 | **1 / 2** | |
| Stream in / out (cells) | — | **28 / 42** | enemies |
| Geo chunk (cells) | — | **32** | `dungeon_geo_stream.gd` |
| Geo ring in / out | — | **1 / 2** | Chunks around the player |
| Geo jobs per follow | — | **3** | 9 on a long tick |
| Crystal min separation | 56 cells | **56** | Between band crystals |
| Crystal clear radius | 12 cells | **12** | Enemies that block activation |
| Crystal arrive radius | 8 cells | **8** | No respawn after a hop |
| Crystal extra max | 4 | **4** | Plus the entrance crystal |
| Crystal place chance | 0.62 | **0.62** | Per extra CL band after the first extra |
| Crystal dead-end sep | 18 | **18** | Dead-end crystals ignore the band cap |

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
| `base_guards` | **5** |
| `room_pack` | 3 |
| `named_scale` / `named_hp` / `named_dmg` | 1.28 / 1.8 / 1.35 |
| `windup_melee` / `windup_ranged` / `windup_mage` | 0.42 / 0.38 / 0.55 |
| `enemy_recover` | 0.35 |
| `enemy_proj_speed` | 9 |
| `enemy_cl_per_floor` | **20** |
| `enemy_cl_end_pct` | 0.86 |
| `enemy_cl_jitter` | 1 |
| `enemy_cl_dmg` / `enemy_cl_gear_dmg` | 0.072 / 0.048 |
| `enemy_cl_hp` / `enemy_cl_gear_hp` | 0.040 / 0.064 |
| `enemy_cl_def` / `enemy_cl_gear_def` | 1.6 / 1.2 |
| `cl_dealt_up` / `cl_dealt_down` | **1.03 / 0.97** |
| `cl_received_up` / `cl_received_down` | **0.97 / 1.03** |
| `cl_xp_up` / `cl_xp_down` | **1.04 / 0.97** |
| `cl_style_weight` | 0.5 |
| `xp_per_kill` | **22** |
| `xp_kill_hp` / `xp_kill_def` | **11.0 / 11.0** |

Roster HP lives in `balance_enemies.gd` (about 2× the pre-retune table). Floor-1 full clear of the budgeted spawn list targets combat level ~17.

## Progression and economy

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Bag capacity | 28 | 28 | |
| Food bring max | 20 | 20 | |
| Permanent XP keep rate on death | 15–25 % | **0.20** | Must feel meaningful after a good run |
| Kill HP XP / kill Defense XP | — | **11.0 / 11.0** | On top of hit/heal XP |
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
| Camera zoom range | 1.0 – 2.5 | Persisted in save. Default 1.75 (slider midpoint). |
| Touch attack tap window | 0.28 s | Double-tap latches hold-to-attack. Debug Settings slider. |
| Touch stick deadzone | 0.24 | Same magnitude idea as pad sticks. Debug Settings slider. |
| Target first-extraction time | 5–10 min | New player on gamepad |
| Target floor-5 clear time | 5–10 hours | Competent player; feel target |
| FPS | 60 minimum | Higher allowed |

All other values (enemy stats, drop rates, remaining forge fields, weapon-specific leftovers, quest rewards, leash-adjacent keys, Bitter loop offset timestamp, etc.) should be chosen to support the same feel targets and MUST also be exposed in the debug menu.