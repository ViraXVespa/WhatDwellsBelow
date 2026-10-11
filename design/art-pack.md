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

1. (No remap step: the keyer samples a drifted plate itself.)
2. Key the plate with the staged keyer (`Still rekey` below).
3. Fit each frame to the 128×128 canvas. A flat nearest upscale is reduced to its pixel grid first. Nearest-neighbor only when sizing up after that. When sizing down, use a premultiplied high-quality resize.
4. Snap to the locked palette.
5. Keep the soft edge as alpha. Do not strip fringe that colour-to-alpha already turned into transparency.
6. Align the foot baseline across the strip.
7. Confirm 8-direction parity and matching frame counts per state.

Do not ship a frame that still has start-chroma rims or a soft magenta halo.

Then the User judges the packed strip. Do not start the next unit until the User says so.

## Still rekey

The open set is the rekey-assets task. Regression plates are in `assets/keytest`.

The keyer is `tools/imglib/matte.py` (`key_to_alpha` and `punch` in `imglib/key.py` call it). Key the source plate directly; no remap first. Stages, each with a debug PNG:
1. Denoise: a 3 px median on the chroma planes only, for classifying. The output keeps the drawn RGB.
2. Plate: the median of border pixels on the plate hue, per image. Drift such as (242,5,181) is normal.
3. Trimap: background is the border flood through plate-coloured pixels, enclosed plate pockets, and plate drift (within the plate's noise of the local plate colour). Solid is paint and stays opaque with its drawn RGB. Everything else outside the hard edge is soft: edge ring, glow, and edge paint that is a plate mix (lavender between magenta and a pale blue glow). Small saturated plate-hue specks in the paint (plate through a tear, a tip pixel) and lavender with plate chroma near the plate are plate mix too. Purple or maroon paint is not plate unless it is bright and on the plate hue.
4. Unmix: one continuous alpha field over all soft pixels, pixel = a*C + (1-a)*plate. G is the rim paint's colour carried smoothly outward. Alpha blends (by how well the pixel fits) the projection onto the plate -> G line and an own-colour estimate for thin lines; In a wide glow the alpha is smoothed (guided by the source's luma) and faded to 0 with a smoothstep across the plate's noise band; a glow runs on into the paint until it reaches its full colour, and only the hard edge next to paint snaps opaque. No separate ring/glow methods, so no rings or cuts.
5. Despill: mixes lose plate-direction chroma (YCrCb) above G's, so glows keep the art's hue at every alpha; edge paint has magenta excess limited to its own.
No halo is painted; every partial alpha is measured from the plate. OpenCV is required.

Proof: `python tools/keytest.py` keys every plate in `assets/keytest` and checks the numbers in `tools/keytest_expect.json` (plate left, magenta left, plate hue left anywhere, green specks, interior opacity, orb glow profile: rings, kinks, blotches and tail length against the source, foreground share against the recorded value, identical repeat, keyer callers). It writes `_logs/keytest/sheets/<name>.png` (source | checker | dark | light) and `overview.png`. Look at the sheets; a PASS is numbers, not the User's yes. `run_build_gate.py --batch` runs it. After an accepted keyer change, `--update` records the new foreground share. `--src DIR --out DIR` runs the generic checks on any folder.

A source that is a flat nearest upscale is reduced to that pixel grid before the fit. Transparent pixels do not count as colour in the cell test. Nearest-neighbor is only when both sides grow after that reduce. Sizing down stays a premultiplied high-quality resize.

Do not nearest-upscale the plate before the key. That distorted the female face.

`rekey_preview.py` fits the open set from `_src` the same way (blue composites). It needs the `_src` link.

