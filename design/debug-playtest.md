# Playtest / AI player and journal

Status: current plan  
Read when: automated playtest or playtest journal  
Code: `scripts/debug/`  

## Automated Playtest / AI Player system

**Why this system is in the design database**
The Automated Playtest system is included so its recording, simulation, and recommendation hooks are designed into the same code the player already runs. That keeps programmatic impact low: playtest actors should drive existing input, combat, inventory, extraction, recap, and save flows rather than a second parallel simulation. MUST NOT invent a separate “AI game” with its own combat, loot, or progression implementations.

**Must-ship (Medium bar)**
The system MUST be able to:

- Run both the fresh-start save and the progressed save
- Collect **only** the capped telemetry set below
- Keep Great Axe, Lightning Staff, and Longbow roughly balanced
- Calculate per-variable impact coefficients from that set
- Offer three recommended configurations per save type (one most-ideal + two close alternatives) that the user can further edit before applying

**Capped telemetry set (non-exhaustive on purpose)**
Implement the following. MAY add a small number of closely related fields if a Medium-bar recommendation cannot be computed without them. MUST NOT add heatmaps, session replay, input recordings, per-frame combat traces, per-projectile logs, exploration pathing maps, quest-step traces, artifact-set timelines, or any other open-ended analytics product.

*A. Run outcome (one row per run)*

- End condition: extraction / death / “Dispel” / interrupted playtest
- Run duration
- Deepest floor reached
- Cycle index (which 5-floor loop)
- Starting weapon + tool type
- Character type (male / female)

*B. Success-criterion proxies*

- Time to first Extraction Gate interaction (`clerk_t`)
- Time to first successful extraction (fresh-start save only)
- Deaths / “Dispels” before first extraction (fresh-start)
- Recap XP-drain completed (bool)

*C. Combat load*

- Time in combat vs out of combat
- Near-death events (HP crossed a tunable threshold; default ~20%)
- Damage dealt / damage taken
- Kills
- Player deaths attributed to the implemented role / type name; Guardian and Gate Master MUST still be tagged separately
- Dash uses; special (LT) uses
- Adrenaline Rush activations and uptime
- Crits landed (count only)

*D. Weapon balance (required for Medium bar)*
Per weapon (Great Axe / Lightning Staff / Longbow), while that weapon was equipped:

- Time equipped
- Damage dealt
- Kills
- Deaths while equipped
- Specials used / specials that hit

*E. Gathering & economy (light)*

- Mining hits landed / successful reward rolls
- Woodcutting hits landed / successful reward rolls
- Time spent gathering
- Gold gained / gold extracted / gold lost on death
- Ore + wood extracted vs lost
- Ghost Shop purchases (count + gold spent)
- Forge actions this session (count only)

*F. Playtest meta*

- Save type: fresh-start vs progressed
- Exact debug-variable configuration snapshot / hash used for that run
- Human run vs Automated Playtest run

**Medium-bar shipping floor:** A–D + F, plus enough of E to detect whether gathering/economy is starving first-extraction. Impact coefficients and recommended configurations MUST be computed from this set.

**Full target** (still required if time/compute allows; Medium bar remains the mandatory early shipping floor for the *playtest runner itself*):

- Replicates natural human gameplay as closely as practical, allowing intentional sub-optimality.
- Selects different loadouts at the start of runs; deep in-run equipment swapping is not required.
- Uses two completely independent save files (never the player’s normal save):
  1. Fresh-start save – repeatedly cleared so every test begins clean.
  2. Progressed save – contains full progression in all eleven skills; can be reset to a fixed default progressed state.
- Weapon-aware: actively works to keep Great Axe, Lightning Staff, and Longbow balanced so no single weapon is clearly stronger.
- Records run history together with the exact variable configuration used.
- Ships with deduced baseline impact coefficients generated at build time; these are refined by real telemetry.
- Presents ideal values as fly-out information when a variable is highlighted: one ideal for the fresh-start save (tuned toward first-extraction goals) and one ideal for the progressed save (tuned toward later constraints).
- Supports accelerated, background, and headless runs. Unlimited queued runs; any run is interruptible without loss of already-collected telemetry.
- The entire system ships in the public demo but remains hidden behind the secret input sequence.

