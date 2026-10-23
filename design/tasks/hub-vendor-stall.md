# Vendor stall geometry, collision, sticks

id: hub-vendor-stall  
owner: web  
status: open  
done-when: Player and shadow correctly sort behind all parts of the vendor stall; walls and front face flush with the ground and connected to the posts for one uniform collision box; hub rebaked so shadows and lighting are final (no horizontal light leak in the front shadow).  
resume: (web) start by naming this task in a web session; no open_slice command.  

## Intent  
Finish vendor stall geometry, collision, and sorting. Posts are locked. Walls and face are in place. Remaining issue is a horizontal bright line in the baked front shadow that has survived every geometry change to the front wall.

## Current state (accurate as of this handoff)  
- Face sprite is visible and positioned at the post front plane (`box_size.z * 0.52`).  
- Solid front wall exists just behind the sprite (`front_z - 0.001`). Its foot has been extended below ground. Sprite casting is disabled.  
- Side and back walls are present and aligned to the outer post faces (hx = post_hx + thickness - 0.001).  
- Posts and walls use FLOOR_Y (-0.02) for ground contact.  
- Bake stamp updates correctly (`run_bake_camp.py` writes HUB_BAKE_STAMP).  
- The horizontal bright line in the front shadow (visible in close-up bake images) remains. It is not removed by changing the front wall’s height, depth, thickness, or foot position. The baker (`_hub_fill` / `_hub_ground`) is the next place to look.

## Remaining work  
1. Identify why the baked front shadow still contains a clean horizontal bright strip. The front wall geometry has been ruled out as the direct cause. Inspect the projection path in `hub_shadow.gd` (`_hub_ground`, protected footprints, barycentric fill) and any other stall casters (tarp, posts) that could produce the strip.  
2. Once the strip is gone, confirm the face, walls, and posts remain flush and the stall looks correct from the vendor-stall recipe.  
3. Final hub rebake.

## Notes  
Geometry and face are in a usable state. Bake gap is the open item. Fresh session recommended.
