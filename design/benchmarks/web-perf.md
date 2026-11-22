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
- 3D scale on headless web: 0.9 / 0.8 / 0.6 = -10% / -30% / -52%. Not used: the scaled blit measured on a real GPU (perf-sweep task log) costs more than it saves, so web Auto stays at 1.0. Headless numbers are not the FPS reading.

## Part 1 release check and hub warmups (2026-11-22, w13, `32bcb8e3`)

Release `--release-ref`, interleaved, 2 runs each (before = `a6e7c1bb` export, after = `32bcb8e3`): camp-idle 7.7 / 8.6 -> 11.0 / 12.4 fps, camp-walk 10.2 / 11.0 -> 15.2 / 15.6. The flow's `camp_load_ms` 32.1 s (its settle never met) -> 6.5 to 9.6 s.

Debug export, `?wdbskip=` A/B of each hub warmup (temporary build, not in the tree), frame times from `window.wdbEval`, 2 runs each:

| Variant | Loader step | After the reveal |
| --- | --- | --- |
| all warmups | warm_frame 1.45 s, warm_ui 2.25 to 2.45 s, settle 3.5 to 3.9 s | first frame 95 to 160 ms, then ~80 ms steady |
| no warm_frame (`Warm.frame`) | warm_frame 0.08 s | first full-yard view 1236 / 1351 ms, then 455 / 553 ms (warm: ~80) |
| no `UiWarm.finish` | warm_ui 1.6 s | `ensure_ui` 105 ms; first open pause 62, inventory 68, anvil 32 ms (warm 17 to 43, 10); budget 16 ms |
| no player texture / lazy-script warm | warm_ui 1.5 s | no extra spike at idle, first move or attack (1 run) |
| hub settle with a flat plateau | settle 0.55 / 0.98 s | first 30 frames max 151 / 175 ms vs 145 / 149 with the 24-frame settle; first frame the same |

Settle frame times on this box: 258 or 178 ms, then flat ~150 ms to the cap (each iteration is a forced draw plus a frame). Kept: warm_frame and `UiWarm.finish` (the cold costs land in play). Changed: the hub settle reveals on a flat plateau after `WARM_HUB_PLATEAU_MIN` frames (debug check: settle 2.2 s, first frame 153 ms). Next: the player texture warm (~0.9 s) needs a walk-and-attack A/B before it moves; ground `hub_sun` textureSize to a uniform (~13 ms) and feather `vnoise` (~12 ms); Pages compression for the 38.6 MB wasm and 30.6 MB pck.

## Part 3: ground hull mask and feather band (2026-11-22, w13, `f1b88f68`)

`hub_sun` reads the hull mask size from the `hull_ts` uniform (set in `Hulls.bind`) instead of `textureSize` per pixel. The ground feather computes its two `vnoise` wobble terms only inside the band `0 < d < feather + 0.37` (the wobble is 0 to 0.37 m, so `k` is the same everywhere) and skips the `under_tex` read when `k` is 1. Same image: ground pixels unchanged in the wide camp shot; camp-prop-shadows diffs are the lantern flicker (the same boxes and size between two after runs).

- Debug export, camp spawn, median of 20 frames, 6 blocks per run, interleaved: before 86.9 / 88.1 / 84.8 ms, after 83.9 / 83.0 ms (third after run disturbed, 93 to 131 ms). About -3 ms (-3.5%), not the ~25 ms the remove-the-term split suggested; the mask fetch, not its size query, is the cost.
- Release `--release-ref`, interleaved, 2 runs each: camp-idle 11.9 / 11.6 -> 12.0 / 10.9 fps, camp-walk 15.4 / 15.3 -> 15.4 / 8.5 (second after run under box load 7). No change beyond noise.

Pages delivery (live site, curl with `Accept-Encoding`, 2026-11-22): gzip, no brotli, `max-age=600`. `index.wasm` 39.5 MB -> 10.2 MB gzip; `index.pck` 30.4 MB -> 29.0 MB (-4.5%); `index.js` 280 KB -> 69 KB. The pck is 2476 files, 28.1 MB of them `.ctex` that already hold lossless WebP, so gzip cannot shrink it and no lossless repo-side cut was found (the biggest files are tutorial and journal art, 0.5 to 1.6 MB each; `torch_bracket_bible.png` is used by `torch_bill.gd`). Lossy import of the two photos (`vira_profile.jpg` 1.37 MB and `load_background.jpg` 1.03 MB as ctex) would save ~1 to 1.5 MB but changes pixels, so it is not done.

Player texture / lazy-script warm A/B (debug export, temporary `?wdbskip=player`, not in the tree), 3 interleaved runs each:

| | warm_ui step | first frame after reveal | first move | first special (frames 0-3) |
| --- | --- | --- | --- | --- |
| warm kept | 2.24 / 2.31 / 2.26 s | 155 / 154 / 143 ms | 112 / 97 / 105 ms | one ~141-155 ms frame at frame 3 |
| warm skipped | 0.98 / 1.10 / 1.02 s | 197 / 248 / 228 ms | 107 / 111 / 200 ms | 145+162, 159+160, 145+160 ms at frames 1-2 |

Steady frames ~80 ms either way. Kept: skipping saves ~1.2 s of loader but moves +45 to +105 ms onto the first visible frame and adds a second ~150 ms frame to the first special (run 3 also 200 ms on the first move), over the 50 ms spike rule.
