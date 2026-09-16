# Player sprite and paper-doll generation pipeline

Status: binding design  
Read when: sprite frames, paper plates, sheet harvest
Code: `tools/sprite_pipeline.py`, `tools/i2v_seeds.py`, `tools/bible_prompt.py`, `tools/attack_keyframes.py`, `tools/plate_remap.py`, `tools/pack_locomotion.py`, `tools/pack_oneshot.py`, `tools/rekey_stills.py`, `tools/process_*.py`, `tools/pack_*.py`, `tools/anim_review_lib.py`, `tools/anim_review_pack.py`, `tools/anim_review_regen.py`, `tools/anim_review_tree.py`, `tools/run_isolated_grok.py`, `assets/sprites/player/`  

This file is the door. Do not run `tools/bible_prompt.py` unless you are writing or locking a Bible. Do not load Appendix D unless you are choosing a generation method. Do not load Job siblings until a table row matches. Do not load art_pipeline.attack_keyframes unless the User is resuming that parked pipeline.

| Job | Open |
|-----|------|
| seed unit, spoken cue | `design/art-i2v.md` |
| cleanup pass, atlas stitch | `design/art-pack.md` |
| brief packet, tree tour | `design/art-review.md` |
| parked | parked |
| canon bible, layer law, quality floor | `design/art-bible.md` |

I2V stays in Grok Build unless the User says otherwise. One CLI week session. One unit per review gate. Mid-week new CLI chat is a catch-up: no week pin.

Imagine calls (`image_gen`, `image_edit`, `image_to_video`) use the isolated-media gate and `tools/run_isolated_grok.py`, not this door. Do not generate in the game-repo session unless that gate’s exception table matches. World tiles, UI stills, and other non-character sheets use that door plus this file’s locked-Bible style rule. Pack and review stay in the week session after accept.

Reliability comes from **one Image-to-Video clip at a time**, the live prompt in `tools/i2v_seeds.py`, **User review**, and plate-correct / cleanup scripts. Do not run automatic multi-pass fill-in.

All character art (player and enemies) MUST follow this pipeline. Props may use a simplified stills-only variant.  
Male and female player characters MUST each have their own locked Character Bible and MUST maintain full animation parity so that weapon and tool paper-doll **layers** composite onto either body without special per-gender tweaks.  
Player and enemy animations use exactly 8 directions matching the Character Bible layout.
