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

## Session note (2026-10-15, logging only)

Perf causes above are untouched. Status stays open.

Vsync, from Godot and Chromium docs:

- Desktop Compatibility does honor `VSYNC_DISABLED` (`wglSwapIntervalEXT(0)`). Adaptive and Mailbox do not. The call is `DisplayServer.window_set_vsync_mode`, not the project setting.
- Godot's own `VSYNC_DISABLED` note says an unlimited framerate can peg the hardware, and to cap it with `Engine.max_fps`. A blank Compatibility project with vsync off has also been reported to spike the GPU into a driver timeout (godotengine/godot#118905). The bench now sets `Engine.max_fps` to 120. That only pads frames faster than 120. A frame over 16.7 ms is still slow.
- Web cannot disable vsync. `DisplayServerWeb::window_set_vsync_mode` is an empty override, and the export loop is `emscripten_set_main_loop(..., -1)`, which is `requestAnimationFrame`. `Engine.max_fps` on web only skips early callbacks. It cannot outrun the browser.
- Chromium's `--disable-frame-rate-limit` also enables `--disable-gpu-vsync` (chromium commit 5590468 / ad3e51ee). Together they remove present back-pressure (`kMaxPendingSubmitFrames`). That is the pair that bugchecked this machine. There is no documented Chromium flag that uncaps a real GPU without that pair. The web leg still refuses both flags.

Logging:

- The old `HB:` begin line printed a fixed `vsync=0`. It now prints the read-back (`vsync`, `max_fps`, `refresh`, `paced`).
- Session and bench rows add `vsync`, `max_fps`, `refresh_hz`, `paced`, `renderer`. The bench row also adds `dt_p50_ms` and `dt_p95_ms` from every counted frame.
- A refresh-paced frame within 3 ms of one refresh is not a hitch and is not a slow frame. An uncapped desktop frame is slow when it is over the 16.7 ms budget. The runner fails a leg whose bench row is missing those present fields. Slowest-hitch lines include `t`, `proc_ms`, and `draw`.

Measured this session, causes untouched:

- Desktop `20261015-190533`: exit 0, sec 24.2, frames 2575, slow 20, fps_pct 99.2, worst 147.6. Read-back vsync=0, max_fps=120, refresh 60, paced=0, p50=p95=8.3 (the 120 cap). That run was before the explicit fullscreen call. Fresh boot was already borderless.
- Web `20261015-191344`: the first window was killed because Edge's starter process exits and the runner treated that as a crash. The rerun stayed up, fullscreen, win=screen=1920x1080. vsync read-back 1, paced=1, p50=16.7 (the refresh), p95=41.6, frames 1041, slow 95, fps_pct 90.9, sec 21.5, ok=1, worst 150. The leg fails the 99% bar. Browser cap and GPU vsync stayed on.

Still open: the 99% bar on the web leg, and the boot / camp / first-walk causes. Do not launch the web leg with the uncap flags. Walk clock ends before 30 s because the end fill stops after two steps.

---

Additional session notes from Vira: I'm not sure that everything got completed on the playtest end. The web playtest definitely had some visible FPS drops going on there that will probably be revealing in regards to the updates needed to the logging. Keep this session focused on getting the hub-bench logics up to the level we need them to be at before we can have you focused entirely on solving the hitching issues.

## Session note (2026-10-15, bench report)

Perf causes are still untouched. Status stays open. Do not launch the web leg with the uncap flags.

The 19:14 web log, reprinted with `run_hub_bench.py --report`, is the drop she saw. It is not the eight 130–150 ms spikes the old summary printed. It is one sustained run: n=42, t=36.9–38.7, dt median 44.8 ms (about 22 FPS), cells 10,15 to 13,19, anim idle_right / start_right / loop_right / loop_down. 38 of those 42 rows have an empty why, and proc_ms repeats on 38 of them. Shape of that file: edge=29, stutter=51, spike=15. p95 41.6 ms is that run.

Logging now:

- Hitch rows carry phase, play_s, frame, refresh_n, phys_ms, proc_held, bench_gen. `gen` stays the hub node count.
- A paused stall is paused=1 and is not counted in frames, slow, or fps_pct. The menu-open frame is ev=gap.
- The summary prints the slow shape and up to three sustained runs (4 or more slow frames with no good frame between them).
- Bench marks also write ev=mark immediately, so a long frame names its last step. A web wait with no bench row says timed out or browser exited, and prints the sink tail.

Desktop `20261015-194431`: exit 0, sec 24.2, frames 2582, slow 17, pause_slow 1, fps_pct 99.3, worst 150. Read-back vsync=0, max_fps=120, refresh 60, paced=0, p50=p95=8.3. Shape edge=3 stutter=8 spike=6. The sustained runs there are the camp load (phase wait, play_s 0), not a walk. Window read-back was 1024x768.

Web, this worktree, three capped Edge runs (`--timeout-sec` 300, then 300, then 120): each timed out with the browser still open. The sink stayed at 4 rows: session bench_gen 0 (max_fps 0), session bench_gen 1 (max_fps 120), `HB: fresh=1`, and one boot hitch t=0.3 phase=wait refresh_n=9. No ev=mark. The stall is before the first HitchLog.mark, so it is in the title-to-hub load, not in a camp build step. Replacing PackedFloat32Array.duplicate did not move it. No web fps_pct this session.

---

Additional session notes from Vira: Looks like we still don't have the web benchmarking nailed down. Make that the goal of this session and don't worry about the actual performance issues.