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
- **Decision cost.** Per-run `think_ms` (avg per think incl. journal), `think_max_ms`, `phys_ms` (whole playtest physics tick) plus `gate_s`, `gate_over`, `unstick_n`, `stuck_max` ride on the run row (`perf_report()`), print in `window.__wdbPlay`, and `perf.py web` lists them under `play`. `playtest_los/los_cache.gd` keeps one per-physics-frame snapshot (grid, closed doors, gate/breakable/prop cells, foe list with distances, A* answers, `dir_open` per heading) so the dozens of steer/path/foe queries per think do not rescan groups; answers are identical to scanning.
- **Natural play** (`playtest_ai/ai_human.gd`, state `pt.hum`): reaction delay 0.18-0.34 s on first contact (0.06-0.14 s when switching foe; skipped when a foe is within 2.6), aim wobble (a new offset every 0.45 s, about 3 deg up close and 4 deg at range), strafe side kept at least 0.9 s (no flicker), dash away after a hit of at least 7% max HP with a foe within 3.2. Random draws use `pt.rng`, seeded from the run seed, never the global RNG. Same seed and same load alignment replay the same run (desktop: `--fixed-fps 60` removes frame-timing noise). Opt-in `--wdb-pt-repeat` (URL `?wdb-pt-repeat`) also reseeds the global RNG before every think from (run seed, think index), so enemy and crit rolls cannot drift apart between runs; without it runs stay random.
- **Live smoke.** `--wdb-playtest-live-smoke` (`playtest/live_smoke.gd`, routed by `smoke.gd`) boots straight into one live AI run and prints `PT:` lines (kills, crits, damage, end condition, perf, time_scale, stuck). Args: `--wdb-seed=N`, `--wdb-pt-weapon=great_axe|staff|longbow`, `--wdb-pt-sec=S` (sim seconds of acting), `--wdb-pt-scale=X` (needs `--wdb-pt-fast`). Watchdog quits with `PT: timeout=1`. `--wdb-pt-campaign` uses that same boot and the same args, on the campaign slot: one job at a time, and a time-limit end enqueues the next weapon. It does not quit after the first `PT:` report. Interrupt, a stall, or the watchdog stops the series. Phase 7 does not pass this flag. It checks two preps and the lag pick without a dive.
- **Hub bench.** `--wdb-hub-bench` (`playtest_bench/hub_bench.gd`, routed by `smoke.gd`) boots the title straight into Placeholdia and walks one pass of 30 s (after the stations, the end fill walks out and back on each facing until the play clock reaches 30 s): all eight facings with idle and walk, then Floor Crystal, Anvil, Vendor, the guild board, the receptionist, and one strike on the dummy. It drives `App.playtest` move / aim / interact / attack with `ai_on`, sets the camera zoom to 1.0 for the walk (pinned before the loader drops, so the settle frames are the measured view), puts the previous zoom back before quit, disables desktop vsync with `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)` (Compatibility honors Disabled; Adaptive and Mailbox do not) and sets `Engine.max_fps` to 120, and does not start a dungeon live run. Godot documents that vsync off with an unlimited framerate can peg the GPU, so the cap stays finite. 120 only pads faster frames; a frame slower than 16.7 ms is still slow. The web display server ignores that vsync call and the page stays on `requestAnimationFrame`. `--wdb-hitch-mult=N` (default 1 on this bench) calls `HitchLog.set_mult`; the bench replaces `user://hitch/hitch.jsonl` and keeps every row from that run (the usual 256 cap stays on for normal play). Lines are `HB:`, including `frames`, `slow`, and `fps_pct` (share of counted frames at or above 60 FPS; paused frames are not counted). A desktop frame with vsync actually off counts as slow when it is over the 16.7 ms budget. A refresh-paced frame (the web leg, or a desktop read-back that is still vsync on) counts as slow only when it is 3 ms over the longer of that budget and one screen refresh, so a 16 to 19 ms present is not a hitch. The bench row records the vsync read-back, `max_fps`, `refresh_hz`, `paced`, `renderer`, `dt_p50_ms`, `dt_p95_ms`, `pause_slow`, and the counted-frame shape (`n_edge`, `n_stutter`, `n_spike`, `slow_run_n`, `slow_run_med_ms`). A hitch row also carries `phase` (wait, face, goto, open, hold, gap, strike, fill, iso), `play_s` (the walk clock; `t` stays the session clock), `frame`, `refresh_n`, `phys_ms`, and `proc_held` when `TIME_PROCESS` repeated the previous frame. The hub bench also stamps `tree_ms` (that frame's `_process` start until `frame_pre_draw`), `submit_ms` (`frame_pre_draw` until `frame_post_draw`), and `after_ms` (that `frame_post_draw` until the next `_process`). The row is written on the next process, so those three belong to the frame `dt_ms` just closed and should add up to it. Viewport render-time queries are not on the row. A stall while the tree is paused is written with `paused=1` and is not counted in `frames`, `slow`, or `fps_pct`. `fps_pct` is the whole time the player can see the hub: camp is the current scene and the loading bar is down. The bar is up when `loader.open` is set or the loader is visible. A frame before the hub is showing, including boot and every frame behind the bar, is written with `bar=1` and is not counted. Those are the only warmup frames. The first walk, the stations, and the rest of the visible hub are in the 99% bar. The frame that opens a menu is `ev=gap`, not a counted hitch. `bench_reset` bumps `bench_gen`, and the runner keeps only the newest generation, so a boot row posted before the reset cannot sit in front of the walk. (`gen` on a hitch row stays the hub generated-node count. Mesh and light totals are counted once per bench, and the display-server read-back is cached for half a second. A full stall row is built at most 10 times a second, plus any new worst, and web does not write that row to `user://` (the sink already has it). A scene walk, a display query, or a file write on every stall held the web present over one refresh for the rest of the walk.) Web `HB:` lines are `ev=hb` rows in that file, because the browser console does not reach the runner. While the bench is recording, each `HitchLog.mark` also writes an `ev=mark` row immediately, so a frame that has not finished still names the last step. On web those sink posts are queued and sent about twice a second, and again with the bench row, so a slow frame does not run a JavaScript call. A web wait that never sees the bench row prints the sink tail and says whether the browser exited or the wait timed out. The summary prints the slow shape and the longest run of slow frames that are not broken by a good frame, so a sustained drop shows up even when it is milder than the worst spike. `--report JSONL` reprints that summary and does not launch a walk. The `HB:` begin line prints that read-back, not a fixed `vsync=0`. `python tools/perf.py hub` runs two walks. The desktop leg opens a gl_compatibility window so the frame time includes the present path, and it points that process at an empty `_logs/hub-bench-fresh` AppData so there is no save and no shader cache. It does not read or delete the real user save. A launch that still sees `user://live/save.json` quits. The web leg exports a local build and opens it in a visible fullscreen Edge window (Chrome if Edge is not installed; `--browser` forces one), with device scale 1 so the adaptive canvas is the screen and not a 1280x720 window. That window is not headless. It keeps the browser frame cap and GPU vsync. Edge's starter process often exits after handing the window off; the runner waits for the bench row, not for that starter. Do not pass `--disable-frame-rate-limit` or `--disable-gpu-vsync`. The launch is not `--guest`: a guest window joins an Edge that is already open and loads from that process's cache. Before the window, the leg deletes `D3DSCache` and the NVIDIA GL/DX shader caches under LocalAppData, and the browser starts with `--disable-gpu-shader-disk-cache`. A wiped `--user-data-dir` alone is still a warm GPU. Each run exports into a new `_logs/hub-bench-web-<stamp>` and binds a free port. The old fixed folder on port 8060 is the service worker's scope, and the shell keeps that cache when the build id matches. Chromium treats `--disable-frame-rate-limit` as also disabling GPU vsync, which removes present back-pressure on the real GPU. The runner refuses those flags. `--headless` on the desktop leg is not an FPS reading. `--layers` (old name `--isolate`) with `--leg web` (URL `wdb-hub-isolate`) stands at the dummy after the loader drops and prints one `HB: isolate layer=` line per hidden group: fence, ground, buildings, sprites, light marks, the HUD, and all of those together. That run does not score the 99% bar. `--walk-layers` (URL `wdb-hub-walk-layers`) runs the full bench first (facings, stations, and the strike), then during the fill walk times each hidden group on that same line, including that layer's `submit` median, and times `base` again at the end. It gathers the groups once, when the fill starts. It does not score the 99% bar. `--fill-aba` (URL `wdb-hub-fill-aba`) is that same full walk. During the fill it times a normal window (`base`), hides every tagged group for 3 s (`bare`), then times the normal fill again (`base2`). Keep that reading only when `base` submit stays near 40 ms. It does not score the 99% bar. A leg passes the FPS bar when `fps_pct` is at least 99. The bench node is added on `App` at start, so the 45 s load wait runs before camp exists and a scene change does not free it. While it is still waiting it posts `HB: wait` every 2 s. At 45 s it posts `missing=stall`, a bench row, and quits, so a load that never reaches the walk is a finished leg rather than a silent browser. Load steps post `ev=mark` as they start (`load_play`, `load_paint`, `preload_<file>`, `load_camp`, `camp_enter`, `camp_layout`, then the camp build marks). Web exports have no threads: `UiWarm.start` does not call `load_threaded_request` there, because `load_threaded_get` spins while that status stays in progress, and `wait` loads the progress panel with `ResourceLoader.load`. The web leg also passes `--enable-logging` and prints console lines. That flag does not uncap the frame rate or turn GPU vsync off.

## Web perf hook (opt-in URL args)

`scripts/app/cli_args.gd` also reads URL params that start with `wdb-` on web (`?wdb-seed=42` reads as `--wdb-seed=42`). `AppRun.begin_run` reads it with `CliArgs.int_arg("--wdb-seed", 0)` (not `seed_arg`, which maps 0 to 1) and, when positive, uses it as the run seed and seeds the global RNG; without the param the seed stays `randi()`. `?wdb-playtest` makes `scripts/debug/web_hook.gd` register `window.wdbPlaytest(sec)` and `window.wdbEnter()` (the player's own dungeon entry with cover and reveal; web_perf flow `dungeon-arrive`) and `window.wdbZoom(z)` (camera zoom; flow `camp-zoom` shoots the hub ground at zoom 1, 2 and 4). `wdbPlaytest` enqueues one fresh Great Axe live run at real time (`scale` 1) through the playtester above; the finished run's telemetry (plus `stuck_t`) lands in `window.__wdbPlay`; `perf.py web` marks a run INVALID when it ends early, makes no kills, is stuck (`stuck_t`, or `stuck_max` over 6 s), has a gate that never opened, runs at a time scale other than 1.0, stalls or logs console errors. `tools/perf.py web` flow `dungeon-fight` uses both. Normal URLs register nothing.

## Local run store

Debug desktop builds append one JSON object per line under `user://playtest/db/` (Windows: `%APPDATA%\Godot\app_userdata\What Dwells Below\playtest\db`). Web and release builds skip the write. The game does not link SQLite. `scripts/debug/playtest_db.gd` owns the spool.

Files: `runs.jsonl`, `decisions.jsonl`, `weapon_band.json`. `curve.sqlite` is written only by `perf.py curve --sqlite`.

A human finish (`finish_end` on extract, death, or dispel, when the run is not a playtest) appends a run row and does not write decisions. A bot `finish_job` appends a run row, updates `weapon_band.json` from that row, and, when the journal is on, appends the journal events already coalesced, each tagged with `run_id`. `--wdb-pt-nolog` and web skip the journal, so they skip decision rows. These spool rows do not enter `history.json` or `coefs.json`. `fresh` and `progressed` keep wiping and restamping for recommendations.

Each run line carries the existing telemetry fields plus `run_id`, `seed`, `save_kind` (`human`, `fresh`, `progressed`, `campaign`), eleven `skill_lv` values (`axe`, `staff`, `bow`, `str`, `mag`, `rng`, `def`, `hp`, `mine`, `wood`, `smith`), equipped pieces (`slot`, `type`, `ilvl`, `rarity`, affix `id` and `v`), `floors`, `changes`, `kill_delta`, and `death_delta` when a killing hit carried an enemy level.

`floors` closes a bucket when `App.floor_n` changes. Each bucket is `n`, `dt`, `dmg_taken`, `deaths`, `near_death`. A death or dispel increments `deaths` on the floor that was open when the run ended.

`changes` records a `skill_lv` crossing from `add_run_xp` or `add_perm_xp`, and an equipped-piece change from `equip_uid`, at the call that changes the value. `phase` is `run` while `App.in_dungeon` is set, otherwise `hub`. A hub equip that belongs on the next run is performed after that run's telemetry `reset`, while the scene is still the hub, so the crossing lands on the new row with phase `hub`.

`kill_delta` counts kills by `enemy.combat_lv - player.combat_lv`. `death_delta` is that same subtraction for the hit that killed the player, and only when that hit carried `combat_lv` (the strike in `enemy_atk.gd`). A hit that does not carry a level clears the stored level, so a killing blow without one leaves `death_delta` off the row. Dispel with no enemy leaves it off the row.

`weapon_band.json` keeps, per weapon id and that weapon's item level, `runs`, `deaths`, `duration`, and `dmg_taken` summed from bot rows. `death` and `dispel` count as a death.

## Curve

`python tools/perf.py curve` reads the spool and `curve.sqlite` when that file exists. It prints four slices, then the level-gap histogram. Slice numbers are runs, death rate, mean duration, and mean damage taken. Death rate counts `death` and `dispel`.

- Floor and cycle, one observation per floor bucket (`dt`, that bucket's damage, a death when the bucket's `deaths` is above zero).
- Weapon skill `axe` / `staff` / `bow` by that weapon's item level. The skill is the worn weapon (`great_axe`, `staff`, `longbow`).
- Weapon by floor and weapon item level, from the floor buckets.
- Each combat affix id by that piece's item level. The same affix on two pieces counts in each piece's band. Tool affixes stay out of this slice.

The level-gap block sums `kill_delta` and counts runs by `death_delta`. That histogram, with the weapon slices, is how a series shows whether the three weapons stay even (`feel.md`).

`--dir` selects the folder. The default is the AppData `user://playtest/db` path. `--sqlite` imports the spool into `curve.sqlite` beside it and, only after that commit succeeds, deletes `runs.jsonl` and `decisions.jsonl`. `weapon_band.json` stays. A failed import leaves the spool. A second import of a new spool adds those rows and deletes the new spool. `--cleanup`, and a successful `--sqlite`, drop decision rows whose `wall` unix time is older than `--keep-days` (default 30) and VACUUM. Run rows stay, so the four slices and the histogram stay. The tool refuses `--sqlite` and `--cleanup` when `--dir` is inside the repo.

## Campaign slot

One slot, `user://playtest/campaign`, primary plus backup, same rules as the fresh and progressed playtest slots. The first start creates a fresh delver and saves it. Later starts load it and do not wipe or restamp it.

One save wears one weapon at a time. After each run that was not interrupted, the next weapon is the one furthest behind on death rate, duration, and damage taken at the shared item level (the lowest current item level among the three weapons' best owned piece, or the starter). A non-white piece in the weapon slot, the bag, the bank, or the weapon holds counts as owned. A weapon with no runs at that level is furthest behind. Otherwise each mean is divided by the max of the three and the three terms are added with equal weight. A tie prefers fewer runs, then Great Axe, then Staff, then Longbow. If that level has no rows, use the previous item level. If none exist, seed Great Axe, then Staff, then Longbow until each has one run. Choose the weapon before the hub forge. The next dive uses it even if the forge raises its item level. Armor stays worn.

The debug menu playtest page starts that loop with one campaign job. `--wdb-pt-campaign` does the same from boot. `finish_job` saves the slot, then enqueues the next job when the run was not a user interrupt and did not stall. A run that ends because it reached its time limit still chains. The follow job keeps the tool, gender, scale, and limit. `begin_run_loadout` equips the best weapon hold of the chosen type (highest item level, then higher affix sum), or the starter when that type has no hold. Armor `hold_pick` is left alone. This unit does not forge. Campaign rows are not appended to `pt.history`. `--wdb-pt-fast` applies only while the dungeon AI is acting. Recap and the hub pass stay at time scale 1.0.

## Hub pass

After recap, before the next campaign job, call the real analyze, pay, forge, and equip functions. Do not stamp items and do not open anvil screens. Analyze every legal AT RISK green and blue. For the chosen weapon type, the tool, and head, body, and legs: quantity one, zero locks, blue when that type and rarity is analyzed and affordable, else green. Forge the highest analyzed item level `can_pay` accepts only when that item level is above the worn piece, or it is equal and a book-peak affix (combat on gear, tool affixes on the tool) is above the worn value. After the roll, equip only when the score beats the worn piece. Score is item level, then the sum of combat affix values. Tools use tool affix values. A weaker roll stays in the results and is not equipped. Save the campaign slot, then enqueue the next job.

## Known non-fatal signals (hub-bench)
- `docs.py code-map row hub_bench` matches the stem (map lists `hub_bench.gd`).
- Web exit may print 3 Mesh + 1 Texture GLES RID leaks (`N5GLES34MeshE`, `N5GLES37TextureE`). These are Compatibility-renderer quit artifacts and do not fail the bench when `fps_pct >= 99` and no other ERROR lines are present.
