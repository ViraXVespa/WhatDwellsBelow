# Tools: media and art pipeline

Status: protocol  
Read when: running a still/I2V/pack/sprite/audio tool (Build / User only)  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. New art flows live on the content pipeline door. Imagine and I2V stay closed for new game art. The Bot reads only the image library section.

Entries here: `media.py`; their code: `tools/lib/media/`.

## Jobs

- **Imagine a still:** `media.py grok --kind ui --brief "..." --out DIR` (flow: the isolated-media gate).
- **Local Comfy character:** Closed for new character art. Stop the Comfy server if it is running, then `media.py comfy-character setup`. That installs the pose page (`WDB Character`, Klein RefControl) and the style page (`WDB Style lock`, SDXL IP-Adapter), writes one depth per bible cell, and extracts the female walk clips. `--name male` extracts the other reel. The review panel shows the female clips. Start the inner ComfyUI `.venv` python `main.py --listen 127.0.0.1 --port 8188` with the shared input directory, output directory, and the shared model path file wdb-model-paths.yaml beside the Comfy install (that file is not in this repo). Comfy Desktop stays closed while that server holds the port. Open both workflows from the workflow list. Gitignored outputs: `_src/comfy-character/depth/`, `walk-reel/`, `walk-test/`, `walk-good/`, `frames/`, and `lora-set/`. `setup` rebuilds the depths and the reel. `_src/comfy-character/.gdignore` keeps Godot out of that folder. Approve or Deny writes `_src/comfy-character/ledger.json`. Good and Bad marks write `_src/comfy-character/walk-picks.json`. Those two stay in git. On the pose page: Review the walk clips, mark Good or Bad, Build the walk test, set Her picture to that facing, then Queue the walk folder. The face cell has no clip. One facing per build. Save knobs writes the open graph into `tools/data/comfy-workflows/`. This does not replace `media.py grok`. Also `status`, `review`, `export-set`, `depth`, `walk-reel`, `walk-build`. Node source `tools/data/comfy_wdb_character/`. Workflows `tools/data/comfy-character-workflow.json` and `tools/data/comfy-workflows/`.
- **Rekey stills:** `media.py rekey --only assets/...png` (live), `--out DIR` (review copy), `--check`; look first with `media.py rekey-preview --only ...`; full-set check `media.py rekey-check --new DIR`.
- **Read-only modeling references:** `slice.py references export` uses the existing layout/image library and retains native provenance. It does not run Imagine/I2V or Blender.
- **Sound effects:** `media.py sfx --list`, `media.py sfx --only CUE`, `media.py sfx --check`.

