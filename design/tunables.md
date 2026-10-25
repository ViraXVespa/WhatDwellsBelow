# Tunables

Status: suggested starts  
Read when: the work changes a number, formula, or debug default  
Code: `scripts/data/balance.gd`, `scripts/data/balance/vars.gd` (aggregate) + `vars_main.gd` (this file's keys; `vars_combat|world|economy.gd` match the other tunables files), `access.gd`, `schema.gd`, `enemies.gd`, `scripts/debug/tunable_overrides.gd`, `scripts/data/tunables.gd`, `scripts/data/progress_forge.gd`, `scripts/data/gear_roll.gd`, `scripts/display_mode.gd`, `scripts/combat/cover.gd`, `scripts/input/touch_pad.gd`, `scripts/input/look_ctrl.gd`  

These are recommended starting points for the current live implementation.  
Every value **MUST** be exposed in the debug menu and treated as non-final.  
Suggested starts are seeds only.
Live defaults are what `balance.gd` (`balance/vars_*.gd`) / `tunables.gd` ship today.  
If you change a live default, update this table in the same slice.
This is a curated table, not a list of every balance key. A number with no row here: add one in the same slice: `python tools/docs.py tunable add --after <neighbor key> --key NEW_KEY --set <live>` (same table, other cells `-`; fill suggested and note with `docs.py patch replace`); do not hunt for a row that does not exist.

List one key with `python tools/docs.py tunable get --key CAM_PITCH` (summary: `_logs/tunable-row/<stamp>-tunable-row.txt`). Patch one Live cell with `python tools/docs.py tunable set --key CAM_PITCH --set -58` (summary: `_logs/tunable-patch/<stamp>-tunable-patch.txt`). Do not open this whole file to change one number.

**Saves and overrides.** Saves store no balance: code defaults ship as-is and reach every save on update (no migration, no forced rewrite). An old save's `debug_bal` / `bal_rev` is ignored and dropped on load; the aim-line prefs stay (own save keys). Debug builds (`Dbg.on()`, Web Debug too) keep debug-menu value edits in `user://debug_tunables.json` (non-default keys only, clamped to the slider range; `tunable_overrides.gd`); release and `--wdb-release` never read it. Profiles > "Reset all values to defaults" clears it.

Forge keys missing from `balance.gd` fall back inside `progress_forge.gd` / `gear_roll.gd`; a slice that adds a key also adds it to balance and the debug menu.

## Camera / presentation (`tunables.gd`)

| Key | Live |
|-----|------|
| `CAM_PITCH` | -58 |
| `CAM_HEIGHT` | 14 |
| `LOOK_LIFT` | 0.42 |
| `ZOOM_MIN` / `ZOOM_MAX` | 1.0 / 4.0 |
| Default `cam_zoom` | 1.75 |
| `PLAYER_BODY` / `PLAYER_H` | (0.42, 0.78, 0.32) / 1.55 |
| `MOVE_EPS` / `WALK_FPS` | 0.12 / 8 |
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
| `DYNRES_ON` | true. Off: false here, or launch flag `--wdb-no-dynres` (web `?wdb-no-dynres`) |
| `DYNRES_FPS_LOW` / `DYNRES_FPS_HIGH` | 40 / 55 (3D scale drops under LOW, may climb back at HIGH+) |
| `DYNRES_STEP` / `DYNRES_MIN` | 0.1 / 0.6 (`scaling_3d_scale` starts 1.0; `dyn_res.gd`) |
| `DYNRES_WINDOW_S` / `DYNRES_HITCH_S` | 1.5 / 0.5 (fps window; longer frames are ignored) |
| `DYNRES_RECOVER_WINDOWS` / `DYNRES_BACKOFF_MAX` | 8 / 8 (windows at HIGH per climb; a failed climb doubles the wait up to 8x) |
| `WARM_FRAMES_MAX` | 6 (dungeon and non-hub `pump_fps` cap; early exit on 2 frames <= 17 ms or `WARM_STEADY_N` 3 deltas within `WARM_STEADY_MS` 3 ms). Hub settle uses `WARM_HUB_FRAMES_MAX`. `pump_fps` first draws 2 frames at one `DYNRES_STEP` lower (`DynRes.warm`), so the first scale drop does not compile in view |
| `WARM_HUB_FRAMES_MAX` | 24 (hub `pump_fps` cap only; exits on 2 frames at or under 17 ms, not on a slow plateau) |

## Ground field

World-xz sheets on grass pads, packed yard, and dungeon floors. Debug menu category Ground. `ground_wear` scales the baked wear sheet (`assets/baked/ground_wear.png`, tileable 32 m sheet, 12 steps at 32 texels/m, one step per 4x4 ground pixels): at 0.5 the most worn ground is about 11% darker, a clearly trodden but clean yard; 0 turns wear off.

| Key | Live |
|-----|------|
| `GROUND_PX_PER_M` / `ground_px_per_m` | 128 |
| `GROUND_WEAR` / `ground_wear` | 0.5 |

## Light buffer

Four texels per tile. Dungeon discs are torch, crystal, and campfire. The hub adds one wide sun disc. Debug menu category Lighting reads the same keys. Do not retune range or energy to fake smoothness.

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
| `LIGHT_SOURCE_CAP` / `light_source_cap` | 32 |

## Other tunables files

Movement and combat, Gathering, Enemy drops and Consumables are in `tunables-combat.md`. Dungeon generation and Enemies and combat level are in `tunables-world.md`; Progression and economy, Anvil / affixes and UI / feel targets are in `tunables-economy.md`. `tools/docs.py tunable` finds a key in any of them.
- `max_clerks` 12. Hall-torch cadence 7–11 on runs of 8+. Hall-traveler cadence 14–18 on runs of 10+.
