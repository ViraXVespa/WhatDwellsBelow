# Graphics buffer

Status: binding design + live snapshot
Read when: one-texel radiance buffer, disc blobs, tile occupancy

The light RT is a small texture lights are stamped into. Ground, walls, and actors sample it. Actors may query nearest_cast (one) or up to three in-range casts, nearest first. Stamp, occupancy, and the source list do not change for that query. Live map is four texels per tile. Occupancy stays one coarse cell per tile until a named buffer pass. That later pass reads gen's fine solid. Torch brackets sit on interior outline faces, not 1 m teeth. Size follows the live stream ring, not a free camera pad.

Occupancy: WALL cells block. Floor, door, opening, and stairs pass. One pass; do not split openings later. No extra door occluders this week.

Sources v1: wall torch, floor crystal, campfire only. No shop, gate, stair, or player lantern. Crystal and campfire keep live meshes; this job only stamps discs on them.

Hub RT: a wide warm sun fill over the camp AABB (yard plus grass pads) plus a small floor-crystal bump. The sun disc paints brightness. It is not a point origin for actor squash. Dungeon RT: no sun. Size follows the live stream ring. Walkable floor starts at a visible dim cold fill in the RT (high enough to read the slate). Torches, crystals, and campfires boost that fill. Pits and void stay black. Env kit owns fog and void, not the floor fill.

Torch placement: at most one per room unless a crystal or campfire already lights it. Halls only at doorways, junctions, and dead ends. Hard cap on sources in the live ring. The bracket stays on the interior wall. Flame is generated code VFX on a Y-billboard (shader or particles): organic fire with flicker. Never a flame sheet. Source sits on the floor in front of the bracket, not inside the wall. Torches spawn and despawn with the geo chunk.

Shaders may filter across texels (bilinear and disc falloff) so a stamp is not a hard square. Stamp discs plus occupancy. Engine DirectionalLight3D and OmniLight3D shadows stay off. Compatibility and web stay the leash. Do not use Decal3D.

Build Imagine: unlit 4-facing torch-and-bracket bible only, isolated, wording like the character stills harvest.

Invented range, energy, and cap values go in tunables and debug.
