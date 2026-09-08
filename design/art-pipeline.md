# Player sprite and paper-doll generation pipeline

Status: binding design  
Read when: generating or replacing player / enemy / weapon frames  
Code: `tools/sprite_pipeline.py`, `tools/i2v_seeds.py`, `tools/plate_remap.py`, `tools/pack_locomotion.py`, `tools/pack_oneshot.py`, `tools/rekey_stills.py`, `tools/process_*.py`, `tools/pack_*.py`, `tools/anim_review_lib.py`, `tools/anim_review_pack.py`, `tools/anim_review_regen.py`, `tools/anim_review_tree.py`, `assets/sprites/player/`  
See also: `design/player.md`, `design/audio-visual.md`, `design/combat.md`, `design/enemies.md`

This section is mandatory for any Grok Build instance. It exists because pure image-generation models (including Grok Imagine) have consistent limitations with multi-frame consistency, identity drift, spatial layout in grids, and pixel-perfect output.

Reliability comes from **one Image-to-Video clip at a time**, the live prompt in `tools/i2v_seeds.py`, **User review**, and plate-correct / cleanup scripts. Do not run automatic multi-pass fill-in.

All character art (player and enemies) MUST follow this pipeline. Props may use a simplified stills-only variant.  
Male and female player characters MUST each have their own locked Character Bible and MUST maintain full animation parity so that weapon and tool paper-doll **layers** composite onto either body without special per-gender tweaks.  
Player and enemy animations use exactly 8 directions matching the Character Bible layout.

## 19.0 Goals and non-negotiables

- One locked Character Bible per character type (male and female) is the single source of truth for identity, proportions, palette, and style.
- Identity drift, anti-aliasing, leftover start-chroma rims, magenta spill, foot sliding, scale inconsistency, and extra limbs/props are hard failures.
- All final frames MUST be true pixel art on an integer grid after cleanup (nearest-neighbor only).
- Prefer fewer high-quality, readable frames over many mediocre ones. The engine can hold or simple-tween if needed.
- Generate and clean one facing’s locomotion set as a proof before scaling to all directions and states.
- Final engine resolution target: 128×128 canvases (recommended). Nearest-neighbor downscale to 64×64 is permitted only if required by import settings; document the choice. Base resolution in `design/audio-visual.md` remains 64×64 for world units; sprite assets ship at 128×128 unless otherwise specified.
- Use game-centric direction names exclusively: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right.
- All directional variants of the same animation state for a given character MUST contain exactly the same number of frames.
- **One I2V clip per review gate.** After each clip, stop and wait for the User. Do not queue the next facing, action, gender, retry, or fill-in pass until the User says so.
- **No fixed I2V duration.** The clip is as long as it needs to be to finish the motion in `tools/i2v_seeds.py`. Do not demand ten seconds or any other clock.
- **Paper-doll means layers, not baked weapon characters.** Body animations ship unarmed. Equipped weapon and tool are separate overlay frames composited onto those body frames.
- **Every I2V first frame keeps an opaque chroma plate.** Never seed I2V from a processed transparent frame. This applies to player, enemy, and any future I2V call.

## 19.1 Character Bible

Create and lock one primary 3×3 Character Bible on a solid chroma plate for each character type (male and female).

Strict cell layout (do not swap, reverse rows, reverse columns, or move any figure). See Appendix C for the prompt template.

**Requirements:**

- Clean limited-palette pixel-art style.
- All eight full-body views in neutral standing pose (**no weapons, no tools, no action props**).
- Consistent silhouette height and foot baseline across all full-body cells.
- Extract and lock the exact palette used.

This single image is the primary design reference for all subsequent generations of that character type.

A visual reference of cell positioning and presentation quality:  
`assets/sprites/player/gdd_reference_bible.jpg`

That file is not a locked art style and is not the desired final look. It exists only to show Bible layout (3×3 cell placement, full-body framing, face close-up in the center) and a quality bar for silhouette readability. Grok Build MUST generate Character Bibles and animation frames from scratch. Do not treat the reference image as an input asset to edit or extend, and do not copy its surface style as a requirement.

**Final styling is intentionally unset before lock.** Grok Build MAY propose new visual options so long as they satisfy this database (readable 64×64 / 128×128 pixel-grid output after cleanup, 8-direction Bible layout, male/female parity, Y-billboard, nearest-neighbor, limited palette after lock, no anti-aliasing in shipping frames). Generate 2–4 distinct style candidates per gender, then lock the best Bible pair and palettes as usual.

