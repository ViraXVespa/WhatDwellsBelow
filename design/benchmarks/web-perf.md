# Benchmark: web export perf

Status: record
Read when: `perf.py web` is rerun or its baseline changes

Baseline file the tool compares against: `tools/data/web-perf-baseline.json` (committed 2026-10-13 in `0204b8ca`, build_id `52f50eb125790f66`). Machine: `unknown` (the file records only `google-chrome`, headless, viewport 1280x720; Chrome version, CPU, GPU and OS were not saved). Renderer: Compatibility on SwiftShader per the tool docstring. Per flow: load_ms / avg_fps / p95 frame ms / heap MB.

| Flow | load_ms | avg_fps | p95 ms | heap MB |
|------|---------|---------|--------|---------|
| title-idle | 2642 | 48.3 | 35.3 | 122.4 |
| hub-load | 3014 | 45.9 | 17.8 | 148.1 |
| camp-idle | 2687 | 23.8 | 53.7 | 103.5 |
| camp-walk | 2617 | 31.0 | 51.3 | 103.6 |
| camp-pause | 2629 | 17.1 | 76.7 | 128.9 |
| camp-shop | 2634 | 24.2 | 54.7 | 104.8 |
| dungeon-load | 3203 | 50.3 | 17.7 | 113.7 |
| dungeon-arrive | 2597 | 28.5 | 52.0 | 124.2 |
| dungeon-walk | 2910 | 25.3 | 50.9 | 139.2 |
| dungeon-fight | 2853 | 35.0 | 40.8 | 122.2 |
| dungeon-music-cold | 89641 | 28.1 | 65.8 | 101.7 |

Reruns, dungeon-arrive (2026-10-11, machine `unknown`): load_ms 2505-2739, avg_fps 27.4-28.2, heap 103-106 MB, wasm 95.8 MB.

## Release reference (`perf.py web --release-ref`)

Release export (preset `Web`, no `scripts/debug/`), only the 9 flows with no in-game hook; file `tools/data/web-perf-release-baseline.json` (2026-10-20, build_id `cc6ff983fb198b8e`, box: Xeon x8, 16 GB, Debian 13, Chrome 155, SwiftShader, 1280x720, 1 run). Release and debug baselines are not comparable (different engine template, no hitch hooks); the tool refuses to cross them.

| Flow | load_ms | avg_fps | p95 ms | heap MB |
|------|---------|---------|--------|---------|
| title-idle | 2021 | 51.1 | 33.2 | 80.9 |
| hub-load | 2067 | 56.9 | 33.2 | 69.6 |
| camp-idle | 2328 | 27.6 | 52.3 | 79.1 |
| camp-walk | 1996 | 33.2 | 49.0 | 69.5 |
| camp-pause | 2096 | 19.7 | 69.1 | 69.3 |
| camp-shop | 2028 | 24.4 | 50.8 | 121.0 |
| dungeon-load | 2089 | 55.9 | 33.4 | 107.2 |
| dungeon-walk | 2088 | 35.3 | 36.3 | 69.8 |
| dungeon-music-cold | 71765 | 27.5 | 64.6 | 72.8 |

## Camp ground fill (2026-11-21, w13, `a6e7c1bb`)

Box: Xeon x8, Chrome 156 headless, SwiftShader, 1280x720, debug export, camp idle at spawn, median of 20 frames (window.wdbEval, `?wdb-playtest`). Release `--release-ref` on the same build: camp-idle 8.6 fps, camp-walk 11.4, dungeon-walk 32.1, title-idle 49.3.

- Camp frame ~118 ms. Script processing is not the cost (disabling every processing node's `process_mode` moves it < 5 ms). Hiding the camp `Generated` ground planes drops it to 13.5 ms; the main yard plane alone is ~65 ms.
- Ground shader split (shader edits removed one term at a time): lantern `pool_light` loop ~60 ms, `hub_sun` ~13, feather `vnoise` ~12, wear/light/albedo taps a few ms each.
- `pools.gd` coverage mask (pool_light returns 0 off the range circles before its loop): 118 -> ~87 ms at spawn (4 runs each). Same light (hub_pool_check `mask`: every lit point is on the mask). Hub settle LOADSTEPS 5.8 s -> 3.8 s from the cheaper frames.
- 3D scale on headless web: 0.9 / 0.8 / 0.6 = -10% / -30% / -52%. Not used: real-GPU web blit cost (design/tasks/perf-sweep.md) keeps web Auto at 1.0. Headless numbers are not the FPS reading.
