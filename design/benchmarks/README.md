# Benchmarks

Status: record
Read when: benchmark records, open_timing, fps_pct, hitch timings

Measured numbers only, newest first, each with date (America/Chicago), version or commit, machine, and the command. Thresholds and budgets stay in the tunables docs; this folder records what a run measured.

Rule: when a benchmark is rerun or a perf change lands, add the new row next to the old one here (keep the old row; do not overwrite it).

| Record | File |
|--------|------|
| Frame-time breakdown and per-function script cost (0.5.21) | `frame-time.md` |
| Menu first open (`open_timing` smoke) | `menu-open.md` |
| Web export load, FPS, heap (`web_perf.py`) | `web-perf.md` |
| Hub walk FPS (`run_hub_bench.py`) | `hub-bench.md` |
