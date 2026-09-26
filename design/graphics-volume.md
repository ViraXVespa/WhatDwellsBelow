# Graphics volume

Status: binding design + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, hitbox-untouched

Dungeon wall visuals stop being one BoxMesh per cell. Emit only faces that touch a floor. Greedy-merge coplanar runs the way collision already merges wall rectangles.

World-UV bricks so the sheet does not reset every meter. Wall shader samples the same light RT as the floor (white / 1.0 until buffer). Collision stays the merged BoxShape path. Stream rings and CHUNK stay.

Torches hang only on interior faces (the face looks at a floor, not the void). The bracket sits on that wall face. Bracket uses a 4-facing unlit bible. Flame is a separate Y-billboard; buffer owns it. This job emits the faces; buffer places the sources. Visual greedy runs call WallRects.merge; do not copy the scan.

Hub buildings are not this job. Do not author arches or modular kits.
