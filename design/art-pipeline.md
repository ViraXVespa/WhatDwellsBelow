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
- If centers do not form a readable 3×3 (skewed rows, missing figure, overlapping cells), discard and regenerate the Bible. Do not guess.

After that square exists, split into nine equal cells.

## 19.2 One I2V, then User review

Always work **one unit** at a time. A unit is exactly one **character type** + one **facing** + one **action**.

Never hard-code exact frame counts. Never generate full multi-direction strips in one pass. Never generate a second I2V for the same unit, a different unit, or a fill-in pass unless the User asked for that next clip.

### Prompts

I2V prompts come from `tools/i2v_seeds.py` (`build_prompt()` + `MOTION[action]` + `IDENTITY_LOCK[gender]`). Do not invent a second walk prompt in this file.

Identity lock is per player gender. Male and female each have their own `IDENTITY_LOCK` in `tools/i2v_seeds.py`. Do not copy male outfit language onto the female character. Pass `--gender male` or `--gender female`, or infer it from `bible_locked_male.png` / `bible_locked_female.png`. Copy the still: one short green cloth wrapped close at the neck only. No hanging end. No tail. No loose strip.

Grok Build I2V uses that body as-is. The web-browser preamble (image-to-video / do not output a still / no fixed duration) is **only** added when `tools/i2v_seeds.py --test` is passed.

`--action walk` is the locomotion method. It is not a breath / idle performance. `MOTION["idle"]` is not a player path.

Walk uses the loop wrapper in `tools/i2v_seeds.py` (starts and ends on the idle still). One-shot actions use the one-shot wrapper (start on the still, finish the motion, recover or hold; do not claim a walk loop).

Walk loop (one clip, starts and ends on the idle still so it can loop):

1. Idle (the start still)
2. Idle into walk
3. At least three clear in-place strides
4. Walk into idle, last plant on the **opposite** foot from the foot that started
5. Idle still again

One-shot `MOTION` keys (full beat sheets, not a shared `attack` / `special` line):

- `attack_great_axe`, `attack_staff`, `attack_longbow`
- `special_great_axe`, `special_staff`, `special_longbow`
- `gather_pickaxe`, `gather_hatchet`
- `death`, `dispel`

`--action gather` (Animation Browser name with no tool suffix) writes **both** gather sheets. Unknown actions MUST NOT fall back to `walk`. `idle_to_walk` / `walk_to_idle` alias to `walk`; they are not I2V units.

Attack / special / gather I2V is unarmed body. Hands stay empty. Do not spawn the item. Paper-doll overlays are I2I / stills, not this prompt set.

`death` is a hit collapse to a downed hold. `dispel` is ritual seppuku: draw one small knife, kneel, one abdominal cut, collapse, hold. That knife is the only legal prop on the Dispel clip. Neither clip paints blood, spray, puddles, or gore — the engine draws a blood pool under the downed body.

Game facing is a locked view copied from the still (`FACING_LOCK` in `tools/i2v_seeds.py`), from the first frame. Down is marching in place toward the camera (both shoulders visible). Walk is a treadmill on the still's center line. Do not name a travel heading. Start/stop feet are “one foot” then “the other foot.”

No fixed clip length. Completeness is the motion goal, not a clock. Dispel may run long enough to read as ritual.

### Generation methods

1. **Image-to-video** (default for locomotion)
   - Use whenever available.
   - Default seed: one full-body Bible cell for that facing, plate still in the pixels, 400% nearest-neighbor (`tools/i2v_seeds.py --cell`).
   - Produce **one** clip. Show that clip to the User immediately. Do not extract frames, harvest, or cleanup until the User accepts.
2. **Individual classic key poses**
   - Contact → Down → Passing → Up (and any needed extremes).
   - One pose at a time against the locked Bible.
   - Only when the User rejects I2V for that unit or asks for stills.
3. **Short in-place horizontal strip**
   - Last resort for a single facing + action.

**Forbidden**

