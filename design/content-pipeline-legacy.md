# Content pipeline — legacy art tools (being migrated)

Status: legacy, being migrated into the unified content pipeline
Read when: rekey manifests, shipped sprite sheets, retired generators
Code: `tools/lib/media/` legacy modules (below), `tools/data/comfy-character-workflow.json`, `tools/data/comfy-workflows/`, `tools/data/comfy_wdb_character/`, `assets/sprites/`

The old art pipeline made the sprites the game ships today. New art goes through the studio and `media.py pipeline` (the other jobs on this door). Nothing here is deleted while the game or a migration step still uses it. Each row says where its work lands in the unified pipeline; a "not wired" landing is a studio action that `studio --gaps` still lists as open.

## Still used for shipped art

| Tool | Status | Lands in |
|---|---|---|
| `media.py rekey`, `rekey-preview`, `rekey-check`, `keyed-region` (`rekey_all_stills.py`, `rekey_preview.py`, `rekey_check.py`, `match_keyed_region.py`) | In use for the stills already in the game | Export hand-off: the pipeline calls the existing key/fit/palette and rekey entry points (task decision 7); `pixel` / `sheet` actions, not wired |
| `media.py sprites` (`sprite_pipeline.py`) | In use: cleanup, keying and fitting of existing sprites | Same export hand-off |
| `media.py gear-icons`, `shop-icons`, `world` (`process_gear_icons.py`, `slice_shop_icons.py`, `process_world_pass.py`) | In use for the shipped icons and hub/dungeon still art | `icon` (gear, shop) and `tile` (world) actions, not wired |
| `media.py keytest` (`keytest.py`, `tools/data/keytest_expect.json`) | In use: keyer regression | Stays: the pipeline keys through the same `imglib` matte (`plates.py`) |
| `media.py glyphs`, `media.py sfx` (`gen_prompt_glyphs.py`, `make_sfx.py`) | In use for prompt glyphs and placeholder cues | `ui` subjects; `sound` action (Stable Audio setup missing) |

## Closed for new art (code kept)

Do not run these for new game art (door rule). The shipped strips they made stay.

| Tool | Lands in |
|---|---|
| `media.py bible-prompt`, `bible-normalize` (`bible_prompt.py`, `bible_normalize.py`) | Locked bible views are references on a subject; `pipeline tune` drops a bible reference on a repeated miss |
| `media.py i2v-seeds`, `pack-loco`, `pack-oneshot`, `pack-turntable`, `plate-remap` (`i2v_seeds.py`, `pack_locomotion.py`, `pack_oneshot.py`, `pack_turntable.py`, `plate_remap.py`) | `animate` / `keyframes` / `sheet` actions (MotionBricks on disk, not wired); packing reused through the export hand-off |
| `media.py comfy-character` (`comfy_character.py`), old page at `http://<lan-ip>:8189/legacy/` | The studio at `/` on the same server |
| `media.py anim-review` (`anim_review.py`, `anim_review_lib.py`) | Studio review screen and per-step approvals |
| `media.py grok` Imagine stills (isolated-media gate) | `reference` / `generate` actions on local models |

## Game side

Live sprites stay on today's `assets/sprites/` paths until their subject is exported. The readers of those paths (for example `scripts/world/player/anim_load.gd`, `scripts/combat/enemy/enemy_setup.gd`, `scripts/combat/roster.gd`, `scripts/world/interact/interact_fx.gd`) belong to their own doors. Each moves to `scripts/data/content_pack.gd` when its id is in `data/pipeline/export/index.json`; the index lists no subjects yet.
