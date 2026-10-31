# Tools: shots, image checks and bakes

Status: protocol  
Read when: taking or comparing screenshots, checking an image, showing pictures to the User, or baking light, ground wear or frame art  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Proof recipes (what is enough): `prove.md`. Flow files: `shot-flows.md`. Shots and bakes need a display; the tools pick one.

Entries here: `shots.py`, `bake.py`; their code: `tools/lib/bake/`, `tools/lib/shots/`.

## Jobs

- **Shoot a job:** `shots.py flow --job door.job`. One flow `--flow NAME`, one state `--flow NAME --state S`; find flows with `--list` or `--survey`; asserts only, no display: `--no-pixels`.
- **Same as main:** fixed-seed flows on both checkouts with `shots.py flow --all --save-baseline DIR`, then `shots.py diff MAIN_DIR BRANCH_DIR --out OUT`. Same checkout before/after: `--save-baseline DIR` first, then `--baseline DIR`.
- **One image vs another:** `shots.py inspect diff A.png B.png --max-ratio 0.001 --out heat.png` (`--mask X,Y,W,H` hides live animation); side by side: `shots.py inspect montage A.png B.png --out OUT`.
- **Look closer:** `shots.py crop SHOT --box X,Y,W,H --zoom 4`; pixel values `--probe X,Y`; count a colour `--near HEX --tol 8` or dark pixels `--dark 40`. `shot_crop` is the quick crop and probe; `img_inspect` holds the named checks.
- **Screen checks:** `shots.py inspect layout SHOT` (clipped, off-screen, overlap, alignment), `shots.py inspect contrast SHOT --box X,Y,W,H` (WCAG), `shots.py inspect grid SHOT --out OUT` (coordinates).
- **Posed camera or the whole floor:** `shots.py capture --scene camp` (`hub`, `dungeon`, `title`, ...), `shots.py capture --full-map`.
- **UI state without a flow:** `shots.py gaps --changed`; add a small flow in `tools/data/shot-flows/`.
- **Show the User:** `shots.py show PATH=description ...` once per ask. A pair scales the larger frame down to the smaller one's size. A session looks with `shots.py review A.png --question "..."` (text report only; do not `read_file` the PNG). Turn budget is at least 8 and rises by 2 per image, cap 16, or `--max-turns` when that is higher. The shared gather does not run it. The forked session whose unit needs the frames does.
- **Bake:** `bake.py camp` (hub light and ground wear; `--overlay` draws the debug boxes), `bake.py ground` alone, `bake.py check` (stamps match the code), `bake.py frames` after frame-art code changes (`--check` only compares).
- **How-to-Play pictures:** `shots.py tutorial --run`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `shots.py flow` | Scripted shot flows (`tools/data/shot-flows/*.json`): `--job door.job` (every flow routes.yaml maps to the job, one call, one summary), `--flow A,B`, `--flow N --state S` (re-shoot one state), `--changed`, `--all`, `--smoke`; `--list` / `--survey` (one line per flow); `--sheet FLOW` tiles frames; `--no-pixels` steps and asserts only; `--save-baseline DIR` / `--baseline DIR` diff; `--publish` to `_out/shots/<flow>/` (never `assets/`); `--out DIR`. Summary: `shot-flow`. | BWD | `--help` | Y |
| `shots.py capture` | Posed-camera postcard, not a smoke: `--scene dungeon\|camp\|hub\|title\|splash\|fs_gate` (menu screens on an isolated save), `--recipe KEY` (`shot-recipes.json`), `--full-map` (whole floor in one PNG; `--overlays`), `--mode web\|build\|user`, `--out`; `--width` + `--height` is the PNG size (FAIL if the PNG differs; `--selftest` shoots 640x360 and checks). Summary: `shots`. | BWD | `--help` | Y |
| `shots.py movie` | Gameplay clip: a scenario from `tools/data/movies.json` (shot-flow header + setup steps, or a flow cut at a state), an input timeline (`walk_to`, `drive`, `tap`), recorded by Godot movie maker (`capture --movie`, `--fixed-fps`) and cut to an MP4 between the marks. `--list`, `--game DIR` (another checkout), `--refs A,B` (two refs, reel; `tools-media.md`), `--dry-run`, `--keep-raw`, `--selftest`. Flow: `tools-media.md`. Summary: `movie`. | D | `--help` | N |
| `shots.py textsize` | Text size on phone viewports: runs the flows in `tools/data/text-size.json` at each viewport x DPR (`--viewport`, `--flow`), prints the smallest CSS px per screen (`--compare OLD_DIR` adds was), `--gate` FAILs on text under the minimum or an in-play screen whose overlays cover more of the frame than its `cover` limit (HUD footprint) on gated viewports, `--from DIR` re-reads a run, `--selftest`. Summary: `textsize`. | BD | `--help` | Y |
| `shots.py diff` | Before/after diff of shot PNGs or folders: `BEFORE AFTER [--out DIR] [--mask X,Y,W,H] [--tol] [--max-ratio]`; changed pixels, bbox, `*.diff.png`. Summary: `shot-diff`. | BWD | `--help` | Y |
| `shots.py inspect` | Named image checks, text facts plus an optional PNG (`--out`): `describe`, `layout` (off-screen, clipped, overlap, safe area, alignment, gaps; `--box` per node rect), `contrast` (WCAG per `--box`), `grid`, `zoom`, `diff` (`--mask`, `--max-ratio`, heatmap), `montage`, `find`, `halo`, `rimclean --refs`, `motion`, `selftest`. Library: `tools/lib/imglib/`. | BWD | `--help` | N |
| `shots.py crop` | Quick pixel look at one shot: `PNG --box X,Y,W,H [--zoom N] [--out P]` crops and enlarges (default under `_logs/shot-crop/`); `--probe X,Y ...` prints RGBA and hex; `--near HEX [--tol N]` / `--dark N` count pixels and print their bbox. Replaces one-off pixel scripts. `--selftest`. | D | `--help` | N |
| `shots.py gaps` | UI states with no shot flow, plus flow and published-shot problems. `--changed [REF]`: new since REF; required at the END for the Bot and for a Build UI or theme prove (`routes.yaml` `shot_gaps`; `gate.py build --batch` runs it), `--advisory` mid-slice. Summary: `shot-gaps`. | BWD | `--help` | Y |
| `shots.py show` | Show pictures to the User: `[--ask NAME] [--group AREA] PATH[=one-line description] ...` stages them into one prove folder, opens the first on Windows and prints `path - description` lines (`--no-open` only prints). Once per ask, after you looked at them; also prints this session's `Did not work:` lines. `--selftest`. | D | `--help` | N |
| `shots.py review` | Second opinion on shots from an isolated Grok session: `PNG ... --question "..." [--rubric TEXT\|@FILE]`; prints the text report and `VERDICT`; RESULT FAIL when isolation cannot run (never a placeholder). Turn budget is at least 8 and rises by 2 per image (cap 16), or `--max-turns` when higher. `--selftest` mocks grok. | BW | `--help` | Y |
| `shots.py tutorial` | How-to-Play screenshots: checks `tutorial_shots.json` (topic id to shot-flow frame); `--run` shoots those flows and stages `_out/tutorial/<id>.png` with a sha list for Build to copy to `assets/ui/tutorial/` (never writes under assets/). | BD | `--help` | Y |
| `bake.py camp` | Bake `hub_light.png` (and `ground_wear.png` through `bake.py ground`) via `--wdb-bake-camp` on a real renderer (auto display; prints `stamp=`; `shadow_px=0` FAILs). `--overlay [PNG]` outlines, from the Layout, the tarp lid (yellow), protected footprints (red), caster bounds (cyan), collision (magenta), lamp pools (orange) and spots (white); path in RESULT `overlay=`. Never rewrites `camp.tscn`. Summary: `bake-camp`. | BD | `--help` | Y |
| `bake.py ground` | Bake the tileable ground wear sheet `ground_wear.png` (domain-warped noise, `--steps` 12, `--px-per-m` 32, 32 m tile; same bytes each run; prints `stamp=` for `GROUND_WEAR_STAMP`). Also run by `bake.py camp`. Summary: `ground-wear`. | BD | `--help` | Y |
| `bake.py frames` | Bake the object-frame art (`progress_ui/*_art.gd` and each `dress()` button look) to `assets/ui/frames/<art>/<key>.png` and verify; `--check` compares code drawing with the committed PNGs (FAIL on stale), `--time` times the skin builds. Re-run after editing art code. | BD | `--help` | Y |

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `data/shot-recipes.json` | Camera recipes for `shots.py capture --recipe KEY`. |
| `data/text-size.json` | `shots.py textsize` viewports, flows, minimum, `allow`, `cover` |
| `data/tutorial_shots.json` | Topic id to `{flow, shot}` map and dest, read by `shots.py tutorial` |
