# Dungeon perf - clear sub-60 FPS on the web bench

id: dungeon-perf
owner: build
status: open
done-when: On Vira's machine, python tools/perf.py dungeon --leg web prints PASS (fps_pct >= 99) on two consecutive cold runs. Desktop already passed once (99.6, run 20261028-033831) and is not re-scored unless a dungeon draw change lands.
resume: python tools/slice.py open debug.playtest --task dungeon-perf

## Notes
Open task for the web miss. Desktop already clears the bar. See Where it stands.

## Intent
Both legs run one fresh-save playtest, seed 42, 30 s of acting, time scale 1, Great Axe. fps_pct counts only while the dungeon scene is showing and the loader bar is down. 99 percent of those frames at or above 60 FPS is the bar. Area debug, door debug, job playtest.

## Where it stands
Desktop 20261028-033831, fullscreen 1920x1080, vsync off, max_fps 120, gl_compatibility: fps_pct 99.6, frames 3483, sec 30.0, p50 8.3 ms, p95 8.3 ms, slow 14, worst 142.9 ms. Those spikes are first-use marks: light_plan with dungeon_show, light_lift, loco_walk face_right, loco_cycle. They are not the web steady cost. Do not rescore desktop unless a dungeon draw change lands. Web cold run 20261028-033953, Edge, 1920x1080, paced 1, vsync 1, refresh 60: fps_pct 0.9, frames 528, slow 523, sec 30.0, ok 1, p50 54.2 ms, p95 83.1 ms, worst 150 ms. Sustained play runs sit near 54 to 66 ms. On those runs tree_med is about 4 to 10 ms, submit_med about 35 ms, after_med about 13 to 16 ms, phys_med about 12 to 19 ms, draw calls about 48 to 70. A single worst row can show submit_ms several times dt_ms; ignore that row. Hitch rows left cell and anim empty on both legs.

The playtest node's `_physics_process` is now removed from the scored `dt` and from `after_ms`. It is not inside `submit_ms`: that tick finishes before idle `_process`, and the draw window is `frame_pre_draw` to `frame_post_draw`. Cold web run 20261028-041329 (same window, harness on): fps_pct 3.6, frames 587, slow 566, sec 30.0, ok 1, p50 48.5 ms, p95 66.5 ms, worst 149.6 ms, `pt_p50_ms` 0.5. Sustained play rows: submit_med 32.5 to 34.6, pt_med 0.6 to 2.0, one hitch at pt_ms 17.2. `phys_ms` on the row is still the whole physics frame, not the playtest node. The harness is not the submit cost and it is not the steady frame. That run also moved the bench `_process` later for one pass, so its tree_med near 0.4 and after_med near 25 are not the split to keep. The priority change was reverted. Keep the 20261028-033953 tree/after split, and keep 20261028-041329 for `pt_ms`, `submit_med`, and the scored p50.

Layer run 20261028-035545, `python tools/perf.py dungeon --leg web --walk-layers`, keep=1 (base submit 33.8 ms, n=39). Submit medians: floor 31.8, walls 31.2, sprites 31.6, props 32.5, lights 33.4, hud 31.7, bare 30.2, base2 31.0. Counts at gather: floor 12, walls 12, sprites 42, props 46, lights 1, hud 10. Hiding every tagged group drops submit by about 4 ms. No group is the steady cost. The `draw=` field on a layer line is one frame at report time, not a window median. base2 reported draw 7 on that single frame; do not read that as the meshes staying hidden. The submit medians are the reading.

## Next
Do not change floor, walls, sprites, props, the sun, or the HUD from the layer run. The ~30 ms submit remains with those groups hidden, and the playtest tick is not that cost (`pt_p50_ms` 0.5 on 20261028-041329). The next instrument has to time what `bare` still submits (environment, tonemap, an untagged node class, or the empty Compatibility viewport) before any dungeon draw change. Two consecutive cold `python tools/perf.py dungeon --leg web` PASS runs still close the task, after a kept reading names a cost. Do not uncap the browser, do not pass `--wdb-pt-fast`, do not treat `perf.py web` headless numbers as the FPS reading, and do not rescore the hub or the desktop leg. Do not put the bench node on a later `process_priority`. That moved game idle time out of `tree_ms` into `after_ms`.

## Handoff
Gather reset: grok -r 01a18192-f080-76d0-b879-f3b5e46db230 --fork-session from this worktree. Do not re-gather. Measured session 01a181be-5071-74e1-aa7c-f2f4365cdf87. The runner is `python tools/perf.py dungeon`. Desktop PASS is summary `_logs/dungeon-bench/20261028-033831-dungeon-bench.txt`. First web FAIL is summary `_logs/dungeon-bench/20261028-033953-dungeon-bench.txt`. Layer keep is summary `_logs/dungeon-bench/20261028-035545-dungeon-bench.txt`. Harness web FAIL is summary `_logs/dungeon-bench/20261028-041329-dungeon-bench.txt`. `--walk-layers` is web only and does not score the 99% bar.
