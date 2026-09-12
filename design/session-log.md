# Grok Build session log

Status: working notes  
Read when: closing a Grok Build session, or when `design/sessions.md` is not enough to name the next unit  
See also: `design/sessions.md`, `design/grok-build.md`

Append-only facts. Newest first. Not binding game design. Not part of every Grok Build boot. Web / chat and Grok Bot do not write this file.

Do not narrate I2V clips. Name units: gender, facing, action, seed/path.

---

### 2026-09-09 — grok_build_w3 pin

**Pin:** `grok_build_w3` = `e7a9d2cf56965b711dc5b22eb7735a1875d96407` (`Grok Build Week 3`). Tag `archive/grok-build-w3`. That is the User completion commit, not the CI stamp.

**Stamp (do not pin):** `6bd72757e606168e0c2d3edb593f5ef275ca5f41` is `chore: stamp 0.2.56 [skip ci]`. CI does not auto-bump series, so it labeled the push 0.2.56. `scripts/data/version.json` is seeded to series 3 / `0.3.0` / `open_commit` = the Grok Build SHA so the next user push stamps `0.3.x`.

**Do not:** pin the stamp. Next **new week** CLI is week 4 init (`grok_web_w3` = then-current `main`).

---

### 2026-09-09 — 0.3.0 week-3 close

**Why we stopped:** User asked for `0.3.0` and to move to the next development week. They will commit, then send the SHA to pin as week-3 Grok Build Results.

**Wrote:** `design/changelog/0.3.0.md` (series-open / Grok Build Week 3). Previous-week museum copies: `archives/docs/grok_build_w3/` from `design/changelog/0.2.*.md`.

**Pins:** Do **not** write `grok_build_w3` into `archive_catalog.json` until the User sends the commit hash. `grok_web_w2` stays `bb70f556108d0e09e070cfaa42260f642af3737a` (`0.2.55`). Next CLI opened by saying **new week** is week 4 init: pin then-current `main` as `grok_web_w3`.

**Do not:** invent a SHA. Do not hand-edit `scripts/data/version.json` (CI stamps `0.3.0` on the User’s push). Do not emit `changelog.json`.

---

### 2026-09-09 — Placeholdia / dungeon world art pass

**Why we stopped:** User ended the weekly Grok Build session. Mid-week catch-up (same week, no pin). World-art slice shipped and patched after in-game review.

**No I2V this session.** Player attack placeholders and walk packing were not resumed.

**Shipped:**

- Style lock: locked player Bibles / Down idle stills. Hub + dungeon tiles, building facades, props, hub NPCs, ghost shopkeep, dummy, boss door, cracked wall. Installer: `tools/process_world_pass.py`. Stills in this session’s `images/` (`1.jpg`–`43.jpg`).
- Hub tiles: `plaza_grass`, `plaza_ground`, `plaza_path` (dirt/cobble blend), `plaza_wall`, `plaza_roof`. Dungeon: `foundation_floor`, `foundation_wall`.
- `camp.gd`: south-face sprites fit the box (`min` of width/height); roof plane with eaves + `uv1_scale`; one yard dirt (no `% 7` dark scatter); path uses `plaza_path`.
- `dungeon_geo.gd`: textured floor/wall albedo `Color.WHITE` (old cold tint removed).
- `boss_door.gd` / `breakable.gd`: `boss_door.png`, `crack_wall.png`.
- Welcome banner: two-line pixel letters inset on the cloth (`WELCOME TO` / `PLACEHOLDIA!`). No TTF.
- Review fixes: dropped 50% quadrant crops (they cut single subjects in half); keyed at native 1024 then nearest-neighbor fit. Do not downscale before chroma key.

**Not done:** enemy stills / I2V; HUD and gear icons; player attack / special / gather / death / Dispel; remaining attack facings; walk pack from `_src/walk_final/`. Dungeon floor still has a 4-stone cluster that can read as a grid.

**Do not:** pin a week archive (User said no pin). Do not resume attack I2V from this leave-off. Do not downscale world stills before key. Do not 50%-crop single-subject stills. Do not put Consolas on the banner.

---

### 2026-09-09 — Week 3 animation handoff

