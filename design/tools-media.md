# Tools catalog: media and art pipeline

Status: binding  
Read when: running a still/I2V/pack/sprite/audio tool (Build / User only)  

Rules, the CLI contract and the surface key are in `tools.md`; flows live in the `art-*.md` docs and the Imagine / I2V skills. The Bot never uses these.

### Media / art pipeline (Build only)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `audio_lib.py` | Placeholder audio helpers (`write_wav`, `write_pcm`, `sine`, `noise`, `mix`, `mix_norm`) behind the `make_*` audio tools; WAV output byte-identical | D | module docstring (no `--help`) | N |
| `sprite_lib.py` | Shared sprite helpers (`dist`, `neighbors8`, `shrink_keyed`, `KEYED_CAP`) for the pack/key tools; variants stay in their tools | D | module docstring (no `--help`) | N |
| `anim_review_lib.py` | Read helpers for the Animation Browser review tools. Allowlisted but only supports non-Bot tools. | D | module docstring (no `--help`) | Y |
| `anim_review_pack.py` | Build a Grok-readable pack brief from Animation Browser review.json | D | `--help` | N |
| `anim_review_regen.py` | Build a Grok-readable regen brief from Animation Browser review.json | D | `--help` | N |
| `anim_review_tree.py` | Build a wiped I2V test tree for every Regenerate clip in review.json | D | `--help` | N |
| `attack_keyframes.py` | Beat-by-beat unarmed attack stills from a locked Bible cell | D | `--help` | N |
| `attack_keyframes_log.json` | Sidecar data for the tool of the same stem | D | - | N |
| `bible_prompt.py` | Character Bible Imagine text. Print and copy | D | `--help` | N |
| `gen_prompt_glyphs.py` | Chunky pixel prompt glyphs. Run from repo root | D | `--help` | N |
| `harvest_walk.py` | Extract evenly spaced walk frames from I2V clips (Section 19) | D | `--help` | N |
| `i2v_seeds.py` | I2V plates: splice or single cell, exact integer nearest-neighbor scale, leave chroma | D | `--help` | N |
| `make_p2_sfx.py` | Tiny placeholder wavs for Phase 2 combat (Section 14 placeholder policy) | D | `--help` | N |
| `make_p9_sfx.py` | Appendix E remaining SFX + gendered VO stand-ins | D | `--help` | N |
| `make_placeholder_audio.py` | Write tiny placeholder WAV loops and one-shot SFX. Final music is by Vira | D | `--help` | N |
| `match_keyed_region.py` | Match a keyed source region against a live sprite, and sort local sources | D | `--help` | N |
| `pack_facing_fix.py` | Pack corrected left-facing player sheets with magenta key + despill | D | `--help` | N |
| `pack_locomotion.py` | Pack idle stills + idle_to_walk / walk / walk_to_idle from I2V clips | D | `--help` | N |
| `pack_oneshot.py` | Pack one-shot I2V clips into engine frames | D | `--help` | N |
| `pack_p2_art.py` | pack_p2_art.py | D | `--help` | N |
| `pack_p4_enemies.py` | Pack Phase 4 enemy stills: magenta key, 128 canvas, 8-dir copies | D | `--help` | N |
| `pack_turntable.py` | Pack 8-dir player sheets from turntable + facing clips, shared scale and torso pin | D | `--help` | N |
| `pack_walk.py` | Extract, key, and pack walk-cycle frames from Imagine videos | D | `--help` | N |
| `plate_remap.py` | Remap a generated chroma plate to exact #FF00FF, including edge bleed | D | `--help` | N |
| `process_enemies.py` | process_enemies.py | D | `--help` | N |
| `process_gear_icons.py` | process_gear_icons.py | D | `--help` | N |
| `process_gloam.py` | Key Imagine stills into assets/3d for the Gloam 3D view | D | `--help` | N |
| `process_session_sprites.py` | Key whatever-magenta Imagine stills and fit them into engine sprites | D | `--help` | N |
| `process_sprites.py` | process_sprites.py | D | `--help` | N |
| `process_world.py` | process_world.py | D | `--help` | N |
| `process_world_pass.py` | Key and install the Placeholdia / dungeon art pass stills | D | `--help` | N |
| `rekey_stills.py` | Re-key live stills from Grok session sources with plate_remap + sprite_pipeline | D | `--help` | N |
| `run_isolated_grok.py` | Stage a scratch directory outside the git tree and run a thin Grok Build media job | D | `--help` | N |
| `shot-recipes.json` | Sidecar data for the tool of the same stem | D | - | N |
| `sprite_pipeline.py` | Section 19 cleanup: Paint.NET-style outside wand + Color-to-Alpha lip + 128 fit | D | `--help` | N |
