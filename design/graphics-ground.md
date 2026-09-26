# Graphics ground

Status: binding design + live snapshot
Read when: hashed field albedo, shared spatial shader, turf quilts, carved planes

One spatial shader on Placeholdia grass pads, packed yard, and dungeon chunk floors.

Field albedo. One seamless sheet per surface, projected in world xz so moving a pad or chunk does not need new art. Hub pads are large planes; do not hash cell index. Sample the light RT in world xz. Until the buffer job lands, that sample is white / 1.0. Nearest filter.

Stop using a framed medallion as the only dungeon albedo. Sheets: grass field, packed dirt, dungeon floor. Wall brick belongs to volume. Variants are shader-side (world-xz hash, tint, wear). Do not Imagine a second sheet per surface.

`tile_layer`, `grass_pad`, and dungeon floor MultiMeshes share the material path. Unique hub atlas is not the system. Hex-tile is not the system.

Unshaded StandardMaterial3D on those surfaces goes away. Invented variant counts and UV scales go in tunables and debug.
