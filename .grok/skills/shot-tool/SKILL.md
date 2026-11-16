---
name: shot-tool
description: >
  Capture a play-camera postcard from What Dwells Below with
  tools/shots.py capture. Use when a web, Build, or User session needs a
  visual proof of a fixed seed/floor. Do not use for numbered smokes,
  Imagine, or tiled world assets.
when-to-use: >
  visual proof, postcard shot, clipboard screenshot, _logs/shots,
  run_shots, seed/floor still, offscreen viewport capture.
user-invocable: true
---
# Screenshot capture

Read design/shot-tool.md once per session and follow it.
After a context break, resume from saved task state rather than repeating completed reads.

Run from repo root: `python tools/shots.py capture --mode web|build|user`.
Read only `python tools/session.py summary --job shots` (index first, newest run; last line is the RESULT line).
Web mode: paste the clipboard image with the printed RESULT (no scratch needed). Do not dump PNG bytes into chat text.

Do not pass Godot `--headless` or `--display-driver headless` for a postcard (Dummy rasterizer, no pixels).
The PNG is an offscreen SubViewport at the requested size. The OS window is a small GL host, not a hidden window. `--show` only when the User wants to watch. A height 4 or 8 pixels under the ask (1080 coming back 1076 or 1072 from window chrome) still passes; a width miss fails. Build mode's 50% frame is the visual check; a few-pixel mark is judged on the 100% crop (`shots.py crop` or `shots.py zoom --box`).

Text in a shot: `python tools/shots.py ocr PNG --box X,Y,W,H --expect "text"` (local Tesseract) first; an LLM read only when it rates weak/fail, Tesseract is unavailable, or you need meaning. Isolated `shots.py review` stages local OCR/crop/zoom/diff helpers and full-size sources; text questions get an automatic OCR attempt and a content-bound hook receipt. Ordinary visual reviews remain available without OCR. `--why REASON` is a logged exception, not host permission.

Source map, adding a knob, troubleshooting: the doc above. If the tool is awkward, fix the tool, do not work around it.
Gap: when the picture needs a UI page or staged state the tool cannot set, extend the tool as part of the task (one knob at a time, one prove shot, documented in the doc's gap process). Do not work around it. A new tool is fine when it will help later tasks; tell the User afterward (design/tools.md rule 5).
