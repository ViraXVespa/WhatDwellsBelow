# Benchmark: frame-time breakdown (0.5.21)

Status: record
Read when: comparing frame cost per system, desktop vs web

Frame-time breakdown (0.5.21, ms per frame, 8-core Xeon shared with other jobs, so +-20% noise; software GL both ways). Measured with a temporary probe (not kept): `process_priority` +-100000 marker nodes bracket every `_process` / `_physics_process` (script and node time), `RenderingServer.viewport_get_measured_render_time_cpu` gives render CPU. `Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS` read above the frame time here and are not usable.

| Build, scene | Frame | Script process | Script physics | Render CPU | Rest (GPU / swap wait) |
|---|---|---|---|---|---|
| Desktop llvmpipe, camp | 13.5-14.2 | 0.45 | 1.5-1.8 (X11 mouse query, see below) | 7.2 | about 4 |
| Desktop, dungeon + playtester | 11.4-12.7 | 1.6-1.9 | 0.9-1.2 | 4.8-5.0 | about 4 |
| Web SwiftShader, camp idle | 29-50 | 0.4-0.9 | 0.02 | 0.5-1.1 | 28-48 |
| Web, dungeon fight + playtester | 28-40 | 1.4-5 (about 3.8 mean) | 1.1-5 (about 3.1 mean) | 0.8-2.4 | 22-33 |

Web is not script-bound: with `disable_3d` or the render loop off the same camp runs 60 fps (the rAF cap) and at 640x360 44-60 fps, so the 17-30 fps is SwiftShader fill rate (about 20 draw calls in camp). Frames land on 60 Hz steps (33/50 ms) and physics then runs 2-3 ticks per frame, which multiplies physics script cost. Desktop camp physics is dominated by `Viewport.get_mouse_position()` (about 2 ms in Xvfb, 0.02 ms on web); do not read it as a game cost.

Per-function script costs, dungeon, desktop us/frame (+-30%): `tick_pressure` 140-190 (room scan before the timer test; about 10), HUD `refresh` about 190 (level/stat maths about 80), `actor_lit` about 200 per actor (11-field string key per slot, 3.3 us each; 0.4 cached), aim line 110-230, `apply_facing` 60-290, `advance_attack` 170-350 while attacking, `set_stats` 40-70, `reveal` 55, `guard` 45, `stream` 45, runtime `load()` of scripts 5-10 us each on desktop and about 9 us on web (about 15 per physics tick; cached). Not changed (needs cache invalidation): HUD level/stat maths, `gear_stat`, `set_stats`.
