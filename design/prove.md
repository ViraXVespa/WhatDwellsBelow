# Prove standard

Status: protocol
Read when: choosing, running or reporting the proof for a change (Bot, Build or web / chat)

One standard for every surface: the cheapest check that would fail if the change were wrong, run once, reported as command plus `RESULT` line plus counts. Gate loops: `tools.md` rule 10. Tools and recipes grow with the work: if a proof needs a check no tool does, extend the library (`imglib`, the shot tools, a gate) in the same job and add its recipe here; do not eyeball it, hand-drive Godot or work around it.

## Proof rules (every surface)

- **No silent fallback.** A required asset or file that is missing or invalid fails loudly (error plus stop). A fallback exists only with the User's explicit OK.
- **Intent first.** Before changing a behavior, state the intended outcome in one line, from the User's words or the design docs, and prove against that line. Unclear: ask with a question prompt.
- **Prove against intent, not yourself.** Compare with the intent and with a reference the User confirmed. "Same as before" counts only when before is what the User wanted; a prior run of the same code is not enough.
- **Say what was shown.** Passing gates are "gates pass", never "proved". For a visual change, open the shot PNGs and describe the material on the screen. A palette swap of the same widgets fails that description. Visual and audio results are unverified until the User confirms. Do not ask for that confirm until the frames show the material. Give the crops, numbers or paths and say so.
- **Fix the bug, keep the improvement.** A bug in a feature is a reason to find the cause and fix it, not to delete the feature.

## Surfaces

| Surface | Runs the proof | Rules |
|---|---|---|
| Bot | its Prove gate, `bot_smokes.py`, `bot_warnscan.py`, shots | `BOT.md` Prove and Smokes |
| Build | gather, change, prove: a visual change uses the door's `shot_flows` (open the frames) and its UI load check; a compile change uses `run_build_gate.py`. Not both for a theme pass. A red prove prints its RETRY prompt | `build-job-cycle.md` |
| Web / chat | cannot run Godot: the emit scratch runs the runners through the `doc_patch` lib (`dump_job`) and the User pastes the RESULT; a missing check is added the same way, as a tool or recipe in that scratch; a Build brief only for work Web cannot do (`web-emit.md`) | `web-test.md`, `web-emit.md`, `doc-library.md` |

## By change kind

| Change | Minimum proof |
|---|---|
| Code (`.gd`) | compile: `run_build_gate.py --batch` (Bot: its Prove gate in `BOT.md`); the smoke phases that load the file (`bot_smokes.py --for FILE`); a pure refactor also needs "same as main" |
| Art, keying | "key is clean", then "looks the same as main" for every sprite that uses it |
| UI | one screen first. Its shot flow (`run_shot_flow.py --flow N`). Open the frames. The named material has to be visible. A recolor fails. Then "layout is clean" and "text readable" |
| Input | P7 binds smoke (`bot_smokes.py --phases 7`) plus the controls flows (`--flows camp-pause-menu,camp-billboard-controls`) |
| Save data | P8 (`bot_smokes.py --phases 8`: save backup on the smoke slot) |
| Tools, docs | `check_tool_cli.py`, `check_tool_docs.py --stale-refs`, `check_load_graph.py`; `img_inspect.py selftest` for imglib |

## Existing prove cases

| Case | Command |
|---|---|
| P1 boot, P2 weapons, P3 floor, P4 roster, P5 gather, P6 forge and quests, P8 hub and save, P9 audio | `python tools/bot_smokes.py --phases N,...` (Build: `run_smokes.py`) |
| P7 HUD, pause, recap and `smoke_binds.gd` (bind table, swap / refuse, Back-key confirm, toasts, hint tokens) | `python tools/bot_smokes.py --phases 7` |
| Phases for a file or door | `bot_smokes.py --for FILE`, `--door D`, `--job D.J` |
| Menu and NPC flows, headless asserts | `bot_smokes.py --door D --flows` |
| New UI state has a flow | `check_shot_gaps.py --changed` |
| Warnings before and after | `bot_warnscan.py --save-baseline B`, then `--non-leak-diff B` |
| Dungeon map, load timing | `run_dungeon_map.py --seed 42 --floor 1`, `run_load_timing.py`, `run_dungeon_load_timing.py` |
| Web build size and frame time | `web_perf.py` (advisory) |

## Recipes

**Doc and code disagree.** Enough to pick the current one: `python tools/list_changed.py --history DOC CODE` lists each path's latest commits (and flags uncommitted edits) and prints `newer=`. Trust the newer, and fix the older in the same job when that is a plain correction. Still unclear (similar dates, an uncommitted edit): Build asks with a question prompt, Web asks one question, Bot lists the line under `Stale doc lines (for the User)`.

Each says when it is enough. Image checks use `python tools/img_inspect.py CMD ...` (programmatic eyes: facts as text, optional annotated PNG; the library is `tools/imglib/`, `tools-media.md`). The `--json` flag gives one object.

**Same as main (shots).** Enough for a change that must not alter pixels. Fixed seed flows only (`fixed_fps`, `seed`; two runs are byte-identical). On a `main` checkout and on the branch: `run_shot_flow.py --all --save-baseline DIR`; then `shot_diff.py MAIN_DIR BRANCH_DIR --out OUT`. Expected diffs are the ones the change asked for; any other changed region is a finding. Frame-level detail: `img_inspect.py diff A B --png OUT`.

**Repeatable.** Enough to call a flow stable: run the same flow twice, `shot_diff.py RUN1 RUN2` reports 0 changed. A flow that differs from itself needs a seed, `freeze` or `mask` first (`shot-flows.md`).

**Key is clean.** Enough for a keyed sprite or banner: `img_inspect.py halo IMG` (rim tinted share against the interior, leftover plate-coloured pixels); fix with `rimclean IMG --refs R,G,B --png OUT`. Clean: tinted rim near the interior share, 0 leftover pixels. Raw sheets: `plate_remap.py` then `sprite_pipeline.py`.

**Layout is clean.** Enough for a screen: `img_inspect.py layout SHOT [--png OUT]` lists off-screen, clipped, outside-safe-area and overlapping elements, near-aligned edges and gaps. Pass `--box X,Y,W,H` per node rect when same-coloured elements touch. Clean: no off-screen, clipped or overlap lines.

**Text readable.** Enough with `assert_texts` (font floor, length, wording; `shot-flows.md`) for the copy: `img_inspect.py contrast SHOT --box X,Y,W,H ...` gives the WCAG ratio per text box (4.5, or `--large` 3.0); `zoom SHOT --box X,Y,W,H --factor 4 --png OUT` for a close look.

**Looks the same as main (one image).** Enough for a sprite, icon or panel: `img_inspect.py diff MAIN_PNG NEW_PNG --max-ratio 0.001 --png OUT` (changed px, regions, heatmap; `--mask` ignores live animation); `montage A B --png OUT` for a side-by-side.

**Moves as intended.** `img_inspect.py motion F1 F2 F3 ...` gives the changed share per step; `find SHOT TEMPLATE` locates an icon or glyph.
