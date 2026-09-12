# Secret debug, playtest, animation browser

Status: binding design + live snapshot
Read when: changing the secret menu, telemetry, playtest, animation browser, or verification
Code: `scripts/combat/debug_menu.gd`, `scripts/combat/debug_menu_val.gd`, `scripts/combat/debug_menu_val_grid.gd`, `scripts/combat/debug_menu_settings.gd`, `scripts/world/sprite_filter.gd`, `scripts/debug/playtest.gd`, `scripts/debug/playtest_log.gd`, `telemetry.gd`, `anim_browser.gd`, `anim_browser_nav.gd`, `anim_browser_review.gd`, `anim_review.gd`, `anim_scan.gd`, `smoke.gd`
See also: `design/constraints.md`, `design/coverage.md`, `design/ui.md`, `design/camera.md`, `design/art-pipeline.md`, `design/input.md`

## Secret debug / balance menu

Accessed only by the following input sequence (gamepad): all four shoulder buttons (RT + RB + LT + LB) must go from pressed → released → pressed → released within a 1.5-second window. The 1.5-second timer resets after the first release so a full 1.5 seconds remains for the second press-and-release.
The menu opening itself is the sole confirmation that the sequence succeeded.
This menu contains:

- Every previously available debug / balance page (all numeric values exposed and tunable)
- Debug profile Save / Load / Delete / Rename system (unlimited named profiles, free naming/renaming, saved to files by default, persist across live-path sessions)
- Automated Playtest / AI Player system
- Animation Browser page (entry MUST exist when this menu is first implemented; full viewer MAY be a stub until Phase 9, and MUST be complete for Demo-Complete)
- Settings page for in-test system and game options that are not yet approved for general players
- All other content that was formerly under Pause → System that is not listed in the player Settings tab

Live also opens with CLI `--wdb-debug`.

### Live snapshot — menu chrome and Values

Live path: `scripts/combat/debug_menu.gd`. This is current chrome, not a new system.

**Pages.** Five pages in LB / RB order: Values → Settings → Profiles → Playtest → Animation Browser. Close (B) sits in the top row but is not a page. The top tab buttons are mouse-clickable and must not take gamepad focus. Title, tabs, and status stay pinned above the scroll so first-open focus cannot hide the tab labels. The active tab is tinted.

**Values (browse / edit).** Values does not use engine SpinBox focus. Tunables are grouped by category in two columns (`debug_menu_val_grid.gd`). Opening the page highlights the top-left category.

- D-pad / left-stick Up / Down move within the current category column and wrap in that column.
- D-pad / left-stick Left / Right move between the two category columns.
- **A** on a category expands that category’s variables in a single column under that category cell. Focus moves to the first variable. Navigation locks to that list (Up / Down). Left / Right do nothing in the var list.
- **A** on a variable enters edit. Up / Down then changes the value by that row’s step. The live balance value is not committed until confirm.
- **A** again writes the value and returns to the var list.
- **B** while editing restores the previous number and returns to the var list.
- **B** on the var list collapses it and returns focus to the two-column category grid.
- **B** on the category grid closes the secret menu (Values is the home page).
- Fly-out ideals still update from the highlighted variable.

**Settings.** Catch-all for in-test display and camera options. Built by `debug_menu_settings.gd`. Changes apply live and persist through `App.save_now()`.

- Camera zoom slider (`ZOOM_MIN`–`ZOOM_MAX`)
- HUD scale slider
- UI text floor slider (8–24, default 14). Applied scale is `clamp(floor / (UI_TEXT_REF × screen_per_design), 1.0, 2.5)`. Floor is saved; applied scale is recomputed on resize
- Force touch overlay toggle. Session-only. Bypasses web / mobile UA / keyboard / pad checks so desktop can preview the cluster in Placeholdia or the dungeon. Overlay still hides while `App.ui_open`
- Sprite filter cycle over all five Godot Sprite3D modes (nearest, nearest+mips, nearest+mips+aniso, linear+mips, linear+mips+aniso)
- Mip blend Sharp / Smooth (`rendering/textures/default_filters/use_nearest_mipmap_filter`)
- Mip bias slider (−2..2). Stored and persisted; Sprite3D has no lod-bias hook yet so the picture does not change
- Touch stick deadzone slider, plus reset. RT is press-and-hold only; there is no double-tap latch
- Look wheel / pinch / stick sliders, plus reset
- Grant anvil test kit (bag gear + gold / ore / root). Debug-only
- Save settings button

