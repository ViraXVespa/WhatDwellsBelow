---
name: shot-tool
description: >
  Capture a play-camera postcard from What Dwells Below with
  tools/run_shots.py. Use when a web, Build, or User session needs a
  visual proof of a pinned seed/floor. Do not use for numbered smokes,
  Imagine, or tiled world assets.
when-to-use: >
  visual proof, postcard shot, clipboard screenshot, _logs/shots,
  run_shots, seed/floor still, hide Godot window for a capture.
user-invocable: true
---
# Postcard shot

Read design/shot-tool.md once per session and follow it. That file is binding.
Do not reopen this skill or that file after compact.

Run from repo root: `python tools/run_shots.py --mode web|build|user`.
Read only `_logs/sess/<session>/shots/summary.txt`.
Web mode: paste the clipboard image with the scratch RESULT. Do not dump PNG bytes into chat text.

Do not pass Godot `--headless` or `--display-driver headless` for a postcard.
Default hides the window off-screen and strips the taskbar tab from the Godot HWND. `--show` or `--taskbar 1` only when the User wants to watch.

Extension test: add a knob only when this session cannot take the picture without it.
Propose the knob, wait if it is a new owner, prove with one shot, stop.
