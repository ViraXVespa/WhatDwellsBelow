---
name: i2v-isolated
description: >
  Isolate What Dwells Below Image-to-Video jobs (image_to_video, one animation
  unit, walk / attack / gather / death / dispel clip). Use when the User or the
  session is about to generate or retry an I2V clip in the game repo. Do not
  use for stills, tiles, UI icons, image_gen, pack, harvest, or Godot edits.
user-invocable: true
metadata:
  short-description: Isolate I2V outside the game repo
---

# I2V isolated

Read `design/isolated-media.md` and `design/art-i2v.md`. Those files are binding.

You are the **parent** in the game repo. Do not call `image_to_video` here unless `design/isolated-media.md` **In-session exceptions** matches.

In this repo first:

1. Build the seed and prompt with `tools/i2v_seeds.py` (opaque `#FF00FF` plate, idle Bible cell, one gender × facing × action).
2. Stop if the User has not approved that seed / prompt yet.
3. Run `tools/run_isolated_grok.py --kind i2v --seed <png> --prompt-file <txt>`.

The child follows bundled `imagine`, `game-asset-core`, and `game-animation-frames`. Motion text is the staged prompt, not cinematic 6s/10s shot language. The child does not harvest or pack.

One unit, then stop for the User. After accept, pack in this repo per `design/art-pack.md`. Do not queue the next facing, action, gender, or retry until the User says so. Do not resume the parked coil / attack-keyframe door unless the User opened `design/art-attack-keyframes.md`.