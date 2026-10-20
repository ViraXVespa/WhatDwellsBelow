# Benchmark: web export perf

Status: record
Read when: `web_perf.py` is rerun or its baseline changes

Baseline file the tool compares against: `tools/web-perf-baseline.json` (committed 2026-10-13 in `0204b8ca`, build_id `52f50eb125790f66`). Machine: `unknown` (the file records only `google-chrome`, headless, viewport 1280x720; Chrome version, CPU, GPU and OS were not saved). Renderer: Compatibility on SwiftShader per the tool docstring. Per flow: load_ms / avg_fps / p95 frame ms / heap MB.

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
