# Hub — yard chrome and live snapshot

Status: binding design  
Read when: striking dummy, Label3D priorities, post-rail fence, hopeful ambience, warmup overlay


## Test Dummy
- Striking dummy (`DummyS` / `scripts/combat/dummy.gd`) for testing.
- Occupancy, no knockback, refill at 0 HP: combat.
- No combat level / `Lv` tag (`combat_lv := 0`).
- Dark ground pad allowed for telegraph readability.
- Sandbox object, not interactable like Floor Crystal / Anvil.
- Centered at the west arm of the cross path (`8.5, 0, PATH_Z + 0.5`).

## Labels
- Hub and dungeon spot labels use `Label3D` with `no_depth_test`, `render_priority = 8`, `outline_render_priority = 7`.
- Fill and outline stay in the same draw order so the black outline does not slip behind the player while the white fill stays in front.
- Labels draw over buildings and props. The aim line is the only world overlay that may sit above them.

## Aim line (hub and dungeon)
- Draws over buildings and props.
- Does not draw on top of the player sprite. Clip + short fade off the player origin (`scripts/combat/aim_line.gd`).
- Hidden-until-`update_line` / no cream-box flash: combat.

## Fence / play area
- Post-and-rail fence on all four edges of the current ground slab (`camp_view.gd`).
- Collision matches the rails so the player cannot leave the yard.
- Grass tiles continue past the slab (`GRASS_PAD`) so the world does not drop to empty outside the fence.

## Hub Audio / Atmosphere
- Warm, hopeful, lightly comedic music and ambience (stand-in until final assets).
- Lighting/mood contrasts with darker dungeon.

## Live Snapshot
- `App.play_from_menu()` / `enter_dungeon()` use loading overlay for hub/dungeon assets (ui). Floor Crystal **Enter dungeon** calls `present.cover_enter` (opaque cyan + caption) on the press, then `wait_painted` (0s always-timer + two `frame_post_draw`) so that sheet is on screen before save / close / scene change. Loadout pause must not block that wait. Do not hitch on the same stack as the cover — Compatibility will present the previous frame.
- Title → Play: `loader.begin()` puts a near-opaque black sheet (`#000000` at alpha `0xFE`) over the viewport for the whole load. The 3D world still draws under it so WebGL can compile and upload. The player must not see the square pop or flicker.
- After camp is ready, the overlay status is `Warming things up for you...`. `camp.warmup()` frames the yard and dummy-slides when the dummy already exists. `AppFlow._warmup_hub` applies already-loaded player textures (idle stills at spawn) in one beat under the sheet, one pinned `move_and_slide`, a `force_draw`, then restores the saved camera and waits two frames. The player body stays visible under the sheet. There is no empty “The square holds.” hold. Title → Play sync-loads hub building facades, props, NPCs, dummy, and hub music (not plaza tiles — ground / buildings `load()` those — and not 8-dir player clips). `camp.tscn` does not const-preload player, interact, dummy, smoke, or gear UI; those `load()` when `_ready` / `ensure_ui()` need them. Hub spots build sprites and labels only; `interact_act` / `interact_chest` load on first interact. Title → Play defers the sandbox dummy until after `loader.finish()`. Extract-wake also defers it (`call_deferred` after the wake fade starts). Other camp loads still spawn it in `_ready`. Dummy sprite and collision only at spawn; hp bar and float numbers load on first hit (boss/guard still pin a bar in setup). Gear UI (`progress_ui`) loads on first crystal / anvil / vendor interact (`world_ui` → `ensure_ui`), not during Title → Play. P6 smoke still builds it before assertions. Hub spawn loads walk/camera/sprites only; combat, telegraph, aim line, and `combat.gd` wait until physics after the sheet. Player spawn loads idle stills; walk / start / stop load on first stick per facing, Down attack/special on first swing. Outer grass is four tiled planes, not a 1×1 MultiMesh ring.
- Recap Continue starts the wake cover immediately (`present.cover_wake`: opaque cream, caption, SFX) and hides recap, then `go_camp()`. Camp rebuilds under that hold; `release_wake()` starts the 1.1s fade when `_ready` finishes. That return does not run the Title → Play warmup overlay. `lose_unextracted` is saved in recap finish; camp does not save again on that wake.
- During that same beat, `camp_warm.gd` moves the camera to the yard center and sets `cam.size` wide enough to frame the full slab plus `GRASS_PAD` (stall, guild, banner, outer grass). `ZOOM_MIN` is not wide enough. `App.cam_zoom` is not written. `camera_rig.warm_hold` ignores player `follow` so the physics tick cannot snap zoom back mid-warm.
- Before `loader.finish()`, warmup restores the user’s zoom and follow target, then waits two frames so the reveal uses the saved camera. The player must not see the pulled-back view.
- Extract-wake / `go_camp()` after a run does not call that warmup overlay.
- Player body and adrenaline aura stay hidden until they have a real texture / non-zero alpha on first spawn. Warmup then keeps the body visible under the sheet.
- Hub ground: grass outside the yard, one packed-dirt fill, cobble-tinted path (`plaza_grass` / `plaza_ground` / `plaza_path`). No scattered dark dirt patches.
- Buildings are 3D boxes with `plaza_wall` sides, a top plane, and a south-face facade sprite fitted to the box (`min` of width/height pixel size).
- Guild roofs use `plaza_roof.png` with world-space `fract` wrap, toon shading, and a luma remap to dark brown-red shingles (US asphalt/terracotta, not dungeon slate). Vendor stall top uses `plaza_tarp.png` as one canvas sheet (UV 0–1, olive hemmed tarp matching the stall face).
- Guild hall and wing have a compact 3D awning at the south eave (`plaza_awning.png`, chunky vertical cream/rust stripes): a short cloth shelf you look down onto, a small front lip, a dark underside, and side triangles. One stripe direction (along the building width) on every face. It covers the painted shingle band only — not the windows. Stall keeps its painted tarp on the sprite.
- South eave is `ROOF_EAVE` (0.42). Guild hall and wing are separate roof planes (L-shape, wing raised 0.01 to avoid z-fight).
- Welcome banner text is pixel letters on the cloth, two lines: `WELCOME TO` / `PLACEHOLDIA!`.
