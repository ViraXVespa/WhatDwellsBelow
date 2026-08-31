Player sprite and paper-doll generation pipeline

Status: binding design
Read when: generating or replacing player / enemy / weapon frames
Code: tools/sprite_pipeline.py, tools/i2v_seeds.py, tools/process_.py, tools/pack_.py, assets/sprites/player/, assets/live/
See also: design/player.md, design/audio-visual.md, design/enemies.md

This section is mandatory for any Grok Build instance.
It exists because pure image-generation models (including Grok Imagine) have consistent, well-documented limitations with multi-frame consistency, identity drift, spatial layout in grids, and pixel-perfect output. The pipeline below is the most reliable process currently achievable after extensive testing.

All character art (player and enemies) MUST follow this pipeline. Props may use a simplified stills-only variant.
Male and female player characters MUST each have their own locked Character Bible and MUST maintain full animation parity so that weapon paper-doll layers and animations function on either without special per-gender tweaks.
Player and enemy animations use exactly 8 directions matching the Character Bible layout.

19.0 Goals and non-negotiables

One locked Character Bible per character type (male and female) is the single source of truth for identity, proportions, palette, and style.
Identity drift, anti-aliasing, magenta spill, foot sliding, scale inconsistency, and extra limbs/props are hard failures.
All final frames MUST be true pixel art on an integer grid after cleanup (nearest-neighbor only).
Prefer fewer high-quality, readable frames over many mediocre ones. The engine can hold or simple-tween if needed.
Generate and fully clean one complete directional set (idle + walk at minimum) as a proof before scaling to all directions and states.
Final engine resolution target: 128×128 canvases (recommended for detail and alignment). Nearest-neighbor downscale to 64×64 is permitted only if required by import settings; document the choice. Base resolution in design/audio-visual.md remains 64×64 for world units, but sprite assets ship at 128×128 unless otherwise specified.
Use game-centric direction names exclusively: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right. These match the orthographic camera, Y-billboard, and 8-directional aim system.
All directional variants of the same animation state for a given character MUST contain exactly the same number of frames.

19.1 Character Bible

