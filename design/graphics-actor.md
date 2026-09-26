# Graphics actor

Status: binding design + live snapshot
Read when: billboard-alpha squash quads, player yard-mannequin foes, source-offset

Y-billboard frames stay nearest stickers. Multiply the sprite by the RT sample at the actor's feet so characters take the light.

Floor mark is a dark, low-alpha contact at the feet, offset by the nearest source on xz. It must not read as a second actor. If a flattened frame still looks like a clone, use a generated blob instead of the current frame. Hidden when no source is in reach.

Casters: player, training dummy, and every enemy that uses the billboard helper (boss, named, summons). One squash per actor. Update when the anim frame changes.

Hub sources for tint and squash: wide sun disc plus floor crystal. Dungeon: torch, crystal, campfire.

Mark is rooted at the feet, sits just above FLOOR_Y, and only on floor cells. Do not enable Sprite3D.cast_shadow. Do not parent the policy only under the player. Filter modes stay on the existing sprite filter owner.
