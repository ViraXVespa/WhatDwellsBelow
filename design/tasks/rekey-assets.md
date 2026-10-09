# Rekey assets after the keying changes

id: rekey-assets
owner: build
status: open
done-when: every asset below keys cleanly (Vira confirms each), and slot_legs.png links to the empty leg slot asset
resume: python tools/open_slice.py art_pipeline.pack --task rekey-assets (from the main checkout; it links _src in)
needs-local: _src

## Source plates
`_src` in the worktree is a link to the main checkout's source plates: read from it only, never edit, move or delete in it. Keying tools: `tools-media.md`.

Vira placed the empty leg-slot plate herself at `_src/sources/assets/ui/gear/slot_legs.jpg` (dark greaves on magenta). The session had written a copy to `_src/shot_legs.png` and did not put `slot_legs.jpg` there. Use her jpg. Do not key `slot_legs.png` from the extract gate.

## Next attempt (her words, 2026-10-09)

The pass on this branch is not accepted. The checklist below is the original report. This section is the direction.

Color-to-alpha is not doing its job. The purple in the keyed shopkeep and the keyed wisp is not purple smoke. The shopkeep has a translucent blue glow. The wisp has a translucent outer layer. Blue mixed with the plate reads as purple. The arrow has translucent shading around it. Leave that shading in the art and turn it to alpha. The same glow caused the borders on the hp orb.

Sample the strong black, white, and blue border pixels and use those as the comparison base for color-to-alpha. Distinguish those border pixels from the subject.

The female face was distorted by the resize. A chunk is still missing from her right arm (her right; the left side of the image).

Green specks show up in some places. She suspects a color inversion. `eat_spill` in `tools/imglib/key.py` inverts RGB while it despills. Check that before inventing another cause.

Small alpha holes: the top of `assets/ui/gear/head.png`, and near the top of the arrow tip in `assets/fx/arrow.png`.

Rough, chunky edges show up on several assets. `hatchet.png` has them in these spots: the bottom of the inner loop at the bottom of the axe; about halfway up the back of the handle; several places along the front edge of the handle; the top of the handle where it comes through the axe head; about halfway along the top of the axe head; two places along the blade. It is not known whether that is the key, the resize, or both.

The longbow string is gone in places. That is a step back.

Downscaling used nearest-neighbor. Nearest is only for upsizing. When sizing down, use the highest-quality resize so detail is not lost.

She wants this simpler. Retool the keyer from scratch if that is what gets color-to-alpha right. Do not keep stacking special cases on the current pass.

What this branch already wrote, so the next session does not treat it as a clean tree: `tools/imglib/key.py` and `tools/imglib/selftest.py`; the listed stills rekeyed at the tooling canvases (game scale comes from the texture, so world size follows aspect); 193 female and male frames whose manifest source stem matched the frame, rekeyed to 128; 142 player frames left untouched because the manifest source is a different pose; all eight wisp facings written from `idle_up`. None of that output is settled.

## Issues (her words)
### assets/fx
- [ ] arrow.png - Looks like there's some weird chroma/coloring around the shaft of the arrow that isn't being keyed correctly.
- [ ] dummy.png - Various bits of the straw and other edges are being unexpectedly culled.

### assets/sprites/buildings
- [ ] guild.png - Tons of unintended areas are being removed.
- [ ] guild_reception.png - Same.
- [ ] stall.png - The entire image is being cleared.

### assets/sprites/enemies
- [ ] wisp - I'm not certain, but it seems like there's a lot of purple that either wasn't supposed to be removed or more that should have been removed.

### assets/sprites/npcs
- [ ] shopkeep.png - Lots of chroma is being left between the body and the hands/arms.

### assets/sprites/player
- [ ] female - Lots of stuff is being removed from the edges of the character. Especially around the hair and the shoulders.
- [ ] male - Lots of stuff is being removed from the edges of the character. Especially around the shoulders and the legs.

### assets/sprites/props
- [ ] anvil.png - Parts of the anvil tip and the wooden base are being erroneously culled.
- [ ] fence.png - Large portions of the fence are being erroneously culled.
- [ ] hp_orb.png - There are rounded areas of chroma left around the edges instead of culling at the hard pixel edges.

### assets/ui/gear
- [ ] hatchet.png - a clear portion of the sharp edge of the axe was cut out.
- [ ] head.png - Part of the nose thing was erroneously cut out.
- [ ] longbow.png - It's hard to tell because of the size, but it seems like the bowsting was culled a bit too hard.
- [ ] pickaxe.png - Various parts of the wooden handle were erroneously culled.
- [ ] slot_legs.png - This was linked to the inactive extract gate instead of to the empty leg slot asset. Vira replaced `_src/sources/assets/ui/gear/slot_legs.jpg` with the empty-slot plate. Key the live png from that jpg.
