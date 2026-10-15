# Hub perf fix — diagnose and clear sub-60 FPS on the bench

id: hub-perf-fix
owner: build
status: open
done-when: The hub-bench walker reports 99 % of frames at or above 60 FPS (threshold 1×) across two full ~30 s runs, with the causes of the previous sub-60 frames fixed and the hitch log clean of recurring major hits. Design docs and code-map updated if ownership or tunables changed.
resume: python tools/open_slice.py debug --task hub-perf-fix
area: debug
door: debug
job: playtest
units: 
needs: none

## Intent
First, update the procedures of the new hub hitch test to be two 30s tests, one in the desktop build and one in a local web export build, instead of a single desktop build test.
Then, use the hitch JSONL and mark() tags produced by the hub-bench task to find why frames drop under 60 FPS in Placeholdia, fix them, and confirm the bench stays at or above the 99 % / 60 FPS bar.

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

## Resume (next session)

Status stays open. Do not launch the web leg with Chromium uncap flags.

The web leg in `tools/run_hub_bench.py` now opens a visible Edge window (Chrome if Edge is not installed) and leaves the browser frame cap and GPU vsync on. It must not pass `--disable-frame-rate-limit` or `--disable-gpu-vsync`. Those flags, copied from headless software-GL `web_perf.py`, were pointed at this machine's real GPU. The window opened and Windows bugchecked `0x1A` `MEMORY_MANAGEMENT` at 18:33:24 on 2026-10-15 (parameters `0x5150a`, `0x175f63`, `0x176863`, `0xC00000A0`; dump `C:\WINDOWS\MEMORY.DMP`). She is not bothered if a later run crashes. She does want the capped window, not the uncapped one. `web_perf.py` is unchanged and is still not an FPS reading.

Next step is `python tools/run_hub_bench.py --leg web`. A refresh-paced browser sits near 16.7 ms, so a 1× hitch row may be the refresh rather than a stall. Read frames clearly over one refresh. Do not turn the GPU uncap back on to make the 1× bar look like the desktop run.

Desktop, last finished run (`_logs/hub-bench/20261015-182024-hub-bench.txt`): exit 0, sec 24.2, frames 5229, slow 19, fps_pct 99.6, worst 150, every station opened. That was before the later camp split. The split (hall, wing, stall, one frame per spot, `build_done` before menu warmup) is in the tree and has not had a finished bench. A follow-up desktop run was killed so the web export could start. The export then died on a stale Godot lock; `godot_lib.lock_fresh` now treats a dead holder pid as not fresh. No web fps_pct exists yet.

Rows still over a refresh on that desktop log, t and dt: boot 0.1 / 144 and 0.8 / 129; hub_buildings 148 inside a 144 ms frame that also marked `ui_close_anvil`; hub_spots 130 inside a 150 ms frame that also marked `ui_close_controls`; first `loco_walk` gaps around 32 to 38 ms with frame dt 132, 52, 43, 41; one `loco_idle` at t=23.4, dt 59, proc 5, idle_left. `dt_ms` on the frame after a long step can be the previous step. `proc_ms` while a menu is up is still not the frame cost.

The 99 % bar is not met until both legs finish and the causes above are actually gone, not only until the percentage passes on one desktop log.

---

Additional session notes from Vira: For this session, don't worry about actually fixing any of the performance issues. This session's goal will be to make sure the benchmarking system is actually functioning correctly and logging everything it needs to be logging. I also want you to investigate the correct way to disable vsync without overloading the GPU and causing a BSOD like the last attempt did. I'm sure there's probably a documented method to do that safely somewhere online.