# Harvest, pack, and cleanup

Status: current plan  
Read when: the User has accepted an I2V clip and it is time to harvest or pack  
Code: `tools/pack_locomotion.py`, `tools/pack_oneshot.py`, `tools/plate_remap.py`, `tools/sprite_pipeline.py`


## Frame counts after harvest

Walk harvest targets **8 frames** for `walk` when the clip supports it. `idle_to_walk` / `walk_to_idle` may be shorter (often 3–4) so long as both genders and all eight facings of that *state* share one count.

The same frame-count rule applies to every animation state: all eight facings of that state share one frame count. Attack / special / gather pack to 6 frames per facing. Death and Dispel keep the accepted clip length (Dispel may be long); those two states still share one count across the eight facings.

Pack one-shots with `tools/pack_oneshot.py` from `_src/sources/clips/oneshot/{gender}_{action}_{facing}.mp4`. Walk harvest stays `tools/pack_locomotion.py` and reads `_src/sources/clips/walk_final/{gender}_{facing}.mp4`.

Idle is not harvested from the video. Walk-clip state cuts stay with the I2V-unit job on art.

If harvest cuts fail but the clip is good, adjust pack points. Do not invent a new I2V method.

## Cleanup after accept

After the User accepts a clip and harvest exists:

1. If the plate is not `#FF00FF`, run `tools/plate_remap.py` first.
2. Colour-to-alpha the plate. Sample the plate from the border. Strong black, white, and blue border pixels are subject samples, not the key. Glow and the soft edge stay partial alpha. Solid plate becomes transparent black. Do not invert RGB to despill, and do not snap the fringe to a hard matte.
3. Fit each frame to the 128×128 canvas. Nearest-neighbor only when sizing up. When sizing down, use a premultiplied high-quality resize.
4. Snap to the locked palette.
5. Keep the soft edge as alpha. Do not strip fringe that colour-to-alpha already turned into transparency.
6. Align the foot baseline across the strip.
7. Confirm 8-direction parity and matching frame counts per state.

Do not ship a frame that still has start-chroma rims or a soft magenta halo.

Then the User judges the packed strip. Do not start the next unit until the User says so.

## Still rekey

The open set is the rekey-assets task. One colour-to-alpha: `tools/imglib/key.py` `chroma_alpha` against the border-sampled key. Strong black, white, and blue border pixels are subject samples. Glow and soft shading stay partial alpha. Solid plate becomes transparent black. `c2a` snaps alpha under 10 to 0 and over 242 to 255. That snap is the hard matte. Do not use it.

Do not wrap that in a fringe walk, a subtract of red-and-blue-above-green, or a resize hairline. Those three deleted the veil, the outlines, and the bowstring on 2026-10-09. Do not nearest-upscale the plate before the key. That distorted the female face.

Proof is `python tools/rekey_preview.py`, then `show_png.py` on the paths it prints. The counts are the check. A picture description is not a pixel count. This is not a play-camera shot, and the gate is `run_build_gate.py --batch` with no `--visual`. Do not match the live PNG while the task calls that PNG rejected. The source plate is the reference.

`rekey_preview.py` stays in `tools/`. Do not write another preview under `_logs/agent-py/`. `run_agent_py.py` deletes those after the run.
