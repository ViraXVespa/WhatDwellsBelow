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
- result look: One soft key, reusing the source plates. The same logic has to work on every asset. Soft edges are likely on many of them, but not all. Proof is the open set. A full repack comes later, after she says this set is right.
- reference: The source plates in `_src`. The live sprite should keep that drawing, with the plate and the glow turned into alpha.
- out of bounds, incl. frames or layouts already built: Dummy, guild, guild reception, stall, anvil, fence, pickaxe, and the male edge-cull stay as the previous session left them. Do not rekey them in this pass. Do not edit `_src`.

## Her decisions
- One soft key, reused from the source plates, for every asset. No per-asset special case.
- Reference is the source plate beside each live still.
- First rewrite is the open set. She judges that before any other frame is rewritten.
- Fixed checklist stays out: dummy, guild, guild_reception, stall, anvil, fence, pickaxe, male edge-cull.
- Nearest-neighbor only when sizing up. High-quality resize when sizing down. A downscale that leaves head.png blurry is not the result.
- slot_legs.png comes from `_src/sources/assets/ui/gear/slot_legs.jpg` (dark greaves on magenta). Not from the extract gate.
- Live stills of each attempt get committed so the next session can see them. They are not accepted.
- Translucent areas on the plate stay as partial alpha. Shopkeep glow, the wisp outer layer, arrow shading, and the orb border were deleted. That is a failure. The orb border was the glow and was supposed to come back as alpha.
- Solid outlines drawn on the plate survive. The hatchet is mostly good and is missing that outline. Other stills lost the same solid edge.
- The longbow string must read as one string. Sparkles are not a string.
- Female idle_down still has chunks missing from the arms.
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
Decisions I made that were yours: all eight wisp idles are this one keyed plate. Fringe colour is a despill (subtract min(R, B) - G from R and B), a light-veil walk, and a dark outline only within 22 degrees of the plate. Red-dominant colours were left as drawn. Fit ignores alpha below 24. Canvases stayed 128, orb 48, gear 64. Downscale is premultiplied Lanczos. Hairline lift only where a thin solid line is not the edge of a solid mass.
Assumptions carried from memory or docs: stills resolve through the manifest in `_src`. slot_legs.jpg is the greaves plate. art-pack.md soft alpha and high-quality downscale still stand. Palette snap was not applied. Her 2026-10-09 review overrides the claim that the veil was kept.
Also changed: tools/imglib/key.py (key_to_alpha, border_comparison, _fringe_color). tools/imglib/geom.py (resize_rgba hairline). Live PNGs in Chosen surfaces, including all eight wisp idles. This task file. No `.gd` files. `_src` was not written. Previews under `_logs/rekey-look/` (gitignored). Callers of key_to_alpha not run: pack_locomotion.py, pack_walk.py, process_gear_icons.py, rekey_stills.py, process_session_sprites.py, match_keyed_region.py. Callers of fit_box not run: pack_facing_fix.py, pack_p4_enemies.py, process_gear_icons.py, process_gloam.py, process_world.py, process_enemies.py.

## Baselines for the chosen surface
Current live stills, reviewed by Vira on 2026-10-09. Not accepted.

- assets/sprites/npcs/shopkeep.png. Slightly improved. Huge sections of the translucent glow are missing.
- assets/sprites/enemies/wisp/idle_up.png, and the other seven idles (same picture). Slightly improved. Huge sections of the translucent outer layer are missing.
- assets/fx/arrow.png. The translucent shading is gone.
- assets/sprites/props/hp_orb.png. The translucent border is gone. That border was the glow and was supposed to return as alpha.
- assets/sprites/player/female/idle_down.png. Chunks of the arms are missing.
- assets/ui/gear/head.png. Blurry.
- assets/ui/gear/hatchet.png. Mostly good. Missing the solid outline from the plate.
- assets/ui/gear/longbow.png. The string reads as sparkles.
- assets/ui/gear/slot_legs.png. Not called out in this review.

The 2026-10-09-0250 worktree notes (magenta gap, purple wisp edge, pink arrow fringe, partial hatchet) were the attempt before this one.

## Files and functions to touch
- tools/imglib/key.py: key_to_alpha, border_comparison, _fringe_color. Solid plate becomes transparent black. The translucent veil must stay as partial alpha. The despill that subtracts min(R, B) - G deleted that veil on shopkeep, the wisp, the arrow, and the orb. Do not bring back the RGB invert. Do not delete glow to make the selftest clean. Solid outlines on the plate have to survive.
- tools/imglib/geom.py: resize_rgba. Nearest only when both sides grow. Sizing down stays high quality, and head.png must not come out blurry. The hairline lift made the bowstring sparkle. A string has to stay one line. fit_box still crops alpha at 24. Do not throw away a faint halo when that halo is the glow she wants kept.
- tools/imglib/selftest.py: run `python tools/img_inspect.py selftest` after a key change. It passed. That is not acceptance.
- The nine live paths above. Write a still only after you have looked at it. She confirms each one.
- design/art-pack.md if the key contract changes again.

## Did not work
`python tools/img_inspect.py selftest` passed (12 checks) after this key change. A passing selftest is not acceptance.

Vira reviewed the open set on blue on 2026-10-09. She does not see the set as fixed. Some stills are slightly improved. None are accepted.

- Hatchet is mostly good. It lacks the solid outline the plate has. Many of these plates have a solid edge, and that outline was lost.
- Shopkeep and the wisp are missing huge sections of their translucent areas.
- The bowstring does not read as a string. It looks like sparkles.
- Chunks of the female's arms are missing.
- The head looks blurry.
- The arrow has none of its translucent shading.
- The orb's translucent areas are completely missing. That border was the glow. It was supposed to come back as alpha.

The key cleared plate and subtracted min(R, B) - G on the fringe. That removed the veil instead of storing it as alpha. The hairline lift in resize_rgba broke the string into separate marks. Do not call the key done. Do not treat the older lip and JPEG selftest failures as open.

## Open questions
none. The look, the reference, the open set, and the out-of-bounds list are settled above. Ask only if a discovery changes what she will see.
