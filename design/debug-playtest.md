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
- The system lives in `scripts/debug/` behind the secret input sequence. Release presets (`Web` for the public Pages demo, `Linux`) exclude `scripts/debug/*`, so it ships only in debug exports (`Web Debug`, `Linux Debug`) and the editor (debug door, Release vs debug builds).

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

- **Ready gate.** The AI acts only when the dungeon scene is ready, the player exists, the tree is not paused, no menu load is running and no enter/wake transition is playing. While gated it zeroes input, sets `ai_on` false and forces `Engine.time_scale` 1.0. Soft gates (paused / transition / loading / scene_not_ready) fail open after 15 s so a stuck overlay cannot stall a run; a hard gate (no dungeon / no player) for 90 s ends the run as `stalled`. While a campaign job is waiting for the hub to finish building, that same 90 s ends the series as stalled (`no_camp`).
- **Clocks.** `sim_t` counts every tick; `act_t` counts only ticks where the AI acted. The run limit (`limit`, smoke 8 s) uses `act_t`, so load and gate time never eat the budget. A campaign slot ignores that limit.
- **Speed.** Default is 1.0 for every run. Faster testing (up to 6x) is opt-in behind its own flag `--wdb-pt-fast` (URL `?wdb-pt-fast`): only then is the job `scale` (default queue `App.bal.playtest_scale`) applied, and only while acting; loads, recap and gates always run at 1.0, and smokes and the web hook stay at 1.0. The scale actually used is `time_scale` in the run telemetry. At scale S the physics delta is S/60, so 6x means 0.1 s ticks; do not take frame or load timings from a scaled run.
- **Think cadence.** `THINK_DT` 0.12 sim-seconds. `think` receives the sim-time since the previous think (not one physics tick), so the unstick, lock, flee and dash timers run in real seconds.
- **Decision cost.** Per-run `think_ms` (avg per think incl. journal), `think_max_ms`, `phys_ms` (whole playtest physics tick) plus `gate_s`, `gate_over`, `unstick_n`, `stuck_max` ride on the run row (`perf_report()`), print in `window.__wdbPlay`, and `perf.py web` lists them under `play`. `playtest_los/los_cache.gd` keeps one per-physics-frame snapshot (grid, closed doors, gate/breakable/prop cells, foe list with distances, A* answers, `dir_open` per heading) so the dozens of steer/path/foe queries per think do not rescan groups; answers are identical to scanning.
- **Natural play** (`playtest_ai/ai_human.gd`, state `pt.hum`): reaction delay 0.18-0.34 s on first contact (0.06-0.14 s when switching foe; skipped when a foe is within 2.6), aim wobble (a new offset every 0.45 s, about 3 deg up close and 4 deg at range), strafe side kept at least 0.9 s (no flicker), dash away after a hit of at least 7% max HP with a foe within 3.2. Random draws use `pt.rng`, seeded from the run seed, never the global RNG. Same seed and same load alignment replay the same run (desktop: `--fixed-fps 60` removes frame-timing noise). Opt-in `--wdb-pt-repeat` (URL `?wdb-pt-repeat`) also reseeds the global RNG before every think from (run seed, think index), so enemy and crit rolls cannot drift apart between runs; without it runs stay random.
- **Live smoke.** `--wdb-playtest-live-smoke` (`playtest/live_smoke.gd`, routed by `smoke.gd`) boots straight into one live AI run and prints `PT:` lines (kills, crits, damage, end condition, perf, time_scale, stuck). Args: `--wdb-seed=N`, `--wdb-pt-weapon=great_axe|staff|longbow`, `--wdb-pt-sec=S` (sim seconds of acting), `--wdb-pt-scale=X` (needs `--wdb-pt-fast`). Watchdog quits with `PT: timeout=1`. `--wdb-pt-campaign` uses that same boot on the campaign slot: one job at a time. It does not end a dive when acting time reaches `--wdb-pt-sec` or `playtest_limit`, and it does not arm the process quit timer. A dive ends on death, extraction, dispel, or a floor-5 clear, then the hub pass starts the next dive. It does not quit after the first `PT:` report. Interrupt or a stall stops the series. The series also stops when Great Axe, Staff, and Longbow have each cleared floor 5. `--wdb-pt-gather=N` stops it after this process has saved at least N decide rows, on the dive that crosses that count, and the slot is saved first. `--wdb-pt-until-death` stops it when a dive ends in death, after the slot is saved. Extraction still starts the next dive. Both flags are off unless passed. Phase 7 does not pass this flag. It checks two preps, the lag pick, the floor-5 clear record, `Campaign.dive_floor()`, and that a campaign job ignores the acting-time limit, without a dive.
- **Benches.** Hub bench, dungeon bench, the perf sweep, the web perf hook and the hub-bench non-fatal signals are the debug.bench job (`debug-bench.md`). They drive the same playtest node.

## Local run store

Debug desktop builds append one JSON object per line under `user://playtest/db/` (Windows: `%APPDATA%\Godot\app_userdata\What Dwells Below\playtest\db`). Web and release builds skip the write. The game does not link SQLite. `scripts/debug/playtest_db.gd` owns the spool.

