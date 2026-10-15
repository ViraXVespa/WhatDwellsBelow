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

The open set is the rekey-assets task. Source plates live under `_src/sources`, mirrored to the live path. `assets/keytest` is retired.

The keyer is `tools/imglib/matte.py` (`key_to_alpha` and `punch` in `imglib/key.py` call it). Key the source plate directly; no remap first. Stages, each with a debug PNG:
1. Denoise: a 3 px median on the chroma planes only, for classifying. The output keeps the drawn RGB.
2. Plate: the median of border pixels on the plate hue, per image. Drift such as (242,5,181) is normal.
3. Trimap: background is the border flood through plate-coloured pixels, enclosed plate pockets, and plate drift (within the plate's noise of the local plate colour). Solid is paint and stays opaque with its drawn RGB. Everything else outside the hard edge is soft: edge ring, glow, and edge paint that is a plate mix (lavender between magenta and a pale blue glow). Small saturated plate-hue specks in the paint (plate through a tear, a tip pixel) and lavender with plate chroma near the plate are plate mix too, as are pale lavender patches reaching background or glow (plate seen through a see-through rim): keyed with the largest alpha that leaves no plate-ward chroma. Purple or maroon paint is not plate unless it is bright and on the plate hue.
4. Unmix: one continuous alpha field over all soft pixels, pixel = a*C + (1-a)*plate. G is the rim paint's colour carried smoothly outward. Alpha blends (by how well the pixel fits) the projection onto the plate -> G line and an own-colour estimate for thin lines; In a wide glow the alpha is smoothed (guided by the source's luma) and faded to 0 with a smoothstep across the plate's noise band; a glow runs on into the paint until it reaches its full colour, and only the hard edge next to paint snaps opaque. Sparkles in a glow are paint over glow: unmixed against the source just around them and laid over the keyed glow, so the glow runs on underneath. No separate ring/glow methods, so no rings or cuts.
5. Despill: mixes lose plate-direction chroma (YCrCb) above G's, so glows keep the art's hue at every alpha; edge paint has magenta excess limited to its own.
No halo is painted; every partial alpha is measured from the plate. OpenCV is required.

Proof: `python tools/keytest.py` keys every plate in `assets/keytest` and checks the numbers in `tools/keytest_expect.json` (plate left, magenta left, plate hue left anywhere, green specks, interior opacity, orb glow profile: rings, kinks, blotches and tail length against the source, foreground share against the recorded value, identical repeat, keyer callers). It writes `_logs/keytest/sheets/<name>.png` (source | checker | dark | light) and `overview.png`. Look at the sheets; a PASS is numbers, not the User's yes. `run_build_gate.py --batch` runs it. After an accepted keyer change, `--update` records the new foreground share. `--src DIR --out DIR` runs the generic checks on any folder.

Sizing (`imglib/geom.py` `resize_rgba`). Nearest-neighbor only when both sides grow. Sizing down: art drawn in flat cells (pixel art, AI pixel art on a loose grid, JPEG noise on top) takes the median of the centre of each output pixel's footprint (`cell_reduce`), so cell edges are never averaged; anything else is premultiplied Lanczos. Either way `snap_edges` keeps hard edges hard: a footprint that jumps from clear to paint takes the side it is mostly on, a thin line through it (bowstring, sub-pixel outline) stays paint in the line's colour, and a glow that changes slowly keeps its partial alpha. A box average over a guessed grid blurred every cell edge: that was the 2026-10-13 global quality loss.

Placement (`geom.fit_like`). A rekeyed still lands exactly like the live still it replaces: same canvas and mode, the solid body (alpha >= 128) scaled to live's body and lined up on live's bottom edge and centre x. No recentring and no padding of its own. A manifest `flip` row is placed like the mirrored live still and then mirrored, so it is exactly its right-facing sibling's mirror. The keyer also drops a thin frame of paint along the picture's own border (a crop seam) so it cannot stretch the body box.

Full set: `python tools/rekey_all_stills.py --out DIR --jobs 8` writes a review copy (live `assets/` untouched); `python tools/rekey_check.py --new DIR` scores every row against live and the plate (canvas, quality, hard, shift, pad, mirror, plate, alpha, stale, lost) into `_logs/rekey-check/last.json`. Live art with no alpha (tiles, finished pictures) has nothing to key and is kept; a plate that no longer matches live is reported stale (live is the truth), and a key that loses the subject (paint on the plate's own hue) keeps live and is reported lost. The out-of-bounds stills are kept unless `--include-frozen`.
Snap: an edge is snapped only when it is hard at source scale (clear and paint in one footprint with at most 35% of it partial alpha, `geom.SOFT_SHARE`); a wider ramp (glow, energy, translucent rim) keeps its partial alpha. `rekey_check` class `soft` flags a soft subject (partial alpha wider than half an output pixel on 3%+ of the plate's subject, `DIR/_soft.json`) that kept under half of it.
Edge side and soft alpha come from each output pixel's exact (fractional) footprint (`geom._coverage`), not the integer sample windows, which drift against a 3.2x footprint and cut notches. A thin line is kept only where clear lies on two opposite sides (`_thin`). Whole-cell box reduce never goes below the target size. `rekey_check` class `notch` flags 2+ px clear where the area-averaged source is mostly paint (shrinks of 1.5x+).
Re-runs: placement uses the manifest `fit` geometry ([W, H, x0, y0, x1, y1], live before any rekey, recorded with `--record-fit REV`), not the current live file, so a re-run reproduces its output. Rows marked `approved` stay as live (`--rekey-approved` shows what the current key would make) and must reproduce live byte for byte: `python tools/rekey_all_stills.py --check` (in the build gate).

Do not nearest-upscale the plate before the key. That distorted the female face.

`rekey_preview.py` fits the open set from `_src` the same way (blue composites). It needs the `_src` link.
