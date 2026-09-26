# Graphics buffer

Status: binding design + live snapshot
Read when: 256-512 xz radiance buffer, disc blobs, tile occupancy

The light RT is a small texture lights are stamped into. Ground, walls, and actors sample it. One texel equals one tile. Size follows the live stream ring, not a free camera pad.

Occupancy: WALL cells block. Floor, door, opening, and stairs pass. One pass; do not split openings later.

Sources v1: wall torch, floor crystal, campfire only. No shop, gate, stair, or player lantern.

Hub RT: one wide warm sun disc plus the floor crystal. Dungeon RT: no sun. Ambient comes from the env kit only so pits stay dark.

Torch placement: at most one per room unless a crystal or campfire already lights it. Halls only at doorways, junctions, and dead ends. Hard cap on sources in the live ring. The bracket stays on the interior wall. The flame is a Y-billboard, not a wall decal. Source sits on the floor in front of the bracket, not inside the wall. Torches spawn and despawn with the geo chunk.

Stamp discs plus occupancy. Engine DirectionalLight3D and OmniLight3D shadows stay off. Compatibility and web stay the leash. Do not use Decal3D.

Build Imagine: unlit 4-facing torch bible, then flame VFX, isolated, wording like the character stills harvest.

Invented range, energy, and cap values go in tunables and debug.
