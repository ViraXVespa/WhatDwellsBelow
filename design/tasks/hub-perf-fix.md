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

Web scored cold, capped Edge, vsync on, 1920x1080. The full sequence is required. Scored runs on 2026-10-27 sit at fps_pct 75.7 to 77.9, p50 about 17, p95 about 45, one fill run of about 245 frames at median about 40 ms, cells along 8,15-12,15. `proc_ms` still repeats and can exceed the frame.

The frame split on those fill rows adds up to `dt_ms`. `tree_ms` is about 3 to 9. `submit_ms` (pre-draw to post-draw) is about 39 to 47. `after_ms` is about 9 to 13. Physics stays a few milliseconds. Draw calls stay about 75. The fill cost is inside the draw. One worst row can show `submit_ms` several times `dt_ms`; ignore that row. Viewport render-time queries returned 0 and are off the row.

A one-refresh scored p50 with a slow fill came back after the 1.1 run (slow from the facings, p50 49.6). That 1.1 run is not the number to chase. The draw hooks are not that collapse.

`--walk-layers` once, just after a 77.9 scored run: whole window fps_pct 99.3, and every fill layer including both base passes was p50 16.7 with submit about 4. The miss was absent, so the hides named nothing. The next scored run was 75.7. A layer time counts only when that same run's base fill stays near a 40 ms submit.

Ground is the week-7 band planes. Uncapping is refused. A per-frame hitch-log scene walk latches the bench. `--walk-layers` gathers the groups once, when the fill starts.

## Next
No hub-draw change yet. The named cost is the draw window during the scored fill, not a mesh group. Next measurement: in one scored run, time a normal fill, then one hidden group, then the normal fill again. Discard the run unless the first fill's submit stays near 40 ms. Then two consecutive cold scored PASS runs close the task.

Do not spend a web leg on the light tap, a second path plane, `texture()` on `hub_light.png`, uncapping, a desktop rescore, or a walk that skips the full sequence. Do not treat a `--walk-layers` RESULT PASS as the bar. That mode is not scored.

## Handoff
Gather reset: `grok -r 01a17ec2-2017-75a0-9ed2-e148e542fe49 --fork-session` from this worktree. Do not re-gather. Latest measured session: `01a17ee9-cc42-7ff1-b4a2-750249612e04`.

The draw split stays (`tree_ms`, `submit_ms`, `after_ms` on the hitch row, `submit` on a layer line). `gd-load` passed after the last script edit. `check.py load-graph` passed after the doc edits. The scored bar is still red.

## Notes from Vira
That hitching on web during that last walk phase looks like a similar issue I've seen happening on the web builds but wasn't able to track down or reproduce. I've gotten it to occur in other places in the hub and without attacking the dummy. That's something I'd really like to get out of the game ASAP. I don't know if the logging is failing to catch whatever's causing it, but do whatever you need to do to diagnose and solve that issue.

## Known non-signals
Settled; do not re-investigate: hub FPS below dungeon FPS is this same web fill tail; the blocky/grainy ground is on main and not this task; vsync stays on (uncapping is refused).
- GLES quit leaks (N5GLES34MeshE / N5GLES37TextureE leaked at exit, and the raw Texture with GL ID / Buffer with GL ID leaked N bytes lines) are Compatibility-renderer artifacts on web exit. They are not the fail.
- Desktop hub-bench already clears the 99% bar (99.7-99.8%, p50/p95 8.3 ms).
- Web is refresh-paced (vsync=1 paced=1). fps_pct stuck mid-70s, dt_p50_ms ~17, dt_p95_ms ~44, worst 100-140. The fail is that tail.
- Do not open shader or mesh files because a quit-leak line named a texture or buffer.
- Attack does not clear the walk cache. ensure_loco and ensure_attack fill separate dictionaries and return once the key is present. The only clear is load_sprites at init.
- Preloading every facing in warmup (ensure_loco + ensure_attack, then apply_tex) did not move the web number. Still fps_pct 76.8.
- A warm Edge process can report 99 %. That is not the cold number the task measures.
- Chrome task-manager lines (fallback_task_provider) are Edge internals, not the fail.
