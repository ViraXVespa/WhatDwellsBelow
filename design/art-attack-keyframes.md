# Attack body keyframes (posed stills)

Status: parked experiment. Not live I2V law.
Read when: the User resumes the attack animation keyframe pipeline, two-hand body stills, coil stills, or names this file.
Code: `tools/attack_keyframes.py`


Do not read when: the job is walk or idle I2V, pack, overlay, Godot, combat numbers, or a general art-pipeline session.

Log: `tools/attack_keyframes_log.json`
Seed: locked Bible Down cell, 4x NN, `#FF00FF`. User file name used in testing: `seed_i2v_down_x4.png`. Chat image ids die with the session. Do not ask for old ones.

## Resume commands (run these; paste the printed block)

    python tools/attack_keyframes.py --resume

Same prompt without the log:

    python tools/attack_keyframes.py --print --gender female --facing down --action attack_great_axe --beat coil

After a roll:

    python tools/attack_keyframes.py --log --verdict parked --note "short note"

`verdict` is `keeper`, `fail`, or `parked`.

    python tools/attack_keyframes.py --beats --action attack_great_axe

Imagine-edit the Bible cell only. Never edit a previous generate. Success means the desired pose appears from that seed on a fresh generate.

## Why this file exists

I2V from the idle still plus an attack paragraph invented props (black vortex in the hands, then literal plates). Hands did not stay a pair. Tight "no weapon" language did not stop it.

Pose-edit stills from the Bible cell can hold an empty stacked grip. Those stills are control pins for later first/last-frame I2V. Walk and idle stay I2V.

Unfinished. Coil has a repeatable sheet (`coil_v31`) that is not a finished product. Mid-swing, contact, follow, recover are not locked.

## Binding constraints

- Body frames stay unarmed.
- Fresh edit of the locked Bible cell every time.
- Square facing. Idle feet unless the beat says otherwise.
- Authored grip is character-left-hand high for every gender. Facing Down, that is camera-right high / camera-left low. Other handedness is runtime `flip_h` plus Left/Right and diagonal remap. Do not generate a second grip sheet. Overlays flip with the body.
- `#FF00FF` plate. Identity from the seed.

## Beats (two-hand arc)

idle (Bible, do not generate), coil (in progress), mid_swing, contact, follow, recover.

## Locked coil sheet

Sheet id `coil_v31`. Live text is whatever `attack_keyframes.py --resume` prints. That is the source of truth if this file and the script drift. `coil_v22` stays in the script as history only.

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
10. Isolated Grok Build (no the repo agent-rules file tree) cost about half a protocol-loaded I2V turn. Context, not the video model, was the extra spend.
11. Video 1.5 can pin first+last frame. That is the planned interpolator after keys exist. It is not a six-key timeline.
12. Naming belt or buckle redraws the strap. Omit both from the Imagine body. The seed copies the belt if you stop asking for it.
13. "Middle of the chest" splits the fists onto two chest spots. Keep one sternum column.
14. Zipper language in the pose line does not transfer to a male sheet. Keep zipper only as female-seed identity if the seed has one.

## Trial log (female Down coil unless noted)

I2V, isolated Build, `attack_great_axe`: black vortex between the hands; hands did not stay together.

I2V retry / still prompts that said "plates": literal armor plates in the hands.

Six authored stills in one shot: failed identity, pose, and empty-hand checks. Do not batch six keys in one Imagine turn.

Coil from `seed_i2v_down_x4.png` (Bible Down 4x). This is the line that produced keepers.

Early stack language (sternum / chest over midriff, hover off jacket): first stacked fists. Wide feet when the foot lock was missing or first.

Tummy-ache: flat palms on chest and belly. Triggers: stomach, navel, "not palms on the stomach", open fingers, fingernails, `fingers curled` on a bad roll.

Heart / C-shape: C-shape language.

Thumbs-up pinch: "thumbs on top".

Horizontal split (jacket strip between hands): "strip of jacket between the hands" or gap language.

Wide fight stance: missing foot lock; foot lock first in a long prompt; "shoulder twist"; "clearer body coil".

Pouch / extra glove: showed up on some early edits. Treat as fail. Do not chain from that still.

v17 / v19: stack + narrow feet + curled fingers. Good, not repeatable. Same text later returned tummy-ache (v21).

v22 sheet (`both hands in fists`, stack, hover, elbows in, feet last): v22, v23, v24, v25 matched. Tight fists. Almost no torso coil.

v26 "ribcage rotates... hips and feet copied": no readable coil. Same idle block.

v27 dropped "same hair", added "small body coil" and "hair may shift": first small twist. Feet a bit wide. Stack held.

v28 "clearer body coil": hair blowout, wide stance, farther.

v29 small coil + hair close to head: coil ok-ish; high hand flipped (unqualified left/right).

v30 (`her left hand` high) generated 2026-09-16: punch/boxer read (`dXNdR`). Not a keeper.

2026-09-16 web Imagine, same seed: zipper-centerline stack could hold (`Jtnrz`, `afeuP`) but feet stayed wide and `her left` kept flipping the high fist to camera-left. Naming belt/buckle grew straps. Omitting those words fixed the belt (`cyH6G`).

Camera-right high / camera-left low flipped grip to the authored side (`Vhhkr`, `GD3gp`). "Middle of the chest" split the stack (`I0058`).

`coil_v31` / still `GDNnn`: best authored-side roll. Camera-right high, closer sternum column, belt quiet. Feet still open. Elbows still off the ribs. Parked, not keeper.

Shoulder-twist and ribcage lines stay banned. Hair-unlock + small coil is still the only torso cue that moved the body without a full fight stance, and it still widened feet a little.

## What a future session should do

1. User says this pipeline is in scope.
2. Run `--resume`. Paste the printout.
3. Attach the Bible Down 4x cell, not a chat thumbnail.
4. Generate `coil_v32` from that seed only, using the printed `coil_v31` sheet.
5. Score against: stacked fists on the sternum, camera-right high (Down), idle feet, square Down, no prop, optional small coil, seed belt copied without naming it.
6. Log the roll. Do not invent mid-swing until coil is accepted as finished product.
7. If quota dies, update leave-off and stop.

## Leave-off (2026-09-16)

Beat: female Down `attack_great_axe` / coil.
Sheet: `coil_v31`. Next id: `coil_v32`.
Best still: `GDNnn` (parked, not keeper).
Grip: `authored_left_high` = camera-right high when facing Down.
Feet and tucked elbows still open. Do not chain edits.
