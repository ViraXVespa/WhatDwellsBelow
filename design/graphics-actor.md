# Graphics actor

Status: binding design + live snapshot
Read when: billboard-alpha squash quads, player yard-mannequin foes, source-offset

Y-billboard frames stay nearest stickers. Multiply the sprite by the RT sample at the actor's feet so characters take the light.

Floor mark is the idle silhouette, near-black, low alpha, projected onto the floor. Left foot of the mark stays on the sticker's left foot. Right foot stays on the sticker's right foot. Those two points do not move. The head edge warps away from the driving light as a trapezoid. It must not read as a second actor. Hidden when no driving light applies.

Casters: player, training dummy, and every enemy that uses the billboard helper (boss, named, summons). One squash per actor. The mark keeps the idle frame while the sticker walks or attacks. Do not copy walk flip_h onto the mark.

Hub squash follows the sun: one direction and one length for the whole yard. It does not rotate around a point on the dirt and does not grow as the actor walks. Crystal may tint a local bump; it is not the hub squash origin. Dungeon squash follows the nearest torch, crystal, or campfire, and length/alpha change with distance.

Mark sits on FLOOR_Y on floor cells only. Kill z-fight with depth bias, not a visible hover. Do not enable Sprite3D.cast_shadow. Do not parent the policy only under the player. Filter modes stay on the existing sprite filter owner.
