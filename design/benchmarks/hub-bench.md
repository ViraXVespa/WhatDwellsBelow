# Benchmark: hub walk FPS

Status: record
Read when: `perf.py hub` is rerun (the bar: 99% of counted frames at 60 FPS)

| Date | Leg | Machine | fps_pct | Frames / s | Hitches | Note |
|------|-----|---------|---------|------------|---------|------|
| 2026-10-20 13:26 | desktop, headless | `bot-box` (Godot 4.7.2, gl_compatibility, vsync on, max_fps 120, 60 Hz paced, window 0x0) | 100.0 | 3263 / 30 s | 0 | Not an FPS reading (the runner fails headless runs); dt p50/p95 8.3 ms |

Web-leg numbers from the hub perf work (open task `hub-perf-fix`, fps_pct near 75 on the light-tap variants) are from machine `unknown` (not recorded in the task).
