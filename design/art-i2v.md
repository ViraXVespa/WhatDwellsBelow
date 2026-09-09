# I2V unit, seed, and prompt

Status: binding design  
Read when: preparing or retrying one player I2V clip  
See also: `design/art-pipeline.md`, `design/art-pack.md`, `design/player.md`  
Code: `tools/i2v_seeds.py`, `tools/plate_remap.py`

Open this file from the door. Do not load Appendix C/D. Pack/cleanup is `design/art-pack.md`.

Always work **one unit** at a time. A unit is exactly one **character type** + one **facing** + one **action**. After the seed and prompt exist, stop and wait for the User.

## Prompts

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

After the User accepts the clip, harvest and pack (`design/art-pack.md`). Then stop again if the next unit is not already named.

## Seed still

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

## What the walk I2V is for

In-game **idle is not an I2V product**. Idle is the directional key still for the facing the player is aiming — the same Bible cell / approved splice used as the I2V seed. One texture per facing. No breath cycle. Do not pack held “standing on the still” frames as idle.

| Packed state | Source |
|--------------|--------|
| `idle` | The key still for that facing. Not harvested from the video. |
| `idle_to_walk` | Opening of the walk I2V: still → first passing step. |
| `walk` | Cyclic strides from the same clip. |
| `walk_to_idle` | End of the same clip: last plant of the other foot, settle on the still. |

`idle_to_walk` and `walk_to_idle` MUST exist for every facing and both genders. They are first-class engine states. They are **not** separate I2V units unless the User rejects the walk clip and asks for a dedicated pass.

If the walk I2V fails the start/stop plant, reject the clip and regenerate that unit. Do not invent a second method in this file.
