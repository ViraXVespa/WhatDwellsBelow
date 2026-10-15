# Hub perf fix — diagnose and clear sub-60 FPS on the bench

id: hub-perf-fix
owner: build
status: blocked
done-when: The hub-bench walker reports 99 % of frames at or above 60 FPS (threshold 1×) across a full ~60 s run, with the causes of the previous sub-60 frames fixed and the hitch log clean of recurring major hits. Design docs and code-map updated if ownership or tunables changed.
resume: python tools/open_slice.py debug --task hub-perf-fix
area: debug
door: debug
job: playtest
units: 
needs: hub-bench

## Intent
Use the hitch JSONL and mark() tags produced by the hub-bench task to find why frames drop under 60 FPS in Placeholdia, fix them, and confirm the bench stays at or above the 99 % / 60 FPS bar.

## Starting point
(Filled by the hub-bench session before it marks itself done: paste worst dt_ms, recurring why tags, player positions, anims, or other context that pointed at the hot spots.)

## Out of scope
New features. Only the performance issues the bench surfaces.