**After lock:** `bible_locked_male.png` / `bible_locked_female.png` (plus palettes) force the look. Every later generation MUST match the locked Bible. Soft identity language applies only after that lock. If a Bible must be regenerated after lock, match the locked Bible. A new style is allowed only if the User explicitly agrees to re-lock.

Store them as:

- `assets/sprites/player/bible_locked_male.png`
- `assets/sprites/player/bible_locked_female.png`
- (+ locked palettes)

**Note on reliability:** Single-pass 3×3 generation currently produces the highest identity consistency. Chained image-edits from a single anchor introduce cumulative off-model drift and should be avoided for the Bible itself. If layout errors persist after 3–4 attempts, fall back to generating the eight full-body views + face individually (using soft identity language against the chosen style, then against the locked Bible once it exists) and compositing them deterministically with a script.

**Plate colour:** Grok often paints near-magenta instead of pure `#FF00FF` (example: `#F50487`, `#EE22DD`, other hot pinks / violets). Do not lock that raw plate. Do not punch it to alpha yet.

Run `tools/plate_remap.py` on the accepted Bible (and on any later raw still used as an I2V seed):

1. Sample the start chroma from the border.
2. Magic-wand the background from the border on that chroma.
3. Fill enclosed plate pockets the border wand cannot reach (armpits, crotch, between arm and torso). Use the same enclosed-island rule as `tools/sprite_pipeline.py` `_fill_pockets`.
4. Hue-correct wand / pocket pixels from start chroma to `#FF00FF`.
5. Analyse pixels on the wand frontier for start-chroma bleed and hue-correct that influence to `#FF00FF` influence.
6. Leave the plate **opaque**.

The remapped Bible / still is still a chroma source. It is the legal I2V seed. `sprite_pipeline.py` key-to-alpha runs only after the User accepts extracted frames.

**Square the Bible before any 3×3 split:** A generated Bible MAY not be a perfect square and MAY include extra margin. Hug the grid, not the silhouettes. Outer-cell plate padding stays in the sprites; only leftover canvas outside the 3×3 is cut.

Do not crop to the union bounding box of the eight bodies. That throws away the padding that belongs inside each cell.

Instead, recover the intended grid and crop to that:

- Range-key / separate the plate so figures are locatable.
- Find the eight full-body figures (ignore the center face close-up for lattice fitting if it sits on a different scale).
- Take each figure’s center. Fit them to a 3×3 lattice.
- Horizontal pitch = average distance between neighboring column centers.
- Vertical pitch = average distance between neighboring row centers.
- Cell size = the larger of those two pitches.
- The crop square is 3 × cell size, centered on the lattice origin (the center cell).
- That square MUST include the plate padding around the outer figures. It MUST NOT include random extra canvas beyond one grid-cell of margin.
- Do not stretch or linearly scale to force a square. Crop only.
- If centers do not form a readable 3×3 (skewed rows, missing figure, overlapping cells), discard and regenerate the Bible rather than guess a crop.

Save the squared, remapped sheet as the locked Bible.

## 19.2 Animation method (one I2V unit, then stop)

Always work **one unit** at a time. A unit is exactly one **character type** + one **facing** + one **action**.

I2V prompts come from `tools/i2v_seeds.py` (`build_prompt()` + `MOTION[action]` + facing lock + identity lock). Identity is per gender and facing: `IDENTITY_LOCK["female_up"]` is used for the female Up cell and omits neckband language because that still has no visible band. Do not invent a second walk prompt in this file.

Identity lock is per player gender and facing. Male and female each have their own `IDENTITY_LOCK` in `tools/i2v_seeds.py`. Do not copy male outfit language onto the female character. Pass `--gender male` or `--gender female`, or infer it from `bible_locked_male.png` / `bible_locked_female.png`. Where the still shows it, copy a short green neckband worn only around the neck, same bulk as the still. A little more of that same band may show at the nape when hair moves. Do not grow extra length or hanging cloth. Female Up uses `IDENTITY_LOCK["female_up"]` and MUST NOT mention a neckband, wrap, scarf, collar, or green cloth.

Grok Build I2V uses that body as-is. The web-browser preamble (image-to-video / do not output a still / no fixed duration) is **only** added when `tools/i2v_seeds.py --test` is passed.

`--action walk` is the locomotion method. It is not a breath / idle performance. `MOTION["idle"]` is not a player path.

Walk uses the loop wrapper in `tools/i2v_seeds.py` (starts and ends on the idle still). One-shot actions use the one-shot wrapper (start on the still, finish the motion, recover or hold; do not claim a walk loop).

