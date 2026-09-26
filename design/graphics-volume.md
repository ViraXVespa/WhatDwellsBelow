# Graphics volume

# Graphics volume

Status: binding design + live snapshot
Read when: exposed coplanar brick runs, BoxMesh retirement, hitbox-untouched

Dungeon wall visuals stop being one BoxMesh per cell. Emit only faces that touch a floor. Greedy-merge coplanar runs the way collision already merges wall rectangles.

World-UV bricks on those quads so the sheet does not reset every meter. Collision stays the merged BoxShape path. Stream rings and CHUNK stay.

Hub buildings are not this job. Do not author arches or modular kits here.
