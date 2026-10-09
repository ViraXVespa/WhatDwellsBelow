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

The 2026-10-09 pack session wrote the open-set live PNGs from one colour-to-alpha. Vira called that attempt close. It is not accepted. Her notes are in Did not work.

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
- 2026-10-09, after the colour-to-alpha attempt: close, not accepted. Weird lines remain around the shaft and the rear of the arrow. Lots of edges got way too soft, especially edges that were clearly meant to be hard. Hard edges on the plate stay hard. The next session fixes those two and does not call the set done.
- 2026-10-09, later session, shopkeep only: the halo looks good. Body holes stay filled. The halo is the nearest low-spill paint colour, not a magenta tint, with alpha falling off away from the body, about a 16th of the short side, far enough to enter the armpits and the gap between the hands and the legs. She saw it on black beside the previous live shopkeep. That yes is the shopkeep halo. It is not a yes for the rest of the open set. The live `assets/sprites/npcs/shopkeep.png` was not rewritten.

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
Decisions I made that were yours: drawn RGB stays (the unmix turned shading green). Pixels deeper than about a 24th of the short side from the plate become opaque, and plate-coloured pixels stay partial. Remap flattens only plate near a border reference. A heavy shrink puts back a near-white run. Canvases stayed 128, orb 48, gear 64. All eight wisp idles are this one plate.
Assumptions carried from memory or docs: stills resolve through the manifest in `_src`. slot_legs.jpg is the greaves plate. One shared key. Source plates are the reference. Her 2026-10-09 notes above override any claim that this attempt is accepted.
Also changed: tools/imglib/key.py (`key_to_alpha`, `remap_plate`). tools/imglib/geom.py (`resize_rgba`). tools/imglib/selftest.py (the light-pink lip keeps partial alpha). design/art-pack.md still-rekey section. Live PNGs in Chosen surfaces, including all eight wisp idles. This task file. No `.gd` files. `_src` was not written. Previews under `_logs/rekey-look/` are gitignored. Callers of key_to_alpha not run: pack_locomotion.py, pack_walk.py, process_gear_icons.py, rekey_stills.py, process_session_sprites.py, match_keyed_region.py. Callers of fit_box not run: pack_facing_fix.py, pack_p4_enemies.py, process_gear_icons.py, process_gloam.py, process_world.py, process_enemies.py, sprite_pipeline.py.

## Baselines for the chosen surface
Live stills from the 2026-10-09 colour-to-alpha attempt. Vira called the set close. Not accepted.

- assets/fx/arrow.png. Translucent shading is back. Weird lines remain around the shaft and the rear.
- Edges that are hard on the plate went too soft on many of these stills. That is the other open defect. It is not limited to one file.
- assets/sprites/npcs/shopkeep.png, the wisp idles, hp_orb.png, female idle_down.png, head.png, hatchet.png, longbow.png, and slot_legs.png were in the same review. She did not name a separate defect on each. Do not treat silence as acceptance.

The attempt before this one had lost the glow, the orb border, the hatchet outline, the bowstring, and chunks of the female's arms, and head.png was blurry. Do not return to that fringe subtract.

## Files and functions to touch
The shopkeep halo is accepted. Do not reopen that look. The code is `key_to_alpha` in `tools/imglib/key.py`. Read `## Work this session` before changing it.

- `python tools/show_func.py tools/imglib/key.py key_to_alpha`, then `remap_plate`. One `chroma_alpha`. Drawn RGB stays on the paint. The halo is the nearest low-spill paint colour, alpha falling off over about a 16th of the short side. Empty plate stays clear. `c2a` snaps alpha under 10 to 0 and over 242 to 255. Do not use it. Do not bring back a fringe walk, a red-and-blue-above-green subtract, a resize hairline, the wide shell, or a fade measured from the plate.
- `remap_plate` flattens solid plate to `#FF00FF`. It does not shift a farther mix.
- `python tools/rekey_preview.py`, then `python tools/show_png.py` on the paths it prints. The counts are the check. A picture description is not a pixel count. `partial` is the veil kept as alpha. `plate_opaque` is solid plate left in the art. `halo_cropped` is faint alpha `fit_box` drops at its default floor of 24. Pass `alpha_min` lower when that glow is the result. A blue glow is hard to see on the blue composite. Also show it on black. This tool stays in `tools/`. Do not write another preview under `_logs/agent-py/`.
- No play-camera baseline and no `--visual` on the gate. Q0 is already answered. Open questions are none.
- Do not match the live PNGs. They are the rejected attempt, except the shopkeep halo, which she accepted from the black preview and which is not yet the live file. The source plates are the reference. Do not call `rekey_stills.prep`. It nearest-upscales a small plate, and that distorted the female face.
- tools/imglib/geom.py: `resize_rgba`. A flat nearest upscale is reduced to its pixel grid first. Nearest only when both sides then grow. Sizing down stays high quality. The hairline lift that sparkled the bowstring stays out. The near-white run keep is only for a run the shrink would average away. `fit_box` crops alpha below `alpha_min` (default 24). Pass a lower floor when that faint alpha is the glow. Do not throw the glow away.
- tools/imglib/selftest.py: run `python tools/img_inspect.py selftest` after a key change. A pass is not acceptance.
- The nine live paths in Chosen surfaces. Write a still only after you have looked at it. She confirms each one. Shopkeep is confirmed. The others are not.
- design/art-pack.md if the key contract changes again.