Create and lock one primary 3×3 Character Bible on a solid pure magenta (#FF00FF) background for each character type (male and female).

Strict cell layout (do not swap, reverse rows, reverse columns, or move any figure):
(See Appendix C below for the full prompt template and exact cell descriptions.)

Requirements:
Clean limited-palette pixel-art style.
All eight full-body views in neutral standing pose (no weapons, no action props).
Consistent silhouette height and foot baseline across all full-body cells.
Extract and lock the exact palette used.

This single image is the primary design reference for all subsequent generations of that character type.

A visual reference of cell positioning and presentation quality can be found at:
assets/sprites/player/gdd_reference_bible.jpg

Important: That file is not a locked art style and is not the desired final look. It exists only to show Bible layout (3×3 cell placement, full-body framing, face close-up in the center) and a quality bar for silhouette readability. Grok Build MUST generate Character Bibles and animation frames from scratch. Do not treat the reference image as an input asset to edit or extend, and do not copy its surface style as a requirement.

Final styling is intentionally unset before lock. Grok Build MAY propose new visual options so long as they satisfy the rest of this database (readable 64×64 / 128×128 pixel-grid output after cleanup, 8-direction Bible layout, male/female parity, Y-billboard, nearest-neighbor, limited palette after lock, no anti-aliasing in shipping frames). Generate 2–4 distinct style candidates per gender, then lock the best Bible pair and palettes as usual.

After lock: bible_locked_male.png / bible_locked_female.png (plus palettes) force the look. Every later generation — directional stills, animation frames, paper-doll layers, video fill-in — MUST match the locked Bible. Soft identity language applies only after that lock. If a Bible must be regenerated after lock, match the locked Bible. A new style is allowed only if the User explicitly agrees to re-lock.

Treat the locked Bibles as immutable unless the User authorizes a re-lock. Store them as:
assets/sprites/player/bible_locked_male.png
assets/sprites/player/bible_locked_female.png
(+ locked palettes).

Note on reliability: Single-pass 3×3 generation currently produces the highest identity consistency. Chained image-edits from a single anchor introduce cumulative off-model drift and should be avoided for the Bible itself. If layout errors persist after 3–4 attempts, fall back to generating the eight full-body views + face individually (using soft identity language against the chosen style, then against the locked Bible once it exists) and compositing them deterministically with a script.

Background color: Grok often paints near-magenta instead of pure #FF00FF (example: #EE22DD and other hot pinks / violets). Treat saturated magenta / hot-pink / violet backdrop as keyable background. Range-key it, despill fringes, then write remaining background pixels to exact #FF00FF. Do not key skin, scarf, metal, or other on-model pinks. If a range catch eats character pixels, tighten the range and retry.

Square the Bible before any 3×3 split: A generated Bible MAY not be a perfect square and MAY include extra margin. Hug the grid, not the silhouettes. Outer-cell magenta padding stays in the sprites; only leftover canvas outside the 3×3 is cut.

Do not crop to the union bounding box of the eight bodies. That throws away the padding that belongs inside each cell.

Instead, recover the intended grid and crop to that:
Range-key the background so figures are separable.
Find the eight full-body figures (ignore the center face close-up for lattice fitting if it sits on a different scale).
Take each figure’s center. Fit them to a 3×3 lattice. Horizontal pitch = average distance between neighboring column centers. Vertical pitch = average distance between neighboring row centers.
Cell size = the larger of those two pitches. Using the larger pitch keeps short-axis padding instead of clipping it.
The crop square is 3 × cell size, centered on the lattice origin (the center cell).
That square MUST include the magenta padding around the outer figures. It MUST NOT include random extra canvas beyond one grid-cell of margin.
Do not stretch or linearly scale to force a square. Crop only.
If centers do not form a readable 3×3 (skewed rows, missing figure, overlapping cells), discard and regenerate the Bible. Do not guess.

After that square exists, split into nine equal cells.

19.2 Generation hierarchy (ordered by reliability)

Always work one direction + one action at a time. Never hard-code exact frame counts. Never generate full multi-direction strips in one pass.

Priority order:

Image-to-video (highest reliability for locomotion)
   Use whenever available. Default seed is a 400% nearest-neighbor splice of one full-body Bible cell, not the full Bible sheet. Extract frames, then curate 4–8 clean ones.

Individual classic key poses
   Contact → Down → Passing → Up (and any needed extremes). Generate one pose at a time against the locked Bible.

Short in-place horizontal strip
   Use the prompt template style from Appendix C, adapted for the specific action and single direction.

Forbidden
   Full multi-direction strips, hard frame-count demands, or multi-action sheets in one generation.

How to extract a splice from the locked Bible
The locked Bible is a perfect 3×3 grid after the square-crop above. Treat it as nine equal cells. Do not use the center cell as an animation seed (that cell is the face close-up only).

| Cell | Contents |
|---|---|
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
Split the locked Bible into nine equal cells. Do not range-key, despill, bbox-crop, or flatten chroma on the cell before I2V. The magenta that already sits in the cell stays.
Take the one full-body cell that matches the facing being generated.
Upscale that cell by exactly 400% with nearest-neighbor only (tools/i2v_seeds.py --cell for one splice, or --bible to batch). Every source pixel becomes a 4×4 block. No bilinear / Lanczos / AI upscale. No non-integer fit. No 1024 canvas pad. No extra margin beyond the cell’s own magenta.
Send that 400% plate as the I2V first frame. Framing is the Bible cell: character large, cell magenta around it. Do not crop to the silhouette.
If a later clean directional still exists for that facing and uses the same cell framing, 400% that still instead of re-splitting the Bible.
After video extract, every frame still goes through §19.6 cleanup. Range-key and despill belong there, not on the I2V seed.

When to use the seed
Default for every Image-to-Video attempt: one 400% spliced still of the needed facing.
Do not start with the full 3×3 sheet.
Do not send the center face close-up as the first frame.
Do not add a second reference image if that switches the generator from first-frame I2V into reference-to-video.
For idle and walk, keep the cell framing. If a later motion needs more room (a long attack arc, a fall), pad after the 400% scale with extra #FF00FF. Do not scale the figure down to fake padding.

Fallback to the full Bible (allowed)
Switch to the full locked Bible (optionally plus extra cropped cells) only if:
single-still I2V fails on-model / motion checks after the normal retry budget, or
the clip clearly needs identity from more than one facing (examples: a turn, a direction-change, an attack that reads the body from two angles).

Even in fallback, prompts MUST still name the primary facing. After video extract, every frame still goes through §19.6 cleanup.

Soft identity language (mandatory in every prompt after Bible lock):
“Keep the same overall character design, face, hair, armor, green scarf, proportions, palette, and sprite style from the Bible. Do not redesign, repaint, recolor, simplify, smooth, or invent new details.”

That language means the locked Bible, not the reference JPG.

Generate one full cardinal direction (Down + Left + Right + Up) completely before deriving diagonals. Horizontal flip is acceptable for opposite sides when the design is mostly symmetric; asymmetric details (green scarf, etc.) MUST be corrected or regenerated.

19.3 Required player states

Minimum required states (from design/player.md and design/audio-visual.md):
idle, walk, attack (per weapon), special (per weapon), gathering (mining/woodcutting), death, “Dispel”.

Prioritize idle + walk first. Animation playback speeds remain tunable.
Full parity between male and female is required for every state and every weapon.
The same frame-count rule applies to every animation state.

19.4 Paper-doll / equipment layers

Generate each equipment piece (especially the three weapons) against a single clean base-body frame from the correct direction (not the full Bible).
Use the same soft identity language, range-keyed magenta background flattened to #FF00FF, and cleanup rules.
Weapon paper-doll layers MUST work correctly on both male and female base bodies.

19.5 Post-generation viability analysis and video fill-in

After the initial animation-generation phase, Grok Build MUST automatically analyze the collected sprite-frame pool for every animation state and every direction.

The analysis MUST verify:
Sufficient frames exist in the “passing” / leg-crossover stage of the cycle.
Generated frames correctly show both legs and arms crossing (forwards/backwards or in-front/behind) as required for natural locomotion and action.
All directional variants of the same animation state contain exactly the same number of frames.

If any requisite frames are missing or incorrect, Grok Build shall:
Use the locked Character Bible(s) as the identity and style reference.
Prefer Image-to-Video seeded from a 400% nearest-neighbor splice of one full-body Bible cell, or a 400% clean directional still of the needed facing, following §19.2. Do not key the seed. Do not add extra pad. Do not fit to 1024.
Generate a short video of the required animation using a motion-focused prompt that explicitly requests the missing passing/crossover frames and correct limb crossing.
Extract candidate frames from the video.
Run every extracted frame through the full mandatory cleanup pipeline (range-key magenta + despill + flatten to #FF00FF, crop + padding, nearest-neighbor scale to target canvas, foot-baseline lock, palette quantize, anti-aliasing removal, etc.).
Integrate the new frames into the pool provided they remain on-model.

Fall back to the full Bible only under the §19.2 fallback conditions.
Maximum practical retries follow the existing generation hierarchy (2–3 Image-to-Video attempts before falling back).
If video-extracted frames still fail the on-model / crossing checks, note the failure, continue the build using the available animations, and at completion inform the user of the failure together with a suggestion for manual cleanup.

19.6 Mandatory cleanup and normalization pipeline

All AI-generated frames (including those extracted from video) MUST pass through cleanup before use in the game.

Recommended tools:
Existing project scripts in tools/
Or Aseprite + DeAI PixelKit / Pixel Refiner / Alpha Remover
Or equivalent browser tools

Required cleanup tasks (in order):
Range-key saturated magenta / hot-pink / violet background around #FF00FF. Apply despill for any fringe. Flatten remaining background pixels to exact #FF00FF. Do not key on-model pinks.
Crop to content bounding box + fixed transparent padding.
Nearest-neighbor scale/fit to exact target canvas (128×128 recommended).
Center horizontally.
Lock feet to a common baseline Y across all frames of a cycle.
Quantize / lock to the Bible palette.
Eliminate anti-aliasing, sub-pixel noise, and ghosting.
For video/strip sources: even frame selection, skip settling frames, validate loop.
Trim to the exact frame count needed by the engine (ensuring directional parity).
Output individual frames or engine-ready sheets + simple manifest (frame size, count, fps, pivot/anchor).

19.7 Success criteria and failure recovery

A generation is acceptable only if it meets all of the following after cleanup:
Readable silhouette at target size.
Correct facing and pose intent.
No extra limbs, props, or invented details.
No palette drift from the locked Bible.
No background remnants or magenta spill.
Consistent scale and foot baseline with the Bible and sibling frames.
Integer pixel edges, no anti-aliasing.
Correct limb crossing and sufficient passing-stage frames.
Identical frame counts across all directions of the same animation state.

Recovery decision tree:
Fail after 2–3 retries of the current method → drop one level in the Generation Hierarchy.
Persistent identity or scale failure → return to Bible and re-lock if necessary (only with User approval if style would change).
Video fill-in still fails checks → note failure, proceed with available frames, inform user at end of build for manual cleanup.
Log the failure mode.

This is the most reliable pipeline currently achievable with Grok Imagine and related tools for the player characters (and enemies) of What Dwells Below. Follow it exactly. Deviations require explicit justification and re-validation under the orthographic camera + Y-billboard + nearest-neighbor filtering.

Appendix C – Full Character Bible Prompt Template

(Consult on demand.)

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

All eight full-body figures must have identical proportions and silhouette height, feet on the same baseline. Character locked across every cell: rugged human dungeon delver, practical layered leather and metal armor, [short messy dark hair / appropriate female hairstyle], determined expression, bright green scarf around neck, limited muted palette (grays, browns, dark greens, skin tones, metal). Crisp true pixel-art style, integer pixel edges, no anti-aliasing, no smoothing. Do not swap any cells. Do not place the face close-up anywhere except the exact center. No cropping of limbs, no props, no weapons, no text, no numbers, no borders, no grid lines. Perfect even 3×3 grid.

Appendix D – Summary Reliability Table

(Consult on demand.)

| Technique | Reliability | Recommendation |
|---|---|---|
| Locked 3×3 magenta Character Bible + palette | High | Mandatory |
| Game-centric direction names (8-dir) | High | Use always |
| Soft identity language after Bible lock | High | Use always after lock |
| Single-pass 3×3 for the Bible | Highest for identity | Preferred for Bible |
| 400% NN I2V plate (cell chroma kept) | High | Default I2V first frame |
| Spliced single-cell I2V seed | Highest | Default video path |
| Full-Bible I2V seed | Fallback only | Use if single still fails or multi-facing motion is required |
| Image-to-video walk cycles (spliced-still-seeded) | Highest | Primary path for fill-in |
| Individual classic key poses | High | Preferred fallback |
| Lattice square-crop before 3×3 split | High | Mandatory before splices |
| Extra pad or 1024-fit I2V seed | Low | Avoid (shrinks the figure) |
| Key / despill on the I2V seed | Low | Avoid (eats cell lips) |
| Magenta range-key + flatten to #FF00FF | High | Bible lock and §19.6 post-video cleanup only |
| Foot baseline locking in post | High | Mandatory |
| Equal frame counts per direction | High | Mandatory |
| Hard frame-count demands | Low | Avoid |
| Full multi-direction strips | Very Low | Forbidden |
| Chained image-edits for Bible directions | Medium-Low | Avoid (causes drift) |
| Aseprite / scripted pixel-grid cleanup | Mandatory | Always perform |