# Retired tools

Kept for reference only. Not catalogued, not smoke-tested, not run by CI. Imports assume `tools/`, so `git mv` a file back before running it.

- `harvest_walk.py`: walk-frame harvest from the first I2V pass; `pack_locomotion.py` packs walk clips now.
- `make_placeholder_audio.py`: first placeholder music and SFX writer; overwrites `assets/audio`. New cues: `make_sfx.py` plus `sfx-cues.json`.
- `pack_facing_fix.py`: one-off left-facing sheet fix from a single Grok session folder.
- `pack_p2_art.py`: phase 2 equipment stills from one session folder; assets are committed.
- `pack_p4_enemies.py`: phase 4 enemy stills pack; assets are committed. Re-key with `rekey_all_stills.py`.
- `pack_walk.py`: walk-cycle packer; replaced by `pack_locomotion.py`.
- `process_enemies.py`: bruiser stills from fixed `_src` names; assets are committed.
- `process_gloam.py`: keyed stills for the Gloam 3D view; the repo has no `assets/3d` folder.
- `process_session_sprites.py`: one-off player stills from one session folder.
- `process_sprites.py`: first sprite pass from `_src`; replaced by `sprite_pipeline.py` and `rekey_all_stills.py`.
- `process_world.py`: first world-prop pass; replaced by `process_world_pass.py`.
- `rekey_stills.py`: per-session re-key; replaced by `rekey_all_stills.py` (manifest driven).
- `run_post_split_gate.py`: import check plus optional smokes; use `run_build_gate.py --batch`, then `run_smokes.py`.
