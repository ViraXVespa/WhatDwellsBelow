# Graphics actor

Status: binding design + live snapshot
Read when: billboard-alpha squash quads, player yard-mannequin foes, source-offset

Y-billboard frames stay nearest stickers. Multiply the sprite by the RT sample at the actor's feet so characters take the light.

Floor mark is a near-black, low-alpha silhouette projected onto the floor. Player mark uses the current animation frame. Dummy and enemies use their still. In that texture, the left-foot opaque pixel pins to the sticker's left foot on the floor, and the right-foot opaque pixel pins to the right foot. The head edge warps away from the driving light as a trapezoid. The quad must keep area when the light sits on the foot line: add a minimum camera-facing shear and smooth the warp so it does not pop. It must not read as a second actor.

Casters: player, training dummy, and every enemy that uses the billboard helper (boss, named, summons). Hub: one mark. Dungeon: up to three marks. Player UVs follow the current frame. Dummy and enemies stay on the still.

Hub squash follows the sun: one direction and one length for the whole yard. It does not rotate around a point on the dirt and does not grow as the actor walks. Crystal may tint a local bump; it is not the hub squash origin. Dungeon squash uses up to three in-range torches, crystals, or campfires, one mark each. Nearest is strongest. Length follows that source's distance. Alpha is split across those marks so they do not stack into a black smear. A mark hides when its alpha is under the hide floor. A source out of range drops its mark.

Mark sits on FLOOR_Y on floor cells only. Kill z-fight with depth bias, not a visible hover. Do not enable Sprite3D.cast_shadow. Do not parent the policy only under the player. Filter modes stay on the existing sprite filter owner.
