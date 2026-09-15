# Attack body keyframes (posed stills)

Status: parked experiment. Not live I2V law.

Read when: the User resumes the attack animation keyframe pipeline, two-hand body stills, coil stills, or names this file.  
See also: `design/art-pipeline.md`

Do not read when: the job is walk or idle I2V, pack, overlay, Godot, combat numbers, or a general art-pipeline session. `design/art-i2v.md` and `tools/i2v_seeds.py` stay the I2V path.

Code: `tools/attack_keyframes.py`
Log: `tools/attack_keyframes_log.json`
Seed: locked Bible Down cell, 4× NN, `#FF00FF`. User file name used in testing: `seed_i2v_down_x4.png`. Session image ids from 2026-09-15 are dead. Do not ask for them.

## Resume commands (run these; paste the printed block)

```
python tools/attack_keyframes.py --resume
```

Same prompt without the log:

```
python tools/attack_keyframes.py --print --gender female --facing down --action attack_great_axe --beat coil
```

After a roll:

```
python tools/attack_keyframes.py --log --verdict keeper --note "short note"
```

`verdict` is `keeper`, `fail`, or `parked`.

```
python tools/attack_keyframes.py --beats --action attack_great_axe
```

Imagine-edit the Bible cell only. Never edit a previous generate. Success means the desired pose appears from that seed on a fresh generate.

## Why this file exists

I2V from the idle still plus an attack paragraph invented props (black vortex in the hands, then literal plates). Hands did not stay a pair. Tight “no weapon” language did not stop it.

Pose-edit stills from the Bible cell can hold an empty stacked grip. Those stills are control pins for later first/last-frame I2V. Walk and idle stay I2V.

Unfinished. Only coil has a repeatable sheet. Mid-swing, contact, follow, recover are not locked.

## Binding constraints

- Body frames stay unarmed.
- Fresh edit of the locked Bible cell every time.
- Square facing. Idle feet unless the beat says otherwise.
- Authored grip is character-left-hand high for every gender. Other handedness is runtime `flip_h` plus Left/Right and diagonal remap. Do not generate a second grip sheet. Overlays flip with the body.
- `#FF00FF` plate. Identity from the seed.

## Beats (two-hand arc)

idle (Bible, do not generate), coil (in progress), mid_swing, contact, follow, recover.

## Locked coil sheet

Sheet id `coil_v22`. Live text is whatever `attack_keyframes.py --resume` prints. That is the source of truth if this file and the script drift.

Do not add: stomach, navel, C-shape, fingernails, thumbs on top, strip of jacket between hands, shoulder twist, clearer coil.

Allowed extras on top of the v22 stack+fists+feet sheet: drop “same hair”; “small body coil”; “hair may shift a little and must stay close to the head”; name `her left hand` / `his left hand`.

## Derived rules (read before changing a prompt)

1. The editor is literal. A noun often becomes a drawn object (plates, vortex, pouch, gloves).
2. “Empty hands + two-hand swing” in I2V fills the gap between palms with a prop. Palms-apart + “plate visible between palms” was the I2V counter; it still failed in Build tests.
3. Image-edit from the Bible can stack two fists on the zipper. Same prompt is not 100% stable (`fingers curled` coin-flips to tummy-ache). The word `fists` is what repeated (v22–v25).
4. Foot language must be last and explicit or the stance widens into a fight pose.
5. Long prompts drop the stack. Stack sentence stays early.
6. “Same hair” pins the idle silhouette. A small coil only appeared after hair was allowed to move a little.
7. Asking for a stronger coil (“clearer”, “shoulder twist”, “ribcage rotate”) scaled feet and hair with the torso.
8. Unqualified “left” / “right” is viewer-left. Use `her left hand` / `his left hand`.
9. Editing a previous generate is not the success case. Fresh Bible only.
10. Isolated Grok Build (no AGENTS.md tree) cost about half a protocol-loaded I2V turn. Context, not the video model, was the extra spend.
11. Video 1.5 can pin first+last frame. That is the planned interpolator after keys exist. It is not a six-key timeline.

## Trial log (female Down coil unless noted)

I2V, isolated Build, `attack_great_axe`: black vortex between the hands; hands did not stay together.

I2V retry / still prompts that said “plates”: literal armor plates in the hands.

Six authored stills in one shot: failed identity, pose, and empty-hand checks. Do not batch six keys in one Imagine turn.

Coil from `seed_i2v_down_x4.png` (Bible Down 4×). This is the line that produced keepers.

Early stack language (sternum / chest over midriff, hover off jacket): first stacked fists. Wide feet when the foot lock was missing or first.

Tummy-ache: flat palms on chest and belly. Triggers: stomach, navel, “not palms on the stomach”, open fingers, fingernails, `fingers curled` on a bad roll.

Heart / C-shape: C-shape language.

Thumbs-up pinch: “thumbs on top”.

Horizontal split (jacket strip between hands): “strip of jacket between the hands” or gap language.

Wide fight stance: missing foot lock; foot lock first in a long prompt; “shoulder twist”; “clearer body coil”.

Pouch / extra glove: showed up on some early edits. Treat as fail. Do not chain from that still.

v17 / v19: stack + narrow feet + curled fingers. Good, not repeatable. Same text later returned tummy-ache (v21).

v22 sheet (`both hands in fists`, stack, hover, elbows in, feet last): v22, v23, v24, v25 matched. This is the consistency candidate. Tight fists. Almost no torso coil.

v26 “ribcage rotates… hips and feet copied”: no readable coil. Same idle block.

v27 dropped “same hair”, added “small body coil” and “hair may shift”: first small twist. Feet a bit wide. Stack held.

v28 “clearer body coil”: hair blowout, wide stance, farther.

v29 small coil + hair close to head: coil ok-ish; high hand flipped (unqualified left/right).

v30 (`her left hand` / `her right hand`) never generated. Imagine burst cap.

Shoulder-twist and ribcage lines are banned. Hair-unlock + small coil is the only torso cue that moved the body without a full fight stance, and it still widened feet a little.

## What a future session should do

1. User says this pipeline is in scope.
2. Run `--resume`. Paste the printout.
3. Attach the Bible Down 4× cell, not a chat thumbnail.
4. Generate `coil_v30` (v22 sheet + explicit `her left hand` high) from that seed only.
5. Score against: stacked fists, character-left high, idle feet, square Down, no prop, optional small coil.
6. Log the roll. Do not invent mid-swing until coil is accepted as finished product.
7. If quota dies, update leave-off and stop.

## Leave-off (2026-09-15)

Beat: female Down `attack_great_axe` / coil.
Sheet: `coil_v22`. Next id: `coil_v30`.
Grip: `authored_left_high`. Other handedness is runtime flip.
Imagine cap hit ~10:12 UTC. Do not chain edits.
