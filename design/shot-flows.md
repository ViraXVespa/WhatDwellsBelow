# Postcard shot tool: flows and process

Status: binding design
Read when: writing or running a `tools/shot-flows/*.json` flow, updating guide images, adding a shot for a new UI state, or a task needs a shot the tool cannot stage

Rendering, modes, worker, bands, display, knobs and troubleshooting live in the shot-tool door. If the tool does not do what you expect, fix the tool; do not work around it.

## Flows

A flow is `tools/shot-flows/<name>.json`: header keys fill unset CLI defaults (`scene hud zoom settle_ms seed floor px pz width height scale`), plus `about`, `covers` (state ids it proves), `smoke` (true = also run headless by `bot_smokes.py --flows`), optional `publish` `{dir, prefix}`, and `steps`.

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
| `wait` `settle` `seed` `hud` `texts` `log` | | `ms` or `frames`; two frames plus a draw; global RNG seed; HUD on or off; text dump alone; a marker |

Targets are dotted paths. The root is an autoload (`App`), `host` (the camp/dungeon scene), `kind:receptionist`, `group:player` or `node:Path`; then properties, child nodes, keys, `[i]`. Example: `host.ui.mode`. Any random state must be seeded or set (the quest board rolls with its own `randomize()`, so a flow sets `quests_offered`); otherwise two runs differ and the diff is noise. The first failing op stops the run with `SHOT: fail op=... why=...`.

Worker flags: `--wdb-shot-steps=FILE --wdb-shot-frames=DIR --wdb-shot-nopix=1 --wdb-shot-show=1` (window stays visible). Code: `step_runner.gd` (loop, `flow.json`), `step_ops.gd` (ops), `step_ref.gd` (paths), `step_input.gd` (events), `step_texts.gd` (text dump), all under `scripts/debug/shot_tool/`.

Commands:
- `python3 tools/run_shots.py --steps tools/shot-flows/X.json [--no-pixels] [--out P]` one flow, summary `shots`.
- `python3 tools/run_shot_flow.py --list | --flow N | --all | --smoke [--no-pixels] [--baseline D] [--save-baseline D] [--publish] [--check-published]` flows by name; frames in `_logs/shot-flow/<flow>/`; summary `shot-flow`.
- `python3 tools/shot_diff.py BEFORE AFTER [--max-ratio R] [--out DIR]` two PNGs or directories; writes `*.diff.png` (red = changed). Before/after of a change: `--save-baseline /tmp/before` first, then `--baseline /tmp/before` (identical frames print `diff=PASS`).
- `python3 tools/check_shot_gaps.py [--changed [REF]] [--advisory] [--strict]` which states (`tools/shot-flows/states.json` sources) have no flow, which states are new since REF (uncovered ones FAIL; `--advisory` prints only), flows without a shot or assert, stale or hand-edited published shots.

## Screenshot update step (docs and guide images)

`run_shot_flow.py --flow N --publish` copies the frames to a hand-over folder, by default `_out/shots/<flow>/` (git-ignored), and writes `<prefix>shots.json` (file, sha256, size). A flow may set `publish: {"dir": "...", "prefix": "..."}` for another folder; `--publish-dir` overrides. **The tooling never writes under `assets/`**: a `--publish-dir` or `publish.dir` that resolves into `assets/` is refused (`error: refusing to publish ...`) and `check_shot_gaps.py` reports a flow that names one. Grok Build alone decides where a guide or tutorial image lives (folder, size budget, `.import` settings) and copies the frames from `_out/shots/<flow>/` there when a feature needs them. When a UI change lands, `--flow N --check-published` (against the flow's `publish.dir`) FAILs with the stale files; re-run `--publish` and hand the new frames over. `check_shot_gaps.py` flags a published file that differs from `shots.json`.

## New UI state checklist (Build)

1. A new menu, NPC panel or page: add its mode/kind strings to a `states.json` source if the regexes do not already match; `check_shot_gaps.py --changed` must list it as covered. Gate: **required for Bot** (`bot_smokes.py` and `run_build_gate.py --batch` FAIL on a new uncovered state), **advisory for Build** (`run_smokes.py` and plain `run_build_gate.py` print it, never fail); `routes.yaml` `shot_gaps` sets the mode, `--no-gaps` / `--shot-gaps off|advisory|required` override it.
2. Copy the nearest flow (`camp-receptionist-menu` for an NPC menu, `camp-anvil-tabs` for pages, `camp-billboard-controls` for a static panel, `camp-npc-panels` for several NPC panels in one session, `camp-inventory` for a panel opened by its method, `dungeon-gate-shop` for dungeon-only panels), change the `interact`, state and asserts, set `covers`, add `smoke: true`.
3. `run_shot_flow.py --flow N`; read the frames (one look), then `--no-pixels` is the cheap rerun. Map it in `routes.yaml` `shot_flows` so `start_build_slice.py` prints it.
4. The report names the flow, the frames, and the `check_shot_gaps.py` RESULT.

## Gap process: the task needs a shot the tool cannot stage

Extending the tool is part of the task. Do not work around it (no hand-driven Godot, no scratch, no PNG edits, no stand-in older image).
1. Name the missing state in one line (example: "tutorial page 3 of 5 open", "anvil with a forged item").
2. Try a flow first (ops above cover input, state, text and pages). A new op goes in `step_ops.gd`/`step_input.gd` with one flow that proves it.
3. A new worker flag or `run_shots.py` argument is the last resort: parse in `tool_args.gd`, add the matching argument, keep each `.gd` under the script cap.
4. Document it in the table below and in `--help` (`check_tool_cli.py`).

| Knob | Stages | Added for |
|---|---|---|
| `--steps`, `--frames-dir`, `--no-pixels` | scripted flows, numbered frames, headless asserts | NPC/menu/page captures (this table's first row) |
| `--width`, `--height`, `--show` | window size; window left visible | were accepted but ignored; now honored |

