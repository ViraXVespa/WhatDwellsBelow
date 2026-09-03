# Grok Build session log

Status: working notes  
Read when: starting a fresh Grok Build instance, especially after a token refresh or a week of User-side work  
See also: `design/protocol.md`, `design/art-pipeline.md`, `design/player.md`

This is the handoff between Grok Build sessions. It is **not** binding game design. Binding behavior stays in the topic files. The live tree is still the source of truth for shipping code.

The User does other work between weeks (git commits, stills, systems). **Image-to-video and complex animation packing/playback stay in Grok Build sessions** unless the User says otherwise.

## Leave-off

**Last closed session:** 2026-09-02  
**Closed because:** User approaching usage limit. Walk re-pack had just finished.

### Pickup checklist (do this first)

1. Read this **Leave-off** and the newest log entry below.
2. Inspect the live tree and `git log` / `git status`. The User will have changed things. Do not assume this file matches disk.
3. Read `design/protocol.md`, `design/constraints.md`, then only the topic files for the requested work.
4. For sprite / I2V / walk work, also read `design/art-pipeline.md` and `tools/i2v_seeds.py`.

### Next Grok Build work (as of 2026-09-02)

Priority if the User does not name something else:

1. **Walk cycle quality.** Play male/female 8-dir locomotion. Packer (`tools/pack_locomotion.py`) still picks weak periods on some facings (see log). If start/loop/stop still slide, stay legs-apart, or loop badly, fix detection — do not regenerate I2V unless the User rejects a clip.
2. **Remaining body I2V** (one clip per unit, User review): attack / special / gather / death / Dispel. Unarmed body only. Paper-doll overlays stay layers. Accepted walk units: female Down, male Down-Left.
3. **Extraction Gates in-world.** Sprites and gen/interact are in. World lighting on the machines is not wired. Confirm 3 north-wall safe rooms, one-use after a mail session.

### Do not redo unless asked

- Re-keying idle with remap + `spill_flood=False` (holes were the aggressive wand on Bible cells).
- Replacing dungeon clerks with Extraction Gates (design + live).
- Splash graffiti treatment (Proudly struck, Shamelessly tag).
- Playtest think-script parse errors (`playtest_ai_think.gd` local helpers).

---

## How to maintain this file

**At the start of a session** (token refresh / “catch up”):

- Read Leave-off.
- Diff live vs the last log (git, `design/` live snapshots, `assets/sprites/player/`).
- Ask once if the User’s between-week work conflicts with the listed next work.

**At the end of a session** (before stopping):

- Rewrite **Leave-off** (date, why we stopped, pickup checklist, next work).
- Prepend a new **Log** entry (newest first): what shipped, paths, what is still open, what the next instance must not assume.
- Keep entries factual. Do not narrate I2V clips. Name units: gender, facing, action, seed/path.
- Binding behavior changes still go in the matching topic file (`player.md`, `art-pipeline.md`, …), not only here.

---

## Log (newest first)

### 2026-09-02 — Walk pack, Extraction Gates, splash, keyer holes

**Why we stopped:** Usage limit. Walk clip re-pack completed after the User signed off for the week.

**Shipped this session (plus compacted earlier work in the same Grok Build week):**

- **Locomotion keyer.** `pack_locomotion.py` was calling `fit_canvas` → `key_to_alpha` with spill-flood on compressed I2V frames and skipping `plate_remap.py`. Same functions as `sprite_pipeline.py`, worse input. Video path: remap plate, then `key_to_alpha(..., spill_flood=False)`, then `fit_canvas(..., key=False)`. Idle Bible cells were still using the aggressive wand; re-packed 16 idle stills the same tight way. Walk/start/stop were already on the tight path.
- **Walk cut + playback.** Packer now looks for one self-similar stride period instead of even-sampling the whole clip. Start/stop are 3 frames (not ~1/3 of the clip). Engine (`player_anim.gd` / `player.gd`): `loc_foot`, reverse `idle_to_walk` when stopping on the start lead foot, else `walk_to_idle`. `WALK_FPS` still 8. Design live snapshot in `design/player.md`.
- **Walk re-pack** of all 16 `{male,female} × 8 facings` from `_src/walk_final/*.mp4` into `assets/sprites/player/{male,female}/`. Harvest reuse `_src/walk_harvest/`. Final pack log (period / index windows) is in the session terminal; weak periods to re-check in-game: `male up_right` (17), `male right` (19), `male left` (6), `female up_left` (loop starts at frame 1).
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
