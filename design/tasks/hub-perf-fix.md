# Hub perf fix — diagnose and clear sub-60 FPS on the bench

id: hub-perf-fix
owner: build
status: open
done-when: The hub-bench walker reports 99 % of frames at or above 60 FPS (threshold 1×) across two full ~30 s runs, with the causes of the previous sub-60 frames fixed and the hitch log clean of recurring major hits. Design docs and code-map updated if ownership or tunables changed.
resume: python tools/open_slice.py debug.playtest --task hub-perf-fix
area: debug
door: debug
job: playtest
units:
needs: none

## Intent
Both legs walk a full 30 s. Eight facings, the stations, one strike on the dummy, then an out-and-back walk on each facing until the play clock reaches 30 s. The window closes when that clock ends. `fps_pct` counts only while the hub is visible: camp is showing and the loader bar is down. 99% of those frames at or above 60 FPS is the bar. 100% is the aim.

## Where it stands
Desktop `20261015-235507`: entered the hub, sec 30.0, frames 3263, slow 0, fps_pct 100.0. Vsync off, max_fps 120, p50 and p95 8.3 ms. Every station opened and the dummy was struck.

Web, same walk, capped Edge, vsync left on: fps_pct 78.0 on the latest run (sec 30.0, frames 1217, slow 268, worst 145.8, p50 16.7, p95 41.7). The miss is the ending walk, from the dummy at cell 9,15 through the rest of the clock, median about 41.7 ms. The facings and stations before that stay near one refresh, plus a few frames when the hub appears. Posting hitch rows in a batch did not change it. Do not pass `--disable-frame-rate-limit` or `--disable-gpu-vsync`.

## Next
The walk stays. The open cost is that ending view on web. Desktop at the same spot stays at 8.3 ms.

## Notes from Vira
That hitching on web during that last walk phase looks like a similar issue I've seen happening on the web builds but wasn't able to track down or reproduce. I've gotten it to occur in other places in the hub and without attacking the dummy. That's something I'd really like to get out of the game ASAP. I don't know if the logging is failing to catch whatever's causing it, but do whatever you need to do to diagnose and solve that issue.