## Playtest journal (PC / Xbox debug only)

`scripts/debug/playtest_log.gd` writes one compact JSON per live Automated Playtest run.

- Path: `user://playtest/runs/`
  Windows: `%APPDATA%\Godot\app_userdata\What Dwells Below\playtest\runs`
- Name: `run_YYYYMMDD_HHMMSS_<save>_<weapon>.json`
- Envelope: `kind: wdb_playtest_journal`, `ver: 2`
- Not written on web (the journal is off there, and with `--wdb-pt-nolog` on desktop: no event building, no file or batch writes; telemetry and the web hook still report). Not part of the Medium-bar A–F telemetry set. Not an analytics product.

Purpose: let an agent reconstruct why the bot chose a goal and whether grid floor, `_dir_open`, and `test_move` disagreed. MUST NOT grow into heatmaps, session replay, input recordings, per-frame combat traces, per-projectile logs, or exploration pathing maps.

Events: `begin`, `wait`, `decide`, `step`, `act`, `beat`, `combat`, `end`.

- `decide` — goal, `why` / `why_raw`, `near` as `[kind, d, x, y]`, `clerk_d`, `gather_d`, path flags `pc` / `pg`
- `step` — cell, `cmd` (`e|w|n|s`), packed cards `g` / `o` / `p` (EWNS bitstrings), `mis` when they disagree. Identical cell+cmd+cards+goal rows coalesce (`n`, `t1`)
- `beat` is sparse (skipped when gold / kills / hp / goal are unchanged)
- `tel.cfg` is omitted; `cfg_hash` on `begin` is enough
- Root `end_cond` / `fail` come from the `end` event, not from an empty tel stamp

## Live driver rules (`playtest/playtest_api.gd`, `playtest/pt_gate.gd`)

