# Graphics volume

Status: binding design + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, BoxShape on welded mass, provided ribbon

Dungeon wall visuals stop being one BoxMesh per cell. Skin gen's provided outline_spans as one thin ribbon per span (any heading, same brick sheet). Do not invent rims. Do not extract a silhouette from occupancy. Ortho faces from the fine solid are a fallback only when outline_spans is empty.

One brick sheet. UV runs along the span tangent and world height so a diagonal ribbon is one course, not a reset every meter. Do not hash `floor(xz)` or a 1 m cell index for the sheet. Extra wear is shader-side hash/tint, not a second Imagine sheet. Do not rebuild a slant as 1 m BoxMeshes. If two provided spans are the same wall (opposite normals, overlapping run), emit one ribbon. If gen still publishes 4-connected ortho teeth along a slant, fold near-collinear runs before skinning. Do not invent a second bake. Wall shader samples the same light RT as the floor. Shaders use textureSize and may filter across texels. Collision stays the merged BoxShape path on gen's bake, authored by stream. This job does not retarget occupancy or torches. Stream rings and CHUNK stay.

Torches hang only on interior faces (the face looks at a floor, not the void). The bracket sits on that wall face. Bracket uses a 4-facing unlit bible. Flame is code VFX on a Y-billboard; buffer owns it. This job emits the faces; buffer places the sources. Do not call WallRects.merge for visuals; merge packs collision cells only. Close each ribbon with a top cap and end caps so halls do not open into void. Caps use the same brick sheet and the same span-tangent / world-height UV. Do not extrude a 1 m slab along each span. Hitboxes stay stream BoxShape on gen's solid.

Hub buildings are not this job. Do not author arches or modular kits.