Linear filters MUST stay on this tab. Player Settings → Graphics uses Mipmaps / Anisotropic checkboxes (nearest implied). Linear stays here.

**Other pages.** Settings, Profiles, and Playtest still use normal button / LineEdit / slider focus. Up / Down moves among those controls.

**Animation Browser tab.** Navigating to that tab (LB / RB or mouse) only rebuilds a confirm prompt. It does not open the full-screen viewer. The first control is **Open Animation Browser**; **A** on that control launches `anim_browser.open_browser()`. **B** on the prompt returns to Values. While the viewer is open, the debug menu MUST release GUI focus and stop processing input so the viewer can take D-pad / keyboard. Debug-menu LB / RB must not steal model-cycle input. Closing the viewer restores debug-menu input and returns focus to this prompt, not to a hidden tab button.

The Phase 7 “gamepad-focusable Animation Browser control” is that Open button, not the top tab chrome.

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
- **Play / Pause** sits under the preview. Default: the selected clip loops. **X** (`gear_drop` / `anim_play`) toggles play/pause from anywhere in the viewer. Highlight + A still works. Playing vs paused MUST be obvious from the couch.
- **Direction list and animation list** sit together to the right of the model widget and preview, as two sibling list widgets with the same interaction pattern. The direction list is next to the animation list.
- **Review status** sits under the lists. Shows Good / Repack / Regenerate for the current clip, or Still — no review when the clip is a single frame.
- **Notes field** sits above Back. Visible only while the current clip is Repack or Regenerate. Keyboard types into it.

**Direction list**

- Lists the eight Character Bible facings in this order: Down, Down-Left, Left, Up-Left, Up, Up-Right, Right, Down-Right. There is no Idle / None facing row. Idle clips live on each facing.
- Open focus is the current facing (Down on first open). Unselected labels are white. The selected facing is gold.
- D-pad Up / Down moves the facing highlight and writes that facing. D-pad Right moves focus to the Animation list (last highlighted clip). D-pad Left on the facing list stays there.
- **Right stick** sets facing from anywhere in the Animation Browser. Deflect past a deadzone and the nearest of the eight in-game aim octants becomes the selected facing. Releasing the stick to neutral **keeps** the last facing. Right-stick facing MUST NOT steal D-pad / keyboard focus or rebuild the facing buttons.
- Changing facing immediately rebuilds the animation list for that facing.

**Animation list**

- Lists only animations available on the current model **for the current facing**. Labels are title-cased.
- A facing lists only clips that exist for that facing (`walk`, `attack_*` / `special_*` per weapon class, `gather_pickaxe` / `gather_hatchet` falling back to `gather_*` files, `death`, “Dispel”, directional attacks, idle, and any other shipped per-facing clips). `idle_to_walk` / `walk_to_idle` are pack-only and MUST NOT appear in this list.
- If the newly selected facing or model does not have the previously selected animation, select the first available animation for that facing.
- If a facing has no clips, show an empty list and a clear empty state in the preview; do not keep a clip from the old facing.
- The list MUST refresh when the selected model or facing changes.
- LT / RT scroll the animation list up / down from any focus position. Mouse wheel does the same. Left click activates the hovered button. Right click does nothing.
- D-pad Up / Down moves the animation highlight when that list has focus. D-pad Left returns to the Facing list (last facing). D-pad Right on the animation list stays there.
- Left stick, while playing, steps playback speed (0.25 / 0.5 / 1.0 / 1.5 / 2.0). While paused, left stick steps individual frames.
- The User may also highlight an entry with normal menu navigation and confirm with A.
- The selected animation is the one currently playing in the preview.

**Review ledger**