- Full multi-direction strips, hard frame-count demands, or multi-action sheets in one generation.
- Automatic retries, automatic viability fill-in, or batched I2V.
- A fixed duration such as “at least ten seconds.”
- Baked “character holding weapon X” body sheets as the source of truth.
- Seeding I2V from `key_to_alpha` / transparent / 128-fit engine frames.

### Review gate (mandatory)

After each I2V clip (or after a stills batch the User requested for that same unit):

1. Show the User the clip immediately. Do not extract frames, harvest contact sheets, or run cleanup first.
2. Report only the unit: facing, action, gender, seed used.
3. **Stop.** Wait. Do not analyze gait, pack shipping frames, or start the next unit until the User answers.
4. Extract candidate frames only after **Accept** (or if the User asks to see frames).

The User decides one of:

| User call | Agent does next |
|-----------|-----------------|
| **Accept** | Run §19.6 cleanup on the chosen frames, pack that unit, wait for the next unit order |
| **Another I2V pass** | One new clip for the same unit (new seed still if the User asked for one). Then review again |
| **Need a new seed still** | Generate or splice one still only. Plate-remap if the plate is not `#FF00FF`. Stop for review before any I2V |
| **Reject / skip this method** | Drop one level in the generation methods list, still one unit only |
| **Next unit** | Start the next facing or action the User named |

### How to extract a splice from the locked Bible

The locked Bible is a perfect 3×3 grid after the square-crop above. Treat it as nine equal cells. Do not use the center cell as an animation seed (that cell is the face close-up only).

| Cell | Contents |
|------|----------|
| Top-left | Up-Left full-body |
| Top-center | Up full-body |
| Top-right | Up-Right full-body |
| Middle-left | Left full-body |
| Center | Face close-up — not an animation seed |
| Middle-right | Right full-body |
| Bottom-left | Down-Left full-body |
| Bottom-center | Down full-body |
| Bottom-right | Down-Right full-body |

Extraction / I2V seed order:

- Split the locked **plate-remapped** Bible into nine equal cells.
- Do not range-key, despill, bbox-crop, or flatten chroma to alpha on the cell before I2V. The `#FF00FF` that sits in the cell stays.
- Take the one full-body cell that matches the facing being generated.
- Upscale that cell by exactly 400% with nearest-neighbor only (`tools/i2v_seeds.py --cell`, or `--bible` to batch plates the User asked for). Every source pixel becomes a 4×4 block. No bilinear / Lanczos / AI upscale. No non-integer fit. No 1024 canvas pad.
- Then pad extra `#FF00FF` around the scaled cell (`PAD_FRAC` of figure height on any short side) so lifted feet and swinging arms stay on-plate. Do not scale the figure down to fake padding. Bible Down cells sit flush with the top/bottom of the cell; walk I2V without this pad clips.
- Send that padded 400% plate as the I2V first frame. Do not crop to the silhouette.
- If a later clean directional still exists for that facing, uses the same cell framing, **and still has an opaque plate**, 400% that still instead of re-splitting the Bible.
- After video extract, every frame the User accepted still goes through §19.6 cleanup. Key-to-alpha belongs there, not on the I2V seed.

**When to use the seed**

- Default for every I2V attempt: one 400% spliced still of the needed facing, plate intact.
- Do not start with the full 3×3 sheet.
- Do not send the center face close-up as the first frame.
- Do not add a second reference image if that switches the generator from first-frame I2V into reference-to-video.
- For walk / start / stop, keep the cell framing. Walk, attack, and other limb-extend motions use the same pad-after-scale rule. Do not scale the figure down to fake padding.

**Fallback to the full Bible (only if the User asks)**

Switch to the full locked Bible only if the User saw the single-still I2V fail, or the clip needs more than one facing **and** the User approved that seed. Prompts MUST still name the primary facing.

**Soft identity language** (mandatory in every prompt after Bible lock):

Keep the same overall character design, face, hair, armor, close green neck wrap, proportions, palette, and sprite style from the Bible. Do not redesign, repaint, recolor, simplify, smooth, or invent new details. No hanging end, tail, or loose strip. Hands are empty. Do not draw a weapon or tool.

