# Graphics ground

Status: binding design + live snapshot
Read when: hashed field albedo, shared spatial shader, turf quilts, carved planes

One spatial shader on Placeholdia grass pads, packed yard, and dungeon chunk floors.

v1: field albedo, hashed 2-4 variants from cell or world xz, sample the light RT in world xz. Nearest filter. Stop using a framed medallion as the only dungeon albedo. Hub `plaza_grass` / `plaza_ground` stamps become field sheets plus the same variant hook.

`tile_layer` and `grass_pad` and dungeon floor MultiMeshes share the material helper. Do not keep a unique hub atlas as the system. Do not hex-tile as the system this week.

Unshaded StandardMaterial3D on those surfaces goes away. Invented variant counts and UV scales go in tunables and debug.