Files: `runs.jsonl`, `decisions.jsonl`, `weapon_band.json`. `curve.sqlite` is written only by `perf.py curve --sqlite`.

A human finish (`finish_end` on extract, death, or dispel, when the run is not a playtest) appends a run row and does not write decisions. `--wdb-pt-human-log` is the exception: while the player moves in a dungeon it appends decide rows with `source` human. The flag is off unless it is passed. A bot `finish_job` appends a run row, updates `weapon_band.json` from that row, and, when the journal is on, appends the journal events already coalesced, each tagged with `run_id`. `--wdb-pt-nolog` and web skip the journal, so they skip decision rows. These spool rows do not enter `history.json` or `coefs.json`. `fresh` and `progressed` keep wiping and restamping for recommendations.

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

On a campaign job, once nothing closer needs a swing, the walker paths to the living guardian and opens doors on the way. Locked stairs are not a usable prop. If it stays on the same cell, it sidesteps and then resumes. After the guardian dies it takes those stairs. Two presses descend, the same confirm the player uses. A learned wander does not replace that step while a living guardian or the floor stairs exist. The press uses the chosen prop when it is inside the interact radius or that prop's own reach.

A floor-5 clear is `App.floor_n` above 5, or floor 5 with the Gate Master dead. Reaching floor 6 counts, because the stairs stay locked until that boss dies. Later cycles are not required. The clear is stored per weapon in `user://playtest/campaign/floor5.json` (not in the player save). A fresh campaign slot deletes that file. An existing slot keeps it.

The debug menu playtest page starts that loop with one campaign job. `--wdb-pt-campaign` does the same from boot. A campaign dive does not end because acting time reached its limit, and a time limit does not chain the next weapon. Death, extraction, dispel, and a floor-5 clear return to the hub. On a floor-5 clear the dive extracts at the gate so the series can switch weapons. `finish_job` saves the slot. It enqueues the next job only when the run was not a user interrupt, did not stall, did not end in death while `--wdb-pt-until-death` is set, did not cross a `--wdb-pt-gather=N` row budget, and a weapon still has not cleared floor 5. The next weapon is the furthest-behind pick among weapons that have not cleared. If that pick has already cleared, the next is Great Axe, then Staff, then Longbow among the rest. When all three have cleared, the series stops. The follow job keeps the tool, gender, and scale. `begin_run_loadout` equips the best weapon hold of the chosen type (highest item level, then higher affix sum), or the starter when that type has no hold. Armor `hold_pick` is left alone. Campaign rows are not appended to `pt.history`. `--wdb-pt-fast` applies only while the dungeon AI is acting. Recap and the hub pass stay at time scale 1.0.

## Hub pass

After recap the series loads the hub and calls the real analyze, pay, forge, and equip functions. Do not stamp items and do not open anvil or vendor screens. Then buy potions and food the way the vendor does (`hold_potion`, `give_food`, `shop_spend`) while bank gold covers `vendor_potion_cost` and `vendor_food_cost` and the hold accepts the item. A new food that `needs_toss` is skipped. The dive starts at `Campaign.dive_floor()` (one floor below the campaign save's deepest floor, never below floor 1) through the hub crystal's enter (loadout write and deferred `enter_dungeon`), not `begin_run`. A fresh delver whose deepest floor is 1 still starts at 1. Touching floor N leaves the next dive at N-1 until a higher floor is touched. The mark itself is not lowered. The first dive forges on that hub visit, after telemetry reset. A follow dive forges before the next job is enqueued and equips after that job's telemetry reset. Analyze every legal AT RISK green and blue. For the chosen weapon type, the tool, and head, body, and legs: quantity one, zero locks, blue when that type and rarity is analyzed and affordable, else green. Forge the highest analyzed item level `can_pay` accepts only when that item level is above the worn piece, or it is equal and a book-peak affix (combat on gear, tool affixes on the tool) is above the worn value. When two of those slots share that item level, the order is weapon, tool, head, body, legs. After the roll, keep the piece in the holds. Equip it only when the score beats the worn piece. Score is item level, then the sum of combat affix values. Tools use tool affix values. A weaker roll stays in the holds and is not equipped. Save the campaign slot after the start floor is written and before `enter_dungeon`. The equip call runs after that job's telemetry reset, so the gear change lands on the new row with phase `hub`.

## Learned goal

A playtest that thinks may read `user://playtest/tuner/policy.json` after the scripted reflexes and an existing lock. The file picks the next goal. On a campaign slot, a wander choice falls through while a living guardian or the floor stairs exist. `--wdb-pt-nopolicy` keeps the scripted ladder. `--wdb-pt-rl` reads a goal from the live bridge and wins over the file and over `--wdb-pt-nopolicy`. `--wdb-pt-rl-port` defaults to 11008. `--wdb-pt-trial=FILE` applies process-local balance floats for that process and does not save the slot. `--wdb-pt-human-log` stays off unless it is passed. `--wdb-pt-gather=N` is the campaign row budget above.
