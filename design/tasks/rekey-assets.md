# Handoff: rekey assets

id: rekey-assets
title: Rekey assets after the keying changes
owner: build
status: open
done-when: Vira confirms the open-set stills below. Each one keys from its source plate with one soft color-to-alpha. slot_legs.png is the empty leg slot from her jpg.
area: art_pipeline
door: art_pipeline
job: art_pipeline.pack
units:
done:
needs-local: _src
resume: python tools/open_slice.py art_pipeline.pack --task rekey-assets
Your first command, before any file read or memory topic: python tools/start_build_slice.py --job art_pipeline.pack --from-task rekey-assets
The survey is done. The answers below stand. Ask again only what Open questions lists, or what a discovery changes. `_src` is a link to the main checkout's source plates: read it only. Never edit, move, or delete anything in it.

## Task (her words)
Color-to-alpha is not doing its job. The purple on the shopkeep and the wisp is blue glow and a translucent outer layer mixed with the plate. The arrow has translucent shading. The same glow made the hp orb border. Leave that shading in the art and turn it to alpha. Sample the strong black, white, and blue border pixels as the comparison base, and keep those border pixels distinct from the subject.

The female face was distorted by the resize. A chunk is still missing from her right arm (her right; the left side of the image). Green specks showed up; she suspected the RGB invert in eat_spill. Small alpha holes: the top of head.png, and near the top of the arrow tip. Rough chunky edges, called out on hatchet.png. The longbow string is gone in places. Nearest-neighbor is only for upsizing. Sizing down uses the highest-quality resize. One soft key for every asset. Do not stack special cases. Retool the keyer if that is what gets color-to-alpha right.

The proof is the open set. She will review a full repack later. Checklist items she did not repeat were already fixed. Do not reopen them.

This session wrote the open-set live PNGs so you can see the attempt. They are not accepted.

## Q0 answers so far
- result look: One soft key, reusing the source plates. The same logic has to work on every asset. Soft edges are likely on all of them. Proof is the open set. A full repack comes later, after she says this set is right.
- reference: The source plates in `_src`. The live sprite should keep that drawing, with the plate and the glow turned into alpha.
- out of bounds, incl. frames or layouts already built: Dummy, guild, guild reception, stall, anvil, fence, pickaxe, and the male edge-cull stay as the previous session left them. Do not rekey them in this pass. Do not edit `_src`.

## Her decisions
- One soft key, reused from the source plates, for every asset. No per-asset special case.
- Reference is the source plate beside each live still.
- First rewrite is the open set. She judges that before any other frame is rewritten.
- Fixed checklist stays out: dummy, guild, guild_reception, stall, anvil, fence, pickaxe, male edge-cull.
- Nearest-neighbor only when sizing up. High-quality resize when sizing down.
- slot_legs.png comes from `_src/sources/assets/ui/gear/slot_legs.jpg` (dark greaves on magenta). Not from the extract gate.
- Live stills of the attempt get committed so the next session can see them. They are not accepted.
- Resume in a fresh session.

## Chosen surfaces, in order
- assets/sprites/npcs/shopkeep.png
- assets/sprites/enemies/wisp/ (all eight idle facings; one plate, idle_up.jpg)
- assets/fx/arrow.png
- assets/sprites/props/hp_orb.png
- assets/sprites/player/female/idle_down.png (this frame only)
- assets/ui/gear/head.png
- assets/ui/gear/hatchet.png
- assets/ui/gear/longbow.png
- assets/ui/gear/slot_legs.png

Do not reopen: assets/fx/dummy.png, assets/sprites/buildings/guild.png, assets/sprites/buildings/guild_reception.png, assets/sprites/buildings/stall.png, assets/sprites/props/anvil.png, assets/sprites/props/fence.png, assets/ui/gear/pickaxe.png, and the male player frames.