`--action gather` (Animation Browser name with no tool suffix) writes **both** gather sheets. Unknown actions MUST NOT fall back to `walk`.

Legal I2V `--action` values:

| `--action` | Use |
|------------|-----|
| `walk` | Locomotion I2V. Pack cuts idle-to-walk / walk / walk-to-idle. |
| `idle` | Not a player path. Debug / still hold only. |
| `attack_great_axe` | Unarmed two-hand swing acting an axe. |
| `attack_staff` | Unarmed short melee poke acting the lightning staff. |
| `attack_longbow` | Unarmed draw and loose. |
| `special_great_axe` | Unarmed slam. |
| `special_staff` | Unarmed bolt-cast body (bolt is later VFX). |
| `special_longbow` | Unarmed fan loose. |
| `gather` | Writes pickaxe + hatchet sheets. |
| `gather_pickaxe` | One mine sheet. |
| `gather_hatchet` | One woodcut sheet. |
| `death` | Hit collapse to a downed hold. |
| `dispel` | Ritual seppuku: draw one small knife, kneel, one abdominal cut, collapse, hold. |

`idle_to_walk` / `walk_to_idle` alias to `walk`; they are not I2V units. Attack / special aliases (`atk_*`, `spc_*`) exist for browser class names.

Game facing is a locked view copied from the still (`FACING_LOCK` in `tools/i2v_seeds.py`), from the first frame. Down is marching in place toward the camera (both shoulders visible). Walk is in place as if on an invisible treadmill; do not draw a treadmill machine. Do not name a travel heading. Start/stop feet are “one foot” then “the other foot.”

After the User accepts the clip, harvest and pack. Then stop again if the next unit is not already named.

### 19.2.1 Seed still

Priority:

1. **Locked Bible cell (default).**
   - Split the locked, plate-remapped Bible into nine equal cells.
   - Take the one full-body cell that matches the facing being generated.
   - Upscale that cell by exactly 400% with nearest-neighbor only (`tools/i2v_seeds.py --cell`, or `--bible` to batch plates the User asked for). Every source pixel becomes a 4×4 block. No bilinear / Lanczos / AI upscale. No non-integer fit. No 1024 canvas pad.
   - After that integer scale, pad extra `#FF00FF` around the figure (`PAD_FRAC` of figure height on every short side) so lifted feet and swinging arms stay on-plate. Never shrink the figure to make padding.
   - If a later clean directional still exists for that facing, uses the same cell framing, **and still has an opaque plate**, 400% that still instead of re-splitting the Bible.

2. **Full locked Bible, only if the User asks.**
   - Same 400% nearest-neighbor rule on the whole sheet.
   - Default for every I2V attempt: one 400% spliced still of the needed facing, plate intact.

3. **Video-fill / last accepted clip, only if the User asks.**
   - Last resort for a single facing + action.

Do **not** seed I2V from a keyed transparent PNG. Overlay stills that go to I2V keep an opaque `#FF00FF` plate.

Switch to the full locked Bible only if the User saw the single-still I2V fail, or the clip needs more than one facing **and** the User approved that seed. Prompts MUST still name the primary facing.

**Soft identity language** (mandatory in every prompt after Bible lock):

Keep the same overall character design, face, hair, armor, green neckband (when that still shows one), proportions, palette, and sprite style from the Bible. Do not redesign, repaint, recolor, simplify, smooth, or invent new details. Hands are empty. Do not draw a weapon or tool. Do not mention a neckband on the female Up cell.

That language means the locked Bible, not the reference JPG. Dispel is the exception for the small ritual knife only (`MOTION["dispel"]` / `DISPEL_IDENTITY_TAIL` in `tools/i2v_seeds.py`).

Generate one full cardinal direction (Down + Left + Right + Up) completely before deriving diagonals, unless the User orders a different facing next. Horizontal flip is acceptable for opposite sides when the design is mostly symmetric; asymmetric details (neckband bulk, hair) MUST be corrected or regenerated.

Suggested first proof (do not run ahead of review): one gender, facing Down, one walk I2V.

### 19.2.2 What the walk I2V is for

In-game **idle is not an I2V product**. Idle is the directional key still for the facing the player is aiming — the same Bible cell / approved splice used as the I2V seed. One texture per facing. No breath cycle. Do not pack held “standing on the still” frames as idle.

