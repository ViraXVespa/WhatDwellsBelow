# Tools: shots, image checks and bakes

Status: protocol  
Read when: taking or comparing screenshots, checking an image, showing pictures to the User, or baking light, ground wear or frame art  

Use the prove standard for evidence, the flow guide for setup and `--help` for flags. Runners select the display; the tools door defines surface permissions.

## Jobs

- **Shoot a job:** `shots.py flow --job door.job`. One flow `--flow NAME`, one state `--flow NAME --state S`; find flows with `--list` or `--survey`; asserts only, no display: `--no-pixels`.
- **Same as main:** fixed-seed flows on both checkouts with `shots.py flow --all --save-baseline DIR`, then `shots.py diff MAIN_DIR BRANCH_DIR --out OUT`. Same checkout before/after: `--save-baseline DIR` first, then `--baseline DIR`.
- **One image vs another:** `shots.py inspect diff A.png B.png --max-ratio 0.001 --out heat.png` (`--mask X,Y,W,H` hides live animation); side by side: `shots.py inspect montage A.png B.png --out OUT`.
- **Look closer:** `shots.py crop SHOT --box X,Y,W,H --zoom 4`; pixel values `--probe X,Y`; count a colour `--near HEX --tol 8` or dark pixels `--dark 40`. Row widths: `shots.py crop SHOT --spans [--step N] [--bg HEX] [--fg HEX]` prints the figure box and connected foreground runs, each with its centre colour. A translucent reference on a still: `shots.py crop MODEL --overlay REF --scale S --anchor-ref X,Y --anchor-model X,Y [--opacity A] [--flip-x]` (nearest scale, anchor landed on the model, edge runs printed). `shot_crop` is the quick crop and probe; `img_inspect` holds the named checks. For text-reading questions, run `shots.py ocr SHOT --box X,Y,W,H --expect "label"` (local Tesseract) first. Shape/colour review needs no OCR.
- **Review size:** view the downsized shot by default; zoom only when a detail needs it: `shots.py zoom SHOT --box X,Y,W,H` (coords of the shot as viewed) reads the kept full-size original in `<shot dir>/full/`.
- **Review detail:** isolated review accepts pixel/normalized ZOOM requests, maps them outward to full-size coordinates and resumes with crops. Maximum 3 rounds and 4 crops/round; malformed requests or no final verdict fail. Implementation: `review_rounds.py`.

- **Screen checks:** `shots.py inspect layout SHOT` (clipped, off-screen, overlap, alignment), `shots.py inspect contrast SHOT --box X,Y,W,H` (WCAG), `shots.py inspect grid SHOT --out OUT` (coordinates).
- **Posed camera or the whole floor:** `shots.py capture --scene camp` (`hub`, `dungeon`, `title`, ...), `shots.py capture --full-map`.
- **UI state without a flow:** `shots.py gaps --changed`; add a small flow in `tools/data/shot-flows/`.
- **Review/show:** `shots.py review A.png --question "..."` returns an isolated assessment. `shots.py show PATH=description ...` presents the comparison to the User. Direct visual references require the scoped grant; review only the current unit.

