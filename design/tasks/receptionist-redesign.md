# Redraw the receptionist sprite to her new design

id: receptionist-redesign
owner: build
status: open
done-when: assets/sprites/npcs/receptionist.png shows the new look in hub-guild.md (the window bust is that sprite clipped, not a second file); hub shot reviewed.
resume: python tools/open_slice.py art_pipeline.pack --task receptionist-redesign

## Intent
Her call 2026-10-20: the receptionist is now a young goth/metal woman in a form-fitting guild uniform (see `design/hub-guild.md`), replacing the old-lady sprite. Redraw the in-game sprite and the window bust to match, same size, pixel grid and hub palette. Tasteful, game-appropriate. The ui-png-art talk portrait follows the same design.

## Process
NPC redesign recipe in `design/art-pack.md` (`run_isolated_grok.py --kind npc`, then the rekey onto the old fit). Show the plate before the rekey; hub shot after.
