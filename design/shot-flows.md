# Postcard shot tool: flows and process

Status: current plan
Read when: writing or running a `tools/data/shot-flows/*.json` flow, updating guide images, adding a shot for a new UI state, or a task needs a shot the tool cannot stage

Capture/display troubleshooting stays in the screenshot tool guide. Fix a missing capability rather than hand-driving the game.

Before guessing a `--state` or `--flow` name, run `python tools/shots.py flow --list` or `--survey`. The tool also prints the valid state names when a `--state` misses.

## Flows

A flow is `tools/data/shot-flows/<name>.json` with a setup header and `steps`. The header fills unset CLI defaults for scene, HUD, camera, viewport, seed and timing. `about` describes intent; `covers` names UI states. `covered_by` suppresses a redundant flow when the covering one is selected. `smoke: true` enables headless assertion coverage. Optional `mask` rectangles/tolerance exclude live animation from baseline diffs; `publish` controls staged outputs. Coordinates for masks are at 1920x1080.

| Op | Keys | Does |
|---|---|---|
| `interact` | `kind` or `target`, `near` | Calls the interactable's `interact()` like a player (NPC, board, anvil, billboard); `near` walks the player next to it first so the prompt shows |
| `press` | `pad` (A B X Y LB RB START BACK UP DOWN LEFT RIGHT LS RS) or `action` or `key`, `times` | Injects a real input event (pad presses flip prompts to pad glyphs) |
| `device` | `kind` pad or kb | Forces the glyph set before a menu is built |
| `shot` | `name`, `texts`, `crop`, `pad` | Saves `NN-name.png` (plus `NN-name.texts.json` with `texts`); `crop` = a Control path |
| `assert` | `target`, one of `equals not_equals contains gt lt is_null` | Fails the run with the value seen |
| `assert_texts` | `root`, `min_font`, `max_chars`, `must_contain`, `forbid` | Checks the visible copy (font floor, line length, wording) |
| `set` / `call` | `target`, `value` / `method`, `args` | Seeds state (`App.prog.quests_offered`, `App.gold`) or calls a method |
| `repeat` | `max`, `until`, `steps` | Pages: loop steps until the `until` assert holds (or `max`) |
| `freeze` | `group`, `on` | Disables (or restores) processing of a node group, e.g. `enemies`; the HUD host keeps running |
| `sweep` | `margin` (3), `frames` (8), `keep_x` (192), `keep_y` (112) | Full-floor capture: streams the whole floor, tiles it with the play camera (one PNG per tile in the frames dir plus `sweep.json`), player and enemies hidden. Driven by `shots.py capture --full-map` (`shot-tool.md`) |
| `walk_to` / `drive` / `tap` / `mark` | `x z near must max_ms` / `move aim attack ms` / `action` / `name` | Play through `App.playtest` like a pad: walk to a ground point, hold a world-space stick (and attack), one-frame press; `mark` prints the frame for `shots.py movie` cuts. Proof flow: `camp-walk-drive` |
| `camera` | `at [x,z]` or `target REF` (+ `offset`), `zoom`, `ms`, `ease linear\|inout`, `wait`, `follow` | Movies: frame a ground point or node at a zoom (rig hooks, no game change), glide over `ms` and hold; `follow` glides back to the player and returns control |
| `wait` `settle` `seed` `hud` `texts` `log` | | `ms` or `frames`; two frames plus a draw; global RNG seed; HUD on or off; text dump alone; a marker |

Targets are dotted paths rooted at an autoload (`App`), scene host, `kind:NAME`, `group:NAME` or `node:Path`. They may traverse children/properties/keys, indices and vector components. `{"v3":[x,y,z]}` becomes a Vector3 for set/call. Seed or explicitly set random state before comparison; otherwise a diff measures randomness. The first failed operation stops the flow with `SHOT: fail op=... why=...`.