**Why we stopped:** User closed the I2V slice. Next CLI chat this week is a different task (catch-up, no pin). User will rewrite the attack I2V pipeline during the week. **Next week’s first Grok Build session: replace every live attack placeholder.**

**Week pins (init, not the User’s 0.3.0):** `grok_web_w2` = `bb70f556108d0e09e070cfaa42260f642af3737a` (`0.2.55`). Missed `grok_build_w2` = `36fb882c9db3b6cd8a83f072d2dfec51d4acedca` (`0.2.0`). Local tags `archive/grok-web-w2`, `archive/grok-build-w2`. Catalog + `archives/docs/grok_web_w2/` uncommitted until User pushes.

**Walk I2V (User packs):** only male Down-Right was packed this session. Accepted clips in `_src/walk_final/`: male `down_right`, `left`, `up_left`, `up`, `up_right`, `right`; female `left`, `up_left`, `up`. Walk MOTION: start-hold then end-hold. Seeds: male `_src/i2v_male_walk_*`, female `_src/i2v_female_walk/` + per-unit folders.

**Attack I2V — ALL PLACEHOLDERS.** Live Down strips exist so baked per-weapon sheets are gone. They are **not** final. Replace at next week’s initial session with the User’s new pipeline. Other facings of `atk_great_axe` / `atk_staff` / `atk_longbow` were deleted; `player_anim.clip()` falls back to Down. Pack: `python tools/pack_oneshot.py --gender male --gender female --action attack_great_axe --action attack_staff --action attack_longbow --facing down`. `pack_oneshot.py` picks 6 harvest indices then cleans those only.

| Unit | Live source (placeholder) | Notes |
|------|---------------------------|--------|
| male Down `attack_great_axe` | `_src/oneshot/male_attack_great_axe_down.mp4` | User accepted motion. |
| female Down `attack_great_axe` | `_src/oneshot/female_attack_great_axe_down.mp4` (pass 10 / video 20) | Gather can be empty; handle/axe still appears as arms extend into the swing. |
| male Down `attack_staff` | `_src/oneshot/male_attack_staff_down.mp4` (pass 2 / video 27) | Retry after stick-then-punch. |
| female Down `attack_staff` | `_src/oneshot/female_attack_staff_down.mp4` (pass 2 / video 28) | Retry after run-cycle + punch. |
| male Down `attack_longbow` | `_src/oneshot/male_attack_longbow_down.mp4` (video 24) | Not retried; side-on draw on a Down still. |
| female Down `attack_longbow` | `_src/oneshot/female_attack_longbow_down.mp4` (pass 2 / video 29) | Retry after rightward draw on Down body. |

**Prompt lessons (for the new pipeline):** Original male-axe MOTION (two-handed great-axe swing, “as if on a long haft”, five beats) produced good **motion**. Over-correcting (geometry-only fists, no haft, belly clash, hands below shoulders, magenta gap between hands, mid-action continuation seed) destroyed motion. One-shot head used to share walk **treadmill / marching in place** — that made staff clips run; live code now uses planted `_PROMPT_HEAD_ONESHOT` + `FACING_LOCK_PLANTED`. Staff “shaft held across the body” spawned a stick; “thrust or tap” became a punch. Longbow “along the facing” on a Down still became a side-on archer. Do not seed I2V from a harvested mid-pose. Do not name pack-slot frame indices in I2V prompts. Seed = idle Bible cell, opaque plate.

**Engine:** `player_anim.gd` basic attack indexes by `atk_t / duration` (attack-speed ready). `atk_fps` is not that clock. Specials still use `atk_fps` for playback speed but now use the same Down placeholder strips as attack (`spc_*_down_*` copies of `atk_*`; other special facings deleted).

**Pack fix:** first oneshot pack `lock_x`'d against the raw Bible cell (wider than 128), which shoved figures off the canvas (half-body in game). `pack_oneshot.py` now `key_fit`s the idle still and `lock_baselines` like locomotion. Re-packed all six Down attacks.

**Not done:** special / gather / death / Dispel I2V; weapon overlays; remaining 7 attack facings; walk pack of this week’s accepted clips (User).

**Do not:** resume this I2V list from a mid-week catch-up unless the User names it.

---

