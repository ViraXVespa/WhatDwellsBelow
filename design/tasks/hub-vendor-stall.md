# Vendor stall geometry, collision, sticks

id: hub-vendor-stall
owner: web
status: open
done-when: Player and shadow correctly sort behind all parts of the vendor stall; walls and front face flush with the ground and connected to the posts for one uniform collision box; hub rebaked so shadows and lighting are final.
resume: (web) start by naming this task in a web session; no open_slice command.

## Intent
Finish vendor stall geometry, collision, and sorting. Posts are locked. Shadow still draws on the tarp. Walls need to be flush and connected. Then rebake the hub.

## Refs
- stall-current.jpg

## Current state (accurate)
- Posts are correctly positioned and uniform height:
  - Front: X = ±box_size.x * 0.48, Z = box_size.z * 0.52, top = y_eave - 0.01
  - Rear: X = ±box_size.x * 0.48, Z = -box_size.z * 0.48, top = y_eave - 0.01
  - Foot at -box_size.y * 0.5 (flush).
- Player sprite occlusion is fixed (tarp ShaderMaterial render_priority + sorting_offset). Player is fully behind the tarp in the proof pose.
- Shadow still appears on the tarp. It comes from the hub light RT (hub_shadow.gd projects the player Sprite3D onto the ground-plane light image; the tarp's wrap_shader samples that light_tex by world XZ). Posts already block shadows via the existing footprint protection (prot). The tarp does not, because its AABB bottom is above SKIP_H so it is not added to prot. The bake is precomputed (hub_light.png); changes to hub_shadow.gd only affect a fresh bake.
- Walls / front face / collision are not yet flush with the ground or connected to the post positions. Extra space above the front face needs a short fill wall (hidden by the fold).

## Remaining work
1. Fix the shadow sorting so the player shadow does not appear on the tarp/ceiling. Prefer a programmatic solution that uses the existing footprint protection (extend it so elevated roof/tarp meshes also protect their XZ footprint, the same way ground-level posts already do). Avoid hardcoded stall rectangles. After the change, force a hub rebake so the light RT updates.
2. Make all walls and the front face flush with the ground (bottom at -box_size.y * 0.5) and connected to the post positions (X ±0.48, Z front 0.52 / rear 0.48) so the stall is one uniform collision box. Fill the extra space at the top of the front face with a short wall segment; the roof fold will hide it.
3. Rebake the hub (LightRt.rebuild_hub / save_hub_bake) so the final shadows and lighting are pretty.

## Notes
Posts locked at the values above. Player sprite sort fixed. Shadow is an RT sampling issue, not a mesh sort issue. Walls still need the flush + connect pass. Do not trust older notes about post multipliers or "occlusion still unresolved".

Use `run_shots.py --mode web --scene camp --hud 0 --zoom 3.2 --px 25.0 --pz 6.2 --cx 0.0 --cz -1.8` to check the shadow issue. After the shadows are fixed, we'll have you set up a shot flow that captures the vendor stall from all angles so we can check everything.