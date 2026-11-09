# Tools: performance, hitches and load time

Status: protocol
Read when: measuring performance or reading a benchmark

`tools.md` defines the CLI contract and Surf/A columns. Entry: `perf.py`; owners: `tools/lib/perf/`. Compare results only on the same machine, build mode and browser-pacing mode. Records live in `design/benchmarks/` (index: `save-tech.md`).

## Choose and run

1. Choose a command below; use its `--help` for flags. Confirm the task permits a runtime before launching one.
2. For hub, dungeon or sweep, choose `--leg desktop`, `web` or `both`. The runners manage the fresh save, cold web export, browser and logs. Do not substitute a headless result for FPS or disable browser pacing. Detailed window, cache, scoring and timing-field contracts belong to `debug-bench.md`.
3. Read the printed summary path. `perf.py hub|dungeon|sweep --report HITCH.jsonl` reprints an existing run without another benchmark. Numeric timings appear as `*_med` in summaries, including `script_med`, `queue_med`, `tail_med`, `bench_med`, `sample_med` and `sample_n_med`; `lit_who` stays on hitch rows.
4. For the continuous sweep, check overall and all four `place` bars: `hub1`, `dungeon1`, `hub2`, `dungeon2`. Each must be present and at least 99%. `pair hub` and `pair dungeon` compare warm minus cold. Two cold web passes require two separate runs; task acceptance may also require a desktop run.

Layer probes diagnose a cause, not a performance pass. Hub `--layers` stands at the dummy; `--walk-layers` measures during the fill. `--fill-aba` compares normal/hidden/normal; retain it only when initial submit stays near 40 ms. Dungeon `--walk-layers` retains its probe only at 30–45 ms initial submit and at least 20 frames. Sweep layer rows require base submit >=45 ms and at least 20 frames (`keep=1`). Probe windows do not count toward the 99% score. Full layer names and field meanings are in `debug-bench.md`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `perf.py hub` | Hub walk/frame-time benchmark. Summary: `hub-bench`; report-only: `hub-bench-report`. | D | `--help` | N |
| `perf.py dungeon` | Fresh seed-42 dungeon playtest, 30 s acting at time scale 1. Scores visible dungeon frames with loader down; excludes playtest physics credit. Summary: `dungeon-bench`; report-only: `dungeon-bench-report`. | D | `--help` | N |
| `perf.py sweep` | Continuous hub → dungeon → dispel → hub → dungeon. Four scored stretches plus total; no exits between them. Summary: `perf-sweep`; report-only: `perf-sweep-report`. | D | `--help` | N |
| `perf.py web` | Advisory exported-web profiling in headless Edge/Chrome via Playwright; not an FPS gate. Export first (`release.py export-web --debug --out DIR`), then `--site DIR`. Release comparisons use `--release-ref` and their separate baseline. `--strict` fails WORSE results; `--video DIR` needs Playwright ffmpeg. Summary: `web-perf`. | BD | `--help` | Y |
| `perf.py hitch` | Serve a local exported web build and append hitch rows to `_logs/web-perf/hitch.jsonl`. Also used by `perf.py web`. | WD | `--help` | N |
| `perf.py bars` | Cold/cached web loading bars, or desktop with `--desktop`. JSON/PNG under `_logs/load-bars/`; flags backward fill and early 100%. `--chart JSON` redraws without a game run. | BD | `--help` | Y |
| `perf.py load` | Title → hub load timing; `--leg dungeon` measures hub → dungeon. Summaries: `load-timing`, `dungeon-load-timing`. First-menu opening timing instead belongs to `gate.py bot-smokes --phases 6`. | WD | `--help` | N |
| `perf.py desktop` | Linux release/debug comparison on separate Xvfb/empty XDG data with software GL. `--export` builds both; `--write-md` records results. Advisory, not a hardware FPS gate. Summary: `desktop-perf`. | D | `--help` | N |
| `perf.py map` | Dungeon generation dump for one seed or a seed sweep. Summaries: `dungeon-map`, `dungeon-map-sweep`. | WD | `--help` | N |
| `perf.py curve` | Local debug playtest spool: floor/cycle, weapon skill by item level, weapon by floor/item level, combat affix and level-gap histogram. `--sqlite` imports then deletes `runs.jsonl`/`decisions.jsonl` (keeps `weapon_band.json`). Cleanup deletes old decision rows, not runs; default retention 30 days. Refuses writes inside the repo. Summary: `playtest-curve`. | D | `--help` | N |

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `lib/perf/run_dungeon_bench.py` | `perf.py dungeon`: launches the dungeon bench through `run_hub_bench._desktop` / `_web`. |
| `lib/perf/run_perf_sweep.py` | `perf.py sweep`: launches the continuous sweep through `run_hub_bench._desktop` / `_web`. |
| `lib/perf/curve.py` | `perf.py curve`: four slices, the level-gap histogram, sqlite import, decision cleanup. |
| `data/web-perf-flows.json` | Flows for `perf.py web` (`_boot` is the shared prefix). `dungeon-fight` runs the playtester: compare its fps only with itself; INVALID runs are never baselined; `expect_change` pairs must differ (else STUCK). `dungeon-music-cold` is the web music regression: cold cache, `mbps`, a `cpu` throttle step, an audio-thread probe (`audio`, `audio_reset`) and `assert` limits (audio gaps 0, music-phase frame p95); an ASSERT fails the run. |
| `data/web-perf-baseline.json` | `--save-baseline` numbers (box, w7 tip, median of 2, Chrome frame pacing off: uncapped, the default). Compare in the same mode (not `--vsync`); re-save per machine. |
| `data/web-perf-release-baseline.json` | `perf.py web --release-ref --save-baseline` numbers: release export, hook-free flows, with the `env` line. Not comparable to `web-perf-baseline.json`. |
