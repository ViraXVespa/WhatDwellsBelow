# Hub light leak + dumpster shadow, bake/shadow checks with planted faults

id: hub-bake-checks
owner: bot
status: open
done-when: bake.py check PASSes with the leak check and its selftest (planted rim FAILs), shots.py flow --flow camp-prop-shadows PASSes with a planted on_face fault FAILing, before/after crops reported, png rebake pushed with Vira's OK
resume: python tools/docs.py task show hub-bake-checks, then the dumpster section

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

## Light leak: fixed on refactorer-catchup
`HubBlur.zones` keeps the blur inside each footprint; `bake_leak.py` (in `bake.py check`, selftest plants a rim) FAILed the old png (hall S +17.8, E +18.5; reception S +17.8, E +18.3 grey, tol 4.0) and PASSes the rebake. Rebake approved by Vira for the lantern regression fix.

## Next
1. Dumpster (above): name the cause, add the planted-fault selftest.