### 2026-09-02 — Walk pack, Extraction Gates, splash, keyer holes

**Why we stopped:** Usage limit. Walk clip re-pack completed after the User signed off for the week.

**Shipped this session (plus compacted earlier work in the same Grok Build week):**

- **Locomotion keyer.** `pack_locomotion.py` was calling `fit_canvas` → `key_to_alpha` with spill-flood on compressed I2V frames and skipping `plate_remap.py`. Same functions as `sprite_pipeline.py`, worse input. Video path: remap plate, then `key_to_alpha(..., spill_flood=False)`, then `fit_canvas(..., key=False)`. Idle Bible cells were still using the aggressive wand; re-packed 16 idle stills the same tight way. Walk/start/stop were already on the tight path.
- **Walk cut + playback.** Packer now looks for one self-similar stride period instead of even-sampling the whole clip. Start/stop are 3 frames (not ~1/3 of the clip). Engine (`player_anim.gd` / `player.gd`): `loc_foot`, reverse `idle_to_walk` when stopping on the start lead foot, else `walk_to_idle`. `WALK_FPS` still 8. Design live snapshot in `design/player.md`.
- **Walk re-pack** of all 16 `{male,female} × 8 facings` from `_src/walk_final/*.mp4` into `assets/sprites/player/{male,female}/`. Harvest reuse `_src/walk_harvest/`. Weak periods to re-check in-game: `male up_right` (17), `male right` (19), `male left` (6), `female up_left` (loop starts at frame 1).
- **Extraction Gates** replace in-dungeon clerks. Three per floor, each in its own safe room, spread (min sep 28). North wall only, 3 tiles wide. Mail anything extractable; artifacts/holds still cannot. Gate spends when the extract UI closes if anything was mailed. Sprites: `assets/sprites/props/extract_gate_on.png`, `extract_gate_off.png` (inactive = wall in the viewport, INACTIVE banner, same metal shading). Code: `scripts/world/dungeon_gate.gd`, `dungeon_props.gd`, `interact.gd`, `interact_fx.gd`, `progress_ui.gd`, `progress_extract.gd`, gen rooms. Design updated: `interactables.md`, `inventory.md`, `dungeon.md`, `overview.md`, `ui.md`, others. Tunable still named `max_clerks` (default 3).
- **Splash.** `scripts/ui/splash.gd`: “Proudly Vibecoded with Grok” with a strike through **Proudly** only; graffiti `assets/ui/splash_shamelessly.png` above it. Do **not** run default `sprite_pipeline.py` key/matte on that tag (pink fill ≈ plate). Keyed with `plate_remap.wand_plate` border punch only.
- **Playtest.** `playtest_ai_think.gd` parse errors: `is_junk` / `mark_pad` / `drop_lock` / `wander_step` / `is_use_kind` were not on `playtest_ai_util.gd`. Locals added on the think module. Headless boot then loaded without those parse errors.
- **Stills re-key** from Grok session JPGs (`tools/rekey_stills.py`) for enemies, NPCs, props, buildings, FX, equip, old player root walks. `shrine` / `lever` / `plate` had no session sources.

**Accepted I2V (do not regenerate unless User rejects):**

| Unit | Notes |
|------|--------|
| Female Down walk | Final. Seed/path under `_src/i2v_female_walk_down/` / `walk_final/female_down.mp4` |
| Male Down-Left walk | Final. `_src/walk_final/male_down_left.mp4` |
| Other 14 walk facings | Generated this week into `_src/walk_final/{gender}_{facing}.mp4`. Packed; quality TBD in-game. |

**Still open for Grok Build:**

- In-game review of walk start / loop / stop after the last pack. Fix packer, not I2V, unless a facing’s motion is wrong.
- Attack / special / gather / death / Dispel body I2V (one unit at a time, User review, opaque chroma seed).
- Extraction Gate world lighting (sprites are unshaded / same albedo both states on purpose).
- Some debug helpers already over the 10KB script cap (`playtest_ai_util.gd` and others) — do not grow them; split if an edit would push further.

**Live paths to open first next time:** `tools/pack_locomotion.py`, `scripts/world/player_anim.gd`, `assets/sprites/player/{male,female}/`, `design/player.md`, `design/art-pipeline.md`.
