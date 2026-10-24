# Benchmarks

Status: record
Read when: benchmark records, open_timing, fps_pct, hitch timings

Measured numbers only, newest first. Thresholds and budgets stay in the tunables docs.

Rules:
- Every record names its machine (a row below) plus date (America/Chicago), commit, Godot version, renderer, vsync / frame cap, resolution, headless or windowed, and the browser and version for web. A field nobody recorded is `unknown`; never fill one in by guess.
- Compare numbers only within one machine. A cross-machine comparison is not valid (different CPU, GPU, OS or browser).
- When a benchmark is rerun or a perf change lands, add the new row next to the old one (keep the old row). `perf.py web`, `perf.py hub`, `perf.py desktop` and the `open_timing` smoke (`gate.py bot-smokes`) print an `env:` line (`tools/lib/perf/bench_env.py`); copy it into the record.

## Machines

| Machine | Who runs it | CPU | GPU | RAM | OS | Notes |
|---------|-------------|-----|-----|-----|----|-------|
| `bot-box` | Grok Bot | Intel Xeon, 8 vCPU (shared with other jobs) | unknown (no GPU query available) | 16 GB | Debian 13 (kernel 6.12) | Google Chrome 155.0.8059.84 (2026-10-20). Headless runs are not FPS readings |
| `build-pc` | Vira / Grok Build | unknown | unknown | unknown | Windows (version unknown) | Fill from the first `env:` line run there |
| `unknown` | unknown | — | — | — | — | Older records whose machine was not written down |

| Record | File |
|--------|------|
| Frame-time breakdown and per-function script cost (0.5.21) | `frame-time.md` |
| Menu first open (`open_timing` smoke) | `menu-open.md` |
| Web export load, FPS, heap (`perf.py web`) | `web-perf.md` |
| Hub walk FPS (`perf.py hub`) | `hub-bench.md` |
| Desktop release vs debug export (`perf.py desktop`) | `desktop-release.md` |
