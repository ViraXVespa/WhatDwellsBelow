# Graphics volume

Status: current plan + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, BoxShape on welded mass, provided ribbon

Dungeon wall visuals stop being one 1 m cell slab per cell (WallRects.faces / per-cell quads). BoxMesh retirement means that slab skin, not a Godot BoxMesh type hunt. Skin gen's provided hall runs as one thin ribbon per run (any heading, same brick sheet). Live already has a delta-span path and a faces fallback. When published runs exist for a chunk, do not keep the 1 m faces skin in that chunk. Live from_faces skips ortho faces, tops, ends, and void fill if any ribbon is present. A walkable hall with no ribbon or cap on a published run is a volume miss. Do not invent rims. Do not extract a new silhouette from the walk mask. Do not bake outline. Gen solid is the one bake; paint it bounded by the provided runs. Ortho faces from the solid are a fallback only when published runs are empty.

Live files in this job: scripts/graphics/wall_mesh.gd, scripts/graphics/wall_shader.gd, and the wall MeshInstance path in scripts/world/dungeon_geo/geo_stream.gd. Out: outline.gd, torch_plan.gd, light_rt.gd, and WallRects.merge used as skin or as a stair collision lip.

One brick sheet. UV runs along the run tangent and world height so a diagonal ribbon is one course, not a reset every meter. Do not hash `floor(xz)` or a 1 m cell index for the sheet. Extra wear is shader-side hash/tint, not a second Imagine sheet and not a fillet or jag rim operator. Do not rebuild a slant as 1 m cell slabs. If two provided runs are the same wall (opposite normals, overlapping run), emit one ribbon. If gen still publishes 4-connected ortho teeth along a slant, fold near-collinear runs before skinning. Do not invent a second bake. Wall shader samples the same light RT as the floor. Acceptance is opposite-normal merge, collinear fold, top-cap UV, drop the wall light minimum (max(lit, 0.42)), drop the world-cell hash UV quilt, both outlined sides of a walkable hall emit, the floor void edge colinear with the ribbon, and boxes that do not stick past that line. Shaders use textureSize and may filter across texels. Collision boxes stay a stream concern on the published solid. This job does not retarget occupancy or torches. Stream rings and CHUNK stay.

Volume closes the hall with ribbon plus caps. Stream floor planes and boxes follow the published run. Missing ribbon on a published run is a volume miss. Missing run on a carved hall is a gen miss.

Torches hang only on interior faces (the face looks at a floor, not the void). This job emits the faces; buffer places the sources. Close each ribbon with a top cap and end caps so halls do not open into void. Caps use the same brick sheet and the same run-tangent / world-height UV. Do not extrude a 1 m slab along each run.

Hub buildings are not this job. Do not author arches or modular kits.
Shared ribbon ends drop open caps and get a square corner column. Do not chamfer or fillet the rim.
