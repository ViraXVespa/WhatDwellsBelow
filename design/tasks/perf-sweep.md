# Perf sweep - one continuous hub/dungeon run at 60+ FPS, desktop and web

id: perf-sweep
owner: build
status: open
done-when: On Vira's machine, the continuous sweep (cold load, hub walk, dungeon walk, dispel, hub walk, dungeon walk, exit) scores fps_pct >= 99 overall on desktop and on two consecutive cold web runs. Goal 100%. Docs and code-map updated if ownership or tunables changed.
resume: python tools/slice.py open debug.playtest --task perf-sweep

## Intent
One continuous run, no exits between states: cold game load, enter the hub, hub walk test, enter the dungeon (no exit), dungeon perf walkthrough, dispel when the dungeon timer ends (no exit), hub walkthrough again, enter the dungeon again, dungeon walkthrough again, then exit. fps_pct counts every frame where the hub or dungeon is showing and the loader bar is down, scored per segment and for the whole run. Goal: 100% of frames at 60+ FPS. Pass: 99% on both desktop and web (cold web window, as below). Replaces `hub-perf-fix` and `dungeon-perf` (merged 2026-10-31 at Vira's request so later states, return trips and the dispel path are covered).

## Next
The sweep runner is in. `python tools/perf.py sweep --leg desktop` and `--leg web` chain the hub walk, a dungeon playtest (seed 42, Great Axe, time scale 1, 30 s acting), dispel, the hub walk, the dungeon walk, then quit. `HB: seg=` is each stretch. The last `fps_pct` is the whole run. Hitch rows still carry `tree_ms`, `submit_ms`, `after_ms`, `pt_ms`.

Dungeon entry from the hub now uses `App.enter_dungeon` (the enter cover, the paint wait, then the scene change). Dispel plays the player's exit clip, then the recap camp handoff (`wake_pending`, `cover_wake`, `go_camp`). The dummy strike is one swing: attack releases once the swing starts, and the station waits until that swing ends. A held attack still chains at `axe_rate` (1.7/s) once the player is in the dungeon. That is the same rule as holding the attack button. Prove has been run on this path. `gd-load` and `build --batch` pass. The 99% bar passes on desktop and misses on both cold web runs.

Desktop sweep `20261103-010816` passes the 99% bar: fps_pct 99.3, frames 12930, sec 138.2, p50 8.3, p95 11.0, sustained none. Segments: hub1 99.7 (3145/10), dungeon1 98.5 (3180/48), hub2 99.7 (3214/10), dungeon2 99.3 (3391/24). Summary `_logs/perf-sweep/20261103-010816-perf-sweep.txt`.

One cold web sweep `20261103-011146` completes the chain (`ok=1`) and misses the bar: fps_pct 55.3, frames 3569, slow 1595, sec 169.9, p50 18.7, p95 83.3, paced 1, vsync 1, 1920x1080, Edge, `127.0.0.1:27135`, folder `_logs/perf-sweep-web-20261103-011149`. Segments: hub1 0.0 (332/332), dungeon1 66.6 (1427/477), hub2 0.0 (327/327), dungeon2 69.0 (1483/459). Both hub walks printed every facing, station, and the strike, so the 0% is the whole walk at about 11 fps, not a skipped sequence. Longest slow run n=98 at median 77.8 ms, `tree_med` 66.0, `submit_med` 5.2, `after_med` 5.6, `phys_med` 1.9, `draw_med` 78, `pt_med` 0, `why_empty` 77. A second run n=83 is the same split (`tree_med` 65.7, `submit_med` 5.1). The steady cost is `tree_ms`, not submit. This is not the old fill tail. One worst row can still show `submit_ms` several times `dt_ms`; ignore that row. No row names a system inside `tree_ms`. Do not hide floor, walls, sprites, props, the sun, the HUD, the environment, or the Label3Ds. Do not uncap. A second cold web of this same sweep was not run. Summary `_logs/perf-sweep/20261103-011146-perf-sweep.txt`. Report `_logs/perf-sweep-report/20261103-011632-perf-sweep-report.txt`.

The desktop and web numbers above used `begin_run` / `go_dungeon` in and `go_camp` out. They skipped the enter cover and the wake cover. Do not treat them as the loading-path reading.

Loading-path prove. Each run printed `HB: dungeon enter`, `HB: dispel`, `HB: camp`, a second hub walk (every facing, station, and `strike=dummy`), a second `HB: dungeon enter`, and `ok=1`.

Desktop `20261103-014806`: fps_pct 99.6, frames 13816, slow 59, sec 141.0, p50 8.3, p95 9.0, vsync 0, max_fps 120, 1920x1080, sustained none. Segments: hub1 99.7 (3221/10), dungeon1 99.3 (3719/25), hub2 99.7 (3226/10), dungeon2 99.6 (3650/14). Summary `_logs/perf-sweep/20261103-014806-perf-sweep.txt`.

Cold web `20261103-015125`: fps_pct 46.4, frames 3494, slow 1874, sec 172.3, p50 20.4, p95 86.4, paced 1, vsync 1, 1920x1080, Edge, `127.0.0.1:29722`, folder `_logs/perf-sweep-web-20261103-015128`. Segments: hub1 0.0 (318/318), dungeon1 53.6 (1436/666), hub2 0.0 (315/315), dungeon2 59.6 (1425/575). Longest slow run n=74 at median 81.0 ms, `tree_med` 67.9, `submit_med` 5.3, `after_med` 5.9, `phys_med` 2.0, `draw_med` 77, `pt_med` 0, `why_empty` 58. The next run in that sweep, n=70, is the same split (`tree_med` 69.2, `submit_med` 5.1). Summary `_logs/perf-sweep/20261103-015125-perf-sweep.txt`.

Cold web `20261103-015634`: fps_pct 50.1, frames 3525, slow 1759, sec 166.4, p50 19.6, p95 91.7, paced 1, vsync 1, 1920x1080, Edge, `127.0.0.1:31752`, folder `_logs/perf-sweep-web-20261103-015637`. Segments: hub1 0.0 (302/302), dungeon1 73.9 (1645/430), hub2 0.0 (312/312), dungeon2 43.5 (1266/715). Longest slow run n=67 at median 80.0 ms, `tree_med` 67.5, `submit_med` 5.7, `after_med` 7.0, `phys_med` 2.0, `draw_med` 75, `pt_med` 0, `why_empty` 53. The next run, n=66, is the same split (`tree_med` 74.5, `submit_med` 5.2). Summary `_logs/perf-sweep/20261103-015634-perf-sweep.txt`.

Both cold webs miss the bar. Both hub walks are 0%. The steady cost is still `tree_ms` on the hub strike and fill. No row names a system inside `tree_ms`. One worst row can show `submit_ms` several times `dt_ms`; ignore that row. Web exit printed `PagedAllocator` pages in use for `N16WorkerThreadPool5GroupE`. That is a quit line, not the fps miss. Do not hide floor, walls, sprites, props, the sun, the HUD, the environment, or the Label3Ds. Do not uncap.

Next edit is a bench-gated split of `tree_ms`, then a fix for the system that split names, then two consecutive cold `python tools/perf.py sweep --leg web` runs. Lighting stays a hypothesis until that row names it. Retry from this worktree: `grok -r 01a1a01c-624f-7321-97f4-942a766579a4 --fork-session`.

Reading runs: use `perf.py hub --report HITCH.jsonl` (about 2.3 KB) or the run's summary txt; do not open the raw hitch.jsonl (about 190 KB, 578 rows per 30 s desktop run).

## Hub: where it stood (from hub-perf-fix)
Desktop `20261016`, fullscreen 1920x1080: fps_pct 99.7 to 99.8, p50 and p95 8.3 ms. Not re-run since.

A cold web run is a new `_logs/hub-bench-web-<stamp>` on a free port, capped Edge, vsync on, 1920x1080, full 30 s sequence. Publishing again to `_logs/hub-bench-web` on port 8060 is warm: that origin is the service worker scope, and the shell keeps the worker when the build id matches. A wiped profile on that origin is still warm. `--guest` joins an Edge that is already open. Vira says the hub bake in `49fb157` did not touch performance and did not fix the hitch.

Same-origin scored runs on 2026-10-27 (the warm publish) sit at fps_pct 75.7 to 77.9, p50 about 17, p95 about 45, one fill of about 245 frames at median about 40 ms, cells along 8,15-12,15. On those fill rows `submit_ms` is about 39 to 47, `tree_ms` about 3 to 9, `after_ms` about 9 to 13, physics a few milliseconds, draw calls about 75. The fill cost is inside the draw. One worst row can show `submit_ms` several times `dt_ms`; ignore that row.

One scored run after the cold publish, `20261027-165026` at `127.0.0.1:10379`: fps_pct 97.9, frames 1589, slow 33, p50 16.7, p95 18.1, sustained none, worst 127.7 at cell 9,15 `idle_left`. That single run does not close the task and does not retire the fill tail.

`--fill-aba` times a normal fill, hides every tagged group for 3 s, then times the normal fill again. The one run was on the old origin and was discarded (`base` submit 4.6). Keep a layer time only when that same run's first fill submit stays near 40 ms. `--walk-layers` and `--fill-aba` do not score the bar.

Ground is the week-7 band planes. Uncapping is refused. A per-frame hitch-log scene walk latches the bench.

Two consecutive cold scored `python tools/perf.py hub --leg web` PASS runs close the task. The cold publish is now the default. If a cold run shows the fill tail again (submit near 40 ms), run `--fill-aba` and discard it unless the first fill submit stays near 40 ms. If cold runs stay near 98 with no sustained fill, the remaining miss is the isolated frames: cell 9,15 `idle_left` and the facing-start frames that miss one refresh. No hub-draw change until a cold run names the cost.

Do not spend a web leg on the light tap, a second path plane, `texture()` on `hub_light.png`, uncapping, a desktop rescore, a walk that skips the full sequence, or another publish to port 8060.

## Hub: notes from Vira
That hitching on web during that last walk phase looks like a similar issue I've seen happening on the web builds but wasn't able to track down or reproduce. I've gotten it to occur in other places in the hub and without attacking the dummy. That's something I'd really like to get out of the game ASAP. I don't know if the logging is failing to catch whatever's causing it, but do whatever you need to do to diagnose and solve that issue.

## Hub: known non-signals
Settled; do not re-investigate: hub FPS below dungeon FPS is this same web fill tail; the blocky/grainy ground is on main and not this task; vsync stays on (uncapping is refused).
- GLES quit leaks (N5GLES34MeshE / N5GLES37TextureE leaked at exit, and the raw Texture with GL ID / Buffer with GL ID leaked N bytes lines) are Compatibility-renderer artifacts on web exit. They are not the fail.
- Desktop hub-bench already clears the 99% bar (99.7-99.8%, p50/p95 8.3 ms).
- Web is refresh-paced (vsync=1 paced=1). The mid-70s fill tail was measured on the repeated 8060 publish. A wiped profile on that origin is warm. `--guest` is not a cold window.
- Do not open shader or mesh files because a quit-leak line named a texture or buffer.
- Attack does not clear the walk cache. ensure_loco and ensure_attack fill separate dictionaries and return once the key is present. The only clear is load_sprites at init.
- Preloading every facing in warmup (ensure_loco + ensure_attack, then apply_tex) did not move the web number. Still fps_pct 76.8.
- A warm Edge process, or the same folder on port 8060, can report a one-refresh fill. That is not the cold number the task measures.
- Chrome task-manager lines (fallback_task_provider) are Edge internals, not the fail.

## Dungeon: where it stood (from dungeon-perf)
Desktop 20261028-033831, fullscreen 1920x1080, vsync off, max_fps 120, gl_compatibility: fps_pct 99.6, frames 3483, sec 30.0, p50 8.3 ms, p95 8.3 ms, slow 14, worst 142.9 ms. Those spikes are first-use marks: light_plan with dungeon_show, light_lift, loco_walk face_right, loco_cycle. They are not the web steady cost. Do not rescore desktop unless a dungeon draw change lands. Web cold run 20261028-033953, Edge, 1920x1080, paced 1, vsync 1, refresh 60: fps_pct 0.9, frames 528, slow 523, sec 30.0, ok 1, p50 54.2 ms, p95 83.1 ms, worst 150 ms. Sustained play runs sit near 54 to 66 ms. On those runs tree_med is about 4 to 10 ms, submit_med about 35 ms, after_med about 13 to 16 ms, phys_med about 12 to 19 ms, draw calls about 48 to 70. A single worst row can show submit_ms several times dt_ms; ignore that row. Hitch rows left cell and anim empty on both legs.

The playtest node's `_physics_process` is now removed from the scored `dt` and from `after_ms`. It is not inside `submit_ms`: that tick finishes before idle `_process`, and the draw window is `frame_pre_draw` to `frame_post_draw`. Cold web run 20261028-041329 (same window, harness on): fps_pct 3.6, frames 587, slow 566, sec 30.0, ok 1, p50 48.5 ms, p95 66.5 ms, worst 149.6 ms, `pt_p50_ms` 0.5. Sustained play rows: submit_med 32.5 to 34.6, pt_med 0.6 to 2.0, one hitch at pt_ms 17.2. `phys_ms` on the row is still the whole physics frame, not the playtest node. The harness is not the submit cost and it is not the steady frame. That run also moved the bench `_process` later for one pass, so its tree_med near 0.4 and after_med near 25 are not the split to keep. The priority change was reverted. Keep the 20261028-033953 tree/after split, and keep 20261028-041329 for `pt_ms`, `submit_med`, and the scored p50.

Bare-split run 20261028-042812, `python tools/perf.py dungeon --leg web --walk-layers`, keep=1 (base submit 34.0 ms, n=39). Viewport at gather: 1920x1080, `scaling_3d_scale` 0.90 (one `dyn_res` step; `DYNRES_STEP` 0.1), msaa 0. Counts: floor 12, walls 12, sprites 42, props 46, lights 1, hud 10, env 1, rest 30, all `Label3D`. Submit medians: floor 31.5, walls 30.3, sprites 30.0, props 31.9, lights 34.2, hud 30.8, bare 30.4, noenv 30.1, linear 33.3, rest 32.2, empty 29.6, base2 30.3. `empty` hides every tagged group, clears the WorldEnvironment, and hides the Label3Ds. Draw calls fall from 51 on base to 18 on empty. Submit does not. Scale is stamped once, at gather, not on later windows.

Layer run 20261028-035545, `python tools/perf.py dungeon --leg web --walk-layers`, keep=1 (base submit 33.8 ms, n=39). Submit medians: floor 31.8, walls 31.2, sprites 31.6, props 32.5, lights 33.4, hud 31.7, bare 30.2, base2 31.0. Counts at gather: floor 12, walls 12, sprites 42, props 46, lights 1, hud 10. Hiding every tagged group drops submit by about 4 ms. No group is the steady cost. The `draw=` field on a layer line is one frame at report time, not a window median. base2 reported draw 7 on that single frame; do not read that as the meshes staying hidden. The submit medians are the reading.

Scale run 20261028-044236, `python tools/perf.py dungeon --leg web --walk-layers`, keep=1 (base submit 33.1 ms, n=42, scale 0.80). Counts at gather: viewport 1920x1080, scale 0.90, msaa 0. Auto then sat on 0.60 for `walls` through `empty`. Submit medians: empty 30.3 at scale 0.60 (draw 18), empty1 4.2 at scale 1.00 (n=115, p50 16.7), empty05 28.8 at scale 0.50. Pixel count went up at 1.0 and submit fell. The scaled blit is the steady cost. `base2` on that run stayed at scale 0.50 because the pin cleared the flag and left the viewport where Auto would not write again. That `base2` is discarded. The pin now sets the scale back to 1.0 when it lets go.

Scored web run 20261028-044706, after web Auto stopped dropping the scale: fps_pct 84.1, frames 1558, slow 248, sec 30.0, ok 1, p50 16.6 ms, p95 27.0 ms, worst 149.6 ms, paced 1, vsync 1, 1920x1080. Longest slow run n=29 at median 27.5 ms. One early cluster of 4 frames at play 0.0-0.6 has tree_med 498 ms. The worst rows are first-use marks (`loco_cycle`, `face_down_right`, `light_clear`, `face_up_right`, `loco_walk`). A submit on those rows can be several times `dt_ms`. Ignore that submit. No row names a steady system for the remaining frames between one refresh and about 27 ms.

Web Auto stays at scale 1.0. Do not turn the drop back on to chase the old 30 ms blit. Two consecutive cold `python tools/perf.py dungeon --leg web` PASS runs still close the task. The median is on refresh. The open miss is 248 of 1558 frames, p95 27 ms, longest run 29 frames at 27.5 ms. That run does not name the next edit. Do not hide floor, walls, sprites, props, the sun, the HUD, the environment, or the Label3Ds again. Do not uncap the browser, do not pass `--wdb-pt-fast`, do not treat `perf.py web` headless numbers as the FPS reading, and do not rescore the hub or the desktop leg. A manual render-scale pin of 0.8 or 0.6 still selects the slow blit on web. Do not put the bench node on a later `process_priority`.

## Handoff
Hub: Gather reset: `grok -r 01a17ec2-2017-75a0-9ed2-e148e542fe49 --fork-session` from this worktree. Do not re-gather. Latest measured session: `01a17f3a-7a84-7831-bd00-3d7a09599856`.

The draw split stays (`tree_ms`, `submit_ms`, `after_ms` on the hitch row, `submit` on a layer line). `gd-load` passed after the bench script edit. The scored bar is still red.

Dungeon: Gather reset: grok -r 01a18192-f080-76d0-b879-f3b5e46db230 --fork-session from this worktree. Do not re-gather. Latest measured session 01a181de-3c57-7490-854e-5ea1f67b591d. The runner is `python tools/perf.py dungeon`. Desktop PASS is summary `_logs/dungeon-bench/20261028-033831-dungeon-bench.txt`. First web FAIL is summary `_logs/dungeon-bench/20261028-033953-dungeon-bench.txt`. Layer keep is summary `_logs/dungeon-bench/20261028-035545-dungeon-bench.txt`. Harness web FAIL is summary `_logs/dungeon-bench/20261028-041329-dungeon-bench.txt`. Bare-split keep is summary `_logs/dungeon-bench/20261028-042812-dungeon-bench.txt`. Scale keep is summary `_logs/dungeon-bench/20261028-044236-dungeon-bench.txt`. Scored web after the Auto change is summary `_logs/dungeon-bench/20261028-044706-dungeon-bench.txt` (fps_pct 84.1). `--walk-layers` is web only, uses 50 s of acting, and does not score the 99% bar.

Note from Vira: We changed a bunch of lighting stuff with Grok Bot since you last worked on the perf stuff. That may have impacted things and those newer changes may need to be optimized.