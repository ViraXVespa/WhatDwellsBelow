# Postcard shot tool: flows and process

Status: current plan
Read when: writing or running a `tools/shot-flows/*.json` flow, updating guide images, adding a shot for a new UI state, or a task needs a shot the tool cannot stage

Rendering, modes, worker, bands, display, knobs and troubleshooting live in the shot-tool door. A tool that misbehaves gets fixed, not worked around.

## Flows

A flow is `tools/shot-flows/<name>.json`: header keys fill unset CLI defaults (`scene hud zoom settle_ms seed floor px pz width height scale fixed_fps`), plus `about`, `mask` (`[[x,y,w,h]]` 1920x1080 rects and `tol` (per-channel delta) that baseline diffs ignore, for live world animation behind a panel), `covers` (state ids it proves), `smoke` (true = also run headless by `bot_smokes.py --flows`), optional `publish` `{dir, prefix}`, and `steps`.

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
| `sweep` | `margin` (3), `frames` (8), `keep_x` (192), `keep_y` (112) | Full-floor capture: streams the whole floor, tiles it with the play camera (one PNG per tile in the frames dir plus `sweep.json`), player and enemies hidden. Driven by `run_shots.py --full-map` (`shot-tool.md`) |
| `wait` `settle` `seed` `hud` `texts` `log` | | `ms` or `frames`; two frames plus a draw; global RNG seed; HUD on or off; text dump alone; a marker |

Targets are dotted paths. The root is an autoload (`App`), `host` (the camp/dungeon scene), `kind:receptionist`, `group:player` or `node:Path`; then properties, child nodes, keys, `[i]`. Example: `host.ui.mode`. A `set`/`call` value `{"v3":[x,y,z]}` becomes a Vector3. Seed or set any random state (the quest board rolls its own `randomize()`, so a flow sets `quests_offered`), or two runs differ and the diff is noise. The first failing op stops the run with `SHOT: fail op=... why=...`.

Worker flags: `--wdb-shot-steps=FILE --wdb-shot-frames=DIR --wdb-shot-nopix=1 --wdb-shot-show=1`. Code: `step_runner.gd` (loop, `flow.json`), `step_ops.gd` (ops), `step_ref.gd` (paths), `step_input.gd` (events), `step_texts.gd` (text dump) in `scripts/debug/shot_tool/`.

Commands:
- `python tools/run_shots.py --steps tools/shot-flows/X.json [--no-pixels] [--out P]` one flow, summary `shots`.
- `python tools/run_shot_flow.py --list | --flow N | --all | --smoke [--no-pixels] [--baseline D] [--save-baseline D] [--publish] [--check-published]` flows by name; frames in `_logs/shot-flow/<flow>/`; summary `shot-flow`.
- `python tools/shot_diff.py BEFORE AFTER [--max-ratio R] [--mask X,Y,W,H] [--out DIR]` two PNGs or directories; writes `*.diff.png` (red = changed). Other checks on a frame (layout, contrast, diff heatmap): `img_inspect.py` (`prove.md`).
- `python tools/check_shot_gaps.py [--changed [REF]] [--advisory] [--strict]` which states (`tools/shot-flows/states.json` sources) have no flow, which states are new since REF (uncovered ones FAIL; `--advisory` prints only), flows without a shot or assert, stale or hand-edited published shots.

## Dungeon flows (seed 42)

`dungeon-f{1..4}-spawns`, `dungeon-f{1..4}-ambush` (three hall ambush groups, player three cells away), `dungeon-f3-elites` (named versus normal archer, orc, skeleton), `dungeon-all-enemies` (all twelve types, two rows), `dungeon-f1-props`, `dungeon-f1-boss`, `dungeon-hud-states`. Each uses `scene: dungeon`, `seed: 42`, `settle_ms: 0`, `fixed_fps: 60`, `smoke: true`, and starts with `freeze` on `enemies` so packs stay put. Shot mode seeds the global RNG from the run seed and `fixed_fps` fixes the frame delta: two runs are byte-identical.

Teleport recipe (the whole floor is populated at boot; the camera follows the player): `call group:player.set_global_position` with `[{"v3":[x,0,z]}]`, `wait` 1500 ms for lights, then `shot`. Stand inside the subject's room (line-of-sight lighting), big map closed; take coordinates from `Gen.generate` rooms (seed 42). Staged subjects: stand in an empty extract-gate room, `call host._add_enemy` with `[id, {"v3":[x,0,z]}, gid, named, name]`, then `freeze` `enemies` again. The floor 3 base room (named archer, imps) is not byte-stable, so it has no stop. HUD states use `set` (`group:player.hp`, `App.shrine_t`, `App.prog.food_t` with `food_left`, `App.gold`, `App.toast_msg`/`toast_t`); never freeze the host there.

## Screenshot update step (docs and guide images)

`run_shot_flow.py --flow N --publish` copies the frames to `_out/shots/<flow>/` (git-ignored) and writes `<prefix>shots.json` (file, sha256, size); a flow's `publish: {"dir","prefix"}` or `--publish-dir` picks another folder. Packing and image tools may write under `assets/` when that is their job. A published shot still lives under `_out/shots/<flow>/` until a tool copies it. Grok Build decides where a guide image lives and copies the frames there. After a UI change `--flow N --check-published` FAILs with the stale files; re-run `--publish` and hand the frames over. `check_shot_gaps.py` flags a published file that differs from `shots.json`.

## New UI state checklist (Build)

1. A new menu, NPC panel or page: add its mode/kind strings to a `states.json` source if the regexes miss them; `check_shot_gaps.py --changed` must list it as covered. Gate: **required for Bot and for Build** (`bot_smokes.py`, `run_build_gate.py --batch`, and a Build UI or theme prove FAIL on a new uncovered state). `routes.yaml` `shot_gaps` sets the mode. `--shot-gaps off|advisory|required` overrides it.
2. Copy the nearest flow (`camp-receptionist-menu` NPC menu, `camp-anvil-tabs` pages, `camp-billboard-controls` static panel, `camp-npc-panels` several NPC panels, `camp-inventory` panel opened by its method, `dungeon-gate-shop` dungeon-only panels, `camp-pause-menu` pause/split menu, `camp-recap` delve recap), change the `interact`, state and asserts, set `covers`, add `smoke: true`.
3. `run_shot_flow.py --flow N`. Open the frames and say what is on them. A restyle whose frames are the old widgets with new colors fails. Do not spread that screen to the others. `--no-pixels` is the cheap rerun after the frames have been opened. Map the flow in `routes.yaml` `shot_flows` so `start_build_slice.py` prints it.
4. The report names the flow, the frames and the `check_shot_gaps.py` RESULT.

## Gap process: the task needs a shot the tool cannot stage

Extending the tool is part of the task (no hand-driven Godot, no scratch, no PNG edits, no stand-in older image).
1. Name the missing state in one line.
2. Try a flow first (ops above cover input, state, text and pages). A new op goes in `step_ops.gd`/`step_input.gd` with one flow that proves it.
3. A new worker flag or `run_shots.py` argument is the last resort: parse in `tool_args.gd`, add the matching argument.
4. Document it in the table below and in `--help` (`check_tool_cli.py`).

| Knob | Stages | Used for |
|---|---|---|
| `--steps`, `--frames-dir`, `--no-pixels` | scripted flows, numbered frames, headless asserts | NPC/menu/page captures (first row) |
| `--width`, `--height`, `--show` | window size; window left visible | honored by the shot runner |

