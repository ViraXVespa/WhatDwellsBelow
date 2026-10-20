# Hub — yard chrome, load and buildings

Status: current plan  
Read when: striking dummy, Label3D priorities, post-rail fence, hopeful ambience, warmup overlay

## Test Dummy
- Striking dummy (`DummyS` / `scripts/combat/dummy.gd`) for testing.
- Occupancy, no knockback, refill at 0 HP: combat.
- No combat level / `Lv` tag (`combat_lv := 0`).
- Dark ground pad allowed for telegraph readability.
- Sandbox object, not interactable like Floor Crystal / Anvil.
- Centered on the `Layout/Spots/Dummy` node (default west arm of the cross path).

## Labels
- Hub and dungeon spot labels use `Label3D` with `no_depth_test`, `render_priority = 8`, `outline_render_priority = 7`.
- Fill and outline stay in the same draw order so the black outline does not slip behind the player while the white fill stays in front.
- Labels draw over buildings and props. The aim line is the only world overlay that may sit above them.

## Aim line (hub and dungeon)
- Draws over buildings and props.
- Does not draw on top of the player sprite. Clip + short fade off the player origin (`scripts/combat/aim_line.gd`).
- Hidden-until-`update_line` / no cream-box flash: combat.

## Fence / play area
- Post-and-rail fence on all four edges of the current ground slab (`camp_view.gd`). Slab extents come from `Layout`.
- Collision matches the rails so the player cannot leave the yard.
- Grass tiles continue past the slab (`GRASS_PAD`) so the world does not drop to empty outside the fence.

## Hub Audio / Atmosphere
- Warm, hopeful, lightly comedic music and ambience (stand-in until final assets).
- Lighting/mood contrasts with darker dungeon.

## Load, warmup and buildings

- Editor: opening `camp.tscn` builds ground, buildings, roofs, awnings and fence under an unsaved `Generated` node; awning, roof tile and UV values are Layout exports. Play does not persist `Generated`.
- Title → Play: a near-opaque black sheet covers the whole load while the world draws under it so WebGL can compile. The player must not see the square pop or flicker.
- After camp is ready the status reads `Warming things up for you...`. Warmup frames the full yard (slab plus `GRASS_PAD`) without writing the user's zoom, draws the loaded idle stills with the body visible, then restores the user's zoom and follow before the settle. The player must not see the pulled-back view. The hub MUST stay covered until two frames are within the 60 FPS budget (16.7 ms) or `WARM_HUB_FRAMES_MAX`; a steady slow rate does not count as ready. No empty “The square holds.” hold.
- Everything the first seconds in camp would add MUST be built and drawn under the loader before it lifts.
- Title → Play sync-loads hub facades, props, NPCs, male idle stills, the dummy sprite and hub music, then warms under the sheet whatever the first seconds would add: the dummy, gear UI (anvil and vendor opened once), pause and recap, the player's telegraph, aim line and lazy scripts, and the interact helper. Walk clips per facing and the dummy's hp bar / float numbers still load on first use. Extract-wake skips this warmup and defers the dummy.
- Enter dungeon: cover on the press and wait until it has presented before save / scene change. Loadout pause must not block that wait. Do not hitch on the same stack as the cover — Compatibility will present the previous frame.
- Recap Continue: wake cover at once, then `go_camp()`; the fade starts when camp is ready. No Title → Play warmup on that return, and camp does not save again.
- Player body and adrenaline aura stay hidden until they have a real texture.
- Hub ground: grass outside the yard, one packed-dirt fill, cobble-tinted path. No scattered dark dirt patches. Outer grass is four tiled planes.
- Buildings are 3D boxes with plain-colour sides (untextured on purpose: the play camera does not show them), a top plane and a south-face facade sprite fitted to the box.
- Guild roofs use `plaza_roof.png` with world-space wrap and a russet remap to awning-red terracotta, not dungeon slate. Lids do not sample the yard atlas. The stall top uses `plaza_tarp.png` as one sheet.
- Hall and wing keep a compact 3D awning at the south eave (`plaza_awning.png`, chunky cream/rust stripes along the building width): a short shelf with a small front lip, dark underside and side triangles, covering the shingle band only. The stall keeps its painted tarp.
- Hall and wing are separate two-slope gables (L-shape), not sheds: ridge along the width, rise 0.55 hall / 0.48 wing, no overhang, timber triangles close each end.
- Welcome banner: pixel letters on the cloth, two lines `WELCOME TO` / `PLACEHOLDIA!`.
