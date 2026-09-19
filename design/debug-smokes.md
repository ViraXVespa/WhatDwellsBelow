# Smoke tests (live snapshot)

Status: binding design  
Read when: smoke phase coverage / how to run smokes / dedicated smoke CLI  
Code: `scripts/debug/`, scripts/combat/debug_menu paths may be under `scripts/debug/debug_menu/`  


## Live snapshot — smoke tests (`smoke.gd`)

Coverage runner, not a particle system. User args: `--wdb-phaseN-smoke` for N = 1..9 (after `--`). Prints on `printerr`, then quits. There are no live `smoke_*.tscn` scenes — phases attach from `boot` / foundation / dungeon / camp via `scripts/debug/smoke.gd`.

Title → Placeholdia load timing is a separate flag, not a numbered phase: `--wdb-load-timing-smoke`. It calls `App.play_from_menu()` from boot (skips splash / title UI), prints `LOAD:` marks for preload / camp `_ready` slices / warmup, then quits. Preferred runner: `powershell -File tools/run_load_timing.ps1` (optional `-TimeoutSec 180`). Read only `_logs/load-timing/summary.txt`. Same headless drivers as numbered smokes.

Placeholdia → Dungeon load timing is a separate flag, not a numbered phase: `--wdb-dungeon-load-timing-smoke`. It `go_camp()`s from boot (skips splash / title / enter overlay), waits until Camp is ready, then runs the live enter path (`save_now`, `_after_enter` / `begin_run` / `go_dungeon`) with seed 42 / floor 1. Prints `LOAD:` marks for enter / gen / travel / geo / spawn slices, then quits. Clock starts at `enter_begin` (hub load is not in `total_ms`). Preferred runner: `powershell -File tools/run_dungeon_load_timing.ps1` (optional `-TimeoutSec 180`). Read only `_logs/dungeon-load-timing/summary.txt`. Same headless drivers. Helper: `scripts/debug/load_timing.gd` (`dmark` / `dnote`).

Dungeon generation map dump is a separate flag, not a numbered phase: `--wdb-dungeon-map-smoke`. It calls `App.begin_run()` from boot (skips splash / title UI), pins `run_seed` / `floor_n` (defaults 42 / 1), dumps the live floor after `dungeon_boot` placement, then quits. Does not `stream_all` — enemy coverage is `spawn_jobs`, not live bodies. Prints `MAP:` lines (counts, rooms, objects, jobs, spec checks, downsampled ASCII). Optional user args: `--wdb-dungeon-map-seed=N`, `--wdb-dungeon-map-floor=N`, `--wdb-dungeon-map-scale=N` (ASCII cell size, default 8, clamp 4–16). Preferred runner: `powershell -File tools/run_dungeon_map.ps1` (optional `-Seed 42`, `-Floor 1`, `-Scale 8`, `-TimeoutSec 180`). Read only `_logs/dungeon-map/summary.txt`. Full dump also at `_logs/dungeon-map/dump.txt`. Same headless drivers as numbered smokes. Helper: `scripts/debug/dungeon_map.gd`.

### How to run (Steam Godot / redirected IO)

Preferred (agent-friendly): from repo root, prefer `& .\tools\run_smokes.ps1 -Phases @(1,2,6)` (optional `-TimeoutSec 180`, `-VerboseGodot`). Avoid `powershell -File tools/run_smokes.ps1 -Phases 1,2,6` - PowerShell can bind that as phase 45. Writes `_logs/smokes/summary.txt` with phase status plus `P*:` / `SCRIPT ERROR` highlights only. Full PC-offload catalog: the pc offload recipe.

Binary (Steam tools build): `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe` (also in `tools/export_web.ps1`).

**Required flags** when stdout/stderr are redirected (CI, `Start-Process -Redirect*`, agent shells):

```
--headless --display-driver headless --audio-driver Dummy --path <WDB_ROOT> -- --wdb-phaseN-smoke
```

- Plain `--headless` alone can **hang forever** with only the engine banner and empty stderr under redirected IO. Always pass `--display-driver headless` `--audio-driver Dummy` for automated smoke.
- Put the phase flag in **user** args (after `--`) so `OS.get_cmdline_user_args()` sees it.
- Capture stderr for `P1:`…`P9:` lines and `SCRIPT ERROR`. Exit is self-quit from the phase (or kill after a timeout if hung).
- Optional: `--verbose` for load traces (huge logs). Not required once drivers are set.
- Compile/reload check is separate: `tools/run_godot_import_check.ps1` (`--headless --editor --import`). Catalog: the pc offload recipe. Do not treat a smoke pass as proof scripts are editor-clean, or vice versa.

| Fn | Checks |
|----|--------|
| p1 | Boot, player, camera, basic weapon |
| p2 | Weapon swap, telegraphs, projectiles, FPS estimate |
| p3 | Floor data, doors, stairs, boss flow |
| p4 | Roster, named, flee, pressure safety |
| p5 | Gather nodes, extract UI, puzzle props |
| p6 | Artifacts, food/potion, forge, quests |
| p7 | HUD, pause, debug, recap |
| p8 | Hub spots, building depth, save backup, archive catalog |
| p9 | Audio, archive catalog, anim models, playtest hook |


## Dedicated smoke session

Smoke coverage is a Build session. **Weekly:** sessions in one instance, kept thin enough to last about one quota (catalog summaries, not Godot logs in chat). Slice, Bot-notes, and PC-offload chats must not rewrite these habits.

- Purpose: write named smoke coverage. Numbered P1–P9: `smoke.gd` (`route_boot` / `attach_*`) plus `smoke_early.gd` / `smoke_late.gd` / `smoke_p*.gd`. Dedicated sweeps are extra flags, not a new N: `--wdb-load-timing-smoke` and `--wdb-dungeon-load-timing-smoke` (`load_timing.gd` mark / dmark), `--wdb-dungeon-map-smoke` (`dungeon_map.gd`)
- Typical slice: one named add. Edit `smoke.gd` routing and that helper (live path only for marks/asserts the smoke must emit). Run that phase (`run_smokes.ps1`) or extra-flag runner. Read only `_logs/smokes/summary.txt`, or `_logs/load-timing/summary.txt` / `_logs/dungeon-load-timing/summary.txt` / `_logs/dungeon-map/summary.txt` when that flag is the job. Stop
- Just do: same-phase / same-helper assertions; `LoadTiming.mark` / `dmark` / `dnote` the smoke must call; hostify facades the phase still calls (`dungeon_boot.ready_floor`, `AppFlow` enter / `play_from_menu`). Headless skip of splash / title / enter overlay. Pin seed 42 / floor 1 on gen-dependent flags. Map dump reads `spawn_jobs`, does not `stream_all`
- Stop and propose: a new catalog runner (already binding on the pc-offload recipe). New numbered phase; a new `--wdb-*-smoke` flag the User did not name this session; a new smoke host scene; `stream_all` / `force_all` for a map dump; splitting an over-cap smoke helper
- Do not: Imagine / I2V; Grok Bot PRs; week pin ritual; invent coverage the User did not name; tree dumps; raw Godot logs in chat; parking Bot opt notes; folding slice or catalog-runner work in
- Stop: only the Smoke tests block in the smoke-tests session block
- Overlap: other Build CLIs **run** existing smokes via the catalog; this CLI **writes** them. PC-offload owns new runners. Bot-notes parks refactor notes. Do not fold those roles in unless the User names that work here.