- **Ready gate.** The AI acts only when the dungeon scene is ready, the player exists, the tree is not paused, no menu load is running and no enter/wake transition is playing. While gated it zeroes input, sets `ai_on` false and forces `Engine.time_scale` 1.0. Soft gates (paused / transition / loading / scene_not_ready) fail open after 15 s so a stuck overlay cannot stall a run; a hard gate (no dungeon / no player) for 90 s ends the run as `stalled`.
- **Clocks.** `sim_t` counts every tick; `act_t` counts only ticks where the AI acted. The run limit (`limit`, smoke 8 s) uses `act_t`, so load and gate time never eat the budget.
- **Speed.** Default is 1.0 for every run. Faster testing (up to 6x) is opt-in behind its own flag `--wdb-pt-fast` (URL `?wdb-pt-fast`): only then is the job `scale` (default queue `App.bal.playtest_scale`) applied, and only while acting; loads, recap and gates always run at 1.0, and smokes and the web hook stay at 1.0. The scale actually used is `time_scale` in the run telemetry. At scale S the physics delta is S/60, so 6x means 0.1 s ticks; do not take frame or load timings from a scaled run.
- **Think cadence.** `THINK_DT` 0.12 sim-seconds. `think` receives the sim-time since the previous think (not one physics tick), so the unstick, lock, flee and dash timers run in real seconds.
- **Decision cost.** Per-run `think_ms` (avg per think incl. journal), `think_max_ms`, `phys_ms` (whole playtest physics tick) plus `gate_s`, `gate_over`, `unstick_n`, `stuck_max` ride on the run row (`perf_report()`), print in `window.__wdbPlay`, and `web_perf.py` lists them under `play`. `playtest_los/los_cache.gd` keeps one per-physics-frame snapshot (grid, closed doors, gate/breakable/prop cells, foe list with distances, A* answers, `dir_open` per heading) so the dozens of steer/path/foe queries per think do not rescan groups; answers are identical to scanning.
- **Natural play** (`playtest_ai/ai_human.gd`, state `pt.hum`): reaction delay 0.18-0.34 s on first contact (0.06-0.14 s when switching foe; skipped when a foe is within 2.6), aim wobble (a new offset every 0.45 s, about 3 deg up close and 4 deg at range), strafe side kept at least 0.9 s (no flicker), dash away after a hit of at least 7% max HP with a foe within 3.2. Random draws use `pt.rng`, seeded from the run seed, never the global RNG. Same seed and same load alignment replay the same run (desktop: `--fixed-fps 60` removes frame-timing noise). Opt-in `--wdb-pt-repeat` (URL `?wdb-pt-repeat`) also reseeds the global RNG before every think from (run seed, think index), so enemy and crit rolls cannot drift apart between runs; without it runs stay random.
- **Live smoke.** `--wdb-playtest-live-smoke` (`playtest/live_smoke.gd`, routed by `smoke.gd`) boots straight into one live AI run and prints `PT:` lines (kills, crits, damage, end condition, perf, time_scale, stuck). Args: `--wdb-seed=N`, `--wdb-pt-weapon=great_axe|staff|longbow`, `--wdb-pt-sec=S` (sim seconds of acting), `--wdb-pt-scale=X` (needs `--wdb-pt-fast`). Watchdog quits with `PT: timeout=1`.
- **Hub bench.** `--wdb-hub-bench` (`playtest_bench/hub_bench.gd`, routed by `smoke.gd`) boots the title straight into Placeholdia and walks one pass of 30 s (after the stations, the end fill walks out and back on each facing until the play clock reaches 30 s): all eight facings with idle and walk, then Floor Crystal, Anvil, Vendor, the guild board, the receptionist, and one strike on the dummy. It drives `App.playtest` move / aim / interact / attack with `ai_on`, sets the camera zoom to 1.0 for the walk (pinned before the loader drops, so the settle frames are the measured view), puts the previous zoom back before quit, disables desktop vsync with `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)` (Compatibility honors Disabled; Adaptive and Mailbox do not) and sets `Engine.max_fps` to 120, and does not start a dungeon live run. Godot documents that vsync off with an unlimited framerate can peg the GPU, so the cap stays finite. 120 only pads faster frames; a frame slower than 16.7 ms is still slow. The web display server ignores that vsync call and the page stays on `requestAnimationFrame`. `--wdb-hitch-mult=N` (default 1 on this bench) calls `HitchLog.set_mult`; the bench replaces `user://hitch/hitch.jsonl` and keeps every row from that run (the usual 256 cap stays on for normal play). Lines are `HB:`, including `frames`, `slow`, and `fps_pct` (share of counted frames at or above 60 FPS; paused frames are not counted). A desktop frame with vsync actually off counts as slow when it is over the 16.7 ms budget. A refresh-paced frame (the web leg, or a desktop read-back that is still vsync on) counts as slow only when it is 3 ms over the longer of that budget and one screen refresh, so a 16 to 19 ms present is not a hitch. The bench row records the vsync read-back, `max_fps`, `refresh_hz`, `paced`, `renderer`, `dt_p50_ms`, `dt_p95_ms`, `pause_slow`, and the counted-frame shape (`n_edge`, `n_stutter`, `n_spike`, `slow_run_n`, `slow_run_med_ms`). A hitch row also carries `phase` (wait, face, goto, open, hold, gap, strike, fill, iso), `play_s` (the walk clock; `t` stays the session clock), `frame`, `refresh_n`, `phys_ms`, and `proc_held` when `TIME_PROCESS` repeated the previous frame. A stall while the tree is paused is written with `paused=1` and is not counted in `frames`, `slow`, or `fps_pct`. `fps_pct` is the whole time the player can see the hub: camp is the current scene and the loading bar is down. The bar is up when `loader.open` is set or the loader is visible. A frame before the hub is showing, including boot and every frame behind the bar, is written with `bar=1` and is not counted. Those are the only warmup frames. The first walk, the stations, and the rest of the visible hub are in the 99% bar. The frame that opens a menu is `ev=gap`, not a counted hitch. `bench_reset` bumps `bench_gen`, and the runner keeps only the newest generation, so a boot row posted before the reset cannot sit in front of the walk. (`gen` on a hitch row stays the hub generated-node count. Mesh and light totals are counted once per bench, and the display-server read-back is cached for half a second. A full stall row is built at most 10 times a second, plus any new worst, and web does not write that row to `user://` (the sink already has it). A scene walk, a display query, or a file write on every stall held the web present over one refresh for the rest of the walk.) Web `HB:` lines are `ev=hb` rows in that file, because the browser console does not reach the runner. While the bench is recording, each `HitchLog.mark` also writes an `ev=mark` row immediately, so a frame that has not finished still names the last step. On web those sink posts are queued and sent about twice a second, and again with the bench row, so a slow frame does not run a JavaScript call. A web wait that never sees the bench row prints the sink tail and says whether the browser exited or the wait timed out. The summary prints the slow shape and the longest run of slow frames that are not broken by a good frame, so a sustained drop shows up even when it is milder than the worst spike. `--report JSONL` reprints that summary and does not launch a walk. The `HB:` begin line prints that read-back, not a fixed `vsync=0`. `python tools/run_hub_bench.py` runs two walks. The desktop leg opens a gl_compatibility window so the frame time includes the present path, and it points that process at an empty `_logs/hub-bench-fresh` AppData so there is no save and no shader cache. It does not read or delete the real user save. A launch that still sees `user://live/save.json` quits. The web leg exports a local build and opens it in a visible fullscreen Edge window (Chrome if Edge is not installed; `--browser` forces one), with device scale 1 so the adaptive canvas is the screen and not a 1280x720 window. That window is not headless. It keeps the browser frame cap and GPU vsync. Edge's starter process often exits after handing the window off; the runner waits for the bench row, not for that starter. Do not pass `--disable-frame-rate-limit` or `--disable-gpu-vsync`. Chromium treats `--disable-frame-rate-limit` as also disabling GPU vsync, which removes present back-pressure on the real GPU. The runner refuses those flags. `--headless` on the desktop leg is not an FPS reading. `--isolate` with `--leg web` (URL `wdb-hub-isolate`) stands at the dummy after the loader drops and prints one `HB: isolate layer=` line per hidden group: fence, ground, buildings, sprites, light marks, the HUD, and all of those together. That run does not score the 99% bar. A leg passes the FPS bar when `fps_pct` is at least 99. The bench node is added on `App` at start, so the 45 s load wait runs before camp exists and a scene change does not free it. While it is still waiting it posts `HB: wait` every 2 s. At 45 s it posts `missing=stall`, a bench row, and quits, so a load that never reaches the walk is a finished leg rather than a silent browser. Load steps post `ev=mark` as they start (`load_play`, `load_paint`, `preload_<file>`, `load_camp`, `camp_enter`, `camp_layout`, then the camp build marks). Web exports have no threads: `UiWarm.start` does not call `load_threaded_request` there, because `load_threaded_get` spins while that status stays in progress, and `wait` loads the progress panel with `ResourceLoader.load`. The web leg also passes `--enable-logging` and prints console lines. That flag does not uncap the frame rate or turn GPU vsync off.

