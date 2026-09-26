# Graphics actor

Status: binding design + live snapshot
Read when: billboard-alpha squash quads, player yard-mannequin foes, source-offset

Y-billboard frames stay unshaded stickers. The shadow is the current frame texture flattened onto the floor, nearest, alpha from the sprite, offset by the nearest light on xz.

v1 casters: player, training dummy, enemies. One shadow per actor. Update when the anim frame changes.

Do not enable Sprite3D.cast_shadow. Do not parent the policy only under the player. Filter modes stay on the existing sprite filter owner.
