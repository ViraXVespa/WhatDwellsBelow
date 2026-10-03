# Postcard shot tool

Status: binding design
Read when: postcard shot, run_shots, visual proof clipboard, _logs/shots, changing a shot knob

Not a numbered P1-P9 smoke. Not Imagine. If the tool does not do what you expect, fix the tool (below); do not work around it with a scratch or by hand-driving Godot.

## Job → Open

| Job | Open |
|---|---|
| Run, stage or change a single shot (modes, worker, bands, display, knobs, troubleshooting) | this file |
| Scripted flows, flow JSON ops, publishing doc images, new UI state checklist, gap process | `shot-flows.md` |

## What it is

Unattended play-camera postcard. Godot paints a real GPU frame. Python owns mode tails, summary, and clipboard/open.

## Modes

- web: full-res PNG plus Windows clipboard. Paste the image with the printed RESULT (the tool prints it; no scratch needed to see it).
- build: scaled PNG (default 50 percent) under `_logs/shots/`.
- user: full-res PNG and open it when done.

Command: `python3 tools/run_shots.py --mode web|build|user` (optional `--seed`, `--floor`, `--scale`, `--settle-ms`, `--timeout-sec`, `--show`, `--out`, `--hud 0|1`, `--fixed-fps N`, `--width`, `--height`, `--zoom`, `--px`, `--pz`, `--cx`, `--cz`, `--steps`, `--no-pixels`, `--dry-run`, `--json`; `--help` is the truth). Presets live in `tools/shot-recipes.json`.
Needs a real GL window, so a display: a Windows desktop with a GPU, or Linux (picked automatically, see Display; the Bot box has X on `:1` and `:2`). Default: HUD on, spawn pose, zoom 1, no taskbar, window parked off-screen.
Summary: `_logs/shots/summary.txt`; the last line is `RESULT PASS|INFO|FAIL band=... summary=_logs/shots/summary.txt`. The Godot launch and lock come from `godot_lib.py` (per-path lock, kills only its own pid).

## Full-floor map (`--full-map`)

`python3 tools/run_shots.py --full-map [--seed S] [--floor N] [--max-px 8192] [--keep-tiles] [--out P]` captures a whole dungeon floor and stitches it into one top-down PNG of the real render (the pixel twin of `run_dungeon_map.py` ASCII). Default out: `_logs/shots/fullmap-s{seed}-f{floor}.png`. Seed 42 floor 1 (426 x 414 cells) takes about 3 minutes and gives 6816 x 5569 px at the 8192 cap (native 27264 x 22275). Needs Pillow.

How: the runner writes a one-step flow (`{"op":"sweep"}`, `step_sweep.gd`) and forces scene dungeon, HUD off, zoom 1, 60 fps. The op streams every chunk (`stream_all`), freezes the player, hides the player and enemies, then walks a grid of tiles: teleport the player, `rig.follow`, tick the stream and light a few frames, read the frame. Tile centres are chosen so the camera shift between tiles is a whole number of pixels (`offset_resid` 0.0 in the log), so tiles butt together with no blending. Each tile keeps only its centre (`keep_x` 192, `keep_y` 112 px trimmed per side) because light sources and the light window follow the player, so tile edges are lit differently from play. `--max-px` box-reduces by a power of two until the long side fits (0 = native). `--keep-tiles` keeps `tiles/` and `sweep.json` next to the PNG for debugging.

The log line `SHOT: stitch ...` reports tiles, native and output size, `offset_resid`, and seam numbers (`seam_mean_diff`, `seam_bad_px`: the same world pixels as seen from the two tiles either side of each cut; flicker and light edges cause small differences; seed 42 floor 1: mean 0.17, 12 of 892 cuts over 4, worst 19). Same seed and floor give a byte-identical PNG.

Not shown by design: player, enemies, HUD, minimap. Knobs live on the `sweep` op (`margin`, `frames`, `keep_x`, `keep_y`; see `shot-flows.md`); a new flag is not needed to change them, edit a flow.

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

- Scenes `dungeon`, `camp`, `hub` (HUD on shows the HUD and minimap only; the full-screen dungeon map stays closed); camera pose (`--px --pz --cx --cz --zoom`, recipes); HUD on/off; window size (`--width --height`).
- **Scripted flows** (`--steps FILE`, or `run_shot_flow.py`): talk to an NPC or open any panel, press gamepad / key / action input, set game state, wait, shoot every page, assert state and text. One worker boot runs the whole list. Ops below. This is the answer to "a menu, dialogue or tutorial page needs a picture".
- Still not staged: crop-to-object beyond `crop` on a Control, dungeon-side UI states without a flow of their own (add the flow, not a hand run).

## Display

Shots need a real GL frame; `godot_lib.pick_display()` chooses: `$DISPLAY` if the X server answers, else the first live socket in `/tmp/.X11-unix`, else the command is wrapped in `xvfb-run` (software GL is fine). `python3 tools/godot_lib.py --display` prints the choice. Windows needs no display. Headless Godot cannot draw pixels, so `--no-pixels` flows (asserts only) and the smokes are the only headless runs. Bake: `run_bake_camp.py` uses the same pick; the shadow projection is CPU-side, so a headless bake gives the same atlas, but the real renderer is the default (`--headless` forces the old driver).

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
