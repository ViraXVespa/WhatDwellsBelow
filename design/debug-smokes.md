# Smoke tests (live snapshot)

Status: binding design  
Read when: smoke phase coverage / how to run smokes / dedicated smoke CLI  
Code: `scripts/debug/`  


## Live snapshot — smoke tests (`smoke.gd`)

Coverage runner. User args: `--wdb-phaseN-smoke` for N = 1..9 (after `--`). Prints on `printerr`, then quits. No `smoke_*.tscn` scenes: phases attach from `boot` / foundation / dungeon / camp via `scripts/debug/smoke.gd`.

Title → Placeholdia load timing is a separate flag, not a numbered phase: `--wdb-load-timing-smoke`. It calls `App.play_from_menu()` from boot (skips splash / title UI), prints `LOAD:` marks for preload / camp `_ready` slices / warmup, then quits. Preferred runner: `python3 tools/run_load_timing.py`. Read only `_logs/load-timing/summary.txt`. On web the same flags work as URL params (`?wdb-load-timing-smoke`); `python3 tools/web_perf.py --flow hub-load,dungeon-load` prints the marks with wasm memory. Each mark ends `vram=` (texture MB).

Placeholdia → Dungeon load timing is a separate flag, not a numbered phase: `--wdb-dungeon-load-timing-smoke`. It `go_camp()`s from boot (skips splash / title / enter overlay), waits until Camp is ready, then runs the live enter path (`save_now`, `_after_enter` / `begin_run` / `go_dungeon`) with seed 42 / floor 1. Prints `LOAD:` marks for enter / gen / travel / geo / spawn slices, then quits. Clock starts at `enter_begin` (hub load is not in `total_ms`). Cover holds until two presented frames are at 16 ms (cap 12), then fade. `dungeon_ready` is RING_IN geo plus the first stamp plus release_enter (cover can drop). The smoke does not wait follow/warm frames before finish. Preferred runner: `python3 tools/run_dungeon_load_timing.py`. Read only `_logs/dungeon-load-timing/summary.txt`. Helper: `scripts/debug/load_timing.gd` (`dmark` / `dnote`).

Playtester live run is a separate flag, not a numbered phase: `--wdb-playtest-live-smoke` (`playtest/live_smoke.gd`). It boots straight into one live AI run (male, fresh save), prints `PT:` lines (kills / crits / damage / end condition / decision cost / time_scale / stuck) and quits. Args `--wdb-seed=N` (default random), `--wdb-pt-weapon=great_axe|staff|longbow`, `--wdb-pt-sec=S`, `--wdb-pt-scale=X` (only with `--wdb-pt-fast`); add `--fixed-fps 60` before `--` to make a seed replay exactly. Details: `debug-playtest.md`.

Dungeon generation map dump is a separate flag, not a numbered phase: `--wdb-dungeon-map-smoke`. It calls `App.begin_run()` from boot (skips splash / title UI), pins `run_seed` / `floor_n` (defaults 42 / 1), dumps the live floor after `dungeon_boot` placement, then quits. Does not `stream_all` — enemy coverage is `spawn_jobs`, not live bodies. Prints `MAP:` lines (counts, rooms, objects, jobs, spec checks, downsampled ASCII). Bake specs in that postcard: `spans_present`, `solid_size`, `span_on_solid`, `jobs_on_solid`, `rim_closed`. Those read gen data and job cells only. They do not count torches or read the light RT. Optional user args: `--wdb-dungeon-map-seed=N`, `--wdb-dungeon-map-floor=N`, `--wdb-dungeon-map-scale=N` (ASCII cell size, default 8, clamp 4–16). Preferred runner: `python3 tools/run_dungeon_map.py` (`--help` lists seed, floor, scale). Read only `_logs/dungeon-map/summary.txt`; full dump at `_logs/dungeon-map/dump.txt`. Helper: `scripts/debug/dungeon_map.gd`.

Shot flows (`tools/shot-flows/*.json`, `shot-flows.md`) are the UI/menu/NPC counterpart: `python3 tools/bot_smokes.py --door hub --flows` runs the phases mapped for the door plus its `routes.yaml` `shot_flows` headless (`--no-pixels`: scripted input and asserts, no pictures, no display). They are not numbered phases.

### How to run (Steam Godot / redirected IO)

