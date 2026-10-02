# Attack body keyframes (posed stills)

Status: parked experiment. Not live I2V law.
Read when: the User resumes the attack animation keyframe pipeline, two-hand body stills, coil stills, or names this file.
Code: `tools/attack_keyframes.py`


Do not read when: the job is walk or idle I2V, pack, overlay, Godot, combat numbers, or a general art-pipeline session.

Log: `tools/attack_keyframes_log.json`
Seed: locked Bible Down cell, 4x NN, `#FF00FF`. User file name used in testing: `seed_i2v_down_x4.png`. Chat image ids die with the session. Do not ask for old ones.

## Resume commands (run these; paste the printed block)

    python3 tools/attack_keyframes.py --resume

Same prompt without the log:

    python3 tools/attack_keyframes.py --print --gender female --facing down --action attack_great_axe --beat coil

After a roll:

    python3 tools/attack_keyframes.py --log --verdict parked --note "short note"

`verdict` is `keeper`, `fail`, or `parked`.

    python3 tools/attack_keyframes.py --beats --action attack_great_axe

Imagine-edit the Bible cell only. Never edit a previous generate. Success means the desired pose appears from that seed on a fresh generate.

## Why this file exists

I2V from the idle still plus an attack paragraph invents props (vortex, literal plates) and the hands do not stay a pair. Pose-edit stills from the Bible cell can hold an empty stacked grip; those are control pins for later first/last-frame I2V (walk and idle stay I2V).

Unfinished: coil has a repeatable sheet (`coil_v31`), not a finished product. Mid-swing, contact, follow, recover are not locked. Roll history and evidence: `art-attack-keyframes-log.md` (open only when asked why a phrase is banned).

## Binding constraints

- Body frames stay unarmed.
- Fresh edit of the locked Bible cell every time.
- Square facing. Idle feet unless the beat says otherwise.
- Authored grip is character-left-hand high for every gender. Facing Down, that is camera-right high / camera-left low. Other handedness is runtime `flip_h` plus Left/Right and diagonal remap. Do not generate a second grip sheet. Overlays flip with the body.
- `#FF00FF` plate. Identity from the seed.

## Beats (two-hand arc)

idle (Bible, do not generate), coil (in progress), mid_swing, contact, follow, recover.

## Locked coil sheet

Sheet id `coil_v31`. Live text is whatever `attack_keyframes.py --resume` prints. That is the source of truth if this file and the script drift. 

Do not add: stomach, navel, C-shape, fingernails, thumbs on top, strip of jacket between hands, shoulder twist, clearer coil, belt, buckle, middle of the chest, her left, his left.

Pose stack is sternum / midriff / torso centerline. Do not key the pose to zipper; male clothing will differ. Identity may still name this female seed's zipper.

Allowed extras on top of the v31 sheet: drop "same hair"; "small body coil"; "hair may shift a little and must stay close to the head"; square fists / straight wrists; "boots stay as close together as this seed".

## Derived rules (read before changing a prompt)

1. The editor is literal. A noun often becomes a drawn object (plates, vortex, pouch, gloves, belt, buckle).
2. "Empty hands + two-hand swing" in I2V fills the gap between palms with a prop. Palms-apart + "plate visible between palms" was the I2V counter; it still failed in Build tests.
3. Image-edit from the Bible can stack two fists on the sternum. Same prompt is not 100% stable (`fingers curled` coin-flips to tummy-ache). The word `fists` is what repeated (v22-v25 and v31).
4. Foot language must be last and explicit or the stance widens into a fight pose.
5. Long prompts drop the stack. Stack sentence stays early.
6. "Same hair" pins the idle silhouette. A small coil only appeared after hair was allowed to move a little.
7. Asking for a stronger coil ("clearer", "shoulder twist", "ribcage rotate") scaled feet and hair with the torso.
8. Unqualified "left" / "right" is camera-left. `her left` / `his left` is also read as camera-left. Facing Down, write camera-right high / camera-left low for authored character-left high. Do not mix `her left` and viewer-right in one prompt.
9. Editing a previous generate is not the success case. Fresh Bible only.
10. Video 1.5 can pin first+last frame: the planned interpolator after keys exist, not a six-key timeline.
11. Naming belt or buckle redraws the strap. Omit both from the Imagine body. The seed copies the belt if you stop asking for it.
12. "Middle of the chest" splits the fists onto two chest spots. Keep one sternum column.
13. Zipper language in the pose line does not transfer to a male sheet. Keep zipper only as female-seed identity if the seed has one.

## What a future session should do

1. User says this pipeline is in scope.
2. Run `--resume`. Paste the printout.
3. Attach the Bible Down 4x cell, not a chat thumbnail.
4. Generate `coil_v32` from that seed only, using the printed `coil_v31` sheet.
5. Score against: stacked fists on the sternum, camera-right high (Down), idle feet, square Down, no prop, optional small coil, seed belt copied without naming it.
6. Log the roll. Do not invent mid-swing until coil is accepted as finished product.
7. If quota dies, stop. Pickup is this file plus `python3 tools/attack_keyframes.py --resume`.

## Parked pickup (2026-09-16)

Beat: female Down `attack_great_axe` / coil.
Sheet: `coil_v31`. Next id: `coil_v32`.
Best still: `GDNnn` (parked, not keeper).
Grip: `authored_left_high` = camera-right high when facing Down.
Feet and tucked elbows still open. Do not chain edits.