For inventory/extract screenshots, stock representative gear/resources before opening the panel. The checked-in extract flow uses `App.prog.stock_extract_shot`; a fresh starter kit does not exercise the full layout.

Worker flags: `--wdb-shot-steps=FILE --wdb-shot-frames=DIR --wdb-shot-nopix=1 --wdb-shot-show=1`. Code: `step_runner.gd` (loop, `flow.json`), `step_ops.gd` (ops), `step_play.gd` (play ops), `step_ref.gd` (paths), `step_input.gd` (events), `step_texts.gd` (text dump) in `scripts/debug/shot_tool/`.

## Run and compare

- `python tools/shots.py flow --flow NAME` captures a named flow; `--job door.job` runs its mapped flows.
- `python tools/shots.py diff BEFORE AFTER --out DIR` compares images/folders and writes heatmaps.
- `python tools/shots.py gaps --changed` validates coverage and published artifacts.

Use `--help` for filters, baselines and output options rather than guessing state names or copying an ad hoc worker command.

## Repeatable dungeon captures

The checked-in dungeon flows cover spawns, ambushes, elites, props, boss and HUD states at seed 42 with fixed fps. They freeze enemies and seed random state for byte-identical repeats. Keep the player in the subject's room for valid lighting, close the big map and do not freeze the host for HUD tests. The flow file is the executable setup reference.

## Screenshot update step (docs and guide images)

`shots.py flow --flow NAME --publish` stages frames and a hash manifest under `_out/shots/`, never directly under assets. Packaging installs accepted images. `--check-published` detects stale files; publish again and pass the frames to that job. `shots.py gaps` also detects files altered outside the manifest.

## New UI state checklist (Build)

When a visual job lacks its own flow, create one before implementation. `slice.py start` reports this as STEP 0, not a failed gate. Flow files and their routes mapping may be prepared before the User answers design questions; this does not authorize changing the screen.

1. Run `shots.py flow --list` and copy the nearest relevant flow. Set its setup, states, assertions and `covers`; use `smoke: true` for headless assertion coverage. Each selected flow should cover distinct work; use `covered_by` when another selected flow already covers it.
2. Map it under the job's own `shot_flows` key in routes. Do not borrow a door's unrelated frames. Add state-source patterns if `states.json` does not recognize the new UI state.
3. Run `shots.py flow --flow NAME` or `--job door.job`. Capture the actual baseline in the session changing the screen, then review it in isolation. Direct reference reads require an explicit task grant. Show the User the relevant before/after together, with paths and descriptions.
4. Iterate one state with `--flow NAME --state STATE`; `shot_states` limits a shared flow automatically for a job. Use crop/zoom for details. `--no-pixels` checks assertions only and is not visual evidence.
5. At final verification, `shots.py gaps --changed` must pass: new UI states need coverage, and missing/stale frames are failures. Required in Build's batch gate and Bot smokes. Report flow, frames and gap-check result.

## Gap process: the task needs a shot the tool cannot stage

Extending the tool is part of the task (no hand-driven Godot, no scratch, no PNG edits, no stand-in older image).
1. Name the missing state in one line.
2. Try a flow first (ops above cover input, state, text and pages). A new op goes in `step_ops.gd`/`step_input.gd` with one flow that proves it.
3. A new worker flag or `shots.py capture` argument is the last resort: parse in `tool_args.gd`, add the matching argument.
4. Document it in the table below and in `--help` (`check.py tool-cli`).

Menu headers may select title, splash or the first-start gate. These captures use an isolated save and fail if live-save isolation cannot be established. Touch-overlay captures still need a touch device. Report an unavailable screen as "not pictured"; ask about extending coverage rather than substituting another screen.

| Knob | Stages | Used for |
|---|---|---|
| `--steps`, `--frames-dir`, `--no-pixels` | scripted flows, numbered frames, headless asserts | NPC/menu/page captures (first row) |
| `--width`, `--height`, `--show` | window size; window left visible | honored by the shot runner |
