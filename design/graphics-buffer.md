# Graphics buffer

Status: current plan + live snapshot
Read when: four-texel radiance buffer, disc blobs, fine occupancy

The light RT is a small texture lights are stamped into. Ground, walls, and actors sample it. Actors may query nearest_cast (one) or up to three in-range casts, nearest first. Stamp, occupancy, and the source list do not change for that query. Stamp density is four texels per tile (`SUB` 4). Do not retune range or energy to fake smoothness.

Occupancy is the cleaned 1 m maze. Floor, door, opening, and stairs pass. Pits and wall mass block. Do not build a floor-wide walk mask from outline_loops. Do not flood a fine solid of the whole floor. SUB is how densely the RT is stamped, not a second dungeon. A disc does not wash through wall mass. Line of sight is a 1 m trace. An open doorway still passes light. Cold fill only on walkable maze samples. Wall mass stays unlit except a neighbor-edge copy along the bake.

Torch brackets sit on interior 1 m faces. Do not mount on void. Size follows the live stream ring, not a free camera pad. Occupancy restamp follows the ring rect and knobs. A geo chunk flipping live only refills torch bills. Do not republish the whole RT on every live-chunk flip. Live `maintain` does at most one of plan, stamp, or torch refill per call. A walking restamp is staged: `maintain` runs `STAGE_US` of the `stamp_job.gd` job per frame (walk rows, clear, one disc per light, lift, walls, blit ranges), then `_commit` swaps image, origin, span and solid together with one upload; the old light keeps drawing until then. The pixels equal one `Stamp.paint`. The first stamp under the cover runs whole. `reset_floor` drops a pending job. First dungeon publish is those three frames, not one. First plan during enter_hold/enter_fade only sites that touch the RING_IN rect. Stamp that rect before release_enter. Cover stays up until two presented frames are at 16 ms (cap 12). release_enter starts the fade after that gate. Full plan waits until the enter fade has finished. Do not copy hub publish (`hub_open`, blank occupancy, sun disc) into the dungeon. Live stamp may still read floor-wide solid until the consume slice. No extra door occluders this week.

Sources v1: wall torch, floor crystal, campfire only. No shop, gate, stair, or player lantern. Crystal and campfire keep live meshes; this job only stamps discs on them.

Hub RT: a wide warm sun fill over the camp AABB (yard plus grass pads) plus a small floor-crystal bump. The sun disc paints brightness. It is not a point origin for actor squash. Dungeon RT: no sun. Size follows the live stream ring. Walkable floor starts at a visible dim cold fill in the RT (high enough to read the slate). Torches, crystals, and campfires boost that fill. Pits and void stay black. Env kit owns fog and void, not the floor fill.

Torch placement: at most one per room unless a crystal or campfire already lights it. Halls only at doorways, junctions, and dead ends. Sparse enough that unused stone stays dark; usually at least one flame in a fully zoomed-out frame. Do not retune range or energy to fake that coverage. Hard cap on sources in the live ring. The bracket stays on the interior shell. Flame is generated code VFX on a Y-billboard (shader or particles): organic fire with flicker. Never a flame sheet. Source sits on the floor in front of the bracket, not inside the wall and not in the abyss behind it. Torches spawn and despawn with the geo chunk. Engine DirectionalLight3D and OmniLight3D shadows stay off.

Shaders may filter across texels (bilinear and disc falloff) so a stamp is not a hard square. Stamp discs plus occupancy. Engine DirectionalLight3D and OmniLight3D shadows stay off. Compatibility and web stay the leash. Do not use Decal3D.

Build Imagine: unlit 4-facing torch-and-bracket bible only, isolated, wording like the character stills harvest.

Invented range, energy, and cap values go in tunables and debug. Do not retune those values to fake smoothness.

Hub sun uses building occupancy. Hub crystal disc does not. Hub RT gets a 3x3 blur. Actor crystal squash is player-only.