That language means the locked Bible, not the reference JPG. Dispel is the exception for the small ritual knife only (`MOTION["dispel"]` / `DISPEL_IDENTITY_TAIL` in `tools/i2v_seeds.py`).

Generate one full cardinal direction (Down + Left + Right + Up) completely before deriving diagonals, unless the User orders a different facing next. Horizontal flip is acceptable for opposite sides when the design is mostly symmetric; asymmetric details (neck wrap bulk, hair) MUST be corrected or regenerated.

Suggested first proof (do not run ahead of review): one gender, facing Down, one walk I2V.

## 19.3 Locomotion harvest (idle is a still)

In-game **idle is not an I2V product**. Idle is the directional key still for the facing the player is aiming — the same Bible cell / approved splice used as the I2V seed. One texture per facing. No breath cycle. Do not pack held “standing on the still” frames as idle.

One accepted **walk** I2V is the pool for start, cycle, and stop. Cut three engine clips and throw held idle frames away:

| Engine clip | Source |
|-------------|--------|
| `idle` | The key still for that facing. Not harvested from the video. |
| `idle_to_walk` | Few frames from the key pose into the plant that starts `walk`. One-shot. |
| `walk` | One looping two-step (both lead feet), plant on frame 0. Eight engine frames. |
| `walk_to_idle` | Few frames from the walk cycle back to the key pose. One-shot, then hold idle. |

`idle_to_walk` and `walk_to_idle` MUST exist for every facing and both genders. They are first-class engine states. They are **not** separate I2V units unless the User rejects the walk clip and asks for a dedicated pass.

Playback MUST play the start transition when leaving idle into walk and the stop transition when coming to rest, rather than popping between the key still and a mid-stride walk frame.

Other required **body** states:

- `attack_great_axe`, `attack_staff`, `attack_longbow` (unarmed swing / poke / draw-loose)
- `special_great_axe`, `special_staff`, `special_longbow` (unarmed slam / cast / fan loose)
- `gather_pickaxe`, `gather_hatchet` (unarmed mine / woodcut)
- `death` (unarmed collapse, then hold)
- `Dispel` (seppuku: small knife in this clip only, then hold)

Full parity between male and female is required for every state.  
The same frame-count rule applies to every animation state: all eight facings of that state share one frame count. Attack / special / gather pack to 6 frames per facing. Death and Dispel keep the accepted clip length (Dispel may be long); those two states still share one count across the eight facings.  
Animation playback speeds remain tunable.

Attack / special / gather body clips exist because those actions change the skeleton. They are still unarmed silhouettes. The weapon or tool is a paper-doll layer (§19.4).

Pack one-shots with `tools/pack_oneshot.py` from `_src/oneshot/{gender}_{action}_{facing}.mp4`. Walk harvest stays `tools/pack_locomotion.py`.

## 19.4 Paper-doll / equipment layers

Paper-doll means **composite layers**, not a new character animation per item.

- Body frames never include a weapon or tool.
- Each equippable weapon (Great Axe, Lightning Staff, Longbow) and each tool (pickaxe, hatchet) is its own overlay art on the same 128×128 canvas as the body frame it sits on.
- Overlay pixels are registered to the empty-hand / grip position of that body frame and facing. Alignment MUST be identical for male and female aside from the body art itself. No per-gender weapon redraws.
- Locomotion and idle (`idle`, `idle_to_walk`, `walk`, `walk_to_idle`, `death`, `Dispel`): use a **carry / rest** overlay per facing. One rest frame per facing is enough unless the User asks for a matching overlay on every body frame.
- Attack, special, and gather: generate weapon/tool overlay frames that follow the hands through that body clip. Still overlays — not a second full-body character sheet.
- Armor, head, and other gear remain stats-only unless the User later asks for those layers.
- Generate each overlay against **one** clean unarmed body frame (or accepted body clip) of the correct facing, not against the full Bible and not as a standalone character. Overlay stills that go to I2V keep an opaque `#FF00FF` plate.
- Engine draw order is body, then tool/weapon (weapon behind the body only when a facing requires it for a back grip; document that facing if used).

