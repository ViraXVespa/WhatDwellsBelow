# Graphics volume

Status: binding design + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, hitbox-untouched

Dungeon wall visuals stop being one BoxMesh per cell. Emit only faces that touch a floor. Greedy-merge coplanar runs the way collision already merges wall rectangles.

World-UV bricks so the sheet does not reset every meter. Wall shader samples the same light RT as the floor (white / 1.0 until buffer). Collision stays the merged BoxShape path. Stream rings and CHUNK stay.

Torches hang only on interior faces (the face looks at a floor, not the void). Bracket uses a 4-facing unlit bible; flame is a separate VFX. This job emits the faces; buffer places the sources.

Hub buildings are not this job. Do not author arches or modular kits.
