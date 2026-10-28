# Long-run campaign playtest store

id: playtest-campaign
owner: build
status: open
done-when: A debug desktop run and a campaign run append local rows; perf.py curve prints the four slices; a campaign keeps its save, picks the lagging weapon, and forges only when the score could rise; a successful sqlite import deletes the JSON spool; cleanup drops decision rows older than 30 days and leaves run rows and curve aggregates.
resume: python tools/slice.py open debug.playtest --task playtest-campaign
area: debug
door: debug
job: playtest
units: store, campaign, hub
done: none

## Intent

A headless campaign keeps one save, wears the weapon furthest behind, forges only when a craft could beat the worn piece, and every debug desktop run appends a local row. The curve command groups those rows by floor and cycle, by weapon skill and item level, by the three weapons, and by combat affix. JSON spools are deleted after they migrate into the local database. Raw decision rows are cleaned on a 30-day keep. Run rows, gear and level changes, and curve aggregates stay.

Vira's words: long semi-natural playtest runs that progress equipment, a local database of runs and decisions for later tuning and difficulty curves, headless and accelerated, three weapons and equipment traits kept even, the same telemetry on human debug builds, stored off the repo. She can bring other players' folders in later.

## Q0

No look, no reference image, no play-camera baseline. The job is NO PLAY CAMERA. Do not add a shot flow and do not pass `--visual`.

## Decisions