- **Bake:** `bake.py camp` (hub light and ground wear; `--overlay` draws the debug boxes), `bake.py ground` alone, `bake.py soles` (actor sole table from sprites and fx; `bake.py check` fails when a png or the scan scripts changed), `bake.py check` (stamps match the code), `bake.py frames` after frame-art code changes (`--check` only compares).
- **How-to-Play pictures:** `shots.py tutorial --run`.
- **Aim line:** off in every shot, flow, movie and ref compare (`--wdb-shot-aim=0`, this run only; the save keeps its setting). Opt in with `--aim-line` on `shots.py capture`/`flow`, or `"aim_line": true` in a flow.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `shots.py flow` | Capture named job flows, one flow/state, or assertion-only coverage. Supports baseline comparison and publishing; setup/state specs are in the flow guide. Summary: `shot-flow`. | BWD | `--help` | Y |
| `shots.py capture` | Capture a posed camera or full floor; choose scene, recipe, viewport and mode. Viewport mismatch fails. Summary: `shots`. | BWD | `--help` | Y |
| `shots.py movie` | Record a scenario/timeline through Godot movie maker; `--game` compares another checkout and `--refs` compares two refs. Media catalog owns the recipes. Summary: `movie`. | D | `--help` | N |
| `shots.py textsize` | Check CSS text size and in-play overlay coverage at configured viewport/DPRs. `--from` rechecks an existing run; `--gate` enforces limits. Summary: `textsize`. | BD | `--help` | Y |
| `shots.py diff` | Compare two PNGs or folders, with masks/tolerance; report changed pixels/bounds and write heatmaps. Summary: `shot-diff`. | BWD | `--help` | Y |
| `shots.py inspect` | Named image checks: layout, contrast, grid, zoom, diff, montage, template find, halo, rim cleanup and motion. Shared implementation: `lib/imglib/`. | BWD | `--help` | N |
| `shots.py crop` | Crop/enlarge an exact box, probe pixel values or count a colour/dark region. No one-off pixel script needed. `--selftest`. | D | `--help` | N |
| `shots.py ocr` | Local Tesseract text evidence: words/confidence, x-height, contrast and `READ ok/weak/fail`. Expected-text mismatch can fail. Content-bound attempt receipts expire after 30 minutes; no engine gives SKIP. Summary: `ocr`. | BWD | `--help` | N |
| `shots.py zoom` | Use the kept full-size source for a box/centre/normalized crop or labeled montage. Coordinates may be supplied-image or full-source pixels. Nearest-neighbour enlargement; `--selftest`. | D | `--help` | N |
| `shots.py gaps` | Find new uncovered UI states, missing/stale flow shots and altered published files. `--changed` is required in final visual verification. Summary: `shot-gaps`. | BWD | `--help` | Y |
| `shots.py show` | Stage one comparison sheet per area and open the first for the User. Paths carry descriptions; `--no-open` stages only. Also prints failed steps since the last ask. `--selftest`. | D | `--help` | N |
| `shots.py review` | Isolated visual assessment, returning text/VERDICT. Text questions attempt OCR first; `--why` records a separate text exception. Full sources/local helpers and bounded zoom rounds are staged. Failure is never a placeholder. `--selftest` uses fake Grok plus real local helpers/hooks. | BW | `--help` | Y |
| `shots.py tutorial` | Capture/publish configured How-to-Play frames with a hash manifest. Does not write live assets. | BD | `--help` | Y |
| `bake.py camp` | Bake hub light and ground wear on a real renderer. Empty shadows fail; `--overlay` draws diagnostic bounds. Never rewrites the scene. Summary: `bake-camp`. | BD | `--help` | Y |
| `bake.py ground` | Deterministic tileable ground-wear sheet; prints its stamp. Also called by camp bake. Summary: `ground-wear`. | BD | `--help` | Y |
| `bake.py soles` | Scan actor sprite/fx PNGs into the sole table and stamp. A changed source requires a new bake; this is not a stamp-edit command. Summary: `bake-soles`. | BD | `--help` | Y |
| `bake.py frames` | Bake code-drawn UI/button art. `--check` detects stale PNGs; `--time` measures builds. | BD | `--help` | Y |

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `data/shot-recipes.json` | Camera recipes for `shots.py capture --recipe KEY`. |
| `data/text-size.json` | `shots.py textsize` viewports, flows, minimum, `allow`, `cover` |
| `data/tutorial_shots.json` | Topic id to `{flow, shot}` map and dest, read by `shots.py tutorial` |

## Isolated review implementation

Portable OCR: `lib/shots/ocr_core.py`; content-bound attempt receipts: `lib/shots/ocr_evidence.py`. `lib/shots/review_bundle.py` stages these, the existing image package and available originals. Internal CLI `lib/shots/review_local.py` provides OCR/crop/zoom/diff; outputs stay under `out/`. Tool-owned entry `lib/shots/review_hook.py` and screenshot-only staged hook `lib/shots/review_policy.py` limits shell execution and gates explicit text reviews, not ordinary visual reads. No host permissions change. Tests: `lib/shots/review_bundle_test.py` via review selftest. Media staging keeps existing generation permissions.

The repository hook separately controls direct image access; the User-approved task/session grant is documented in the Build reference guide. The isolated reviewer's OCR gate remains independent: text questions attempt Tesseract and need fresh content-bound evidence. Neither mechanism changes host permissions.
