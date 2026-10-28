# Tools: media and art pipeline

Status: protocol  
Read when: running a still/I2V/pack/sprite/audio tool (Build / User only)  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Flows live in the `art-*.md` docs and the Imagine / I2V skills. The Bot reads only the image library section.

Entries here: `media.py`; their code: `tools/lib/media/`.

## Jobs

- **Imagine a still:** `media.py grok --kind ui --brief "..." --out DIR` (flow: the isolated-media gate).
- **Rekey stills:** `media.py rekey --only assets/...png` (live), `--out DIR` (review copy), `--check`; look first with `media.py rekey-preview --only ...`; full-set check `media.py rekey-check --new DIR`.
- **Animation review briefs:** `media.py anim-review pack`, `media.py anim-review regen`, `media.py anim-review tree --out DIR`.
- **Bible prompts and sheets:** `media.py bible-prompt --gender female` / `--enemy ID`; `media.py bible-normalize`.
- **Sound effects:** `media.py sfx --list`, `media.py sfx --only CUE`, `media.py sfx --check`.

### Media / art pipeline (Build only)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `media.py anim-review` | Animation Browser review briefs: `pack` (Repack notes + Good locomotion clips), `regen` (Regenerate notes + current I2V prompt), `tree --out DIR` (wiped I2V test tree). Summary: `anim-review` | D | `--help` | N |
| `media.py attack-keys` | Beat-by-beat unarmed attack stills from a locked Bible cell | D | `--help` | N |
| `media.py clip` | Thin ffmpeg wrapper: `info`, `trim --start --end`, `join A B ... --fade S [--transition T]` (xfade), `caption --text [--start --end --pos]` or `--cue S,E,TEXT` (repeat), `sbs BEFORE AFTER [--labels --stack v]`, `crop`/`zoom`/`fit`, `wipe`, `pip`, `mark`, `ba` (Edit below), `export --for x\|gif [--size --fill]` (checks the X limits); default out `_logs/clip/`. `--selftest` on synthetic clips. Summary: `clip`. | D | `--help` | N |
| `media.py bible-normalize` | Squared 3×3 Bible to live lock sheet: plate remap, SCUNet denoise at 2x (`--no-denoise` skips), full bodies to shared height with `--margin` plate, bust keeps crop, 4x4 trimmed-mean rebuild to `--cell`; prints a per-cell scale/bbox table and edge/width flags (`art-bible-character.md`) | D | `--help` | N |
| `media.py bible-prompt` | Bible Imagine text: `--gender` player, `--enemy ID` enemy (prop, hand and idle-pose table lives in the tool). Print and copy | D | `--help` | N |
| `media.py glyphs` | Chunky pixel prompt glyphs. Run from repo root | D | `--help` | N |
| `media.py i2v-seeds` | I2V plates: splice or single cell, exact integer nearest-neighbor scale, leave chroma (`--out DIR`) | D | `--help` | N |
| `media.py sfx` | Placeholder SFX wavs from `tools/data/sfx-cues.json` (one entry per cue; sine, noise, mix, cat nodes). `--list`, `--only`, `--prefix`, `--dry-run`, `--check` (render to temp and compare with `assets/audio`; the 21 p2/p9 cues are byte-identical). A new cue is one JSON entry, not a new script | D | `--help` | N |
| `media.py keyed-region` | Match a keyed source region against a live sprite, and sort local sources (also the matcher library for the rekey tools) | D | `--help` | N |
| `media.py pack-loco` | Pack idle stills + idle_to_walk / walk / walk_to_idle from I2V clips | D | `--help` | N |
| `media.py pack-oneshot` | Pack one-shot I2V clips into engine frames | D | `--help` | N |
| `media.py pack-turntable` | Pack 8-dir player sheets from turntable + facing clips, shared scale and torso pin | D | `--help` | N |
| `media.py plate-remap` | Remap a generated chroma plate to exact #FF00FF. Solid plate near a border reference only; a farther mix keeps its drawn RGB (`imglib.key.remap_plate`; `--tol`) | D | `--help` | N |
| `media.py gear-icons` | Key `_src/sources/assets/ui/gear` plates into `assets/ui/gear`. `--check` fails if an expected icon has no plate or live png. The batch gate runs `--check`. | D | `--help` | N |
| `media.py shop-icons` | Slice the ghost-shop Imagine sheet into gear source plates and keyed 64px icons. Sheet: `_src/sources/assets/ui/shop-icons/shop_icons.png`. | D | `--help` | N |
| `media.py world` | Key and install the Placeholdia / dungeon art pass stills | D | `--help` | N |
| `media.py keytest` | Golden-set keying regression: truth mattes in `_src/truth` keyed again from a drifting JPEG plate (alpha error, area, edge, halo, interior detail, repeat); sheets in `_logs/keytest/`. Summary: `keytest`. | BD | `--help` | N |
| `media.py rekey-preview` | Open-set rekey preview on blue (`_logs/rekey-look/`). Counts are the check. Does not write live assets. Summary: `rekey-preview`. | D | `--help` | N |
| `media.py rekey` | Rekey every manifest still from `_src`, placed like live (`--out DIR` for a review copy; without it overwrites live; `--check`: two runs byte-identical). Summary: `rekey-all-stills`. | D | `--help` | N |
| `media.py rekey-check` | Full-set rekey check of a `--new DIR` against live and the plates: per-class counts, rows in `_logs/rekey-check/last.json`. Summary: `rekey-check`. | D | `--help` | N |
| `media.py grok` | Stage a scratch directory outside the git tree and run a thin Grok Build media job: `--kind ui\|npc\|tile\|character\|still\|i2v --brief "..." --out DIR` (`--dest-name`, `--copy REF`, `--aspect`, `--edit` with one `--copy` calls `image_edit` on that file and ignores `--aspect`); `--selftest` mocks grok | D | `--help` | N |
| `media.py sprites` | Section 19 cleanup: Paint.NET-style outside wand + Color-to-Alpha lip + 128 fit (keying and fit in `imglib`) | D | `--help` | N |

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

