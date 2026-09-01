# Secret debug, playtest, animation browser

Status: binding design + live snapshot
Read when: changing the secret menu, telemetry, playtest, animation browser, or verification
Code: `scripts/combat/debug_menu.gd`, `scripts/debug/playtest.gd`, `scripts/debug/playtest_log.gd`, `telemetry.gd`, `anim_browser.gd`, `smoke.gd`
See also: `design/constraints.md`, `design/coverage.md`, `design/ui.md`

## Secret debug / balance menu

Accessed only by the following input sequence (gamepad): all four shoulder buttons (RT + RB + LT + LB) must go from pressed → released → pressed → released within a 1.5-second window. The 1.5-second timer resets after the first release so a full 1.5 seconds remains for the second press-and-release.
The menu opening itself is the sole confirmation that the sequence succeeded.
This menu contains:
- Every previously available debug / balance page (all numeric values exposed and tunable)
- Debug profile Save / Load / Delete / Rename system (unlimited named profiles, free naming/renaming, saved to files by default, persist across live-path sessions)
- Automated Playtest / AI Player system
- Animation Browser page (entry MUST exist when this menu is first implemented; full viewer MAY be a stub until Phase 9, and MUST be complete for Demo-Complete)
- All other content that was formerly under Pause → System that is not listed in the player System tab

Live also opens with CLI `--wdb-debug`.

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
- Time to first clerk interaction
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

## Animation Browser (secret debug page)

Purpose: let the User review player and enemy animation states so art and facing can be checked without playing a full run.

**Phase rule**
- Phase 7: the Animation Browser control MUST exist in the secret debug menu. It MUST be labeled, gamepad-focusable, and reachable with the same tab/page navigation as other debug pages. A stub panel (“Animation Browser — implemented in Phase 9”) is acceptable.
- Phase 9 / Demo-Complete: the full viewer MUST ship. This is a vital development tool in the final product. It is deliberately *not* part of early build logic so sprite pipelines and combat can land first.

**Layout**
The Animation Browser is a full-screen page. It MUST be TV-readable and gamepad-first, and MUST open with valid initial focus.

- **Back** sits at the bottom of the screen. Activating it returns the User to the main secret debug menu. Activation methods (both required): highlight Back and press A, or press B at any time while the Animation Browser is open. B MUST work regardless of current highlight.
- **Model selection widget** at the top of the screen:
  - Left: Previous model button. LB at any time selects the previous model.
  - Middle: display-only name of the current model.
  - Right: Next model button. RB at any time selects the next model.
  - Wrapping at the ends of the model list is allowed.
  - Model list MUST include player male, player female, and every shipped enemy type including Floor Guardians and the Gate Master.
- **Preview viewport** directly beneath the model selection widget. Shows a zoomed-in view of the current model playing the current animation. Updates immediately when model, facing, or animation changes.
- **Play / Pause** sits under the preview. Default: the selected clip loops. Highlight the control and press A to toggle play/pause. Playing vs paused MUST be obvious from the couch.
- **Direction list and animation list** sit together to the right of the model widget and preview, as two sibling list widgets with the same interaction pattern. The direction list is next to the animation list.

**Direction list**
- Lists every available facing for the current model: the eight Character Bible directions plus **Idle / None**.
- The User may move a highlight with the D-pad (or equivalent menu navigation) and press A to select a facing, consistent with other menu lists.
- **Right stick** sets facing from anywhere in the Animation Browser. Deflect past a deadzone and the nearest of the eight in-game aim octants becomes the selected facing. Releasing the stick to neutral **keeps** the last facing.
- **R3** sets facing to **Idle / None** from anywhere.
- Manual highlight + A, right stick, and R3 all write the same current facing. The list highlight MUST match the active facing after any of those inputs.
- Changing facing immediately rebuilds the animation list for that facing.

**Animation list**
- Lists only animations available on the current model **for the current facing**.
- Idle / None lists only clips that belong to that bucket (idle and any other non-directional clips shipped for that model).
- A compass facing lists only clips that exist for that facing (walk, attack, special, gather, death, “Dispel”, directional attacks, and any other shipped per-facing clips).
- If the newly selected facing or model does not have the previously selected animation, select the first available animation for that facing.
- If a facing has no clips, show an empty list and a clear empty state in the preview; do not keep a clip from the old facing.
- The list MUST refresh when the selected model or facing changes.
- LT scrolls the animation list up and RT scrolls it down from any focus position.
- The User may also highlight an entry with normal menu navigation and confirm with A.
- The selected animation is the one currently playing in the preview.

**Always-available gamepad chords (Animation Browser only)**

| Input | Action |
|---|---|
| LB / RB | Previous / next model |
| LT / RT | Scroll animation list up / down |
| Right stick | Set facing to that octant |
| R3 | Facing = Idle / None |
| A | Activate highlight (direction entry, animation entry, Play/Pause, Back, on-screen model buttons) |
| B | Back to main secret debug menu |

Keyboard / mouse MUST have equivalents for every action (suggested start: arrow keys or WASD for facing, a dedicated Idle / None key, Q/E or equivalent for model, list scroll on mouse wheel / keys). Exact bindings MAY be invented at implementation time and MUST appear in the rebinding screen.

Exact compare-two, frame-scrubber, and bible-overlay extras MAY be invented at implementation time so long as the requirements above are met.

## Live snapshot — smoke tests (`smoke.gd`)

Coverage runner, not a particle system. CLI: `--wdb-phaseN-smoke` for N = 1..9. Prints on `printerr`, then quits.

| Fn | Checks |
|----|--------|
| p1 | Boot, player, camera, basic weapon |
| p2 | Weapon swap, telegraphs, projectiles, FPS estimate |
| p3 | Floor data, doors, stairs, boss flow |
| p4 | Roster, named, flee, pressure safety |
| p5 | Gather nodes, extract UI, puzzle props |
| p6 | Artifacts, food/potion, forge, quests |
| p7 | HUD, pause, debug, recap |
| p8 | Hub spots, building depth, save backup |
| p9 | Audio, archives, anim models, playtest hook |