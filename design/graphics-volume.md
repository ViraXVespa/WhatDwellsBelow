# Graphics volume

Status: binding design + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, hitbox-untouched

Dungeon wall visuals stop being one BoxMesh per cell. Emit faces that touch a floor, and the void-facing sides of those same cells so a step against the abyss has brick sides. Do not emit a face between two wall cells. Greedy-merge coplanar runs the way collision already merges wall rectangles.

One brick sheet, world-UV so the pattern does not reset every meter. Extra wear is shader-side hash/tint, not a second Imagine sheet. Wall shader samples the same light RT as the floor (white / 1.0 until buffer). Collision stays the merged BoxShape path. Stream rings and CHUNK stay.

Torches hang only on interior faces (the face looks at a floor, not the void). The bracket sits on that wall face. Bracket uses a 4-facing unlit bible. Flame is code VFX on a Y-billboard; buffer owns it. This job emits the faces; buffer places the sources. Do not call WallRects.merge for visuals; merge packs collision cells only. Face runs come from WallRects.faces (origin, size, normal). This job emits those quads; it does not reimplement the scan. Close each run with a top cap and end caps so halls do not open into void. Caps use the same brick sheet and world UV. Void-facing sides of those cells use the same sheet. Do not change dungeon gen.

Hub buildings are not this job. Do not author arches or modular kits.