From the repo root: `python3 tools/run_smokes.py --phases 1,2,6` (flags: `--help`). It writes `_logs/smokes/summary.txt` with phase status plus `P*:` / `SCRIPT ERROR` highlights only.

Binary (Steam tools build): `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe` (also in `tools/export_web.py`). Bot Linux VM: BOT.md Smokes (`python3 tools/bot_smokes.py`), same required flags below.

**Required flags** when stdout/stderr are redirected (CI, `Start-Process -Redirect*`, agent shells):

```
--headless --display-driver headless --audio-driver Dummy --path <WDB_ROOT> -- --wdb-phaseN-smoke
```

- Plain `--headless` alone can **hang forever** under redirected IO. Always pass `--display-driver headless` `--audio-driver Dummy` for automated smoke.
- Put the phase flag in **user** args (after `--`) so `OS.get_cmdline_user_args()` sees it.
- Capture stderr for `P1:`…`P9:` lines and `SCRIPT ERROR`. Exit is self-quit from the phase (or kill after a timeout if hung).
- Compile/reload check is separate: `tools/run_godot_import_check.py` (`--headless --editor --import`). Catalog: `tools.md`. Do not treat a smoke pass as proof scripts are editor-clean, or vice versa.

| Fn | Checks |
|----|--------|
| p1 | Boot, player, camera, basic weapon |
| p2 | Weapon swap, telegraphs, projectiles, FPS estimate |
| p3 | Floor data, doors, stairs, boss flow |
| p4 | Roster, named, flee, pressure safety |
| p5 | Gather nodes, extract UI, puzzle props |
| p6 | Artifacts, food/potion, forge, quests |
| p7 | HUD, pause, debug, recap |
| p8 | Hub spots, building depth, save backup on the smoke slot, archive catalog |
| p9 | Audio, archive catalog, anim models, playtest hook |


## Dedicated smoke session

Build slices do not need this session: they run the phases mapped in `routes.yaml` `smokes` and add or update asserts for what they implement (Build job cycle). The limits below apply to this dedicated session only.

Smoke coverage is a Build session kept thin (summaries, not Godot logs in chat). Slice, Bot-notes and PC-offload chats must not rewrite these habits.

- Purpose: write named smoke coverage. Numbered P1–P9: `smoke.gd` (`route_boot` / `attach_*`) plus `smoke_early.gd` (helpers `early_p3.gd`, `early_p4.gd`) / `smoke_late.gd` / `smoke_p5.gd`, `smoke_p6.gd`, `smoke_p7.gd`, `p79.gd`, `smoke_p8.gd`, `smoke_p9.gd`. Dedicated sweeps are extra flags, not a new N: `--wdb-load-timing-smoke` and `--wdb-dungeon-load-timing-smoke` (`load_timing.gd` mark / dmark), `--wdb-dungeon-map-smoke` (`dungeon_map.gd`)
- Typical slice: one named add. Edit `smoke.gd` routing and that helper (live path only for marks/asserts the smoke must emit). Run that phase (`run_smokes.py`) or extra-flag runner. Read only `_logs/smokes/summary.txt`, or `_logs/load-timing/summary.txt` / `_logs/dungeon-load-timing/summary.txt` / `_logs/dungeon-map/summary.txt` when that flag is the job. Stop
- Just do: same-phase / same-helper assertions; `LoadTiming.mark` / `dmark` / `dnote` the smoke must call; hostify facades the phase still calls (`dungeon_boot.ready_floor`, `AppFlow` enter / `play_from_menu`). Headless skip of splash / title / enter overlay. Pin seed 42 / floor 1 on gen-dependent flags. Map dump reads `spawn_jobs`, does not `stream_all`
- Stop and propose: a new catalog runner (already binding on the pc-offload recipe). New numbered phase; a new `--wdb-*-smoke` flag the User did not name this session; a new smoke host scene; `stream_all` / `force_all` for a map dump; splitting an over-cap smoke helper
- Do not: Imagine / I2V; Grok Bot PRs; week pin ritual; invent coverage the User did not name; postcard shots (`tools/run_shots.py`) which are not numbered smokes; tree dumps; raw Godot logs in chat; parking Bot opt notes; folding slice or catalog-runner work in
- Overlap: other Build CLIs **run** existing smokes via the prove-cycle runner table; this job **writes** them. PC-offload owns new runners; Bot-notes parks refactor notes. Do not fold those roles in unless the User names them.
