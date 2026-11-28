# Dungeon map dump

Status: current plan
Read when: generation dump, ascii seal fixtures
Code: `scripts/debug/dungeon_map.gd` (facade) + `scripts/debug/dungeon_map/` (collect, emit, spec, rim, gate_wall, ascii, edge_fixture); runner `python tools/perf.py map`

Dungeon generation map dump is a separate flag, not a numbered phase: `--wdb-dungeon-map-smoke`. It calls `App.begin_run()` from boot (skips splash / title UI), pins `run_seed` / `floor_n` (defaults 42 / 1), dumps the live floor after `dungeon_boot` placement, then quits. Does not `stream_all` — enemy coverage is `spawn_jobs`, not live bodies. Prints `MAP:` lines (counts, rooms, objects, jobs, spec checks, downsampled ASCII). Gate spec `gate_top_wall` fails when any Extraction Gate is not on a top-wall face (3 wall cells behind, 3 floor cells in front; `scripts/debug/dungeon_map/gate_wall.gd`). Bake specs in that postcard: `spans_present`, `solid_size`, `span_on_solid`, `jobs_on_solid`, `rim_closed`. Those read gen data and job cells only. They do not count torches or read the light RT. Optional user args: `--wdb-dungeon-map-seed=N`, `--wdb-dungeon-map-floor=N`, `--wdb-dungeon-map-scale=N` (ASCII cell size, default 8, clamp 4–16). Preferred runner: `python tools/perf.py map` (`--help` lists seed, floor, scale; `--seeds 42,7,9` sweeps; `--fixtures` runs `scripts/debug/dungeon_map/edge_fixture.gd`, hand-written edge keys and seal fragments). Read only `_logs/dungeon-map/<stamp>-dungeon-map.txt`; full dump at `_logs/dungeon-map/dump.txt`. Helper: `scripts/debug/dungeon_map.gd`.

The specs are white-box: they read `scripts/world/dungeon/dungeon_cells.gd` and `scripts/dungeon/gen/edge_mark.gd` / `outline_seal.gd` directly.
