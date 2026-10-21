---
name: imagine-isolated
description: >
  Isolate Grok Imagine stills for What Dwells Below (tiles, character stills,
  overlays, UI screens / panels / mockups / icons, image_gen, image_edit). Use when the User or the session
  is about to generate a still or tile in the game repo. Do not use for
  image_to_video / I2V clips (that is i2v-isolated). Do not use for pack,
  remap, glyphs, export, or Godot edits.
user-invocable: true
metadata:
  short-description: Isolate Imagine stills outside the game repo
---

# Imagine isolated

Read `design/isolated-media.md` and follow it. That file is binding.

You are the **parent** in the game repo. Do not call `image_gen` or `image_edit` here unless that file’s **In-session exceptions** row matches.

Pick `--kind`:

- world tile / roof / ground / wall → `tile`
- Bible, facing variant, overlay-on-body → `character`
- UI screen, menu, panel, HUD, mockup or icon → `ui` (text allowed; a no-text icon says so in `--brief`; `--dest-name` names the file, subfolders allowed)
- none of the above → `still`

Run `tools/run_isolated_grok.py` with that kind. Pass `--bible-style` when the locked Bibles should travel as style or identity sheets. Pass `--copy` for any other staged reference (one clean body frame for an overlay). Pass `--brief` for the User’s material / subject. The runner caches an ingest session per reference-file hash and forks later gens from it. Stop after the runner prints `results=` / `keep=`.

The child follows bundled `imagine` and `game-assets`. On a still job, read the one `game-assets` reference for that kind, not `animation.md`.

Review the output with the User before replacing any file under `assets/`.
