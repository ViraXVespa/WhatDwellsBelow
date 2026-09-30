# Postcard shot tool

Status: binding design
Read when: postcard shot, run_shots, visual proof clipboard, _logs/shots

Not a numbered P1-P9 smoke. Not Imagine.

## What it is

Unattended play-camera postcard. Godot paints a real GPU frame. Python owns mode tails, summary, and clipboard/open.

## Modes

- web: full-res PNG plus Windows clipboard. Paste the image with the scratch RESULT.
- build: scaled PNG (default 50 percent) under `_logs/sess/<session>/shots/`.
- user: full-res PNG and open it when done.

Command: `python tools/run_shots.py --mode web|build|user` (optional `--seed`, `--floor`, `--scale`, `--settle-ms`, `--timeout-sec`, `--show`, `--out`, `--hud 0|1`, `--width`, `--height`, `--zoom`, `--px`, `--pz`, `--cx`, `--cz`, `--taskbar 0|1`).
Default: HUD on, spawn pose, zoom 1, no taskbar, window parked off-screen.
Summary: `_logs/sess/<session>/shots/summary.txt` (falls back to `_logs/shots/` when no agent session exists).

## Worker

Flag `--wdb-shot` plus `--wdb-shot-seed`, `--wdb-shot-floor`, `--wdb-shot-out`, `--wdb-shot-scale`, `--wdb-shot-settle-ms`, `--wdb-shot-show`.
Boots past splash/title through the existing CLI multiplexer, `begin_run` on that seed/floor, forces stream, settles, captures the play viewport, prints `SHOT:` marks, quits.
Rendering driver is `d3d12`. Audio is Dummy. Do not pass `--headless` or `--display-driver headless` (that pair is Dummy rasterizer and yields no pixels).
Default window: no-focus, borderless, popup-wm-hint, parked off the primary screen, still WINDOWED so the frame keeps drawing. `tools/run_shots.py` also polls Godot HWNDs by PID and sets `WS_EX_TOOLWINDOW` so the process stays off the taskbar. `--show` or `--taskbar 1` leaves the tab visible.

## Bands

Numbers live on `tools/run_shots.py`: `BUILD_SCALE_PCT = 50`, `SETTLE_MS = 1000`, `TIMEOUT_SEC = 180`, `WARN_BYTES = 2048`.
good: PNG exists, `SHOT: ok=true`, bytes at or above warn floor.
warn: PNG exists but bytes below warn floor.
fail: timeout, nonzero Godot exit, no image, or script error.
Do not attach PNG bytes to the CLI transcript.

## Extension test

Add a knob only when a session cannot take the needed picture without it. One flag or one preset, one prove shot, then stop. Crop-to-object, custom camera, UI pages, and earlier boot hide are later knobs.
