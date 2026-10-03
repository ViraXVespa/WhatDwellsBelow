# Tunables: world, economy and UI

Status: suggested starts + live snapshot  
Read when: the work changes a dungeon-gen, enemy, progression, anvil or UI-feel number  

Same table shape and rules as the tunables door; `tools/tunables.py get|set|add --key KEY` reads both files.

## Dungeon generation

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Floor grid size | 48×48 – 64×64 | **432×432** | Geo streams like enemies |
| Rooms | — | **128** | Keeps empty walks short |
| Room min / max | — | 5 / 9 | |
| Extra loops | — | 8 | MST + extra loops |
| Hall hug gap min / default | 3 / 4 | **3 / 4** | Unused cells between hall floors; closer loops rejected |
| Hall width min / mode / max | 2 / 3 / 4 | **2 / 3 / 4** | Mode changes every `hall_w_interval` |
| Hall width interval | 10 | **10** | Tiles along a winding path |
| Hall width min / mode pct | 0.15 / 0.60 | **0.15 / 0.60** | Remainder is max width |
| Fog of war reveal radius | 5 tiles | 5 | Map disk only, not 3D chunks |
| Max Extraction Gates per floor (`max_clerks`) | 3 | 3 | |
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
| Geo jobs per follow | — | **3** | 9 on a long tick |
| Crystal min separation | 56 cells | **56** | Between every crystal, dead-ends included |
| Crystal clear radius | 12 cells | **12** | Enemies block activation |
| Crystal arrive radius | 8 cells | **8** | No respawn after a hop |
| Crystal extra max | 6 | **6** | Plus the entrance crystal |
| Crystal place chance | 0.50 | **0.50** | Per extra CL band after the first |
| Crystal CL band | 2 | **2** | Walk-level CL per placement band |
| Crystal dead-end sep | 32 | **32** | Minimum Manhattan from spawn |
| Crystal dead-end length | 28 | **28** | Spur walk to nearest multi-exit room |
| Outline fine size (`outline_fine_m`) | 0.25 m | **0.25** | Piece-bake resolution only |
| Outline fillet fraction (`outline_fillet_frac`) | unused | **unused** | Wear is shader-side |
| Outline jag fraction (`outline_jag_frac`) | unused | **unused** | Wear is shader-side |
| Angled corridors max (`angled_corridor_max`) | 4 | **4** | First-class off-axis halls per floor |
| Corner chords max (`corner_chord_max`) | 8 | **8** | Short turn cuts per floor |
| Angled degrees (`angled_deg`) | 27 / 33 / 45 | **27 / 33 / 45** | Snap targets |
| Angled snap (`angled_snap_deg`) | 6 | **6** | Degrees off target before the link stays cardinal |
| Angled vs dogleg (`angled_vs_dogleg_min`) | 12 | **12** | Extra cardinal tiles before angled wins |

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
| `cl_xp_up` / `cl_xp_down` | **1.04 / 0.97** |
| `cl_style_weight` | 0.5 |
| `xp_per_kill` | **22** |
| `xp_kill_hp` / `xp_kill_def` | **11.0 / 11.0** |

Roster HP: `enemies.gd`. CL 17 budget and rank multipliers: combat. Walk vs crystal labels: enemies and dungeon.

## Progression and economy

| Parameter | Suggested start | Live default | Notes |
|-----------|-----------------|--------------|-------|
| Bag capacity | 28 | 28 | |
| Food bring max | 20 | 20 | |
| Permanent XP keep rate on death | 15–25 % | **0.20** | Meaningful after a good run |
| Shrine damage buff | +20 % / 45 s | 0.2 / 45 | |
| Campfire heal | 40 % max HP | 0.4 | |
| Food HoT total (X) | 40 HP | 40 | Delivered over Y seconds |
| Food HoT duration (Y) | 8 s | 8 | Same food does not restack |
| Potion instant heal (Z) | 100 % max HP | 100 | Instant; distinct from food |
| Snack cost / heal | 25 g | 25 / 22 | |
| Artifact cost | — | 40 | |
| Pawn gold | — | 8 | |

## Anvil / affixes

Fallbacks in `progress_forge.gd` / `gear_roll.gd` until these keys exist on `App.bal`. Root is no forge material.

| Key | Fallback | Role |
|-----|----------|------|
| `forge_gold` | 18 | Base gold |
| `forge_gold_per_lv` | 3 | Extra gold per item level above 1 |
| `forge_ore` | 6 | Base ore |
| `forge_ore_per_lv` | 1 | Extra ore per item level |
| `forge_wood` | 4 | Base wood (weapon + tool only) |
| `forge_wood_per_lv` | 1 | Extra wood per item level |
| `forge_blue_mult` | 1.45 | Blue rarity multiplier |
| `forge_lock_mult` | 2.0 | Per-lock multiplier (`pow` by lock count) |
| `forge_smith_disc` | 0.03 | Cost discount per smith level above 1 |
| `forge_time` | 2.0 | Craft-beat base seconds |
| `forge_time_min` / `forge_time_max` | 0.35 / 8.0 | Clamp |
| `forge_time_step` | 1.15 | `base * step^(ilvl - smith)` |
| `xp_smith` | 12 | Permanent smith XP on a successful hold write |
| `affix_flat_base` | 2.0 | Flat affix base before level |
| `affix_flat_per_lv` | 0.65 | Flat per item level |
| `affix_pct_per_lv` | 0.004 | Percent affix per item level (plus 0.02 floor) |

Roll rules and the holds cap: inventory (gear job).

## UI / feel targets

| Parameter | Suggested start | Notes |
|-----------|-----------------|-------|
| Camera zoom range | 1.0 – 4.0 | Saved. Default 1.75. Wheel / pinch / look-mode RS also set it. |
| HUD scale range | 0.7 – 1.4 | System slider and look-mode RS X. |
| UI text floor | 14 | Debug slider (8–24). Floor is saved; applied scale (clamp formula: debug menu) is recomputed on resize. |
| Look wheel step | 0.08 | Per notch; debug slider. |
| Look pinch gain | 1.15 | Debug slider. |
| Look stick zoom / HUD / pan | 0.9 / 0.35 / 520 | Debug sliders. |
| Map zoom range | 1.0 – 10.0 | Fit to 10×, independent of world camera. |
| Touch stick deadzone | 0.24 | Same magnitude idea as pad sticks. Debug Settings slider. |
| Display mode | borderless | Desktop: windowed / borderless / exclusive. Web: `web_fullscreen` off until a gesture. |
| Target first-extraction time | 5–10 min | New player on gamepad |
| Target floor-5 clear time | 5–10 hours | Competent player; feel target |
| FPS | 60 minimum | Higher allowed |
| Hitch budget | 1/60 s | Frame budget used by the hitch log |
| Hitch multiplier | 4 | Trip when `delta >= budget × 4` (~66.7 ms) |
| Hitch cap | 256 | Newest hitch rows kept in `user://hitch/hitch.jsonl` |

All other values (enemy stats, drop rates, remaining forge fields, weapon-specific leftovers, quest rewards, leash-adjacent keys, Bitter loop offset timestamp, etc.) should be chosen to support the same feel targets and MUST also be exposed in the debug menu.