Do not create `walk` / `idle` / transition sheets that already have a Great Axe, staff, or bow painted into the character.

## 19.5 What the User reviews (no automatic fill-in)

The User judges the I2V clip itself first (facing lock, travel, identity). Do not pre-harvest a rejected clip.

After the User accepts a unit’s frames, the agent MUST check — and report, not silently regenerate:

- Whether idle is the key still (not a harvested breath loop).
- Whether `idle_to_walk` leaves idle and enters walk without a pop.
- Whether `walk` has a readable passing / leg-crossover stage.
- Whether `walk_to_idle` settles to the key pose without a pop.
- Whether both legs and arms cross as needed for that action.
- Whether all accepted directional variants of the same state share one frame count.
- Whether any accepted body frame baked in a weapon or extra prop (Dispel knife excepted).
- Whether death / Dispel I2V painted blood. That is a defect; the engine draws the pool.
- Whether the I2V seed still had an opaque plate.

If anything is missing or wrong, **tell the User** and wait. The User chooses whether to spend another I2V, supply or request a new seed still, drop to key poses, or ship the available frames.

Do not run an automatic video-fill loop. Do not spend hidden retries.

If the User accepts imperfect frames, note the defect, continue with what was accepted, and list open cleanup at the end of the slice.

## 19.6 Mandatory cleanup and normalization pipeline

All AI-generated frames (including those extracted from video) MUST pass through cleanup before use in the game. Cleanup of a unit starts only after the User accepts that unit, unless the User asks for a preview matte.

Recommended tools: `tools/plate_remap.py`, `tools/sprite_pipeline.py`, `tools/pack_locomotion.py`, `tools/pack_oneshot.py`, `tools/rekey_stills.py`, Aseprite + DeAI PixelKit / Pixel Refiner / Alpha Remover, or equivalent.

**Video extract** (walk clips, `_src/walk_final/` → `_src/walk_harvest/`; one-shots, `_src/oneshot/` → `_src/oneshot_harvest/`):

- Dump **full-size RGB** PNGs. ffmpeg: `-sws_flags neighbor+accurate_rnd+full_chroma_int`, `fps=…,format=rgb24`.
- Do not decode through OpenCV’s default 4:2:0 bilinear chroma upsample.
- Do not shrink (`KEY_MAX` or any other cap) before remap or key. A 4:2:0 mp4 already mixed magenta into the lip; shrinking first makes that lip thicker in 128-canvas pixels.
- Always re-extract. Do not reuse older harvest 320s.
- Remap + key only the frames that will be packed. Idle-compare stamps may use a tiny nearest copy; that stamp is not a shipping matte.

H.264 4:2:0 cannot be un-smeared. Prefer a PNG sequence from I2V when the tool can dump one. Nearest-chroma extract + remap is the recovery path for an existing mp4.

Required cleanup tasks (in order):

1. If the extract’s plate is not exact `#FF00FF`, run `tools/plate_remap.py` (sample start chroma, wand, pocket fill, bleed remap). Keep the plate opaque until the next step. Remap **once**. Do not remap in extract and again in `key_fit`.
2. Range-key / wand the `#FF00FF` plate. Despill fringe. `sprite_pipeline.py` `key_to_alpha` punches the plate. Video extracts and session stills pass `spill_flood=False` after remap so compressed maroon / hair / purple cloth is not treated as plate. Then **snap alpha hard** (figure `255`, plate `0`) before any fit so Color-to-Alpha cannot leave a magenta-ish lip on dark backdrops.
3. Crop to content bounding box + fixed transparent padding.
4. Nearest-neighbor scale/fit to exact target canvas (128×128 recommended). Never nearest-shrink the still-opaque plate and then key.
5. Center horizontally.
6. Lock feet to a common baseline Y across all frames of a cycle.
7. Quantize / lock to the Bible palette.
8. Eliminate anti-aliasing, sub-pixel noise, and ghosting.
9. For walk I2V sources: `tools/pack_locomotion.py` finds one early self-similar stride cycle (period 8–16 harvest frames), rotates the plant to `walk[0]`, and cuts `idle_to_walk` / `walk_to_idle` from the frames touching that plant. Do not even-sample the whole clip. Skip held idle. Front/back use leg height; side views use leg width. Lock a shared foot baseline and torso X to the idle still.
9b. For one-shot I2V sources: `tools/pack_oneshot.py` remaps, keys, fits, and even-samples attack / special / gather to 6 frames. Death and Dispel keep the clip length. Output names match `AnimScan` (`atk_*`, `spc_*`, `gather_pickaxe_*`, `gather_hatchet_*`, `death_*`, `dispel_*`).
10. Trim to the exact frame count needed by the engine (ensuring directional parity).
11. Output individual frames or engine-ready sheets + simple manifest (frame size, count, fps, pivot/anchor, layer: `body` or `weapon`/`tool`).

