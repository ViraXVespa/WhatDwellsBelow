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

Command: `python tools/run_shots.py --mode web|build|user` (optional `--seed`, `--floor`, `--scale`, `--settle-ms`, `--timeout-sec`, `--show`, `--out`, `--hud 0|1`, `--width`, `--height`, `--zoom`, `--px`, `--pz`, `--cx`, `--cz`, `--taskbar 0|1`; `--help` is the truth). Presets live in `tools/shot-recipes.json`.
Needs a real GL window, so a display: a Windows desktop with a GPU, or Linux with `DISPLAY` set (the Bot box uses `:2`; a 960x540 build shot was verified there). Default: HUD on, spawn pose, zoom 1, no taskbar, window parked off-screen.
Summary: `_logs/shots/summary.txt`; the last line is `RESULT PASS|INFO|FAIL band=... summary=_logs/shots/summary.txt`. The Godot launch and lock come from `godot_lib.py` (per-path lock, kills only its own pid).

## Source map

| Piece | File |
|---|---|
| Orchestrator, bands, summary, clipboard/open | `tools/run_shots.py` |
| Presets (poses, zoom, hud) | `tools/shot-recipes.json` |
| Worker entry (`--wdb-shot` boot, settle, grab, quit) | `scripts/debug/shot_tool.gd` |
| Flag parsing (`--wdb-shot-*`) | `scripts/debug/shot_tool/tool_args.gd` |
| Camera pose and zoom | `scripts/debug/shot_tool/tool_pose.gd` |
| Viewport capture and `SHOT:` marks | `scripts/debug/shot_tool/capture.gd` |

## Worker

Flag `--wdb-shot` plus `--wdb-shot-seed`, `--wdb-shot-floor`, `--wdb-shot-out`, `--wdb-shot-scale`, `--wdb-shot-settle-ms`, `--wdb-shot-show`.
Boots past splash/title through the existing CLI multiplexer, `begin_run` on that seed/floor, forces stream, settles, captures the play viewport, prints `SHOT:` marks, quits.
Rendering method is `gl_compatibility` and the driver is `opengl3`, same as play. Audio is Dummy. Do not pass `--rendering-driver d3d12` (that leaves Compatibility and washes the hub through the Forward+ filmic pass). Do not pass `--headless` or `--display-driver headless` (that pair is Dummy rasterizer and yields no pixels).
Default window: no-focus, borderless, popup-wm-hint, parked off the primary screen, still WINDOWED so the frame keeps drawing. `--show` or `--taskbar 1` leaves the tab visible.

## Bands

Numbers live on `tools/run_shots.py`: `BUILD_SCALE_PCT = 50`, `SETTLE_MS = 1000`, `TIMEOUT_SEC = 180`, `WARN_BYTES = 2048`.
good: PNG exists, `SHOT: ok=true`, bytes at or above warn floor.
warn: PNG exists but bytes below warn floor.
fail: timeout, nonzero Godot exit, no image, or script error.
Do not attach PNG bytes to the CLI transcript.

## What it can stage today

Scenes `dungeon`, `camp`, `hub`; camera pose (`--px --pz --cx --cz --zoom`, recipes); HUD on/off; window size. It does **not** open a UI page (quest, anvil, inventory, recap, extract, map) and does not set game state (bag, forged item, XP drain, quests). Those are gaps, filled by the process below.

## Gap process: the task needs a shot the tool cannot stage

Extending the tool is part of the task. Do not work around it (no hand-driven Godot, no scratch, no PNG edits, no stand-in older image).
1. Name the missing state in one line (example: "quest pane open with three offers", "anvil open with a forged item", "recap mid XP drain").
2. Check `tools/shot-recipes.json` and the flag list above for an existing way. Smallest change wins: recipe > `run_shots.py` argument > worker flag.
3. Add **one** knob (below), prove it with one shot, then the next gap. Never batch knobs. Typical worker knob: `--wdb-shot-ui=<mode>` opens the same panel an interact opens (for example `open_quest()` / `open_anvil()` on `scripts/ui/progress_ui.gd`) after `begin_run`/camp ready and before the grab; state seeding goes through `App.prog` in the same step and stays shot-only.
4. Document it here in one row of the table below, and in `--help` (`check_tool_cli.py`).
5. Use it for the task's pictures. Name each new knob in the report and the changelog bullet only if players see a change.

| Knob | Stages | Added for |
|---|---|---|
| (none yet) | | |

## Add or change a knob

One flag or one preset, one prove shot, then stop (or go on to the next gap with its own prove). Crop-to-object and earlier boot hide are later knobs.
1. Python only (a preset or a default): edit `tools/shot-recipes.json` or the constant in `tools/run_shots.py`.
2. New flag: add the `--wdb-shot-<name>` parse in `tool_args.gd`, apply it in `tool_pose.gd` or `capture.gd`, add the matching `run_shots.py` argument (it forwards through `_extra_flags`). Keep each `.gd` under the script cap.
3. Prove: one `python tools/run_shots.py --mode build` shot; read `_logs/shots/summary.txt`. Then `check_tool_cli.py`.

## Troubleshooting

- `fail` with `status=TIMEOUT`: raise `--timeout-sec`, or the window never drew (do not pass headless flags).
- `fail` with COMPILE: a `.gd` parse error; run `run_godot_import_check.py` and fix the script.
- `warn` (tiny PNG): black or blank frame; raise `--settle-ms`.
- `error: godot_lib: no Godot`: set `GODOT_BIN` (or run `bot_smokes.py --setup` on Linux).

## Fix the tool, don't work around

If a picture needs a hand-edited command line, a scratch file or a post-edit of the PNG, the tool is missing a knob or has a bug. Fix `run_shots.py` or the worker in the same PR (rule 9 in the catalog), and name it in the report.
