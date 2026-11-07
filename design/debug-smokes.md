# Smoke tests

Status: current plan  
Read when: smoke phase coverage / how to run smokes / dedicated smoke CLI  
Code: `scripts/debug/`  

## Smoke tests (`smoke.gd`)

Coverage runner. User args: `--wdb-phaseN-smoke` for N = 1..9 (after `--`). Prints on `printerr`, then quits. No `smoke_*.tscn` scenes: phases attach from `boot` / foundation / dungeon / camp via `scripts/debug/smoke.gd`.

Title → Placeholdia load timing is a separate flag, not a numbered phase: `--wdb-load-timing-smoke`. It calls `App.play_from_menu()` from boot (skips splash / title UI), prints `LOAD:` marks for preload / camp `_ready` slices / warmup, then quits. Preferred runner: `python tools/perf.py load`. Read only `_logs/load-timing/<stamp>-load-timing.txt`. On web the same flags work as URL params (`?wdb-load-timing-smoke`); `python tools/perf.py web --flow hub-load,dungeon-load` prints the marks with wasm memory. Each mark ends `vram=` (texture MB).

Placeholdia → Dungeon load timing is a separate flag, not a numbered phase: `--wdb-dungeon-load-timing-smoke`. It `go_camp()`s from boot (skips splash / title / enter overlay), waits until Camp is ready, then runs the live enter path (`save_now`, `_after_enter` / `begin_run` / `go_dungeon`) with seed 42 / floor 1. Prints `LOAD:` marks for enter / gen / travel / geo / spawn slices, then quits. Clock starts at `enter_begin` (hub load is not in `total_ms`). Cover holds until two presented frames are at 16 ms (cap 12), then fade. `dungeon_ready` is RING_IN geo plus the first stamp plus release_enter (cover can drop). The smoke does not wait follow/warm frames before finish. Preferred runner: `python tools/perf.py load --leg dungeon`. Read only `_logs/dungeon-load-timing/<stamp>-dungeon-load-timing.txt`. Helper: `scripts/debug/load_timing.gd` (`dmark` / `dnote`).

Playtester live run is a separate flag, not a numbered phase: `--wdb-playtest-live-smoke` (`playtest/live_smoke.gd`). It boots straight into one live AI run (male, fresh save), prints `PT:` lines (kills / crits / damage / end condition / decision cost / time_scale / stuck) and quits. Args `--wdb-seed=N` (default random), `--wdb-pt-weapon=great_axe|staff|longbow`, `--wdb-pt-sec=S`, `--wdb-pt-scale=X` (only with `--wdb-pt-fast`); add `--fixed-fps 60` before `--` to make a seed replay exactly. `--wdb-pt-campaign` is the same boot on the kept campaign slot: one job, and a time-limit end enqueues the next weapon until Interrupt, a stall, or the watchdog. Phase 7 does not pass it. Details: `debug-playtest.md`.

Dungeon generation map dump is a separate flag, not a numbered phase: `--wdb-dungeon-map-smoke`. It calls `App.begin_run()` from boot (skips splash / title UI), pins `run_seed` / `floor_n` (defaults 42 / 1), dumps the live floor after `dungeon_boot` placement, then quits. Does not `stream_all` — enemy coverage is `spawn_jobs`, not live bodies. Prints `MAP:` lines (counts, rooms, objects, jobs, spec checks, downsampled ASCII). Bake specs in that postcard: `spans_present`, `solid_size`, `span_on_solid`, `jobs_on_solid`, `rim_closed`. Those read gen data and job cells only. They do not count torches or read the light RT. Optional user args: `--wdb-dungeon-map-seed=N`, `--wdb-dungeon-map-floor=N`, `--wdb-dungeon-map-scale=N` (ASCII cell size, default 8, clamp 4–16). Preferred runner: `python tools/perf.py map` (`--help` lists seed, floor, scale; `--seeds 42,7,9` sweeps). Read only `_logs/dungeon-map/<stamp>-dungeon-map.txt`; full dump at `_logs/dungeon-map/dump.txt`. Helper: `scripts/debug/dungeon_map.gd`.

Shot flows (`tools/data/shot-flows/*.json`, `shot-flows.md`) are the UI/menu/NPC counterpart: `python tools/gate.py bot-smokes --door hub --flows` runs the phases mapped for the door plus its `routes.yaml` `shot_flows` headless (`--no-pixels`: scripted input and asserts, no pictures, no display). They are not numbered phases.

### How to run (Steam Godot / redirected IO)

From the repo root: `python tools/gate.py smokes --phases 1,2,6` (flags: `--help`). It writes `_logs/smokes/<stamp>-smokes.txt` with phase status plus `P*:` / `SCRIPT ERROR` highlights only.

Binary (Steam tools build): `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe` (also in `tools/release.py export-web`). Bot Linux VM: BOT.md Smokes (`python tools/gate.py bot-smokes`), same required flags below.

**Required flags** when stdout/stderr are redirected (CI, `Start-Process -Redirect*`, agent shells):

```
--headless --display-driver headless --audio-driver Dummy --path <WDB_ROOT> -- --wdb-phaseN-smoke
```

- Plain `--headless` alone can **hang forever** under redirected IO. Always pass `--display-driver headless` `--audio-driver Dummy` for automated smoke.
- Put the phase flag in **user** args (after `--`) so `OS.get_cmdline_user_args()` sees it.
- Capture stderr for `P1:`…`P9:` lines and `SCRIPT ERROR`. Exit is self-quit from the phase (or kill after a timeout if hung).
- Compile/reload check is separate: `tools/gate.py import` (`--headless --editor --import`). Catalog: `tools-gates.md`. Do not treat a smoke pass as proof scripts are editor-clean, or vice versa.

| Fn | Checks |
|----|--------|
| p1 | Boot, player, camera, basic weapon |
| p2 | Weapon swap, telegraphs, projectiles, FPS estimate |
| p3 | Floor data, doors, stairs, boss flow |
| p4 | Roster, named, flee, pressure safety |
| p5 | Gather nodes, extract UI, puzzle props |
| p6 | Artifacts, food/potion, forge, quests |
| p7 | HUD, pause, debug, recap, playtest curve spool, campaign slot kept across two preps |
| p8 | Hub spots, building depth, save backup on the smoke slot, archive catalog |
| p9 | Audio, archive catalog, anim models, playtest hook |

## A named smoke-coverage task

Ordinary Build tasks run their mapped phases and add or update relevant assertions. A dedicated coverage task stays within the phase/helper the User named:

1. Edit the existing routing/helper. Touch live code only for required marks, assertions or a called facade. Existing owners are listed in the code map; dedicated load/map runs are flags, not new numbered phases.
2. Run the named phase or dedicated runner above and inspect its bounded summary, including `SCRIPT ERROR` lines. Do not paste raw logs into chat.
3. Ask before adding a numbered phase, an unrequested smoke flag or a host scene. A map dump reads `spawn_jobs`; do not replace it with `stream_all`/`force_all`.

Do not expand the coverage task into art generation, promo captures, unrelated gameplay or runner work. Record an uncovered requirement rather than inventing unnamed coverage.
