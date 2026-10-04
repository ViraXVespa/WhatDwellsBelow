# Graphics actor

Status: current plan + live snapshot
Read when: billboard-alpha squash quads, player yard-mannequin foes, source-offset

Y-billboard frames stay nearest stickers. Multiply the sprite by the RT sample at the actor's feet so characters take the light.

Floor mark is a near-black, low-alpha silhouette projected onto the floor. Player mark uses the current animation frame. Dummy and enemies use their still. The left sole pixel pins to the sticker's left foot and the right sole pixel pins to the right foot. The head edge shears away from the driving light. Width stays on the billboard axis. Stacked feet share one contact and keep the body width; they do not hinge the quad open. Length stays within about one body so a side stance does not become a needle. The quad must keep area when the light sits on the foot line: add a minimum camera-facing shear and smooth the warp so it does not pop. It must not read as a second actor.

Casters: player, training dummy, and every enemy that uses the billboard helper (boss, named, summons). Hub: one mark. Dungeon: up to three marks. Player UVs follow the current frame. Dummy and enemies stay on the still.

Hub squash follows the sun: one direction and one length for the whole yard. It does not rotate around a point on the dirt and does not grow as the actor walks. The hub crystal is a second mark on the player only, cast away from the crystal, not a copy of the sun quad. It is not the hub squash origin for the dummy. Dungeon squash uses up to three in-range torches, crystals, or campfires, one mark each. Nearest is strongest. Length follows that source's distance. Crystal marks stay long (ground lamp). Torches stay short when close (overhead). Alpha is split across those marks so they do not stack into a black smear. A mark hides when its alpha is under the hide floor. A source out of range drops its mark.

Mark sits on FLOOR_Y on floor cells only. Kill z-fight with depth bias, not a visible hover. Do not enable Sprite3D.cast_shadow. Do not parent the policy only under the player. Filter modes stay on the existing sprite filter owner.
