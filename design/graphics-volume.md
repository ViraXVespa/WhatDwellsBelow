# Graphics volume

Status: binding design + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, BoxShape on welded mass, provided ribbon

Default dungeon walls are coplanar 1 m brick runs on the cleaned maze grid. BoxMesh retirement still means the old per-cell slab skin, not a type hunt. Ribbon tech stays for angled pieces only: one thin run per long edge, any heading, same brick sheet. A cardinal hall with no ribbon is correct. A cardinal hall with a floor-wide ribbon is a volume miss. Do not invent rims. Do not extract a new silhouette from the walk mask. Do not kill 1 m faces because outline_spans exists on the floor.

Live files in this job: scripts/graphics/wall_mesh.gd, scripts/graphics/wall_shader.gd, and scripts/world/dungeon_geo_stream.gd (1 m runs, piece runs, the wall MeshInstance, interior floors, and collision that matches the mesh). Out: torch_plan.gd, light_rt.gd, light_stamp.gd, gen_outline.gd, and WallRects.merge used as a floor-wide ribbon or as a stair under an angled wall.

One brick sheet. On an angled piece, UV runs along the span tangent and world height so the run is one course. Do not hash `floor(xz)` on that ribbon. 1 m faces may keep tile UVs. Extra wear is shader-side hash/tint, not a second Imagine sheet. Do not rebuild an angled piece as a staircase of 1 m slabs. If two piece runs are the same wall, emit one ribbon. Fold near-collinear piece runs before skinning. Do not invent a second bake. Wall shader samples the same light RT as the floor. Drop the wall light minimum (max(lit, 0.42)). Stream rings and CHUNK stay. This job does not retarget occupancy or torches.

Tile chunks: merged interior floors, 1 m wall faces, BoxShapes on void that touches that floor. Piece chunks: band floor, slanted runs, hulls flush with those runs. _emit_floor_lip / _clip_cell as the default path is the miss on a maze hall. add_collision must not WallRects.merge a second staircase under a piece. Live may still take the outlined dual path until the consume slice.

Torches hang only on interior faces. The bracket sits on that wall face. Bracket uses a 4-facing unlit bible. Flame is code VFX on a Y-billboard; buffer owns it. This job emits the faces; buffer places the sources. Close each angled ribbon with a top cap and end caps. Caps use the same brick sheet and the same span-tangent / world-height UV. Do not extrude a 1 m slab along each piece run.

Hub buildings are not this job. Do not author arches or modular kits.
