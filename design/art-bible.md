# Bible lock, plate remap, overlays, quality bar

Status: current plan
Read when: locking a Character Bible, plate remap, overlays, or the quality bar

art is already open when this sibling is loaded. Do not reopen art_pipeline from this file.

## 19.0 Goals and non-negotiables

- One locked Character Bible per character type (male and female) is the single source of truth for identity, proportions, palette, and style.
- Identity drift, anti-aliasing, leftover start-chroma rims, magenta spill, foot sliding, scale inconsistency, and extra limbs/props are hard failures.
- All final frames MUST be true pixel art on an integer grid after cleanup (nearest-neighbor only).
- Prefer fewer high-quality, readable frames over many mediocre ones. The engine can hold or simple-tween if needed.
- Generate and clean one facing’s locomotion set as a proof before scaling to all directions and states.
- Final engine resolution target: 128×128 canvases (recommended). Nearest-neighbor downscale to 64×64 is permitted only if required by import settings; document the choice. Base resolution in audio_visual remains 64×64 for world units; sprite assets ship at 128×128 unless otherwise specified.
- Use game-centric direction names exclusively: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right.
- All directional variants of the same animation state for a given character MUST contain exactly the same number of frames.
- **One I2V clip per review gate.** After each clip, stop and wait for the User. Do not queue the next facing, action, gender, retry, or fill-in pass until the User says so.
- **Do not seed I2V from a mid-action video extract** or name pack-slot indices in the prompt. Seed is the idle Bible cell. Packer chooses frames after accept.
- **No fixed I2V duration.** The clip is as long as it needs to be to finish the motion in `tools/i2v_seeds.py`. Do not demand ten seconds or any other clock.
- **Paper-doll means layers, not baked weapon characters.** Body animations ship unarmed. Equipped weapon and tool are separate overlay frames composited onto those body frames.
- **Every I2V first frame keeps an opaque chroma plate.** Never seed I2V from a processed transparent frame. This applies to player, enemy, and any future I2V call.

## Character Bible

The Character Bible spec, its prompt template and the method-reliability appendix are in `art-bible-character.md`.

## 19.2.4 Paper-doll overlays (weapons and tools)

Body clips stay unarmed. Weapons and gathering tools are **overlay layers**.

- Overlay pixels are registered to the empty-hand / grip position of that body frame and facing. Alignment MUST be identical for male and female aside from the body art itself. No per-gender weapon redraws.
- Locomotion and idle (`idle`, `idle_to_walk`, `walk`, `walk_to_idle`, `death`, `Dispel`): use a **carry / rest** overlay per facing. One rest frame per facing is enough unless the User asks for a matching overlay on every body frame.
- Attack / special / gather: one overlay frame per packed body frame for that action.
- Generate each overlay against **one** clean unarmed body frame (or accepted body clip) of the correct facing, not against the full Bible and not as a standalone character. Overlay stills that go to I2V keep an opaque `#FF00FF` plate.
- Engine draw order is body, then tool/weapon (weapon behind the body only when a facing requires it for a back grip; document that facing if used).
- Other handedness is a runtime flip of the authored body (character-left-hand high) plus Left/Right remap. Flip the overlay with that body. Do not author a second grip sheet.

Do not bake a held axe, staff, bow, pick, or hatchet into a body frame. The Dispel knife is the only baked prop, and only on the Dispel clip. Bible and reference stills that show a held weapon or prop draw it at rest (carried, never aimed, drawn or swung) so it can be animated later; the swing or draw comes from the animation.

## 19.3 Review gate (mandatory)

The User judges the I2V clip itself first (facing lock, travel, identity). Do not pre-harvest a rejected clip.

After accept, harvest, pack, and cleanup (art_pipeline.pack). Then the User judges the packed strip.

Do not start the next unit until the User says so.

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

