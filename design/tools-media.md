# Tools: media and art pipeline

Status: protocol  
Read when: running a still/I2V/pack/sprite/audio tool (Build / User only)  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Flows live in the `art-*.md` docs and the Imagine / I2V skills. The Bot reads only the image library section.

Entries here: `media.py`; their code: `tools/lib/media/`.

## Jobs

- **Imagine a still:** `media.py grok --kind ui --brief "..." --out DIR` (flow: the isolated-media gate).
- **Rekey stills:** `media.py rekey --only assets/...png` (live), `--out DIR` (review copy), `--check`; look first with `media.py rekey-preview --only ...`; full-set check `media.py rekey-check --new DIR`.
- **Read-only modeling references:** `slice.py references export` uses the existing layout/image library and retains native provenance. It does not run Imagine/I2V or Blender.
- **Sound effects:** `media.py sfx --list`, `media.py sfx --only CUE`, `media.py sfx --check`.

### Media / art pipeline (Build only)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `media.py anim-review` | Build pack/regen briefs or a fresh test tree from the Animation Browser ledger. Summary: `anim-review`. | D | `--help` | N |
| `media.py attack-keys` | Make beat-by-beat unarmed attack reference stills from a locked Bible cell. | D | `--help` | N |
| `media.py clip` | ffmpeg editing/composition: inspect, trim, join, caption, compare, frame and export clips. Recipes below; `--selftest` uses synthetic media. Summary: `clip`. | D | `--help` | N |
| `media.py bible-normalize` | Normalize a 3x3 sheet with shared body height, optional SCUNet denoise and trimmed-mean rebuild. Reports cell scales/bounds and edge flags; character Bible spec owns the method. | D | `--help` | N |
| `media.py bible-prompt` | Print/copy the player or enemy Bible prompt from the current facing/prop/pose tables. | D | `--help` | N |
| `media.py glyphs` | Generate the approved pixel input-prompt glyphs. | D | `--help` | N |
| `media.py i2v-seeds` | Prepare seed plates/cells with integer nearest scaling and opaque chroma. This is not the Blender reference workflow. | D | `--help` | N |
| `media.py sfx` | Render configured placeholder cues or compare them with live WAVs; deterministic helpers own the synthesis. Summary: `sfx`. | D | `--help` | N |
| `media.py keyed-region` | Match keyed source/live regions; shared matching library for rekey tools. | D | `--help` | N |
| `media.py pack-loco` | Pack idle, transition and walk frames from accepted I2V clips. | D | `--help` | N |
| `media.py pack-oneshot` | Pack accepted one-shot clips into engine frames. | D | `--help` | N |
| `media.py pack-turntable` | Pack eight-facing player sheets with shared scale and torso pin. | D | `--help` | N |
| `media.py plate-remap` | Remap only the outside opaque plate to exact magenta; preserve drawn RGB farther from the border reference. | D | `--help` | N |
| `media.py gear-icons` | Key approved gear source plates into live icons; `--check` fails missing expected sources/outputs. | D | `--help` | N |
| `media.py shop-icons` | Slice/key the approved shop-icon sheet into source plates and 64px icons. | D | `--help` | N |
| `media.py world` | Key/install the approved hub/dungeon still-art pass. | D | `--help` | N |
| `media.py keytest` | Golden-set keying regression, including matte error, edge/halo/interior and repeatability. Summary: `keytest`. | BD | `--help` | N |
| `media.py rekey-preview` | Review-copy still keying on blue; optional pixelation previews. Counts are evidence; never writes live assets. Summary: `rekey-preview`. | D | `--help` | N |
| `media.py rekey` | Key manifest stills from source into live or an explicit review output. Check mode verifies repeatability. Summary: `rekey-all-stills`. | D | `--help` | N |
| `media.py rekey-check` | Compare a full new still set with live/source plates and report per-class counts. Summary: `rekey-check`. | D | `--help` | N |
| `media.py grok` | Stage an isolated media child by kind. Flags/permissions are defined by the runner and isolated-media guide; `--selftest` mocks Grok. | D | `--help` | N |
| `media.py sprites` | Existing sprite cleanup, keying and fitting pipeline; image operations remain in imglib. | D | `--help` | N |

