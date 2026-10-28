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
Desktop 20261028-033831, fullscreen 1920x1080, vsync off, max_fps 120, gl_compatibility: fps_pct 99.6, frames 3483, sec 30.0, p50 8.3 ms, p95 8.3 ms, slow 14, worst 142.9 ms. Those spikes are first-use marks: light_plan with dungeon_show, light_lift, loco_walk face_right, loco_cycle. They are not the web steady cost. Do not rescore desktop unless a dungeon draw change lands. Web cold run 20261028-033953, Edge, 1920x1080, paced 1, vsync 1, refresh 60: fps_pct 0.9, frames 528, slow 523, sec 30.0, ok 1, p50 54.2 ms, p95 83.1 ms, worst 150 ms. Sustained play runs sit near 54 to 66 ms. On those runs tree_med is about 4 to 10 ms, submit_med about 35 ms, after_med about 13 to 16 ms, phys_med about 12 to 19 ms, draw calls about 48 to 70. The steady cost is the draw submit. A single worst row can show submit_ms several times dt_ms; ignore that row. Hitch rows left cell and anim empty on both legs.

## Next
Do not change dungeon draw until a cold run names the group. Add the cheapest layer time during the play, the hub walk-layers shape: hide one group at a time and record that layer submit median. Keep the reading only when the unhidden play submit stays near 35 ms. Then fix the named group. Two consecutive cold python tools/perf.py dungeon --leg web PASS runs close the task. Do not uncap the browser, do not pass --wdb-pt-fast, do not treat perf.py web headless numbers as the FPS reading, and do not rescore the hub.

## Handoff
Gather reset: grok -r 01a18192-f080-76d0-b879-f3b5e46db230 --fork-session from this worktree. Do not re-gather. Bench, docs, and this task are the unit. Measured session 01a1819e-27e0-7b02-b913-c252f69b90df. The runner is python tools/perf.py dungeon. Desktop PASS is summary _logs/dungeon-bench/20261028-033831-dungeon-bench.txt. Web FAIL is summary _logs/dungeon-bench/20261028-033953-dungeon-bench.txt.
