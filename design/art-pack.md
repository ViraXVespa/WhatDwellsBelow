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

The keyer is `tools/imglib/matte.py` (`key_to_alpha` and `punch` in `imglib/key.py` call it). Key the source plate directly at full resolution; no remap first. Order (`key(im, debug=DIR)` dumps plate, trimap, alpha, keyed):
1. Clean plate: border pixels on the plate hue are clustered in YCrCb; the sure plate is the border flood within 3 sigma of the local plate plus enclosed plate pockets; B(x) is that plate inpainted under the subject. Drift and gradients (B 153..243) follow B(x).
2. Trimap: unknown is the edge band plus plate-tinted regions (magenta excess at least 15% of the plate's) that reach the plate, hold a near-plate pixel, or are small shadowed-plate patches (armpits); paint deep inside (a pink robe) stays foreground.
3. Alpha: one solve, I = a F + (1 - a) B(x), F = the paint behind the edge carried outward; the projection onto B -> F, raised to the least alpha that keeps F in gamut. Alpha within the plate's noise is 0 (twice the noise beside hard paint, for JPEG ringing); specks that reach neither paint nor half coverage are dropped. No snapping.
4. Colour: F = (I - (1 - a) B) / a; faint pixels lean to the carried paint colour; magenta excess on the edge band limited to the paint's own.

Sizing (`imglib/geom.py` `resize_rgba`): nearest only when both sides grow; otherwise ONE premultiplied box (area) average, so alpha is exact coverage. Then `alpha_policy`, once, at output scale: `soft` keeps coverage (default for `assets/fx/`, and rows with manifest `"alpha": "soft"`: wisp, orbs), `crisp` (default) clears coverage under 12% and fills over 88% and keeps the anti-aliased middle, `hard` thresholds at half coverage. `geom.detect_grid` finds a pixel-art grid (pitch, phase); when its pitch is within 1.5% of the fit scale, the shrink uses it and starts on a grid line. A thin line (bowstring) keeps its true coverage; it is not thickened.

Placement (`geom.fit_like`). A rekeyed still lands exactly like the live still it replaces: same canvas and mode, the solid body (alpha >= 128) scaled to live's body and lined up on live's bottom edge and centre x. No recentring and no padding of its own. A manifest `flip` row is placed like the mirrored live still and then mirrored. The keyer drops a thin frame of paint along the picture's own border (a crop seam).

Full set: `python tools/rekey_all_stills.py --out DIR --jobs 8` writes a review copy (live `assets/` untouched) and `DIR/_metrics.json`; `python tools/rekey_check.py --new DIR` scores every row (canvas, quality, area, edge, halo, shift, pad, mirror, plate, alpha, stale, lost, notch) into `_logs/rekey-check/last.json`. area, edge, halo and notch compare the output with the exact area average of the same key. Live art with no alpha is kept; a stale plate is reported (live is the truth); a key that loses the subject keeps live (lost).
Golden set: `python tools/keytest.py` keys the truth mattes in `_src/truth` (nail, crack, lightning, tree, longbow, wisp, female idle) again from a drifting JPEG plate and checks alpha error, area, edge and halo (`keytest_expect.json`). The truth mattes come from the keyer and were reviewed once; `--make-truth` rewrites them only after the User accepts a new key.
Re-runs: placement uses the manifest `fit` geometry ([W, H, x0, y0, x1, y1], recorded with `--record-fit REV`), not the current live file. Every run rekeys every still; the only pass-throughs are opaque live art, the lost-subject guard and `SOURCE_WINS`. `python tools/rekey_all_stills.py --check` (in the build gate) runs the set twice and fails unless the runs are byte-identical. A pass is numbers, not the User's yes.

Do not nearest-upscale the plate before the key. That distorted the female face.

`rekey_preview.py` fits the open set from `_src` the same way (blue composites). It needs the `_src` link.
