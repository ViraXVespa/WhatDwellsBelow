# App start-up, shims and launch flags

Status: current plan  
Read when: startup order, Dbg shim, wdb flags  
Code: `scripts/boot.gd`, `scripts/app/app_boot.gd`, `scripts/app/cli_args.gd`, `scripts/app/dbg.gd`, `scripts/app/telemetry.gd`, `scripts/app/app_set.gd`

## Order

1. `App` (autoload, `scripts/app.gd`) `_ready` runs `app_boot._ready`: locale setup with the launch args, balance and progress objects, bind registration, then its child nodes in this order: sfx, the debug playtester (debug builds only), pause menu, recap, presentation, music, archives UI, loader, web pad, touch HUD. The telemetry object and the debug web hook are set up between sfx and the playtester.
2. The live save loads (not in smokes), the crash marker is written, saved zoom, HUD scale, text scale, sprite filter and display mode apply, and the debug menu is built (at once for smokes and `--wdb-debug`, else on the first idle frame).
3. `boot.tscn` (`boot.gd`) changes to the fullscreen gate when the display wants one, else to the splash. A smoke run may take the route itself (`Dbg.smoke_route_boot`).

New start-up work goes into `app_boot._ready`, in the step that needs it; keep heavy loads off this path (web boot load set).

## Launch flags

`CliArgs.args()` is the user args after `--`, else the full command line; on the web, URL params that start with `wdb-` read as flags (`?wdb-seed=42` is `--wdb-seed=42`). Helpers: `has`, `int_arg`, `float_arg`, `seed_arg`. A flag that changes normal play is a debug feature: name it `--wdb-*` and read it only through `CliArgs`.

## Dbg shim

`Dbg.on()` is true only with the OS `debug` feature, the `scripts/debug/` folder present and no `--wdb-release`. Off, every `Dbg.*` call is a no-op: `script`, `make`, hitch and load-timing marks, smoke checks and attach. Release presets drop the folder, so a debug script reached any other way breaks the release build.

## Telemetry

`telemetry.gd` (`App.tel`) keeps one capped row per run: damage, kills, dashes, specials, extraction, levels, skill and gear changes, end condition. `app_run` resets it at run start and writes the end; the recap reads it. It ships in release builds.