## Web perf hook (opt-in URL args)

`scripts/debug/cli_args.gd` also reads URL params that start with `wdb-` on web (`?wdb-seed=42` reads as `--wdb-seed=42`). `AppRun.begin_run` reads it with `CliArgs.int_arg("--wdb-seed", 0)` (not `seed_arg`, which maps 0 to 1) and, when positive, uses it as the run seed and seeds the global RNG; without the param the seed stays `randi()`. `?wdb-playtest` makes `scripts/debug/web_hook.gd` register `window.wdbPlaytest(sec)` and `window.wdbEnter()` (the player's own dungeon entry with cover and reveal; web_perf flow `dungeon-arrive`) and `window.wdbZoom(z)` (camera zoom; flow `camp-zoom` shoots the hub ground at zoom 1, 2 and 4). `wdbPlaytest` enqueues one fresh Great Axe live run at real time (`scale` 1) through the playtester above; the finished run's telemetry (plus `stuck_t`) lands in `window.__wdbPlay`; `web_perf.py` marks a run INVALID when it ends early, makes no kills, is stuck (`stuck_t`, or `stuck_max` over 6 s), has a gate that never opened, runs at a time scale other than 1.0, stalls or logs console errors. `tools/web_perf.py` flow `dungeon-fight` uses both. Normal URLs register nothing.

## Known non-fatal signals (hub-bench)
- `code_map.py row hub_bench` matches the stem (map lists `hub_bench.gd`).
- Web exit may print 3 Mesh + 1 Texture GLES RID leaks (`N5GLES34MeshE`, `N5GLES37TextureE`). These are Compatibility-renderer quit artifacts and do not fail the bench when `fps_pct >= 99` and no other ERROR lines are present.
