# Graphics volume

Status: binding design + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, BoxShape on welded mass, provided ribbon

Dungeon wall visuals stop being one 1 m cell slab per cell (WallRects.faces / per-cell quads). BoxMesh retirement means that slab skin, not a Godot BoxMesh type hunt. Skin gen's provided outline_spans as one thin ribbon per span (any heading, same brick sheet). Live already has a delta-span path and a faces fallback. When outline_spans exist for a chunk, do not keep the 1 m faces skin in that chunk. A walkable hall with no ribbon or cap on an outlined span is a volume miss. Do not invent rims. Do not extract a silhouette from occupancy. Ortho faces from the fine solid are a fallback only when outline_spans is empty.

Live files in this job: scripts/graphics/wall_mesh.gd, scripts/graphics/wall_shader.gd, and scripts/world/dungeon_geo_stream.gd (_wall_runs, _spans_on_chunk, and the wall MeshInstance only). Out: light_stamp.gd, light_rt.gd, torch_plan.gd, gen_outline.gd, _emit_floors, solid_cells floor rects, and WallRects.merge used as skin.

One brick sheet. UV runs along the span tangent and world height so a diagonal ribbon is one course, not a reset every meter. Do not hash `floor(xz)` or a 1 m cell index for the sheet. Extra wear is shader-side hash/tint, not a second Imagine sheet. Do not rebuild a slant as 1 m cell slabs. If two provided spans are the same wall (opposite normals, overlapping run), emit one ribbon. If gen still publishes 4-connected ortho teeth along a slant, fold near-collinear runs before skinning. Do not invent a second bake. Wall shader samples the same light RT as the floor. _push_span existing and LightRt.bind existing are not acceptance. Acceptance is opposite-normal merge, collinear fold, top-cap UV, drop the wall light minimum (max(lit, 0.42)), drop the world-cell hash UV quilt, and both outlined sides of a walkable hall emit. Shaders use textureSize and may filter across texels. Collision stays the merged BoxShape path on gen's bake, authored by stream. This job does not retarget occupancy or torches. Stream rings and CHUNK stay.

Stair-step void along a slant is gen's fine solid emitted as floor rects, not wall volume. Volume closes the hall with ribbon plus caps. Do not clip floor planes or occupancy to hide the teeth. If both sides are capped and light still walks those teeth, that is buffer.

Torches hang only on interior faces (the face looks at a floor, not the void). The bracket sits on that wall face. Bracket uses a 4-facing unlit bible. Flame is code VFX on a Y-billboard; buffer owns it. This job emits the faces; buffer places the sources. Do not call WallRects.merge for visuals; merge packs collision cells only. Close each ribbon with a top cap and end caps so halls do not open into void. Caps use the same brick sheet and the same span-tangent / world-height UV. Do not extrude a 1 m slab along each span. Hitboxes stay stream BoxShape on gen's solid.

Hub buildings are not this job. Do not author arches or modular kits.
