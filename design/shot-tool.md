# Postcard shot tool

Status: binding design
Read when: postcard shot, run_shots, visual proof clipboard, _logs/shots, changing a shot knob

Not a numbered P1-P9 smoke. Not Imagine. If the tool does not do what you expect, fix the tool (below); do not work around it with a scratch or by hand-driving Godot.

## What it is

Unattended play-camera postcard. Godot paints a real GPU frame. Python owns mode tails, summary, and clipboard/open.

## Modes

- web: full-res PNG plus Windows clipboard. Paste the image with the printed RESULT (the tool prints it; no scratch needed to see it).
- build: scaled PNG (default 50 percent) under `_logs/shots/`.
- user: full-res PNG and open it when done.

Command: `python3 tools/run_shots.py --mode web|build|user` (optional `--seed`, `--floor`, `--scale`, `--settle-ms`, `--timeout-sec`, `--show`, `--out`, `--hud 0|1`, `--width`, `--height`, `--zoom`, `--px`, `--pz`, `--cx`, `--cz`, `--steps`, `--no-pixels`, `--dry-run`, `--json`; `--help` is the truth). Presets live in `tools/shot-recipes.json`.
Needs a real GL window, so a display: a Windows desktop with a GPU, or Linux (picked automatically, see Display; the Bot box has X on `:1` and `:2`). Default: HUD on, spawn pose, zoom 1, no taskbar, window parked off-screen.
Summary: `_logs/shots/summary.txt`; the last line is `RESULT PASS|INFO|FAIL band=... summary=_logs/shots/summary.txt`. The Godot launch and lock come from `godot_lib.py` (per-path lock, kills only its own pid).

## Source map

| Piece | File |
|---|---|
| Orchestrator, bands, summary | `tools/run_shots.py` (clipboard/open: `shot_clip_lib.py`) |
| Presets (poses, zoom, hud) | `tools/shot-recipes.json` |
| Worker entry (`--wdb-shot` boot, settle, grab, quit) | `scripts/debug/shot_tool.gd` |
| Flow runner and ops | `scripts/debug/shot_tool/step_*.gd` |
| Flows, state sources | `tools/shot-flows/*.json`, `states.json` |
| Flow batch, diff, gaps | `tools/run_shot_flow.py`, `shot_diff.py`, `check_shot_gaps.py` |
| Flag parsing (`--wdb-shot-*`) | `scripts/debug/shot_tool/tool_args.gd` |
| Camera pose and zoom | `scripts/debug/shot_tool/tool_pose.gd` |
| Viewport capture and `SHOT:` marks | `scripts/debug/shot_tool/capture.gd` |

## Worker

Flag `--wdb-shot` plus `--wdb-shot-seed`, `--wdb-shot-floor`, `--wdb-shot-out`, `--wdb-shot-scale`, `--wdb-shot-settle-ms`, `--wdb-shot-show`.
Boots past splash/title through the existing CLI multiplexer, `begin_run` on that seed/floor, forces stream, settles, captures the play viewport, prints `SHOT:` marks, quits.
Rendering method is `gl_compatibility` and the driver is `opengl3`, same as play. Audio is Dummy. Do not pass `--rendering-driver d3d12` (that leaves Compatibility and washes the hub through the Forward+ filmic pass). Do not pass `--headless` or `--display-driver headless` (that pair is Dummy rasterizer and yields no pixels).
Default window: no-focus, borderless, popup-wm-hint, parked off the primary screen, still WINDOWED so the frame keeps drawing. `--show` leaves the window visible.

## Bands

Numbers live on `tools/run_shots.py`: `BUILD_SCALE_PCT = 50`, `SETTLE_MS = 1000`, `TIMEOUT_SEC = 180`, `WARN_BYTES = 2048`.
good: PNG exists, `SHOT: ok=true`, bytes at or above warn floor.
warn: PNG exists but bytes below warn floor.
fail: timeout, nonzero Godot exit, no image, or script error.
Do not attach PNG bytes to the CLI transcript.

## What it can stage today

- Scenes `dungeon`, `camp`, `hub`; camera pose (`--px --pz --cx --cz --zoom`, recipes); HUD on/off; window size (`--width --height`).
- **Scripted flows** (`--steps FILE`, or `run_shot_flow.py`): talk to an NPC or open any panel, press gamepad / key / action input, set game state, wait, shoot every page, assert state and text. One worker boot runs the whole list. Ops below. This is the answer to "a menu, dialogue or tutorial page needs a picture".
- Still not staged: crop-to-object beyond `crop` on a Control, dungeon-side UI states without a flow of their own (add the flow, not a hand run).

## Display

Shots need a real GL frame; `godot_lib.pick_display()` chooses: `$DISPLAY` if the X server answers, else the first live socket in `/tmp/.X11-unix`, else the command is wrapped in `xvfb-run` (software GL is fine). `python3 tools/godot_lib.py --display` prints the choice. Windows needs no display. Headless Godot cannot draw pixels, so `--no-pixels` flows (asserts only) and the smokes are the only headless runs. Bake: `run_bake_camp.py` uses the same pick; the shadow projection is CPU-side, so a headless bake gives the same atlas, but the real renderer is the default (`--headless` forces the old driver).

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

## Add or change a knob

One flag or one preset, one prove shot, then stop. Python only: edit `tools/shot-recipes.json` or a constant in `tools/run_shots.py`. New flag: parse in `tool_args.gd`, apply in `tool_pose.gd`, `capture.gd` or the step modules, add the `run_shots.py` argument (forwarded by `_extra_flags`). Prove with one `python3 tools/run_shots.py --mode build` shot, read `_logs/shots/summary.txt`, then `check_tool_cli.py`.

## Troubleshooting

- `fail` with `status=TIMEOUT`: raise `--timeout-sec`, or the window never drew (do not pass headless flags).
- `fail` with COMPILE: a `.gd` parse error; run `run_godot_import_check.py` and fix the script.
- `warn` (tiny PNG): black or blank frame; raise `--settle-ms`.
- Flow diff says `changed` with a tiny bbox (about 0.01 percent, for example the anvil icon): an animated sprite caught mid-cycle, not a regression. Judge with `--max-ratio 0.001`; a real change moves hundreds of times more pixels.
- Flow diff or `--check-published` on a different display (xvfb vs `:2`): about 0.2 percent of a camp frame can differ (animated crystal); compare on the same display.
- `error: godot_lib: no Godot`: set `GODOT_BIN` (or run `bot_smokes.py --setup` on Linux).

## Fix the tool, don't work around

If a picture needs a hand-edited command line, a scratch file or a post-edit of the PNG, the tool is missing a knob or has a bug. Fix `run_shots.py` or the worker in the same PR (rule 9 in the catalog), and name it in the report.