Never take the output of steps 2–11 and send it back into I2V.

## 19.7 Success criteria and failure recovery

A generation is acceptable only if it meets all of the following after cleanup:

- Readable silhouette at target size.
- Correct facing and pose intent.
- No extra limbs, props, or invented details.
- No weapon or tool baked into a body frame, except the small ritual knife on `Dispel`.
- No blood, spray, puddle, or gore in death / Dispel I2V. Engine draws the pool.
- No palette drift from the locked Bible.
- No background remnants, start-chroma rims, or magenta spill.
- Consistent scale and foot baseline with the Bible and sibling frames.
- Integer pixel edges, no anti-aliasing.
- Correct limb crossing and sufficient passing-stage frames on accepted walk cycles.
- Readable `idle_to_walk` and `walk_to_idle` on every facing that has shipped those states.
- Identical frame counts across all directions of the same animation state.
- Weapon/tool overlays register to the matching body frame.

**Recovery decision tree**

- User rejects the clip → one change only (new I2V, new seed still, or drop one generation method), then review again.
- Persistent identity or scale failure → return to Bible and re-lock only with User approval if style would change.
- User accepts a short set → pack what they accepted and list gaps. Do not auto-fill.
- Log the failure mode.

Follow this pipeline exactly. Deviations require explicit justification and re-validation under the orthographic camera + Y-billboard + nearest-neighbor filtering.

## 19.8 Animation Browser review tools

The Animation Browser writes a local ledger at `tools/anim_review/review.json` (editor-only, gitignored). That file is not a game setting and is not part of `SaveStore`.

CLI tools read it from the live checkout:

- `python tools/anim_review_pack.py` — pack brief (`tools/anim_review/pack_brief.md` + `.json`). Repack notes are failure cases. Good on-disk locomotion clips (`walk`, `idle_to_walk`, `walk_to_idle`) are keep-behavior. Ignore Regenerate rows here.
- `python tools/anim_review_regen.py` — regen brief (`tools/anim_review/regen_brief.md` + `.json`). Regenerate notes plus the current `i2v_seeds.build_prompt` text for player clips. `i2v_action` keeps class keys (`attack_great_axe`, not `attack`). `gather` writes both tool prompts. Use this when editing MOTION / IDENTITY_LOCK / FACING_LOCK.
- `python tools/anim_review_tree.py` — wiped test tree at `tools/anim_review/regen_tree/<model>/<facing>/<anim>/`. Each player folder gets `source.png` (locked Bible cell, same scale/pad as `i2v_seeds.py --cell`), `prompt.txt`, and `notes.txt` when the User typed a note. The dest tree is deleted and rebuilt every run.
- `python tools/pack_oneshot.py` — pack an accepted one-shot mp4 from `_src/oneshot/` into engine frames. Not driven by `review.json`.

`AnimScan` lists `gather_pickaxe` and `gather_hatchet` when those sequences exist, and falls back to `gather_{facing}_*` if a tool set is missing. `idle_to_walk` / `walk_to_idle` stay out of the browser list (repack-only).

Enemy clips may be flagged in the browser. Until an enemy I2V / pack pipeline exists, the regen brief and regen tree write a warning instead of a seed and prompt.

