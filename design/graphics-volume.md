# Graphics volume

Status: binding design + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, BoxShape on welded mass, span ribbon

Dungeon wall visuals stop being one BoxMesh per cell. Emit faces that touch a floor, and the void-facing sides of those same cells so a step against the abyss has brick sides. Do not emit a face between two wall cells. Greedy-merge coplanar runs the way collision already merges wall rectangles.

One brick sheet, world-UV so the pattern does not reset every meter. Extra wear is shader-side hash/tint, not a second Imagine sheet. Wall shader samples the same light RT as the floor (white / 1.0 until buffer). Collision stays the merged BoxShape path on gen's clipped solid (fine cells after spans are burned), authored by gen and stream. Stream rings and CHUNK stay.

Torches hang only on interior faces (the face looks at a floor, not the void). The bracket sits on that wall face. Bracket uses a 4-facing unlit bible. Flame is code VFX on a Y-billboard; buffer owns it. This job emits the faces; buffer places the sources. Do not call WallRects.merge for visuals; merge packs collision cells only. Face runs come from the scan of gen's walkable solid (origin, size, normal on the fine occupancy). This job emits those quads; it does not reimplement the scan and it does not invent the silhouette. Close each run with a top cap and end caps so halls do not open into void. Caps use the same brick sheet and world UV. Void-facing sides of those cells use the same sheet. Do not invent the dungeon silhouette. Consume the solid gen already emitted. When gen stores outline_spans, emit one thin ribbon shell per span (any heading, same brick sheet). If spans are empty, keep ortho faces from the fine solid. Do not extrude a 1 m slab along each span. Hitboxes stay merged BoxShape on gen's clipped solid. Volume must not leave staircase teeth in front of a ribbon.

Hub buildings are not this job. Do not author arches or modular kits.
