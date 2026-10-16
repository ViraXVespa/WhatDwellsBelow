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
Desktop `20261016` on this machine, fullscreen 1920x1080: fps_pct 99.7, frames 3221, sec 30.0, p50 and p95 8.3 ms.

Web, capped Edge, vsync on, same window: the ending fill is still the miss. After the hitch-log change below, a run was fps_pct 77.7, frames 1201, slow 268, sec 30.0, p50 16.7, p95 50.0. The counted slow run was 237 frames, median 41.7 ms, and it was the fill (about play 19 s through 30 s, cells on the west arm around the dummy). Facings and station walks stay near one refresh.

A run that still built a hitch row on every miss, including a scene walk for mesh and light counts, latched the whole walk: fps_pct 1.7, p50 43.9. Stopping that per-frame walk put the early phases back on one refresh. The fill median stayed 41.7 ms, so the fill cost is not the log.

Samples during that fill (render-time counters, then removed): render CPU about 0.8 ms, draw about 48 to 78, primitives about 670 to 870. Facings were the same band (draw about 38 to 69, primitives about 530 to 830, render CPU about 1 to 3 ms) and presented at 16.7 ms. GPU time read 0 on this WebGL. A mesh per fence post was not the gap: batching the posts did not move fps_pct. Do not pass `--disable-frame-rate-limit` or `--disable-gpu-vsync`.

## Next
The walk stays. The open cost is GPU time in that west-arm view: same draw and primitive counts as a fast facing, render CPU under 3 ms, frame median 41.7 ms. Desktop at the same spot stays at 8.3 ms. Next change should cheapen fragment work that covers that view, not another hitch-log throttle.

## Notes from Vira
That hitching on web during that last walk phase looks like a similar issue I've seen happening on the web builds but wasn't able to track down or reproduce. I've gotten it to occur in other places in the hub and without attacking the dummy. That's something I'd really like to get out of the game ASAP. I don't know if the logging is failing to catch whatever's causing it, but do whatever you need to do to diagnose and solve that issue.