## Ledger
Decisions I made that were yours: all eight wisp idles are this one keyed plate, because the only source is idle_up.jpg. The fit ignores alpha below 24 so a faint halo does not shrink the subject. I removed the RGB invert in eat_spill instead of adding another spill case.
Assumptions carried from memory or docs: stills resolve through the manifest in `_src`. art-pack.md now says soft alpha and a high-quality downscale, matching her 2026-10-09 note. Palette snap was not applied to these stills.
Also changed: tools/imglib/key.py (key_to_alpha, border_comparison, _fringe_color). tools/imglib/geom.py (resize_rgba, shrink, fit_axis, fit_box). tools/sprite_pipeline.py key_to_alpha docstring. tools/imglib/selftest.py JPEG check now treats alpha above 200 as opaque plate. design/art-pack.md steps 2, 3, and 5. Live PNGs listed above. No `.gd` files. `_src` was not written. Callers of key_to_alpha not run: pack_locomotion.py, pack_walk.py, process_gear_icons.py, rekey_stills.py, process_session_sprites.py, match_keyed_region.py. Callers of fit_box, shrink, and fit_axis not run: pack_locomotion.py, pack_walk.py, pack_turntable.py, pack_facing_fix.py, pack_p4_enemies.py, process_gear_icons.py, process_enemies.py, process_world.py, process_world_pass.py, process_gloam.py, rekey_stills.py.

## Baselines for the chosen surface
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\sprites\npcs\shopkeep.png - repo path assets/sprites/npcs/shopkeep.png. Body intact. Magenta gap beside the apron.
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\sprites\enemies\wisp\idle_up.png - repo path assets/sprites/enemies/wisp/idle_up.png. Blue wisp, purple outer edge. The other seven idle facings match this file.
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\fx\arrow.png - repo path assets/fx/arrow.png. Pink fringe on the fletching. Softer outline.
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\sprites\props\hp_orb.png - repo path assets/sprites/props/hp_orb.png. Gem with a purple edge. Much of the canvas is partial alpha.
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\sprites\player\female\idle_down.png - repo path assets/sprites/player/female/idle_down.png. Softer 128. A few magenta pixels on the armor.
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\ui\gear\head.png - repo path assets/ui/gear/head.png. Top hole measured 0. Metal is soft.
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\ui\gear\hatchet.png - repo path assets/ui/gear/hatchet.png. Softer edges. Axe body is mostly partial alpha.
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\ui\gear\longbow.png - repo path assets/ui/gear/longbow.png. String still broken. Bow is mostly partial alpha.
C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipelinepack-20261009-0250\assets\ui\gear\slot_legs.png - repo path assets/ui/gear/slot_legs.png. Empty-slot greaves from her jpg. Softer than the file it replaced.

## Files and functions to touch
- tools/imglib/key.py: key_to_alpha, border_comparison, _fringe_color. Plate pixels become transparent black. Plate-hued fringe is despilled by subtracting min(R, B) - G from R and B. Do not bring back the RGB invert.
- tools/imglib/geom.py: resize_rgba (nearest only when both sides grow; premultiplied Lanczos when either side shrinks; hairline lift), fit_box (crop alpha at 24).
- tools/imglib/selftest.py: run `python tools/img_inspect.py selftest` after a key change. It passed at the end of this session.
- The nine live paths above. Write a still only after you have looked at it. She confirms each one.
- design/art-pack.md if the key contract changes again.

## Did not work
Latest `python tools/img_inspect.py selftest` passed (12 checks). Earlier failures in this session, since fixed: light-pink lip recolored the maroon cloth; JPEG plate left 103 then 94 pixels opaque; light-pink lip stayed fully opaque. Do not treat those as open.

The live stills are not accepted. Shopkeep gap, wisp edge, arrow fringe, and orb edge still show plate color. Longbow string and hatchet solidity got worse. Do not call the key done.

## Open questions
none. The look, the reference, the open set, and the out-of-bounds list are settled above. Ask only if a discovery changes what she will see.
