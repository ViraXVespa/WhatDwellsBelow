# Tools: shots, image checks and bakes

Status: protocol  
Read when: taking or comparing screenshots, checking an image, showing pictures to the User, or baking light, ground wear or frame art  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Proof recipes (what is enough): `prove.md`. Flow files: `shot-flows.md`. Shots and bakes need a display; the tools pick one.

## Jobs

- **Shoot a job:** `run_shot_flow.py --job door.job`. One flow `--flow NAME`, one state `--flow NAME --state S`; find flows with `--list` or `--survey`; asserts only, no display: `--no-pixels`.
- **Same as main:** fixed-seed flows on both checkouts with `run_shot_flow.py --all --save-baseline DIR`, then `shot_diff.py MAIN_DIR BRANCH_DIR --out OUT`. Same checkout before/after: `--save-baseline DIR` first, then `--baseline DIR`.
- **One image vs another:** `img_inspect.py diff A.png B.png --max-ratio 0.001 --out heat.png` (`--mask X,Y,W,H` hides live animation); side by side: `img_inspect.py montage A.png B.png --out OUT`.
- **Look closer:** `shot_crop.py SHOT --box X,Y,W,H --zoom 4`; pixel values `--probe X,Y`; count a colour `--near HEX --tol 8` or dark pixels `--dark 40`. `shot_crop` is the quick crop and probe; `img_inspect` holds the named checks.
- **Screen checks:** `img_inspect.py layout SHOT` (clipped, off-screen, overlap, alignment), `img_inspect.py contrast SHOT --box X,Y,W,H` (WCAG), `img_inspect.py grid SHOT --out OUT` (coordinates).
- **Posed camera or the whole floor:** `run_shots.py --scene camp` (`hub`, `dungeon`, `title`, ...), `run_shots.py --full-map`.
- **UI state without a flow:** `check_shot_gaps.py --changed`; add a small flow in `tools/shot-flows/`.
- **Show the User:** `show_png.py PATH=description ...` once per ask. Second opinion: `review_shots.py A.png --question "..."`.
- **Bake:** `run_bake_camp.py` (hub light and ground wear; `--overlay` draws the debug boxes), `bake_ground_wear.py` alone, `check_hub_bake.py` (stamps match the code), `bake_frame_art.py` after frame-art code changes (`--check` only compares).
- **How-to-Play pictures:** `tutorial_shots.py --run`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `run_shot_flow.py` | Scripted shot flows (`tools/shot-flows/*.json`): `--job door.job` (every flow routes.yaml maps to the job, one call, one summary), `--flow A,B`, `--flow N --state S` (re-shoot one state), `--changed`, `--all`, `--smoke`; `--list` / `--survey` (one line per flow); `--sheet FLOW` tiles frames; `--no-pixels` steps and asserts only; `--save-baseline DIR` / `--baseline DIR` diff; `--publish` to `_out/shots/<flow>/` (never `assets/`); `--out DIR`. Summary: `shot-flow`. | BWD | `--help` | Y |
| `run_shots.py` | Posed-camera postcard, not a smoke: `--scene dungeon\|camp\|hub\|title\|splash\|fs_gate` (menu screens on an isolated save), `--recipe KEY` (`shot-recipes.json`), `--full-map` (whole floor in one PNG), `--mode web\|build\|user`, `--out`. Summary: `shots`. | BWD | `--help` | Y |
| `shot-recipes.json` | Camera recipes for `run_shots.py --recipe KEY`. | D | - | N |
| `shot_diff.py` | Before/after diff of shot PNGs or folders: `BEFORE AFTER [--out DIR] [--mask X,Y,W,H] [--tol] [--max-ratio]`; changed pixels, bbox, `*.diff.png`. Summary: `shot-diff`. | BWD | `--help` | Y |
| `img_inspect.py` | Named image checks, text facts plus an optional PNG (`--out`): `describe`, `layout` (off-screen, clipped, overlap, safe area, alignment, gaps; `--box` per node rect), `contrast` (WCAG per `--box`), `grid`, `zoom`, `diff` (`--mask`, `--max-ratio`, heatmap), `montage`, `find`, `halo`, `rimclean --refs`, `motion`, `selftest`. Library: `tools/imglib/`. | BWD | `--help` | N |
| `shot_crop.py` | Quick pixel look at one shot: `PNG --box X,Y,W,H [--zoom N] [--out P]` crops and enlarges (default under `_logs/shot-crop/`); `--probe X,Y ...` prints RGBA and hex; `--near HEX [--tol N]` / `--dark N` count pixels and print their bbox. Replaces one-off pixel scripts. `--selftest`. | D | `--help` | N |
| `check_shot_gaps.py` | UI states with no shot flow, plus flow and published-shot problems. `--changed [REF]`: new since REF; required at the END for the Bot and for a Build UI or theme prove (`routes.yaml` `shot_gaps`; `run_build_gate.py --batch` runs it), `--advisory` mid-slice. Summary: `shot-gaps`. | BWD | `--help` | Y |
| `show_png.py` | Show pictures to the User: `[--ask NAME] [--group AREA] PATH[=one-line description] ...` stages them into one prove folder, opens the first on Windows and prints `path - description` lines (`--no-open` only prints). Once per ask, after you looked at them; also prints this session's `Did not work:` lines. `--selftest`. | D | `--help` | N |
| `review_shots.py` | Second opinion on shots from an isolated Grok session: `PNG ... --question "..." [--rubric TEXT\|@FILE]`; prints the text report and `VERDICT`; RESULT FAIL when isolation cannot run (never a placeholder). `--selftest` mocks grok. | BW | `--help` | Y |
| `tutorial_shots.py` | How-to-Play screenshots: checks `tutorial_shots.json` (topic id to shot-flow frame); `--run` shoots those flows and stages `_out/tutorial/<id>.png` with a sha list for Build to copy to `assets/ui/tutorial/` (never writes under assets/). | BD | `--help` | Y |
| `tutorial_shots.json` | Topic id to `{flow, shot}` map and dest, read by `tutorial_shots.py` | D | - | Y |
| `run_bake_camp.py` | Bake `hub_light.png` (and `ground_wear.png` through `bake_ground_wear.py`) via `--wdb-bake-camp` on a real renderer (auto display; prints `stamp=`; `shadow_px=0` FAILs). `--overlay [PNG]` outlines skirt boxes (yellow), protected footprints (red) and caster bounds (cyan); path in RESULT `overlay=`. Never rewrites `camp.tscn`. Summary: `bake-camp`. | BD | `--help` | Y |
| `bake_ground_wear.py` | Bake the tileable ground wear sheet `ground_wear.png` (domain-warped noise, `--steps` 12, `--px-per-m` 32, 32 m tile; same bytes each run; prints `stamp=` for `GROUND_WEAR_STAMP`). Also run by `run_bake_camp.py`. Summary: `ground-wear`. | BD | `--help` | Y |
| `bake_frame_art.py` | Bake the object-frame art (`progress_ui/*_art.gd` and each `dress()` button look) to `assets/ui/frames/<art>/<key>.png` and verify; `--check` compares code drawing with the committed PNGs (FAIL on stale), `--time` times the skin builds. Re-run after editing art code. | BD | `--help` | Y |
