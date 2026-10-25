# Player sprite and paper-doll generation pipeline

Status: current plan  
Read when: sprite frames, paper plates, sheet harvest
Code: `tools/media.py sprites`, `tools/media.py i2v-seeds`, `tools/media.py bible-prompt`, `tools/media.py attack-keys`, `tools/media.py plate-remap`, `tools/media.py bible-normalize`, `tools/lib/imglib/`, `tools/shots.py inspect`, `tools/media.py pack-loco`, `tools/media.py pack-oneshot`, `tools/media.py rekey`, `tools/media.py world`, `tools/media.py gear-icons`, `tools/media.py pack-turntable`, `tools/media.py anim-review`, `tools/lib/media/anim_review_lib.py`, `tools/media.py grok`, `assets/sprites/player/`  

This file is the door. Do not run `tools/media.py bible-prompt` unless you are writing or locking a Bible. Do not load Appendix D unless you are choosing a generation method. Do not load Job siblings until a table row matches. Do not load art_pipeline.attack_keyframes unless the User is resuming that parked pipeline.

| Job | Open |
|-----|------|
| seed unit, spoken cue | `design/art-i2v.md` |
| cleanup pass, atlas stitch | `design/art-pack.md` |
| brief packet, tree tour | `design/art-review.md` |
| parked | parked |
| canon bible, layer law, quality floor | `design/art-bible.md` |
| identity sketch, template wording, reliability notes | `design/art-bible-character.md` |
| enemy facings, prop hands, mirror swap, quiver and staff | `design/art-bible-enemy.md` |

I2V stays in Grok Build unless the User says otherwise. I2V stays in a slice thread (not Bot notes, PC offload, or smoke tests). One unit per review gate. Mid-week new CLI chat is a catch-up: no week pin.

Imagine calls (`image_gen`, `image_edit`, `image_to_video`) use the isolated-media gate and `tools/media.py grok`, not this door. Do not generate in the game-repo session unless that gate’s exception table matches. World tiles, UI stills, and other non-character sheets use that door plus this file’s locked-Bible style rule. Pack and review stay in the slice thread after accept.

Reliability comes from **one Image-to-Video clip at a time**, the live prompt in `tools/media.py i2v-seeds`, **User review**, and plate-correct / cleanup scripts. Do not run automatic multi-pass fill-in.

After an isolated still lands under `_src/`, key the source plate directly with `python tools/media.py sprites key` (or `matte`; both use `tools/lib/imglib/matte.py`), no remap first (art-pack, Still rekey). `tools/media.py plate-remap` is only for opaque I2V seed plates. Do not write a new keyer, a PIL loop, or a one-off script for chroma. Extend `media.py world` or `media.py gear-icons` only if a durable batch wrapper is needed, and tell the User.

All character art (player and enemies) MUST follow this pipeline. Props may use a simplified stills-only variant.  
Male and female player characters MUST each have their own locked Character Bible and MUST maintain full animation parity so that weapon and tool paper-doll **layers** composite onto either body without special per-gender tweaks.  
Player and enemy animations use exactly 8 directions matching the Character Bible layout.
