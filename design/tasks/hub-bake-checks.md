# Hub light leak + dumpster shadow, bake/shadow checks with planted faults

id: hub-bake-checks
owner: bot
status: open
done-when: bake.py check PASSes with the leak check and its selftest (planted rim FAILs), shots.py flow --flow camp-prop-shadows PASSes with a planted on_face fault FAILing, before/after crops reported, png rebake pushed with Vira's OK
resume: python tools/docs.py task show hub-bake-checks, get Vira's OK for the hub_light.png rebake, then python tools/bake.py check

## When
Bot session on Saturday, Oct 31, 2026 (Vira's wrap-up of Oct 25 vendor-fixes).

## Intent
Vira's hub review on vendor-fixes (review grid hub-buildings, frame 7, and the reception crop from the play camera). Two faults are left:
1. A thin warm glow runs around the guild hall and reception outlines, over the yard just outside the walls.
2. The dumpster's shadow reads as if it sits on the dumpster's front face.

Fix both. Make the bake/shadow check catch each one, and prove it with a planted fault: the check FAILs on the fault and PASSes after the fix. Do not touch the path fade or the vendor's stacked shadow; Vira wants those left as they are.

## Already done (a8638e9a and the commit before it)
- Stall front no longer z-fights: the front wall is `SHADOWS_ONLY`, so the bake is byte-identical.
- Stall walls show lit timber planks (`STALL.plank_m`).
- Reception lantern now hangs from the awning hem beside the window (`WING.hang` / `hang_x`, `lamps.gd _hung`).
- The aim line (`aim_line.gd`) is depth-tested, so the sword swing no longer draws over the stall walls.
- Review frame `stall-tarp` is relabelled. The player hidden under the tarp is intended; that frame checks tarp occlusion only.
- New check: `scripts/debug/hub_shadow_check.gd` plus the flow `camp-prop-shadows`. It checks each marked prop's sun mark: on the ground, on the sun-away side, at least `MIN_AWAY` away, and under 20% on the prop's visible face. It PASSes for every prop:
  - dumpster away=0.26, on_face=0.08
  - anvil 0.30/0.08
  - notice board 0.31/0.08
  - billboard 0.31/0.08

  A planted fault (dumpster mark pushed toward the sun) FAILed with `dumpster:not_sun_side away=-0.33`. That planted-fault proof was manual and is not a committed selftest.

## Dumpster: not reproduced
The dumpster has no baked shadow. Its runtime mark (ActorLit `marks[0]`) sits on the ground behind it and passes the face test. Next steps:
- Look at the review frame Vira flagged (the dumpster from the play camera, zoom 3.2) next to `shots.py flow --flow camp-prop-shadows` frame 01.
- If the dark patch is the sprite's own painted shading, or the hall's baked shadow, it is not the mark. Say which one.
- Add a planted-fault selftest, e.g. a `plant` var in `hub_shadow_check.gd` that moves the mark onto the face, with a flow step that asserts `bad` contains `on_face`.

## Light leak: cause found, fix drafted (not committed)
Cause: `HubBlur._blur_hub` (`scripts/graphics/light_rt/hub_blur.gd`) blurs the whole light map. The lit roof footprints bleed 3-5 texels (16 px/m) past the walls onto the shaded yard.

Measured before the fix (the new check FAILed): rim brighter than the yard by:
- hall S +14.8, E +18.4
- reception S +15.4, E +18.3

The tolerance is 4.0 grey.

Draft fix (rewrite it; about 9 KB of patch, lost on a cold box):
- `hub_shadow.gd`: add `static var prot_rects: Array = []` and set `prot_rects = prot` after `var prot := feet.values()`. The file stays under 10 KB at 9961 B, so trim the comments.
- `hub_blur.gd`:
  - Add `zones(img, origin, rects) -> PackedInt32Array`, giving a footprint id per texel and 0 for the yard.
  - Change `_blur_hub(img, zone := PackedInt32Array())` so it averages only same-zone texels (`_masked`) where a kernel spans two zones (`_mixed`).
- `hub_bake.gd`: call `HubBlur._blur_hub(img, HubBlur.zones(img, Vector2(x0, z0), HubShadow.prot_rects))`.
- New `tools/bake_leak.py`:
  - `record()` writes the footprints to `tools/data/hub_bake_feet.json`, called from `run_bake_camp.py` after `bake_inputs.record`.
  - `problems()` compares each footprint side's rim (3-5 texels out) with the yard further out. LEAK_TOL is 4.0 and corners are skipped (CORNER 4).
  - `selftest()` plants a bright rim and expects a FAIL.
- `check_hub_bake.py`: add those problems and the selftest. A `--props` option that runs the camp-prop-shadows flow is optional; if you add it, update the comments in the check and the flow.
- Footprints (min x, min z, w, d), with the org at -18,-18:
  - hall 5.4, 3.9, 5.6, 4.2
  - reception 10.88, 3.9, 3.8, 3.2
  - stall 22.712, 6.288, 4.576, 3.56

## Blocker
The fix changes `assets/baked/hub_light.png` through `bake.py camp`, and `tools/bot_allow.txt` denies `!assets/*`. So prove FAILs the allowlist and a Bot cannot push the rebake. Ask Vira to OK the rebake: either allow `assets/baked/hub_light.png` for this task, or have a Build session commit the png. Do that before rebaking.

## Next
1. Rewrite the draft fix.
2. Run `bake.py check` on the old png and confirm the leak lines FAIL.
3. Run `bake.py camp`, then `bake.py check`, and confirm it PASSes.
4. Make before/after crops of the hall and reception outlines with the hub-buildings recipe (`shots.py capture --scene camp --mode build --scale 100 --recipe hub-buildings`). Do not commit media.
5. Changelog line.
6. Push once the png is allowed.
