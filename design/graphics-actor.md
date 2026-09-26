# Graphics actor

Status: binding design + live snapshot
Read when: billboard-alpha squash quads, player yard-mannequin foes, source-offset

Y-billboard frames stay nearest stickers. Multiply the sprite by the RT sample at the actor's feet so characters take the light.

Floor squash is the current frame flattened onto the floor, nearest, alpha from the sprite, offset by the nearest source on xz. No squash when no source is nearby.

Casters: player, training dummy, and every enemy that uses the billboard helper (boss, named, summons). One squash per actor. Update when the anim frame changes.

Hub sources for tint and squash: wide sun disc plus floor crystal. Dungeon: torch, crystal, campfire.

Quad sits just above FLOOR_Y and only on floor cells. Do not enable Sprite3D.cast_shadow. Do not parent the policy only under the player. Filter modes stay on the existing sprite filter owner.
