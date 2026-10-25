# Tunables: dungeon and enemies

Status: suggested starts  
Read when: the work changes a dungeon-gen or enemy number  
Code: `scripts/data/balance/vars_world.gd` (live defaults for this file's keys)  

Same table shape and rules as the tunables door; `tools/docs.py tunable get|set|add --key KEY` reads both files.

## Dungeon generation

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Floor grid size (`gen_w` / `gen_h`) | 48×48 – 64×64 | **432×432** | Geo streams like enemies |
| Rooms (`gen_rooms`) | — | **128** | Keeps empty walks short |
| Room min / max (`gen_room_min` / `gen_room_max`) | — | 5 / 9 | |
| Extra loops (`gen_extra_loops`) | — | 8 | MST + extra loops |
| Hall hug gap min / default | 3 / 4 | **3 / 4** | Unused cells between hall floors; closer loops rejected |
| Hall width min / mode / max | 2 / 3 / 4 | **2 / 3 / 4** | Mode changes every `hall_w_interval` |
| Hall width interval | 10 | **10** | Tiles along a winding path |
| Hall width min / mode pct | 0.15 / 0.60 | **0.15 / 0.60** | Remainder is max width |
| Fog of war reveal radius | 5 tiles | 5 | Map disk only, not 3D chunks |
| Max Extraction Gates per floor (`max_clerks`) | 12 | **12** | |
| Ghost shop chance | ~33 % | 0.33 | Always in safe room |
| Named monster rate | ~1 every 3 floors | 3 | |
| Flee events per full clear | Average 2 | 2 | Small speed boost |
| Idle / no-reveal timers | 20–30 s | 24 / 22 | Outside safe rooms |
| Pressure count / radius / cd | — | 3 / 5 / 18 | |
| Pressure waves per floor | 3 | **3** | Caps idle/pressure XP |
| Ambush cap / spacing | 40 / 10 | **40 / 10** | Hall anchors outside rooms |
| Ambush pack min / max | 1 / 2 | **1 / 2** | |
| Stream in / out (cells) | — | **28 / 42** | enemies |
| Geo chunk (cells) | — | **32** | `geo_stream.gd` |
| Geo ring in / out | — | **1 / 2** | Chunks around the player |
| Geo jobs per follow | — | **3** | 1 on the first two frames |
| Crystal min separation | 56 cells | **56** | Between every crystal, dead-ends included |
| Crystal clear radius | 12 cells | **12** | Enemies block activation |
| Crystal arrive radius | 8 cells | **8** | No respawn after a hop |
| Crystal extra max | 6 | **6** | Plus the entrance crystal |
| Crystal place chance | 0.50 | **0.50** | Per extra CL band after the first |
| Crystal CL band | 2 | **2** | Walk-level CL per placement band |
| Crystal dead-end sep | 32 | **32** | Minimum Manhattan from spawn |
| Crystal dead-end length | 28 | **28** | Spur walk to nearest multi-exit room |
| Smallest floor | — | **24×24 cells, 6 rooms** | Floors never generate smaller than this, whatever the sliders say |
| Boss room distance | — | **16 cells or half the floor side; 55 % of the farthest walk** | The boss is always a real trek from spawn |
| Extraction Gate spacing | — | **28 cells, relaxed by 4 down to 8** | Gates spread across the whole floor before any cluster |
| Hall travelers | — | **run ≥ 10 cells; one per 14–18 cells, ≥ 10 apart** | Lone corridor enemies between rooms |

## Enemies and combat level

| Key | Live default |
|-----|--------------|
| `leash_range` | 9 |
| `hunt_duration` | 1.8 |
| `reaggro_cd` | 0.6 |
| `aggro_range` | 7.5 |
| `flee_speed_mult` | 1.45 |
| `flee_hp_frac` | 0.4 |
| `FLEE_PACK_MEAN` | 4 (`tunables.gd`; flee packs per floor) |
| `flee_run_time` | 1.15 |
| `flee_help` | 2 |
| `boss_hp_mult` | 8 |
| `cycle_hp` | 0.2 |
| Normal enemy types (roster / per floor) | **12 / at least 5** |
| Floor-1 full-clear target | **CL 17** (rooms + capped ambushes + capped pressure waves) |
| `base_guards` | **5** |
| `room_pack` | 3 |
| `named_scale` / `named_hp` / `named_dmg` | 1.28 / 1.8 / 1.35 |
| `windup_melee` / `windup_ranged` / `windup_mage` | 0.42 / 0.38 / 0.55 |
| `enemy_recover` | 0.35 |
| `enemy_proj_speed` | 9 |
| `los_period` | **0.12** |
| `sep_max` | **6** |
| `enemy_cl_per_floor` | **20** |
| `enemy_cl_end_pct` | 0.86 |
| `enemy_cl_jitter` | 1 |
| `enemy_cl_dmg` / `enemy_cl_gear_dmg` | 0.072 / 0.048 |
| `enemy_cl_hp` / `enemy_cl_gear_hp` | 0.040 / 0.064 |
| `enemy_cl_def` / `enemy_cl_gear_def` | 1.6 / 1.2 |
| `cl_dealt_up` / `cl_dealt_down` | **1.03 / 0.97** |
| `cl_received_up` / `cl_received_down` | **0.97 / 1.03** |
| `cl_style_weight` | 0.5 |
| `xp_per_kill` | **22** |
| `xp_kill_hp` / `xp_kill_def` | **11.0 / 11.0** |

Roster HP: `enemies.gd`. CL 17 budget and rank multipliers: combat. Walk vs crystal labels: enemies and dungeon.

Progression, economy, anvil / affixes and UI / feel targets: `tunables-economy.md`.