| Packed state | Source |
|--------------|--------|
| `idle` | The key still for that facing. Not harvested from the video. |
| `idle_to_walk` | Opening of the walk I2V: still → first passing step. |
| `walk` | Cyclic strides from the same clip. |
| `walk_to_idle` | End of the same clip: last plant of the other foot, settle on the still. |

`idle_to_walk` and `walk_to_idle` MUST exist for every facing and both genders. They are first-class engine states. They are **not** separate I2V units unless the User rejects the walk clip and asks for a dedicated pass.

If the walk I2V fails the start/stop plant, reject the clip and regenerate that unit. Do not invent a second method in this file.

### 19.2.3 Frame counts after harvest

Walk harvest targets **8 frames** for `walk` when the clip supports it. `idle_to_walk` / `walk_to_idle` may be shorter (often 3–4) so long as both genders and all eight facings of that *state* share one count.

The same frame-count rule applies to every animation state: all eight facings of that state share one frame count. Attack / special / gather pack to 6 frames per facing. Death and Dispel keep the accepted clip length (Dispel may be long); those two states still share one count across the eight facings.

Pack one-shots with `tools/pack_oneshot.py` from `_src/oneshot/{gender}_{action}_{facing}.mp4`. Walk harvest stays `tools/pack_locomotion.py`.

### 19.2.4 Paper-doll overlays (weapons and tools)

Body clips stay unarmed. Weapons and gathering tools are **overlay layers**.

- Overlay pixels are registered to the empty-hand / grip position of that body frame and facing. Alignment MUST be identical for male and female aside from the body art itself. No per-gender weapon redraws.
- Locomotion and idle (`idle`, `idle_to_walk`, `walk`, `walk_to_idle`, `death`, `Dispel`): use a **carry / rest** overlay per facing. One rest frame per facing is enough unless the User asks for a matching overlay on every body frame.
- Attack / special / gather: one overlay frame per packed body frame for that action.
- Generate each overlay against **one** clean unarmed body frame (or accepted body clip) of the correct facing, not against the full Bible and not as a standalone character. Overlay stills that go to I2V keep an opaque `#FF00FF` plate.
- Engine draw order is body, then tool/weapon (weapon behind the body only when a facing requires it for a back grip; document that facing if used).

Do not bake a held axe, staff, bow, pick, or hatchet into a body frame. The Dispel knife is the only baked prop, and only on the Dispel clip.

## 19.3 Review gate (mandatory)

The User judges the I2V clip itself first (facing lock, travel, identity). Do not pre-harvest a rejected clip.

After accept, harvest, pack, and cleanup. Then the User judges the packed strip.

Do not start the next unit until the User says so.

## 19.4 Cleanup after accept

After the User accepts a clip and harvest exists:

1. If the plate is not `#FF00FF`, run `tools/plate_remap.py` first.
2. Range-key / wand the `#FF00FF` plate. Despill fringe. `sprite_pipeline.py` `key_to_alpha` punches the plate. Video extracts and session stills pass `spill_flood=False` after remap so compressed maroon / hair / purple cloth is not treated as plate. Then **snap alpha hard** (figure `255`, plate `0`) before any fit so Color-to-Alpha cannot leave a magenta-ish lip on dark backdrops.
3. Fit each frame to the 128×128 canvas with nearest-neighbor only. Integer scale. No bilinear.
4. Snap to the locked palette.
5. Remove anti-aliased edge pixels.
6. Align the foot baseline across the strip.
7. Confirm 8-direction parity and matching frame counts per state.

Do not ship a frame that still has start-chroma rims or a soft magenta halo.

## 19.5 Quality bar

A unit is acceptable only when all of the following hold:

- Correct facing and pose intent.
- Identity matches the locked Bible.
- No extra limbs, props, or invented costume.
- Feet plant on a stable baseline.
- Packed walk loops; start/stop cuts are readable.
- Readable `idle_to_walk` and `walk_to_idle` on every facing that has shipped those states.
- Pixel-grid edges after cleanup. No anti-aliasing. No magenta lip.

Failures:

- Persistent identity or scale failure → return to Bible and re-lock only with User approval if style would change.
- One bad facing → regenerate that unit only.
- Harvest cuts fail but the clip is good → adjust pack points; do not silently invent a new I2V method.

## 19.6 Animation Browser review briefs

The Animation Browser writes a local ledger at `tools/anim_review/review.json` (editor-only, gitignored). That file is not a game setting and is not part of `SaveStore`.

CLI:

- `python tools/anim_review_pack.py` — pack brief (`tools/anim_review/pack_brief.md` + `.json`). Repack notes are failure cases. Good on-disk locomotion clips (`walk`, `idle_to_walk`, `walk_to_idle`) are keep-behavior. Ignore Regenerate rows here.
- `python tools/anim_review_regen.py` — regen brief (`tools/anim_review/regen_brief.md` + `.json`). Regenerate notes plus the current `i2v_seeds.build_prompt` text for player clips. `i2v_action` keeps class keys (`attack_great_axe`, not `attack`). `gather` writes both tool prompts. Use this when editing MOTION / IDENTITY_LOCK / FACING_LOCK.
- `python tools/anim_review_tree.py` — wiped test tree at `tools/anim_review/regen_tree/<model>/<facing>/<anim>/`. Each player folder gets `source.png` (locked Bible cell, same scale/pad as `i2v_seeds.py --cell`), `prompt.txt`, and `notes.txt` when the User typed a note. The dest tree is deleted and rebuilt every run. Split the locked Bible with `dict(zip(CELL_NAMES, split_equal_3x3(...)))`; `split_equal_3x3` returns a list, not a name map.

`AnimScan` lists `gather_pickaxe` and `gather_hatchet` when those sequences exist, and falls back to `gather_{facing}_*` if a tool set is missing. `idle_to_walk` / `walk_to_idle` stay out of the browser list (repack-only).

Enemy clips in the regen brief / tree get a warning until that pipeline exists. Do not invent an enemy I2V path here.

## Appendix C — Character Bible prompt template

Create a single clean image that is a perfect 3×3 Character Bible grid on solid pure magenta `#FF00FF` background for the [male/female] player character of "What Dwells Below".

Strict cell layout (do not swap, reverse rows, reverse columns, or move any figure):

Top row:  
Top-left: Up-Left full-body, complete head-to-feet, character facing Up-Left, neutral standing  
Top-center: Up full-body, complete head-to-feet, character facing Up (full back view), neutral standing  
Top-right: Up-Right full-body, complete head-to-feet, character facing Up-Right, neutral standing

Middle row:  
Middle-left: Left full-body, complete head-to-feet, character facing Left (left profile), neutral standing  
Exact center: clear head-and-shoulders face close-up of the same character  
Middle-right: Right full-body, complete head-to-feet, character facing Right (right profile), neutral standing

Bottom row:  
Bottom-left: Down-Left full-body, complete head-to-feet, character facing Down-Left, neutral standing  
Bottom-center: Down full-body, complete head-to-feet, character facing Down (front view), neutral standing  
Bottom-right: Down-Right full-body, complete head-to-feet, character facing Down-Right, neutral standing

All eight full-body figures must have identical proportions and silhouette height, feet on the same baseline. Character locked across every cell: rugged human dungeon delver, practical layered leather and metal armor, [short messy dark hair / appropriate female hairstyle], determined expression, a short green neckband worn only around the neck, limited muted palette (grays, browns, dark greens, skin tones, metal). Crisp true pixel-art style, integer pixel edges, no anti-aliasing, no smoothing. Hands empty. No weapons, no tools. Do not swap any cells. Do not place the face close-up anywhere except the exact center. No cropping of limbs, no props, no weapons, no text, no numbers, no borders, no grid lines. Perfect even 3×3 grid.

## Appendix D — Method reliability

| Method | Reliability | Notes |
|--------|-------------|-------|
| Soft identity language after Bible lock | High | Use always after lock |
| Single-pass 3×3 for the Bible | Highest for identity | Preferred for Bible |
| Chained image-edits for Bible cells | Low | Drift; avoid for Bible |
| `i2v_seeds.py` walk prompt (in-place steps, short arm swing, loop to still) | High | Only locomotion I2V method |
| `i2v_seeds.py` one-shot MOTION keys (per weapon / tool, death, Dispel) | High | Required for Regenerate flags |
| One 400% NN spliced still as the I2V seed | High | Default seed |
| `i2v_seeds.py --test` web preamble | Browser tests only | Do not send in Grok Build I2V |
| Full-Bible seed | Medium | Only if the User asks after a still-seed miss |
| Video-fill from last accepted clip | Medium | Last resort, User-asked |
| `plate_remap.py` before key-to-alpha | High | Required when plate ≠ `#FF00FF` |
| `spill_flood=False` on video / jpg stills after remap | High | Avoid eating hair / maroon / purple cloth |
| Automatic multi-pass fill-in | Forbidden | One unit, then User review |
| Overlay I2V / stills for weapons and tools | High | Layers, not baked body props |
| Nearest-neighbor / scripted pixel-grid cleanup | Mandatory | Always perform after accept |