Stills (idle / single-frame clips) cannot be flagged. Do not invent a still-regeneration path here.

## Appendix C – Full Character Bible Prompt Template

Create a single clean image that is a perfect 3×3 Character Bible grid on solid pure magenta #FF00FF background for the [male/female] player character of "What Dwells Below".

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

All eight full-body figures must have identical proportions and silhouette height, feet on the same baseline. Character locked across every cell: rugged human dungeon delver, practical layered leather and metal armor, [short messy dark hair / appropriate female hairstyle], determined expression, one short bright green cloth wrapped close at the neck with no hanging end, limited muted palette (grays, browns, dark greens, skin tones, metal). Crisp true pixel-art style, integer pixel edges, no anti-aliasing, no smoothing. Hands empty. No weapons, no tools. Do not swap any cells. Do not place the face close-up anywhere except the exact center. No cropping of limbs, no props, no weapons, no text, no numbers, no borders, no grid lines. Perfect even 3×3 grid.

## Appendix D – Summary Reliability Table

| Technique | Reliability | Recommendation |
|-----------|-------------|----------------|
| Locked 3×3 Character Bible + palette | High | Mandatory |
| `plate_remap.py` start-chroma → `#FF00FF` + bleed + pockets | High | Mandatory before lock / I2V if plate is not `#FF00FF` |
| Opaque plate on every I2V seed | High | Mandatory; never seed from keyed frames |
| Game-centric direction names (8-dir) | High | Use always |
| Soft identity language after Bible lock | High | Use always after lock |
| Single-pass 3×3 for the Bible | Highest for identity | Preferred for Bible |
| 400% NN I2V plate (cell chroma kept) | High | Default I2V first frame |
| `i2v_seeds.py` walk prompt (idle → ≥3 strides → opposite-foot stop) | High | Only locomotion I2V method |
| `i2v_seeds.py` one-shot MOTION keys (per weapon / tool, death, Dispel) | High | Required for Regenerate flags |
| `pack_oneshot.py` for accepted one-shot mp4s | High | Attack/special/gather to 6; death/Dispel keep length |
| `i2v_seeds.py --test` web preamble | Browser tests only | Do not send in Grok Build I2V |
| One I2V + User review gate | High | Mandatory; replaces auto-retry |
| No fixed I2V duration | High | Length follows the motion goal |
| Idle = directional key still | High | Do not I2V a breath loop |
| Engine clips cut from one walk I2V | High | `idle_to_walk` / `walk` / `walk_to_idle` |
| Full-Bible I2V seed | Fallback only | Only if the User asks |
| Individual classic key poses | High | User-requested fallback |
| Lattice square-crop before 3×3 split | High | Mandatory before splices |
| `#FF00FF` pad after 400% NN (`PAD_FRAC`) | High | Required so walk/attack limbs stay on-plate |
| Extra pad or 1024-fit that shrinks the figure | Low | Avoid |
| Key / despill on the I2V seed | Low | Avoid |
| Magenta key-to-alpha | High | After accept only (§19.6) |
| Full-size RGB extract + nearest chroma | High | Mandatory for mp4 harvest |
| Shrink-then-key (`KEY_MAX` / 512 cap before wand) | Low | Avoid |
| Binary matte snap after key | High | Mandatory before 128 fit |
| `spill_flood=False` on video / jpg stills after remap | High | Avoid eating hair / maroon / purple cloth |
| Foot baseline locking in post | High | Mandatory |
| Equal frame counts per direction | High | Mandatory |
| Hard frame-count or 10s duration demands | Low | Avoid |
| Full multi-direction strips | Very Low | Forbidden |
| Automatic multi-pass video fill-in | Low (token-expensive) | Forbidden unless User orders one clip |
| Chained image-edits for Bible directions | Medium-Low | Avoid |
| Baked per-weapon full-body sheets | Wrong model | Forbidden as source of truth |
| Paper-doll weapon/tool overlays | High | Mandatory for gear visuals |
| Aseprite / scripted pixel-grid cleanup | Mandatory | Always perform after accept |