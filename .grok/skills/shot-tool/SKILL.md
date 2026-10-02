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
Read only `_logs/shots/summary.txt` (last line is the RESULT line).
Web mode: paste the clipboard image with the printed RESULT (no scratch needed). Do not dump PNG bytes into chat text.

Do not pass Godot `--headless` or `--display-driver headless` for a postcard.
Default hides the window off-screen and strips the taskbar tab from the Godot HWND. `--show` or `--taskbar 1` only when the User wants to watch.

Source map, adding a knob, troubleshooting: the doc above. If the tool is awkward, fix the tool, do not work around it.
Gap: when the picture needs a UI page or staged state the tool cannot set, extend the tool as part of the task (one knob at a time, one prove shot, documented in the doc's gap process). Do not work around it. A new runner is still propose-first.
