# Player sprite and paper-doll generation pipeline

Status: binding design  
Read when: generating or replacing player / enemy / weapon frames  
Code: `tools/sprite_pipeline.py`, `tools/i2v_seeds.py`, `tools/bible_prompt.py`, `tools/attack_keyframes.py`, `tools/plate_remap.py`, `tools/pack_locomotion.py`, `tools/pack_oneshot.py`, `tools/rekey_stills.py`, `tools/process_*.py`, `tools/pack_*.py`, `tools/anim_review_lib.py`, `tools/anim_review_pack.py`, `tools/anim_review_regen.py`, `tools/anim_review_tree.py`, `tools/run_isolated_grok.py`, `assets/sprites/player/`  
See also:

This file is the door. Do not run `tools/bible_prompt.py` unless you are writing or locking a Bible. Do not load Appendix D unless you are choosing a generation method. Do not load the siblings until the job matches the table. Do not load `design/art-attack-keyframes.md` unless the User is resuming the attack animation keyframe pipeline.

`See also:` is not a read list. Isolated generate is the Job-table row, not a default open.

| Job | Open |
|-----|------|
| Isolated Imagine / I2V (CLI) | `design/isolated-media.md` |
| Seed, prompt, one I2V unit | `design/art-i2v.md` |
| Harvest, pack, cleanup | `design/art-pack.md` |
| Animation Browser briefs / regen tree | `design/art-review.md` |
| Attack body stills / coil keys (parked) | `design/art-attack-keyframes.md` |
| Bible lock, plate remap, overlays, quality bar | `design/art-bible.md` |

I2V stays in Grok Build unless the User says otherwise. One CLI week session. One unit per review gate. Mid-week new CLI chat is a catch-up: no week pin.

Imagine calls (`image_gen`, `image_edit`, `image_to_video`) default to an isolated scratch job (`design/isolated-media.md`, `tools/run_isolated_grok.py`). Do not generate in the game-repo session unless that file’s exception table matches. World tiles, UI stills, and other non-character sheets use that door plus this file’s locked-Bible style rule. Pack and review stay in the week session after accept.

Reliability comes from **one Image-to-Video clip at a time**, the live prompt in `tools/i2v_seeds.py`, **User review**, and plate-correct / cleanup scripts. Do not run automatic multi-pass fill-in.

All character art (player and enemies) MUST follow this pipeline. Props may use a simplified stills-only variant.  
Male and female player characters MUST each have their own locked Character Bible and MUST maintain full animation parity so that weapon and tool paper-doll **layers** composite onto either body without special per-gender tweaks.  
Player and enemy animations use exactly 8 directions matching the Character Bible layout.
