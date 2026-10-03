# Tunables

Status: suggested starts + live snapshot  
Read when: the work changes a number, formula, or debug default  
Code: `scripts/data/balance.gd`, `access.gd`, `schema.gd`, `enemies.gd`, `migrate.gd`, `scripts/data/tunables.gd`, `scripts/data/progress_forge.gd`, `scripts/data/gear_roll.gd`, `scripts/display_mode.gd`, `scripts/combat/cover.gd`, `scripts/input/touch_pad.gd`, `scripts/input/look_ctrl.gd`  


These are recommended starting points for the current live implementation.  
Every value **MUST** be exposed in the debug menu and treated as non-final.  
Suggested starts are seeds only.
Live defaults are what `balance.gd` / `tunables.gd` ship today.  
If you change a live default, update this table in the same slice.
This is a curated table, not a list of every balance key. A number with no row here: add one in the same slice: `python3 tools/tunables.py add --after <neighbor key> --key NEW_KEY --set <live>` (same table, other cells `-`; fill suggested and note with `doc_patch.py replace`); do not hunt for a row that does not exist.

List one key with `python3 tools/tunables.py get --key CAM_PITCH` (summary: `_logs/tunable-row/summary.txt`). Patch one Live cell with `python3 tools/tunables.py set --key CAM_PITCH --set -58` (summary: `_logs/tunable-patch/summary.txt`). Do not open this whole file to change one number.

`BAL_REV` is 13. Old saves pick up shipped default retunes through `migrate.gd`.

Forge keys missing from `balance.gd` fall back inside `progress_forge.gd` / `gear_roll.gd`; a slice that adds a key also adds it to balance and the debug menu.

## Camera / presentation (`tunables.gd`)

| Key | Live |
|-----|------|
| `CAM_PITCH` | -58 |
| `CAM_HEIGHT` | 14 |
| `LOOK_LIFT` | 0.42 |
| `ZOOM_MIN` / `ZOOM_MAX` | 1.0 / 4.0 |
| Default `cam_zoom` | 1.75 |
| `HUD_SCALE_MIN` / `HUD_SCALE_MAX` | 0.7 / 1.4 |
| `UI_TEXT_FLOOR` | 14 |
| `UI_TEXT_FLOOR_MIN` / `UI_TEXT_FLOOR_MAX` | 8 / 24 |
| `UI_TEXT_REF` | 18 |
| `UI_TEXT_SCALE_MIN` / `UI_TEXT_SCALE_MAX` | 1.0 / 2.5 |
| `LOOK_WHEEL_STEP` | 0.08 |
| `LOOK_PINCH_GAIN` | 1.15 |
| `LOOK_STICK_ZOOM` | 0.9 |
| `LOOK_STICK_HUD` | 0.35 |
| `LOOK_STICK_PAN` | 520 |
| `MAP_ZOOM_MIN` / `MAP_ZOOM_MAX` | 1.0 / 10.0 |
| `TILE` / `PX` | 1.0 / 64 |
| Default `sprite_filter` | 2 (nearest + mips + aniso) |
| `sprite_mip_sharp` | false (smooth mip blend) |
| `sprite_mip_bias` | 0.0 (stored; Sprite3D has no lod-bias hook yet) |
| Default `display_mode` | `borderless` |
| Default `display_fs_kind` | `borderless` |
| Default `web_fullscreen` | false |
| `BITTER_LOOP_DEFAULT` | 15.52 |
| `PATREON_URL` | https://www.patreon.com/cw/ViraXVespa |
| `ARCHIVE_ID_FULL_3D` | full_3d_pass |
| Archive catalog | `scripts/data/archive_catalog.json` |
| `TOUCH_DEAD` | 0.24 |

## Ground field

World-xz sheets on grass pads, packed yard, and dungeon floors. Debug menu category Ground. `ground_wear` at 0 leaves the sheet untinted by wear.

| Key | Live |
|-----|------|
| `GROUND_PX_PER_M` / `ground_px_per_m` | 128 |
| `GROUND_HASH_M` / `ground_hash_m` | 4 |
| `GROUND_VARIANTS` / `ground_variants` | 3 |
| `GROUND_WEAR` / `ground_wear` | 0.22 |

## Light buffer

Four texels per tile. Dungeon discs are torch, crystal, and campfire. The hub adds one wide sun disc. Debug menu reads the same keys. Do not retune range or energy to fake smoothness.

| Key | Live |
|-----|------|
| `LIGHT_TORCH_RANGE` / `light_torch_range` | 5.5 |
| `LIGHT_TORCH_ENERGY` / `light_torch_energy` | 1.0 |
| `LIGHT_CRYSTAL_RANGE` / `light_crystal_range` | 7.5 |
| `LIGHT_CRYSTAL_ENERGY` / `light_crystal_energy` | 0.95 |
| `LIGHT_FIRE_RANGE` / `light_fire_range` | 6.0 |
| `LIGHT_FIRE_ENERGY` / `light_fire_energy` | 1.0 |
| `LIGHT_SUN_RANGE` / `light_sun_range` | 48 |
| `LIGHT_SUN_ENERGY` / `light_sun_energy` | 0.9 |
| `LIGHT_SOURCE_CAP` / `light_source_cap` | 24 |

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
| Crit chance | 12 % | 0.12 | Planted coverage only; gear adds `crit_chance` |
| Crit mult | 2× | 2.0 | Gear adds `crit_dmg` on top |
| Adrenaline kill window | 4.5 s | 4.5 | |
| Adrenaline kill threshold | 4 | 4 | |
| Adrenaline speed / XP stack / timeout | — | 1.35 / 0.15 / 4.5 | |
| Knockback / hitstop | — | 3.4 / 0.055 | Dummy ignores knockback |
| Player max HP | — | 100 | |
| Hurt i-frame | — | 0.35 | |
| Defense k | — | 100 | diminishing returns |
| Aim-line on / opacity / width | on | true / 0.85 / 0.08 | Bow line is shoulder height. Mesh hidden until `update_line`. |
| Aim-line use weapon range / length | — | true / 4.0 | Gear `atk_range` extends reach |
| Cover full-band / edge mult | — | 0.18 / 0.35 | Full damage until the last 18% of fan radius |
| Cover columns / alpha | — | 24 / 0.4 | Opaque mask grid |
| Pierce stop | — | 0.85 | Arrow despawns at this coverage |
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
| Skill gather / tool gather | — | 0.02 / 0.03 | per level / tool quality |
| Mine nodes / wood nodes | — | 18 / 14 | |
| Break count / gold / orb | — | 24 / 0.55 / 0.35 | |
| Orb heal | — | 18 | |
| Crack HP | 8 | 8 | |

## World, economy and UI sections

Dungeon generation, Enemies and combat level, Progression and economy, Anvil / affixes and UI / feel targets are in `tunables-world.md`. `tools/tunables.py` finds a key in either file.