## Did not work
`python tools/img_inspect.py selftest` passed 12 checks after the accepted halo. A passing selftest is not acceptance of the open set.

This session, before that pass: `python tools/img_inspect.py selftest` failed `key exact plate` (wrong px 560) and recolored the lip cloth. Cause: the halo was painted onto empty plate, and a real edge colour was treated as bloom. Fixed by leaving empty plate clear and keeping opacity above 0.55 as paint. The rerun passed.

`python tools/check_tool_cli.py` failed `MUTATE anim_review_pack.py: --help changed files`. This slice did not edit that file. The worktree's changed paths after that check were only the key, geom, plate_remap docstring, art-pack, and tools-media.

Shopkeep body holes and the halo are the accepted look. Arrow lines, soft hard-edges, and the other open-set stills are not confirmed. Do not call the set done.

## Open questions
none. The look, the reference, the open set, and the out-of-bounds list are settled above. Ask only if a discovery changes what she will see.

## Work this session
Shopkeep halo accepted 2026-10-09. The rest of the open set is not. Live PNGs were not written. The key change is on `grok-build-w7` in the commit that added this note. Resume with `python tools/open_slice.py art_pipeline.pack --task rekey-assets`.

What she saw: `_logs/prove-view/rekey-shopkeep/01-shopkeep.png` (previous live beside the new still on black). The black still is `_logs/rekey-look/shopkeep-black.png`. Both are gitignored and will not be in a fresh worktree. Blue hid this halo. Show a blue glow on black.

The key now, in `tools/imglib/key.py` `key_to_alpha`:

- Paint stays opaque. That is what put the shopkeep's missing sections back.
- A plate mix within about a 16th of the short side of real paint (spill under 12) takes that paint colour. Alpha falls off away from the paint (`fade ** 0.55`, times 0.95). Empty plate stays clear.
- `remap_plate` flattens solid plate to `#FF00FF` and does not shift a farther mix. That shift was the arrow-line suspect.
- `tools/imglib/geom.py` reduces a flat nearest upscale before the fit. On a keyed image the detector often stops at a small cell. Do not nearest-upscale the plate before the key.

Do not put back the wide shell (short side / 24), the one-pixel snap of every light pixel, or a fade measured from the plate. Those three deleted the glow, reopened the holes, or left a magenta rim.

Counts on the accepted shopkeep fit (128, pad 8, alpha floor 8): partial 1230, opaque 4062. Partial RGB median 127 128 163. `img_inspect.py selftest` then passed 12. An earlier selftest failed (`key exact plate` wrong px 560, and the lip cloth was recolored). Empty plate must stay clear, and paint with opacity above 0.55 stays paint.

Next session, in order:

1. Refit the open set with `python tools/rekey_preview.py`. For a blue glow, also composite on black. Shopkeep is the reference for the halo.
2. She confirms each still. Write that live PNG only after her yes. Shopkeep's yes is already in. Write `assets/sprites/npcs/shopkeep.png` from this key when she wants it on disk. She has not asked for that write yet.
3. All eight wisp idles are the one `idle_up.jpg` plate. Do not rekey dummy, guild, guild reception, stall, anvil, fence, pickaxe, or the male frames.
4. Do not edit `_src`.
5. Commit only when she says so. Gate is `python tools/run_build_gate.py --batch` with no `--visual`.
