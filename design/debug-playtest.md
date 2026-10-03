# Playtest / AI player and journal

Status: binding design  
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
- **Natural play** (`playtest_ai/ai_human.gd`, state `pt.hum`): reaction delay 0.18-0.34 s on first contact (0.06-0.14 s when switching foe; skipped when a foe is within 2.6), aim wobble (a new offset every 0.45 s, about 3 deg up close and 4 deg at range), strafe side kept at least 0.9 s (no flicker), dash away after a hit of at least 7% max HP with a foe within 3.2. Random draws use `pt.rng`, seeded from the run seed, never the global RNG. Same seed and same load alignment replay the same run (desktop: `--fixed-fps 60` removes frame-timing noise).
- **Live smoke.** `--wdb-playtest-live-smoke` (`playtest/live_smoke.gd`, routed by `smoke.gd`) boots straight into one live AI run and prints `PT:` lines (kills, crits, damage, end condition, perf, time_scale, stuck). Args: `--wdb-seed=N`, `--wdb-pt-weapon=great_axe|staff|longbow`, `--wdb-pt-sec=S` (sim seconds of acting), `--wdb-pt-scale=X` (needs `--wdb-pt-fast`). Watchdog quits with `PT: timeout=1`.

## Web perf hook (opt-in URL args)

`scripts/debug/cli_args.gd` also reads URL params that start with `wdb-` on web (`?wdb-seed=42` reads as `--wdb-seed=42`). `AppRun.begin_run` reads it with `CliArgs.int_arg("--wdb-seed", 0)` (not `seed_arg`, which maps 0 to 1) and, when positive, uses it as the run seed and seeds the global RNG; without the param the seed stays `randi()`. `?wdb-playtest` makes `scripts/debug/web_hook.gd` register `window.wdbPlaytest(sec)`, which enqueues one fresh Great Axe live run at real time (`scale` 1) through the playtester above; the finished run's telemetry (plus `stuck_t`) lands in `window.__wdbPlay`; `web_perf.py` marks a run INVALID when it ends early, makes no kills, is stuck (`stuck_t`, or `stuck_max` over 6 s), has a gate that never opened, runs at a time scale other than 1.0, stalls or logs console errors. `tools/web_perf.py` flow `dungeon-fight` uses both. Normal URLs register nothing.
