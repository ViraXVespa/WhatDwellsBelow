# Playtest / AI player and journal

Status: binding design
Read when: automated playtest or playtest journal
Code: scripts/debug/, scripts/combat/debug_menu paths may be under scripts/debug/debug_menu/
See also: `design/debug.md`, `design/debug-menu.md`, `design/debug-anim-browser.md`, `design/debug-smokes.md`, `design/pc-offload.md`, `design/refactor.md`, `design/doc-refactor.md`, `design/README.md`

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
- Not written on web. Not part of the Medium-bar A–F telemetry set. Not an analytics product.

Purpose: let an agent reconstruct why the bot chose a goal and whether grid floor, `_dir_open`, and `test_move` disagreed. MUST NOT grow into heatmaps, session replay, input recordings, per-frame combat traces, per-projectile logs, or exploration pathing maps.

Events: `begin`, `wait`, `decide`, `step`, `act`, `beat`, `combat`, `end`.

- `decide` — goal, `why` / `why_raw`, `near` as `[kind, d, x, y]`, `clerk_d`, `gather_d`, path flags `pc` / `pg`
- `step` — cell, `cmd` (`e|w|n|s`), packed cards `g` / `o` / `p` (EWNS bitstrings), `mis` when they disagree. Identical cell+cmd+cards+goal rows coalesce (`n`, `t1`)
- `beat` is sparse (skipped when gold / kills / hp / goal are unchanged)
- `tel.cfg` is omitted; `cfg_hash` on `begin` is enough
- Root `end_cond` / `fail` come from the `end` event, not from an empty tel stamp

