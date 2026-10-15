# Hub perf fix — diagnose and clear sub-60 FPS on the bench

id: hub-perf-fix
owner: build
status: open
done-when: The hub-bench walker reports 99 % of frames at or above 60 FPS (threshold 1×) across a full ~60 s run, with the causes of the previous sub-60 frames fixed and the hitch log clean of recurring major hits. Design docs and code-map updated if ownership or tunables changed.
resume: python tools/open_slice.py debug --task hub-perf-fix
area: debug
door: debug
job: playtest
units: 
needs: none

## Intent
Use the hitch JSONL and mark() tags produced by the hub-bench task to find why frames drop under 60 FPS in Placeholdia, fix them, and confirm the bench stays at or above the 99 % / 60 FPS bar.

## Starting point
Display run, not headless. `run_hub_bench.py` opened a gl_compatibility window, turned vsync off, set zoom to 1.0 (code default was 1.75), and used an empty `_logs/hub-bench-fresh` AppData (`HB: fresh=1`). Real save was not read. 58 s, 16 hitches at 1× (16.7 ms), worst 150 ms. Log: `_logs/hub-bench-fresh/Godot/app_userdata/What Dwells Below/hitch/hitch.jsonl`.

The walk held the line after the opens. Rows at or over 20 ms:

- 150 ms at t=0.1, boot, no why (window still coming up).
- 143 ms at t=1.6, camp build, idle_down, cell 16,16. Gaps on the tags: hub_ground 94, hub_buildings 89, hub_spots 100, hub_bake_load 41, hub_player 37, hub_bake_push 19, hub_fence 7. proc 100, draw 22.
- 133 ms at t=2.5, why ui_close_anvil, ui recorded as vendor,pause, draw 161, proc 1496. The bench did not open the pause menu.
- 131 ms at t=3.2, idle_down, ui=ui, draw 33, proc 747. No why tag.
- 117 ms at t=0.8, boot, draw 5, proc 100. No why tag.
- 90 ms at t=35, loco_idle, idle_left, cell 9,15, draw 73, proc 7. Frame time is not the process time.
- 85 ms at t=2.5, ui_close_vendor, ui=loadout, draw 153, proc 747.
- 48 ms at t=3.2, ui_close_controls, ui=ui, draw 43. The bench never opens the controls billboard.
- 28 to 19 ms, one each, on the first idle-to-walk of down_right, up_right, down_left, up_left, up, and left. proc stays under 20. draw 42 to 72.

`proc_ms` on the menu rows is several times `dt_ms`. Do not treat that monitor as the frame cost while a menu has paused the tree. `dt_ms` is the frame.

Steady walk cycles did not recur as hitches. One loop row, 17 ms, loop_up_right.

## Out of scope
New features. Only the performance issues the bench surfaces.
