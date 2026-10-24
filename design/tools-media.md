# Tools: media and art pipeline

Status: protocol  
Read when: running a still/I2V/pack/sprite/audio tool (Build / User only)  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Flows live in the `art-*.md` docs and the Imagine / I2V skills. The Bot reads only the image library section.

## Jobs

- **Imagine a still (UI, NPC, tile, character):** `run_isolated_grok.py --kind ui --brief "..." --out DIR` (flow: the isolated-media gate).
- **Rekey stills:** `rekey_all_stills.py --only assets/...png` (live), `--out DIR` (review copy), `--check` (two runs byte-identical); look first with `rekey_preview.py --only ...`; full-set check `rekey_check.py --new DIR`.
- **Animation review briefs:** `anim_review.py pack`, `anim_review.py regen`, `anim_review.py tree --out DIR`.
- **Bible prompts and sheets:** `bible_prompt.py --gender female` / `--enemy ID`; `bible_normalize.py`.
- **Sound effects:** `make_sfx.py --list`, `make_sfx.py --only CUE`, `make_sfx.py --check`.
- **Image facts for a proof:** `img_inspect.py` (`tools-shots.md`).

### Media / art pipeline (Build only)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `audio_lib.py` | Placeholder audio helpers (`write_wav`, `write_pcm`, `sine`, `noise`, `mix`, `mix_norm`) behind the `make_*` audio tools; WAV output byte-identical | D | docstring | N |
| `anim_review_lib.py` | Read helpers for the Animation Browser review tools, plus the shared pack/regen brief CLI and writer (`brief_args`, `load_with_missing`, `add_missing`, `write_brief`). Allowlisted but only supports non-Bot tools. | D | docstring | Y |
| `anim_review.py` | Animation Browser review briefs: `pack` (Repack notes + Good locomotion clips), `regen` (Regenerate notes + current I2V prompt), `tree --out DIR` (wiped I2V test tree). Summary: `anim-review` | D | `--help` | N |
| `attack_keyframes.py` | Beat-by-beat unarmed attack stills from a locked Bible cell | D | `--help` | N |
| `attack_keyframes_log.json` | Sidecar data for the tool of the same stem | D | - | N |
| `bible_normalize.py` | Squared 3×3 Bible to live lock sheet: plate remap, SCUNet denoise at 2x (`--no-denoise` skips), full bodies to shared height with `--margin` plate, bust keeps crop, 4x4 trimmed-mean rebuild to `--cell`; prints a per-cell scale/bbox table and edge/width flags (`art-bible-character.md`) | D | `--help` | N |
| `bible_prompt.py` | Bible Imagine text: `--gender` player, `--enemy ID` enemy (prop, hand and idle-pose table lives in the tool). Print and copy | D | `--help` | N |
| `gen_prompt_glyphs.py` | Chunky pixel prompt glyphs. Run from repo root | D | `--help` | N |
| `i2v_seeds.py` | I2V plates: splice or single cell, exact integer nearest-neighbor scale, leave chroma (`--out DIR`) | D | `--help` | N |
| `make_sfx.py` | Placeholder SFX wavs from `tools/sfx-cues.json` (one entry per cue; sine, noise, mix, cat nodes). `--list`, `--only`, `--prefix`, `--dry-run`, `--check` (render to temp and compare with `assets/audio`; the 21 p2/p9 cues are byte-identical). A new cue is one JSON entry, not a new script | D | `--help` | N |
| `sfx-cues.json` | Cue specs read by `make_sfx.py` (name, scale, graph) | D | - | N |
| `match_keyed_region.py` | Match a keyed source region against a live sprite, and sort local sources (also the matcher library for the rekey tools) | D | `--help` | N |
| `pack_locomotion.py` | Pack idle stills + idle_to_walk / walk / walk_to_idle from I2V clips | D | `--help` | N |
| `pack_oneshot.py` | Pack one-shot I2V clips into engine frames | D | `--help` | N |
| `pack_turntable.py` | Pack 8-dir player sheets from turntable + facing clips, shared scale and torso pin | D | `--help` | N |
| `plate_remap.py` | Remap a generated chroma plate to exact #FF00FF. Solid plate near a border reference only; a farther mix keeps its drawn RGB (`imglib.key.remap_plate`; `--tol`) | D | `--help` | N |
| `process_gear_icons.py` | Key `_src/sources/assets/ui/gear` plates into `assets/ui/gear`. `--check` fails if an expected icon has no plate or live png. The batch gate runs `--check`. | D | `--help` | N |
| `slice_shop_icons.py` | Slice the ghost-shop Imagine sheet into gear source plates and keyed 64px icons. Sheet: `_src/sources/assets/ui/shop-icons/shop_icons.png`. | D | `--help` | N |
| `process_world_pass.py` | Key and install the Placeholdia / dungeon art pass stills | D | `--help` | N |
| `keytest.py` | Golden-set keying regression: truth mattes in `_src/truth` keyed again from a drifting JPEG plate (alpha error, area, edge, halo, interior detail, repeat); sheets in `_logs/keytest/`. Summary: `keytest`. | BD | `--help` | N |
| `keytest_expect.json` | Limits for `keytest.py` (`default` plus per-name overrides). | D | - | N |
| `rekey_preview.py` | Open-set rekey preview on blue (`_logs/rekey-look/`). Counts are the check. Does not write live assets. Summary: `rekey-preview`. | D | `--help` | N |
| `rekey_all_stills.py` | Rekey every manifest still from `_src`, placed like live (`--out DIR` for a review copy; without it overwrites live; `--check`: two runs byte-identical). Summary: `rekey-all-stills`. | D | `--help` | N |
| `rekey_check.py` | Full-set rekey check of a `--new DIR` against live and the plates: per-class counts, rows in `_logs/rekey-check/last.json`. Summary: `rekey-check`. | D | `--help` | N |
| `run_isolated_grok.py` | Stage a scratch directory outside the git tree and run a thin Grok Build media job: `--kind ui\|npc\|tile\|character\|still\|i2v --brief "..." --out DIR` (`--dest-name`, `--copy REF`, `--aspect`); `--selftest` mocks grok | D | `--help` | N |
| `sprite_pipeline.py` | Section 19 cleanup: Paint.NET-style outside wand + Color-to-Alpha lip + 128 fit (keying and fit in `imglib`) | D | `--help` | N |