### Media / art pipeline (Build only)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `media.py anim-review` | Build pack/regen briefs or a fresh test tree from the Animation Browser ledger. Summary: `anim-review`. | D | `--help` | N |
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
| `media.py pipeline` | WIP and export store for the art pipeline. `check` round-trips a temp repo and does not touch the real WIP. `tune` reviews and regenerates a locked still until the checklist passes or `--turns` (default 4) is hit, then writes a progress report with the in-between images. `mesh` fails a coarse glb that has an empty height band. `body` builds a Hunyuan3D surface-net mesh from the passing text-only front still and retries one smaller octree if the blueprint does not fit. A fragmented mesh stops. `smooth` tunes four text-only T-pose stills, then builds the body from the front if they pass. Idle is a later animation. `edit ID --text TEXT` draws that change on one Qwen whole-body still, then Hi3D v1.0 refines a copy of the kept mesh into a new glb. The kept body file stays. The chain is 512, then 1024, then 1536. A fit failure retries 512 alone. A failed mesh is not presented. `proportion ID` measures a still or a glb against the measures that subject lists. Head, thigh, calf, and ears are body measures. Aspect is a general one. The numbers live on the subject. A missing list fails. When ears are the only miss, those lobes are clipped back to the skull curve and measured again. A vision pass does not override it. When review or tune is given the still workflow, Qwen3-VL also checks that prompt: each positive sentence must be visible, and each comma-separated negative tag must be absent. Those clauses are whatever that workflow sent. The asks go out four at a time. A miss is restated and regenerated by tune. Summary: `pipeline`. | D | `--help` | N |
| `media.py plate-remap` | Remap only the outside opaque plate to exact magenta; preserve drawn RGB farther from the border reference. | D | `--help` | N |
| `media.py gear-icons` | Key approved gear source plates into live icons; `--check` fails missing expected sources/outputs. | D | `--help` | N |
| `media.py shop-icons` | Slice/key the approved shop-icon sheet into source plates and 64px icons. | D | `--help` | N |
| `media.py world` | Key/install the approved hub/dungeon still-art pass. | D | `--help` | N |
| `media.py keytest` | Golden-set keying regression, including matte error, edge/halo/interior and repeatability. Summary: `keytest`. | BD | `--help` | N |
| `media.py rekey-preview` | Review-copy still keying on blue; optional pixelation previews. Counts are evidence; never writes live assets. Summary: `rekey-preview`. | D | `--help` | N |
| `media.py rekey` | Key manifest stills from source into live or an explicit review output. Check mode verifies repeatability. Summary: `rekey-all-stills`. | D | `--help` | N |
| `media.py rekey-check` | Compare a full new still set with live/source plates and report per-class counts. Summary: `rekey-check`. | D | `--help` | N |
| `media.py grok` | Stage an isolated media child by kind. Flags/permissions are defined by the runner and isolated-media guide; `--selftest` mocks Grok. | D | `--help` | N |
| `media.py comfy-character` | Set up the local Comfy pose page and bible style-lock page. `setup` rebuilds the gitignored cell depths and walk reel. Record Approve or Deny, and mark walk-clip frames Good or Bad before a walk test. This does not replace `media.py grok`. Summary: `comfy-character`. | D | `--help` | N |
| `media.py studio` | Pipeline studio on port 8189 for a phone on the LAN. `WDB_PIPELINE_SIMULATE=1` fakes every long job in `data/pipeline/wip/_sim`. `--selftest` runs both modes on a temp repo. `--gaps [--check]` writes the Build gap list. Summary: `studio`. | D | `--help` | N |
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
| `lib/media/__init__.py` | Media package marker. Subcommands stay modules run by `media.py`. |
| `lib/media/pipeline/__init__.py` | Pipeline store package. |
| `lib/media/pipeline/store.py` | WIP and export JSON for `media.py pipeline`. WIP stays gitignored. |
| `lib/media/pipeline/vision_review.py` | Qwen3-VL pass/fail checklists. The sent prompt is checked four clauses at a time. The review context is 65536. The reply cap is 16384. A miss becomes the next prompt correction. |
| `lib/media/pipeline/tune.py` | Turn-limited review, correct, and regenerate loop. Each turn reviews the prompt that turn sent. The limit writes the in-between images. |
| `lib/media/pipeline/mesh_check.py` | Read a glb. An empty height band fails. A fragmented mesh fails. A pass is not a look approval. |
| `lib/media/pipeline/body.py` | Hunyuan3D surface-net body from the passing text-only front still. The 32-grid path and four-view conditioning are not used. |
| `lib/media/pipeline/smooth.py` | Text-only T-pose mannequin stills. The pose is shared. The body shape comes from the subject. Idle is a later animation. The standing pixel plates are not copied. |
| `lib/media/pipeline/edit.py` | One text change on a whole-body still, then a Hi3D refine of a copy of the kept mesh. The source glb stays. |
| `lib/media/pipeline/proportion.py` | Measure a silhouette against the measures that subject lists. Head, thigh, calf, and ears are body measures. Aspect is a general one. The numbers live on the subject. A pass is not a look approval. |
| `lib/media/pipeline/comfy_run.py` | Queue one local Comfy workflow and fetch its saved image. |
| `lib/media/mobile_ui_server.py` | HTTP server on port 8189. Serves the studio, the old page at `/legacy/`, and the Comfy proxy. |
| `lib/media/mobile_ui/` | Studio page (`index.html`, `studio.css`, `js/`). `legacy/` is the old character page. |
| `lib/media/studio_cmd.py` | `media.py studio`: serve, `--selftest`, or `--gaps`. |
| `lib/media/studio/__init__.py`, `lib/media/studio/api.py`, `lib/media/studio/jobs.py` | Studio routes and the job registry that survives a page reload. |
| `lib/media/studio/backend.py` | Real mode: the store and `media.py pipeline` jobs. Seams Build has not wired answer 501. |
| `lib/media/studio/registry.py` | Source of truth for every type's steps, fields and actions, the model setups behind them, and what is wired. |
| `lib/media/studio/steps.py` | Step plan per type, actions per step, and step status. |
| `lib/media/studio/selftest.py` | `studio --selftest`: real-mode gates and every type walked to export in simulate. |
| `lib/media/studio/gaps.py` | Writes the Build gap list from the registry (`studio --gaps`). |
| `lib/media/studio/sim.py`, `lib/media/studio/fakes.py` | Simulate mode: canned staged jobs and placeholder stills and glbs. |
| `lib/media/pipeline/plates.py` | Frame a keyed mannequin view on a black square. The figure's long side is 1/1.1 of the canvas. Specks outside the main mass are dropped. |
| `lib/media/clip_fx.py` | Clip framing/effects; compose/tracking/promo modules own specs and overlays. The clip guide describes supported recipes. |
| `lib/media/anim_review_lib.py` | Shared Animation Browser ledger/brief readers and writers; supports non-Bot commands |
| `data/movies.json` | `shots.py movie` scenarios, movies, views and sets (the scenario catalog) |
| `lib/shots/movie_refs.py` | `shots.py movie --refs`: worktrees, tooling injection, record, diff, reel, contact sheet |
| `lib/shots/map_overlay.py` | `--full-map --overlays`: room/spawn/torch/loot marks on the stitched floor |
| `data/sfx-cues.json` | Cue specs read by `media.py sfx` (name, scale, graph) |
| `data/keytest_expect.json` | Limits for `media.py keytest` (`default` plus per-name overrides). |
| `requirements.txt` | Pip deps for the image tools |
| `requirements-ml.txt` | Optional torch + einops for the `media.py bible-normalize` denoise (`imglib/scunet.py`) |
| `lib/media/clip_compose.py`, `lib/media/clip_promo.py`, `lib/media/clip_track.py` | Composition specs, promotional overlays and stable callout tracking |
The old page is at `http://<lan-ip>:8189/legacy/`; the server starts with the Comfy server or with `media.py studio`. Written for a non-technical user. Good/Bad and Approve/Deny write the same `_src/comfy-character/walk-picks.json` and `ledger.json`. Comfy is reached through the UI proxy. Workflow is loaded from `tools/data/comfy-character-workflow.json`. Positive prompt uses node 5 and negative uses node 6 (matching api_graph), with title fallback. Form state persists. Cancel kills the process. Previews are cache-busted. Generate and Generate another append to the set (Generate another can force a new seed). Prompt is shown on the review screen with a copy button. Generate is disabled when the prompt is empty. Newest image auto-scrolls into view. Clear marks asks for confirmation. Undo clears a mark. Hideable session summary flyout. Status pill is tappable. Soft haptic on Good and Approve. More options open state is remembered. Start picture maker attempts a best-effort ComfyUI launch. Start a new one clears the prompt. Enter in the prompt field generates. Build walk test calls walk-build; Queue walk folder calls run with the exposed flags. New art does not use this page's generate button. The studio at `/` calls `python tools/media.py pipeline`.
