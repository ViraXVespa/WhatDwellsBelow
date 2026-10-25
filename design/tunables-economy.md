# Tunables: economy, anvil and UI

Status: suggested starts  
Read when: the work changes a progression, economy, anvil or UI-feel number  
Code: `scripts/data/balance/vars_economy.gd` (live defaults for this file's keys)  

Same table shape and rules as the tunables door; `tools/docs.py tunable get|set|add --key KEY` reads every tunables file.

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
| Ghost shop Artifacts on sale / bought per visit | 2–4 / 2 | 2–4 / 2 | `shop_stock_min`–`max`, `shop_buy_max` |
| Artifact cost | — | 40 | |
| Pawn gold | — | 8 | |

## Anvil / affixes

Live defaults are in `balance/vars_economy.gd` (single source). Code fallbacks in `forge_act.gd` / `gear_roll.gd` only apply when `App.bal` is missing and mirror these. Root is no forge material.

| Key | Default | Role |
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
| `affix_flat_per_lv` | 0.35 | Flat per item level |
| `affix_pct_per_lv` | 0.004 | Percent affix per item level (plus 0.02 floor) |
| `affix_quality_min` / `max` | 0.5 / 1.0 | Dungeon Quality roll; also the Finish keep-filter range |
| `affix_luck_min` / `max` | 0.75 / 1.25 | Dungeon Luck roll; also the Fortune keep-filter range |
| `affix_white_quality` / `affix_white_luck` | 0.5 / 0.75 | Whites never roll |
| `forge_luck_window` | 0.25 | Forged Luck spans this far below the analyzed peak (never under the Luck minimum) |
| Forge quantity | 1–9 | Pieces per order |

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
| Floor Transport list grouping | 10 floors | Reached floors group by decades past ten |
| Dungeon enter fade | 1.05 s | After the floor is ready |
| Touch stick deadzone | 0.24 | Same magnitude idea as pad sticks. Debug Settings slider. |
| Display mode | borderless | Desktop: windowed / borderless / exclusive. Web: `web_fullscreen` off until a gesture. |
| Target first-extraction time | 5–10 min | New player on gamepad |
| Target dives to steady early clears | 20–30 | Competent player; feel target |
| Target time to reach floor 6 or clear floor 5 | 5–10 hours | Competent player; feel target |
| FPS | 60 minimum | Higher allowed |
| Hitch budget | 1/60 s | Frame budget used by the hitch log |
| Hitch multiplier | 4 | Trip when `delta >= budget × 4` (~66.7 ms) |
| Hitch cap | 256 | Newest hitch rows kept in `user://hitch/hitch.jsonl` |
| `potion_cooldown` | **8.0 s** | `balance/vars_economy.gd` only; potions carry no baked cooldown |
| `RENDER_SCALE_OPTS` | Auto, 1.0, 0.8, 0.6 | Settings > Graphics "Render scale", saved as `render_scale` (0 = Auto, the default: `dyn_res.gd` dynamic scale). A fixed pick stops Auto. |
| Aim-line prefs | on, 0.85 | `store_data.gd` `DEF` is the home; `balance.gd` reads it |

All other values (enemy stats, drop rates, remaining forge fields, weapon-specific leftovers, quest rewards, leash-adjacent keys, Bitter loop offset timestamp, etc.) should be chosen to support the same feel targets and MUST also be exposed in the debug menu.