### Image library `tools/imglib/` (shared; the Bot may read this section; rows marked Y run on the Bot)

Install: `pip install -r tools/requirements.txt` (Pillow, numpy, OpenCV; all required). New image logic goes in the library and the tools import it; per-asset key rules, banner and glyph drawing and the one-off `process_*` passes stay in their tools. The pack_* / process_* passes import these helpers (`imgio.load`, `geom.flip`, `scale_nearest`, `shrink`, `fit_box`, `fit_axis`); an adopted helper ships with a before/after pixel diff of 0. Proof recipes: `prove.md`.

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `requirements.txt` | Pip deps for the image tools | BWD | - | Y |
| `requirements-ml.txt` | Optional torch + einops for the `bible_normalize.py` denoise (`imglib/scunet.py`) | D | - | N |

| Module | Owns |
|---|---|
| `imglib/imgio.py` | `load` / `save`, numpy round trip, `MAGENTA`, `hex_of` (named `imgio`, not `io`, to keep stdlib names free) |
| `imglib/geom.py` | `bbox`, `crop`, `scale_nearest`, `shrink`, `flip`, `grid_split`, `fit_box` (square canvas), `fit_axis`, `fit_like`; `resize_rgba` (nearest up, one premultiplied box down), `shrink_art` (box edge band, exact interior), `alpha_policy` (soft / crisp / hard), `detect_grid` |
| `imglib/color.py` | Lab distance, hue, `background_refs`, `palette`, WCAG `contrast_ratio` |
| `imglib/key.py` | plate mask, `remap_plate` (every plate pixel exactly #FF00FF), border flood, pockets, `strip_rim`; `key_to_alpha` / `punch` call `matte` |
| `imglib/band.py` | edge band for `shrink_art`: 2 px, wider along a detected glow ramp |
| `imglib/overlay.py` | post-key pixel text (5x7 font); manifest `"overlay"` rows (the welcome banner) are drawn by `rekey_all_stills` every run, centred on the detected cloth |
| `imglib/matte.py` | the keyer: clean plate B(x), trimap, one alpha solve, decontaminate F = (I - (1-a)B)/a; `key(im, debug=DIR)` dumps each stage |
| `imglib/compare.py` | `delta_map`, `diff`, `heatmap`, `montage`, `checker` (behind `shot_diff.py` and the `run_shots.py` seam check) |
| `imglib/look.py` | the `img_inspect.py` checks as functions |
| `imglib/scunet.py` | Optional SCUNet denoiser (vendored cszn/SCUNet, Apache-2.0); weights downloaded to `_cache/models/` with pinned sha256; needs `requirements-ml.txt` |