Desktop, frame-exact: `shots.py movie NAME` boots one shot flow with Godot movie maker (frames scaled to the movie size) and keeps the frames between the timeline's `start` / `end` marks as H.264. A scenario reuses shot-flow state (`{flow, state}`); game code adds no hooks. Timeline ops: `walk_to`, `drive`, `tap`, `camera` (`shot-flows.md`). A movie's `regions` names crop boxes (fractions of the frame) for `clip crop --box NAME --movie NAME`. One movie against another checkout: `--game DIR`.

Web, real time: `perf.py web --flow camp-walk --video DIR` (Playwright WebM from page open, boot included; cut with `media.py clip trim`).

Edit: `media.py clip sbs` then `caption`, then `export --for x` (FAIL over 140 s or 512 MB) or `--for gif` (FAIL over 15 MB). Clips stay in `_logs/` or outside the repo; never commit video.

Framing and overlays (`lib/media/clip_fx.py`; flags: `media.py clip --help`): `--box` is pixels, fractions, or a movie region; `crop`, `zoom` (Ken Burns), `fit`, `join --transition` (any xfade name), `wipe` (reveal line), `pip`, `mark` (box plus arrow).

Before/after recipe: `clip ba BEFORE AFTER` finds the changed area; a small one (at most 35% of the frame) is zoomed in and slider-wiped, a subtle one (mean difference at most 24 levels) is wiped however wide, only a strong wide change gets `sbs`. `--layout` or `--box` overrides; it prints the pick. Then `export --for x` and `--for gif`.

## Ref compare and scenario catalog

`shots.py movie --refs A,B NAMES` (`lib/shots/movie_refs.py`): any two git refs. Per ref a temp worktree gets this checkout's recording tooling (shot tool, `shot_views.gd`, and missing deps with a fresh `.uid`; listed in `compare.json`), `gate.py import`, then every name is recorded and the pair diffed. Unchanged pairs print `no visible change` and stay out of the reel; each change gets a captioned `clip ba` segment. The out dir (default `_logs/movie/refs-A-B-NAMES/`, one per name list, so a subset rerun keeps the full run) holds `reel.mp4`, `reel-x.mp4`, `reel.gif`, `contact.png` (A | B | heat per change) and `compare.json`. About 1 to 3 min per name per ref plus the import. Every view still first calls `shot_views.gd` `still_hud` (pins wall-clock pulses such as the HUD danger gem).

The catalog lives in `data/movies.json`:
- `movies`: clips.
- `views`: stills. A view is a `{flow, state}`, a `scenario`, or `kind: full-map`: the stitched floor with `overlays` (`shots.py capture --full-map --overlays`, drawn by `lib/shots/map_overlay.py`).
- `sets`: named groups (`hub-ui`, `dungeon-gen`, `debug`).

`shots.py movie --list` prints them. Views normal play cannot show (overhead hub, fly-through, debug draw, drop roll) call `scripts/debug/shot_views.gd`.

Media bot (Bottie Boop): triggers, refs, commands and rules in `media-bot.md`. It picks from this catalog only.

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `lib/media/audio_lib.py` | Placeholder audio helpers (`write_wav`, `write_pcm`, `sine`, `noise`, `mix`, `mix_norm`) behind the `make_*` audio tools; WAV output byte-identical |
| `lib/media/clip_fx.py` | `media.py clip` framing, transitions and overlays (`crop`, `zoom`, `fit`, `wipe`, `pip`, `mark`, `change_box`, `ba`) on top of `clip_edit.py` |
| `lib/media/anim_review_lib.py` | Read helpers for the Animation Browser review tools, plus the shared pack/regen brief CLI and writer (`brief_args`, `load_with_missing`, `add_missing`, `write_brief`). Allowlisted but only supports non-Bot tools. |
| `data/attack_keyframes_log.json` | Sidecar data for the tool of the same stem |
| `data/movies.json` | `shots.py movie` scenarios, movies, views and sets (the scenario catalog) |
| `lib/shots/movie_refs.py` | `shots.py movie --refs`: worktrees, tooling injection, record, diff, reel, contact sheet |
| `lib/shots/map_overlay.py` | `--full-map --overlays`: room/spawn/torch/loot marks on the stitched floor |
| `data/sfx-cues.json` | Cue specs read by `media.py sfx` (name, scale, graph) |
| `data/keytest_expect.json` | Limits for `media.py keytest` (`default` plus per-name overrides). |
| `requirements.txt` | Pip deps for the image tools |
| `requirements-ml.txt` | Optional torch + einops for the `media.py bible-normalize` denoise (`imglib/scunet.py`) |