- Owner stays `debug.playtest`. `fresh` and `progressed` keep wiping and restamping for recommendations. Campaign rows do not enter `history.json` or `coefs.json`.
- Store the existing per-run counters, a progression snapshot, per-floor buckets, gear and skill changes, kill and death level gaps, and a copy of the bot's existing decision events. Heatmaps, replays, and per-frame traces stay out.
- Human debug desktop runs append the run row on extract, death, and dispel. They do not write decisions. Web and release builds skip the write.
- One slot, `user://playtest/campaign`, primary plus backup, same rules as the other playtest slots. First start creates a fresh delver. Later starts load it and do not wipe it.
- One campaign save wears one weapon at a time. After each run, pick the weapon furthest behind on death rate, duration, and damage taken at the shared item level (the lowest current item level among the three weapons' best owned piece, or the starter). A weapon with no runs at that level is furthest behind. Otherwise normalize each mean by the max of the three and add them with equal weight. Tie: fewer runs, then Great Axe, Staff, Longbow. If that level has no rows, use the previous item level. If none exist, seed Great Axe, then Staff, then Longbow until each has one run. Choose the weapon before the hub forge. The dive uses it even if the forge raises its item level. Armor stays worn.
- Hub pass calls the real analyze, pay, forge, and equip functions. It does not stamp items and it does not click every anvil screen. Analyze every legal AT RISK green and blue. For the chosen weapon type, the tool, and head, body, and legs: quantity one, zero locks, blue if that type and rarity is analyzed and affordable, else green. Forge the highest analyzed item level `can_pay` accepts only when that item level is above the worn piece, or it is equal and a book-peak affix (combat on gear, tool affixes on the tool) is above the worn value. After the roll, equip only when the score beats the worn piece. Score is (item level, sum of combat affix values). Tools use tool affix values. A weaker roll stays in the results and is not equipped. Recap and the hub pass stay at time scale 1.0. `--wdb-pt-fast` applies only while the dungeon AI is acting.
- The series runs until interrupted.
- Files live under `user://playtest/db/` (AppData, never the repo). Another person's data is a copy of that folder.
- The game appends JSONL. It does not link SQLite. The reader is `python tools/perf.py curve` (a subcommand, not a 14th top-level `tools/*.py`; `design/tools.md` keeps 13 entry tools). `--sqlite` imports the spool into `curve.sqlite` beside the JSONL and, only after that commit succeeds, deletes `runs.jsonl` and `decisions.jsonl`. `weapon_band.json` stays. A failed import leaves the spool. `--cleanup` and a successful `--sqlite` also drop decision rows older than `--keep-days` (starting value 30) and VACUUM. Run rows and the four curve aggregates stay. No `tunables.md` row unless a game number is added. The tool refuses to write inside the repo.
- Gear and level changes are why a kept-but-not-equipped roll is acceptable. Each run line carries a `changes` list: skill level changes (`skill_lv`) and equipped-piece changes (slot, item level, rarity, affix ids). Hub changes before the dive use phase `hub`. In-run changes use phase `run`. Record the change where the value actually changes (`skill_lv` crossings in the xp grant, `equip_uid` and the forge hold that becomes equipped). Do not poll every frame.
- Level gap, for balance: when the player kills an enemy, add one to `kill_delta` keyed by `enemy.combat_lv - player.combat_lv` (`EnemyHit.die` has `host.combat_lv`; `App.prog.combat_lv()`). When an enemy kills the player, set `death_delta` to that same subtraction (`enemy_atk.gd` already calls `take_hit` with `kill_tag()`; pass `combat_lv` through `last_hit_lv` on the player and record it at `player_die`). Dispel with no enemy leaves `death_delta` unset. This is a histogram plus one death number, not a per-hit log.

## Fork

The User opens a unit from the repo root with the `resume` line. This session never runs that line. The session's first command is:

`python tools/slice.py start --door debug --job debug.playtest --task playtest-campaign`

Read this task whole before any other file. Work the first unit not listed in `done`. One unit per session. After the prove, update docs and the code-map, `python tools/slice.py commit`, then `git push origin` of the week branch (never main, never force). Then `python tools/slice.py start --unit-done`. Stop. The next unit is a fresh session.

No new smoke phase. Extend phase 7, which already prints the telemetry row (`scripts/debug/smoke/smoke_p7.gd`). Phases for this job stay 7 and 9.

## Unit store

Done when a fixture run line and a debug-desktop `finish_end` append `runs.jsonl` with the snapshot, per-floor buckets, `changes`, `kill_delta`, and `death_delta`; a bot finish with the journal on also appends coalesced decision events; `perf.py curve` prints the four slices; `--sqlite` then deletes the spool and a second run imports cleanly; `--cleanup` drops old decision rows and leaves run rows.

Files:

- `scripts/app/telemetry.gd` — floor buckets inside `tick` (on `App.floor_n` change: `n`, `dt`, `dmg_taken`, `deaths`, `near_death`; a death or dispel counts on the ending floor). `note_kill_levels(enemy_lv, player_lv)`. `death_delta` at death. Fields on `to_dict`.
- `scripts/combat/enemy/enemy_hit.gd` — `die` calls `note_kill_levels` while `host.combat_lv` is alive.
- `scripts/combat/enemy/enemy_atk.gd` — pass `host.combat_lv` into the player hit.
- `scripts/world/player.gd` — `last_hit_lv`.
- `scripts/world/player/player_act.gd` — store it in `take_hit`; set `death_delta` in `player_die`.
- `scripts/data/progress.gd` — hook the existing `add_run_xp` / `add_perm_xp` / `equip_uid` facades once, so a skill level or equipped piece change appends to the open run's `changes`.
- `scripts/app/app_run.gd` — `finish_end` appends the human row on a debug desktop build only.
- `scripts/debug/playtest/sim.gd` — `finish_job` appends the bot row and copies the journal events. Do not add these rows to `pt.history`.
- `scripts/debug/playtest_log.gd` and `scripts/debug/playtest_log/` — the events already built (`begin`, `wait`, `decide`, `step`, `act`, `beat`, `combat`, `end`). Tag them with `run_id`. Skip when the journal is off (`--wdb-pt-nolog`, web).
- New `scripts/debug/playtest_db.gd` — append JSONL, update `weapon_band.json` from bot rows, debug-desktop gate, spool paths.
- `tools/perf.py` plus a module under `tools/lib/perf/` — subcommand `curve`. Flags: `--dir` (default the AppData `user://playtest/db` folder), `--sqlite`, `--cleanup`, `--keep-days` (default 30). Prints floor and cycle; weapon skill (`axe` / `staff` / `bow`) by that weapon's item level; weapon by floor and weapon item level; each combat affix id by that piece's item level (a run with the same affix on two pieces counts in each band). Numbers are runs, death rate, mean duration, mean damage taken.
- `scripts/debug/smoke/smoke_p7.gd` — assert a synthetic row has the new fields and the curve printer can see them. Do not boot a second dungeon.
- Docs: `design/debug-playtest.md` (the whole store, campaign, hub, and cleanup, so later units implement against it), `design/save-tech-persist.md` (campaign slot and `user://playtest/db/`), `design/feel.md` (the curve report is how the three-weapon sentence is checked over a series, including the level-gap histogram), `design/tools.md` (one row for `perf.py curve`), `design/tools-perf.md` (the command), `design/debug-smokes.md` only if the P7 line needs a sentence. Code-map row for `playtest_db.gd`. `check.py load-graph` after the doc edits. `check.py tool-docs` after the perf subcommand.

Run line fields beyond today's `to_dict`: `run_id`, seed, save kind (`human`, `fresh`, `progressed`, `campaign`), eleven `skill_lv` values (`axe`, `staff`, `bow`, `str`, `mag`, `rng`, `def`, `hp`, `mine`, `wood`, `smith`), equipped pieces (slot, type, item level, rarity, affix ids with values), `floors`, `changes`, `kill_delta`, `death_delta`.

## Unit campaign

Done when a second campaign prep still has the skills, bank, and gear the first run saved, the next weapon follows the lag rule on a fixture `weapon_band.json`, and `--wdb-pt-campaign` plus a debug-menu button start a loop that stops when interrupted.

Files:

- `scripts/data/save_store.gd` and `scripts/data/save_store/store_io.gd` — both define `FRESH` and `PROG`. Add `user://playtest/campaign` in both. `dir_for` must return it for slot `campaign`.
- `scripts/debug/playtest/sim.gd` — `prep_slot`: load `campaign` and do not wipe or restamp. Missing save: `fresh_delver`, then save. `finish_job`: if the job is campaign and the run was not interrupted, enqueue the next campaign job with the weapon `playtest_db` picked. Do not forge in this unit. Equip that weapon's best owned piece (starter if none) through the existing loadout path. Armor untouched.
- `scripts/debug/playtest/playtest_api.gd` — job key `save: campaign`. The loop is one job at a time, not a pre-filled queue, because the weapon depends on the row just written.
- `scripts/debug/playtest/live_smoke.gd` — follow its flag pattern for `--wdb-pt-campaign` (headless, one series until the smoke's own short limit, or a single prep-and-repick assert if a full dive is too heavy). Document the flag next to the live-smoke flag in `design/debug-playtest.md` and `design/debug-smokes.md`.
- `scripts/debug/debug_menu/menu_pages.gd` — `page_playtest` gains a campaign start button. Status text can name `user://playtest/db/`.
- `scripts/debug/smoke/smoke_p7.gd` — two preps leave the slot in place; the second weapon matches the lag rule.
- Code-map if a new script appears. No forge in this unit.

## Unit hub

Done when a campaign with an analyzed book and enough materials forges one piece when the score could rise, equips it only when the rolled score wins, skips the craft when it could not, and writes the gear change onto the next run's `changes` with phase `hub`.

Files:

- New helpers in `scripts/debug/playtest_hub/` next to the playtest facade. Call `analyze_destroy` (`scripts/data/progress/progress_town.gd`), `can_pay_forge` / `pay_forge` / `forge_cost` on `App.prog`, `make_forged` and `set_holds_for_type` (`scripts/data/progress_forge/forge_act.gd`), then `App.prog.equip_uid`. Read the forge book the anvil already reads. Do not add a second peak or cost formula.
- `scripts/debug/playtest/sim.gd` — after recap, before the next campaign enqueue, run the hub pass at time scale 1.0, save the campaign slot, then enqueue.
- `scripts/debug/smoke/smoke_p7.gd` — call the hub function on a fixture book. One case forges and equips. One case skips. No live anvil screens.
- Docs only if the code diverges from the Unit store write-up in `design/debug-playtest.md`.

## Prove

Each unit: `python tools/gate.py gd-load` after the script edits, then `python tools/gate.py build --batch` with no `--visual`, then `python tools/session.py summary --job build-gate`. Design-doc edits also run `python tools/check.py load-graph` and need RESULT PASS before the unit is reported done. A perf subcommand also runs `python tools/check.py tool-docs`.

Playtest confirmation is recommended for one watched hub visit after unit hub (the weapon it picks, and that it forges only when the score could rise). The file format and the four tables are the smokes' job.

## Do not

- Do not invent a second combat, loot, or forge implementation.
- Do not put play data, `curve.sqlite`, or `_logs/` in the commit.
- Do not hand-edit `version.json`.
- Do not reset `fresh` or `progressed` behavior.
- Do not feed campaign rows into the recommendation history.
- Do not raise the 6x cap.
- Do not add heatmaps, replays, per-frame traces, or a per-kill event list. The level gap is the histogram plus one death number.
