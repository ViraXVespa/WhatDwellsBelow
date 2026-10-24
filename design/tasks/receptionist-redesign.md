# Redraw the receptionist sprite to her new design

id: receptionist-redesign
owner: build
status: open
done-when: assets/sprites/npcs/receptionist.png shows the new look in hub-guild.md (the window bust is that sprite clipped, not a second file); hub shot reviewed.
resume: python tools/slice.py open art_pipeline.pack --task receptionist-redesign

**Folded into web task** `hub-guild-reception` (owner web). Do not start this Build task until that lands or the User reopens it.

## Intent
Her call 2026-10-20: the receptionist is now a young goth/metal woman in a form-fitting guild uniform (see `design/hub-guild.md`), replacing the old-lady sprite. Redraw the in-game sprite and the window bust to match, same size, pixel grid and hub palette. Tasteful, game-appropriate. The ui-png-art talk portrait follows the same design.

## Process
NPC redesign recipe in `design/art-pack.md` (`media.py grok --kind npc`, then the rekey onto the old fit). Show the plate before the rekey; hub shot after.
