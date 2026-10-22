# Vendor stall geometry, collision, sticks

id: hub-vendor-stall
owner: web
status: open
done-when: Ceiling sorts correctly behind/with character; front face blocks player; side sticks visible and aligned with existing collision; right wall present so bake can shadow it.
resume: (web) start by naming this task in a web session; no open_slice command.

## Intent
Fix vendor stall sorting, collision, missing sticks, and right-side wall from the hub issue list.

## Refs
- stall-character.jpg — player near stall (ceiling sort / walk-through)
- stall-front.jpg — front face of stall
- stall-side.jpg — side view (missing sticks)
- stall-top.jpg — top-down stall
- missing-wall-shadow.jpg — right-side wall / shadow gap

## Notes
Geometry, collision, posts, and right wall fixes applied in solid + pitched_tarp. Sorting set for proper occlusion. web-session.md clarified on parked task flow.

## resume
(web) front collision is verified fixed. Posts are visible (currently hidden behind the shop face) but still not aligned to the black edges of the face. Attempted post multipliers: original 0.42, then 0.49/0.50 (too far out), 0.38 (too far in), 0.45 (still off). Tarp-vs-player occlusion is still completely unresolved (player draws on top of the tarp; ShaderMaterial vs Sprite3D sort). Right-wall mesh and bake-stamp experiments landed locally. Next session starts from the live files and the latest-*.jpg images already in this task's refs.
