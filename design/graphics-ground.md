# Graphics ground

Status: binding design + live snapshot
Read when: hashed field albedo, shared spatial shader, turf quilts, carved planes

One spatial shader on Placeholdia grass pads, packed yard, and dungeon chunk floors.

Dungeon floor mesh on the abyss rim follows the cleaned 1 m maze. Angled pieces use their published band, not a floor-wide polyline raster. The sheet and world-xz shader do not change.

Field albedo. One seamless sheet per surface, projected in world xz so moving a pad or chunk does not need new art. Hub pads are large planes; do not hash cell index. Sample the light RT in world xz. Dungeon RT is four texels per 1 m tile (`Stamp.SUB`). Hub bake is `HUB_SUB` 16 texels per metre. Do not sample hub as one texel per tile. Shaders use textureSize and may filter across texels. Do not sample as one texel per tile.

Stop using a framed medallion as the only dungeon albedo. Sheets: grass field, packed dirt, dungeon floor. Wall brick belongs to volume. Variants are shader-side (world-xz hash, tint, wear). Do not Imagine a second sheet per surface.

`tile_layer`, `grass_pad`, and dungeon floor MultiMeshes share the material path. Unique hub atlas is not the system. Hex-tile is not the system.

Unshaded StandardMaterial3D on those surfaces goes away. Invented variant counts and UV scales go in tunables and debug.

Live: `scripts/graphics/ground_shader.gd` samples `scripts/graphics/light_rt/light_rt.gd` (world xz). Sheets: `assets/tiles/grass_field.png`, `packed_dirt.png`, `dungeon_floor.png`. The yard path keeps `plaza_path.png` on that same shader. Wall faces stay on the volume job.