- **Y** (live bind: `gear_tip`) cycles Good → Repack → Regenerate → Good on the current clip.
- Stills (one frame or fewer) MUST NOT accept a cycle. Idle bible stills stay unflagged.
- Session memory keeps the note text while the User toggles states. Disk write drops Good rows and drops notes on Good.
- Store: `tools/anim_review/review.json` in the live checkout. Editor-only. MUST NOT use `SaveStore` / `user://live`. Not written on web. The `tools/anim_review/` directory is gitignored.
- Key: `model_id/facing/anim` (same catalog ids as `AnimScan`).
- Offline tools that read this file are listed in `design/art-pipeline.md`. A Regenerate flag on a player clip resolves to a specific `i2v_seeds.py` MOTION key (`attack_great_axe`, not a generic `attack`). A `gather` flag writes both pickaxe and hatchet prompts. Pack accepted one-shot I2V with `tools/pack_oneshot.py`.

**Always-available gamepad chords (Animation Browser only)**

| Input | Action |
|---|---|
| LB / RB | Previous / next model |
| LT / RT | Scroll animation list up / down |
| D-pad Up / Down | Move highlight in the focused list (Facing or Animation) |
| D-pad Left / Right | Animation list ↔ Facing list |
| Left stick | Playback speed while playing; frame step while paused |
| Right stick | Set facing to that octant |
| X | Play / Pause |
| Y | Cycle review state (multi-frame clips only) |
| A | Activate highlight (direction entry, animation entry, Play/Pause, Back, review button, on-screen model buttons) |
| B | Back to main secret debug menu |

Keyboard / mouse MUST have equivalents for every action (arrow keys for list columns, Q/E or LB/RB for model, mouse wheel for the animation list, Y for review cycle, X for play/pause). Exact bindings MAY be invented at implementation time and MUST appear in the rebinding screen. Notes require a keyboard; there is no on-screen keyboard.

Exact compare-two, frame-scrubber, and bible-overlay extras MAY be invented at implementation time so long as the requirements above are met.

### Live snapshot — review chrome

- Facade: `scripts/debug/anim_browser.gd`
- Review helper: `scripts/debug/anim_browser_review.gd`
- Ledger: `scripts/debug/anim_review.gd`

## Live snapshot — smoke tests (smoke.gd)

Coverage runner, not a particle system. User args: --wdb-phaseN-smoke for N = 1..9 (after --). Prints on printerr, then quits. There are no live smoke_*.tscn scenes — phases attach from oot / foundation / dungeon / camp via scripts/debug/smoke.gd.

### How to run (Steam Godot / redirected IO)

Binary (Steam tools build): C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe (also in 	ools/export_web.ps1).

**Required flags** when stdout/stderr are redirected (CI, Start-Process -Redirect*, agent shells):

`
--headless --display-driver headless --audio-driver Dummy --path <WDB_ROOT> -- --wdb-phaseN-smoke
`

- Plain --headless alone can **hang forever** with only the engine banner and empty stderr under redirected IO. Always pass --display-driver headless --audio-driver Dummy for automated smoke.
- Put the phase flag in **user** args (after --) so OS.get_cmdline_user_args() sees it.
- Capture stderr for P1:…P9: lines and SCRIPT ERROR. Exit is self-quit from the phase (or kill after a timeout if hung).
- Optional: --verbose for load traces (huge logs). Not required once drivers are set.
- Compile/reload check is separate: see design/grok-bot-session.md (--editor --import). Do not treat a smoke pass as proof scripts are editor-clean, or vice versa.

| Fn | Checks |
|----|--------|
| p1 | Boot, player, camera, basic weapon |
| p2 | Weapon swap, telegraphs, projectiles, FPS estimate |
| p3 | Floor data, doors, stairs, boss flow |
| p4 | Roster, named, flee, pressure safety |
| p5 | Gather nodes, extract UI, puzzle props |
| p6 | Artifacts, food/potion, forge, quests |
| p7 | HUD, pause, debug, recap |
| p8 | Hub spots, building depth, save backup, archive catalog |
| p9 | Audio, archive catalog, anim models, playtest hook |
