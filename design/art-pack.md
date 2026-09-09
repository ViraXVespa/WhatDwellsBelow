# Harvest, pack, and cleanup

Status: binding design  
Read when: the User has accepted an I2V clip and it is time to harvest or pack  
See also: `design/art-pipeline.md`, `design/art-i2v.md`, `design/player.md`  
Code: `tools/pack_locomotion.py`, `tools/pack_oneshot.py`, `tools/plate_remap.py`, `tools/sprite_pipeline.py`

Open this file from the door. Do not harvest a rejected clip.

## Frame counts after harvest

Walk harvest targets **8 frames** for `walk` when the clip supports it. `idle_to_walk` / `walk_to_idle` may be shorter (often 3–4) so long as both genders and all eight facings of that *state* share one count.

The same frame-count rule applies to every animation state: all eight facings of that state share one frame count. Attack / special / gather pack to 6 frames per facing. Death and Dispel keep the accepted clip length (Dispel may be long); those two states still share one count across the eight facings.

Pack one-shots with `tools/pack_oneshot.py` from `_src/oneshot/{gender}_{action}_{facing}.mp4`. Walk harvest stays `tools/pack_locomotion.py`.

Idle is not harvested from the video. See `design/art-i2v.md` for which packed states come from a walk clip.

If harvest cuts fail but the clip is good, adjust pack points. Do not invent a new I2V method.

## Cleanup after accept

After the User accepts a clip and harvest exists:

1. If the plate is not `#FF00FF`, run `tools/plate_remap.py` first.
2. Range-key / wand the `#FF00FF` plate. Despill fringe. `sprite_pipeline.py` `key_to_alpha` punches the plate. Video extracts and session stills pass `spill_flood=False` after remap so compressed maroon / hair / purple cloth is not treated as plate. Then **snap alpha hard** (figure `255`, plate `0`) before any fit so Color-to-Alpha cannot leave a magenta-ish lip on dark backdrops.
3. Fit each frame to the 128×128 canvas with nearest-neighbor only. Integer scale. No bilinear.
4. Snap to the locked palette.
5. Remove anti-aliased edge pixels.
6. Align the foot baseline across the strip.
7. Confirm 8-direction parity and matching frame counts per state.

Do not ship a frame that still has start-chroma rims or a soft magenta halo.

Then the User judges the packed strip. Do not start the next unit until the User says so.