### Image library `tools/lib/imglib/` (shared; the Bot may read this section; rows marked Y run on the Bot)

Install: `pip install -r tools/requirements.txt` (Pillow, numpy, OpenCV; all required). New image logic goes in the library and the tools import it; per-asset key rules, banner and glyph drawing and the one-off `process_*` passes stay in their tools. The pack_* / process_* passes import these helpers (`imgio.load`, `geom.flip`, `scale_nearest`, `shrink`, `fit_box`, `fit_axis`); an adopted helper ships with a before/after pixel diff of 0. Proof recipes: `prove.md`.

| Module | Owns |
|---|---|
| `imglib/imgio.py` | `load` / `save`, numpy round trip, `MAGENTA`, `hex_of` (named `imgio`, not `io`, to keep stdlib names free) |
| `imglib/geom.py` | `bbox`, `crop`, `scale_nearest`, `shrink`, `flip`, `grid_split`, `fit_box` (square canvas), `fit_axis`, `fit_like`; `resize_rgba` (nearest up, one premultiplied box down), `shrink_art` (box edge band, exact interior), `alpha_policy` (soft / crisp / hard), `detect_grid` |
| `imglib/color.py` | Lab distance, hue, `background_refs`, `palette`, WCAG `contrast_ratio` |
| `imglib/key.py` | plate mask, `remap_plate` (every plate pixel exactly #FF00FF), border flood, pockets, `strip_rim`; `key_to_alpha` / `punch` call `matte` |
| `imglib/band.py` | edge band for `shrink_art`: 2 px, wider along a detected glow ramp |
| `imglib/overlay.py` | post-key pixel text (5x7 font); manifest `"overlay"` rows (the welcome banner) are drawn by `rekey_all_stills` every run, centred on the detected cloth |
| `imglib/matte.py` | the keyer: clean plate B(x), trimap, one alpha solve, decontaminate F = (I - (1-a)B)/a; `key(im, debug=DIR)` dumps each stage |
| `imglib/compare.py` | `delta_map`, `diff`, `heatmap`, `montage`, `checker` (behind `shots.py diff` and the `shots.py capture` seam check) |
| `imglib/look.py` | the `shots.py inspect` checks as functions |
| `imglib/scunet.py` | Optional SCUNet denoiser (vendored cszn/SCUNet, Apache-2.0); weights downloaded to `_cache/models/` with pinned sha256; needs `requirements-ml.txt` |

## Gameplay clips

Recording, reference comparisons, framing and export recipes are in the clip guide. The command remains `media.py clip`; movie names/sets remain in the scenario catalog.

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `lib/media/audio_lib.py` | Shared deterministic WAV/synthesis helpers behind the audio tools |
| `lib/media/clip_fx.py` | Clip framing/effects; compose/tracking/promo modules own specs and overlays. The clip guide describes supported recipes. |
| `lib/media/anim_review_lib.py` | Shared Animation Browser ledger/brief readers and writers; supports non-Bot commands |
| `data/attack_keyframes_log.json` | Sidecar data for the tool of the same stem |
| `data/movies.json` | `shots.py movie` scenarios, movies, views and sets (the scenario catalog) |
| `lib/shots/movie_refs.py` | `shots.py movie --refs`: worktrees, tooling injection, record, diff, reel, contact sheet |
| `lib/shots/map_overlay.py` | `--full-map --overlays`: room/spawn/torch/loot marks on the stitched floor |
| `data/sfx-cues.json` | Cue specs read by `media.py sfx` (name, scale, graph) |
| `data/keytest_expect.json` | Limits for `media.py keytest` (`default` plus per-name overrides). |
| `requirements.txt` | Pip deps for the image tools |
| `requirements-ml.txt` | Optional torch + einops for the `media.py bible-normalize` denoise (`imglib/scunet.py`) |
| `lib/media/clip_compose.py`, `lib/media/clip_promo.py`, `lib/media/clip_track.py` | Composition specs, promotional overlays and stable callout tracking |
