# Hub perf fix - diagnose and clear sub-60 FPS on the bench

id: hub-perf-fix
owner: build
status: open
done-when: On Vira's machine (env `build-pc`), `python tools/perf.py hub --leg web` prints PASS (fps_pct >= 99) on two consecutive cold runs. Desktop already passes and is not re-scored. Docs and code-map updated if ownership or tunables changed.
resume: python tools/slice.py open debug.playtest --task hub-perf-fix
area: debug
door: debug
job: playtest
needs: none

## Intent
Both legs walk a full 30 s. Eight facings, the stations, one strike on the dummy, then an out-and-back walk on each facing until the play clock reaches 30 s. The window closes when that clock ends. `fps_pct` counts only while the hub is visible: camp is showing and the loader bar is down. 99% of those frames at or above 60 FPS is the bar. 100% is the aim.

## Where it stands
Desktop `20261016`, fullscreen 1920x1080: fps_pct 99.7 to 99.8, p50 and p95 8.3 ms. Not re-run since.

A cold web run is a new `_logs/hub-bench-web-<stamp>` on a free port, capped Edge, vsync on, 1920x1080, full 30 s sequence. Publishing again to `_logs/hub-bench-web` on port 8060 is warm: that origin is the service worker scope, and the shell keeps the worker when the build id matches. A wiped profile on that origin is still warm. `--guest` joins an Edge that is already open. Vira says the hub bake in `49fb157` did not touch performance and did not fix the hitch.

Same-origin scored runs on 2026-10-27 (the warm publish) sit at fps_pct 75.7 to 77.9, p50 about 17, p95 about 45, one fill of about 245 frames at median about 40 ms, cells along 8,15-12,15. On those fill rows `submit_ms` is about 39 to 47, `tree_ms` about 3 to 9, `after_ms` about 9 to 13, physics a few milliseconds, draw calls about 75. The fill cost is inside the draw. One worst row can show `submit_ms` several times `dt_ms`; ignore that row.

One scored run after the cold publish, `20261027-165026` at `127.0.0.1:10379`: fps_pct 97.9, frames 1589, slow 33, p50 16.7, p95 18.1, sustained none, worst 127.7 at cell 9,15 `idle_left`. That single run does not close the task and does not retire the fill tail.

`--fill-aba` times a normal fill, hides every tagged group for 3 s, then times the normal fill again. The one run was on the old origin and was discarded (`base` submit 4.6). Keep a layer time only when that same run's first fill submit stays near 40 ms. `--walk-layers` and `--fill-aba` do not score the bar.

Ground is the week-7 band planes. Uncapping is refused. A per-frame hitch-log scene walk latches the bench.

## Next
Two consecutive cold scored `python tools/perf.py hub --leg web` PASS runs close the task. The cold publish is now the default. If a cold run shows the fill tail again (submit near 40 ms), run `--fill-aba` and discard it unless the first fill submit stays near 40 ms. If cold runs stay near 98 with no sustained fill, the remaining miss is the isolated frames: cell 9,15 `idle_left` and the facing-start frames that miss one refresh. No hub-draw change until a cold run names the cost.

Do not spend a web leg on the light tap, a second path plane, `texture()` on `hub_light.png`, uncapping, a desktop rescore, a walk that skips the full sequence, or another publish to port 8060.

## Handoff
Gather reset: `grok -r 01a17ec2-2017-75a0-9ed2-e148e542fe49 --fork-session` from this worktree. Do not re-gather. Latest measured session: `01a17f3a-7a84-7831-bd00-3d7a09599856`.

The draw split stays (`tree_ms`, `submit_ms`, `after_ms` on the hitch row, `submit` on a layer line). `gd-load` passed after the bench script edit. The scored bar is still red.

## Notes from Vira
That hitching on web during that last walk phase looks like a similar issue I've seen happening on the web builds but wasn't able to track down or reproduce. I've gotten it to occur in other places in the hub and without attacking the dummy. That's something I'd really like to get out of the game ASAP. I don't know if the logging is failing to catch whatever's causing it, but do whatever you need to do to diagnose and solve that issue.

## Known non-signals
Settled; do not re-investigate: hub FPS below dungeon FPS is this same web fill tail; the blocky/grainy ground is on main and not this task; vsync stays on (uncapping is refused).
- GLES quit leaks (N5GLES34MeshE / N5GLES37TextureE leaked at exit, and the raw Texture with GL ID / Buffer with GL ID leaked N bytes lines) are Compatibility-renderer artifacts on web exit. They are not the fail.
- Desktop hub-bench already clears the 99% bar (99.7-99.8%, p50/p95 8.3 ms).
- Web is refresh-paced (vsync=1 paced=1). The mid-70s fill tail was measured on the repeated 8060 publish. A wiped profile on that origin is warm. `--guest` is not a cold window.
- Do not open shader or mesh files because a quit-leak line named a texture or buffer.
- Attack does not clear the walk cache. ensure_loco and ensure_attack fill separate dictionaries and return once the key is present. The only clear is load_sprites at init.
- Preloading every facing in warmup (ensure_loco + ensure_attack, then apply_tex) did not move the web number. Still fps_pct 76.8.
- A warm Edge process, or the same folder on port 8060, can report a one-refresh fill. That is not the cold number the task measures.
- Chrome task-manager lines (fallback_task_provider) are Edge internals, not the fail.
