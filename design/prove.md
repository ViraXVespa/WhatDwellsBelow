# Prove standard

Status: protocol
Read when: choosing, running or reporting the proof for a change (Bot, Build or web / chat)

One standard for every surface: the cheapest check that would fail if the change were wrong, run once, reported as command plus `RESULT` line plus counts. Gate loops: `tools.md` rule 10. Tools and recipes grow with the work: if a proof needs a check no tool does, extend the library (`imglib`, the shot tools, a gate) in the same job and add its recipe here; do not eyeball it, hand-drive Godot or work around it.

## Proof rules (every surface)

- **No silent fallback.** A required asset or file that is missing or invalid fails loudly (error plus stop). A fallback exists only with the User's explicit OK.
- **Intent first.** Before changing anything, state in your own words what was asked and what would be visible or observable if it worked, from the User's words or the design docs, and prove against that. Unclear: ask with a question prompt.
- **Prove against intent, not yourself.** Compare with the intent and with a reference the User confirmed. "Same as before" counts only when before is what the User wanted; a prior run of the same code is not enough.
- **Say what was shown.** Passing gates are "gates pass", never "proved". For a visual change, import first (`gate.py gd-load`, `gate.py import`), shoot a baseline (`band=fail` is not one: re-shoot) and open it first, then show them with one `shots.py show` call and describe what is on each sheet. Build opens only the first file in `_logs/prove-view/<ask>/`; Photos arrows through the rest.
All sheets for that ask must already be written before the open. Do not open the baseline or before image for the User when it is first shot; it is only for the restate. Before and after of one place appear together on the settle sheet.
 Before and after of one place are one sheet (side by side when each is taller than wide, stacked when each is wider than tall; more than two use that grid). A different area is the next file. Do not open one window per PNG. Visual and audio results are unverified until the User confirms. After the compile check passed, every output was read, and the slice is committed and pushed, the done notice carries a change summary and the PNG paths and says a playtest confirmation is required. It is not a question. Give the crops, numbers or paths and say so.
- **Read what you run.** stderr or check output you did not open cannot be called harmless. A passing check that does not cover the claim is not evidence of it (the import check does not load every script; a smoke that asserts nodes exist does not show a look).
- **Fix the bug, keep the improvement.** A bug in a feature is a reason to find the cause and fix it, not to delete the feature.

## Surfaces

| Surface | Runs the proof | Rules |
|---|---|---|
| Bot | its Prove gate, `gate.py bot-smokes`, `gate.py warnscan`, shots | `BOT.md` Prove and Smokes |
| Build | gather, change, prove: `gate.py gd-load` every pass; a visual change adds its `shot_flows` (one `shots.py show` folder, first sheet opened) and its UI load check; the flow is created at the START (step 0), and a missing or stale frame fails the prove at the END; `gate.py build --batch` once at the end. A red prove prints its RETRY prompt | `build-job-cycle.md` |
| Web / chat | The User runs `python tools/_scratch.py`. The scratch may call any `tools/` script, including those that launch Godot (`bake.py camp`, `shots.py capture --mode web`, `gate.py import`, `gate.py build`, smokes, map, timing, etc.). It bases the printed `RESULT` solely on the runner’s exit code. The User pastes that RESULT (plus any clipboard shot or new bake stamp). Full hub bake + stamp and non-tiled asset processing are in scope for web. A Build brief is only for work that truly cannot be expressed as a scratch (complex animation packing, isolated Imagine tiled world assets, etc.). | `web-session.md`, `web-emit.md`, `web-test.md` |

## By change kind

| Change | Minimum proof |
|---|---|
| Code (`.gd`) | compile: `gate.py gd-load` each pass, then `gate.py build --batch` once (Bot: its Prove gate in `BOT.md`); the smoke phases that load the file (`gate.py bot-smokes --for FILE`); a pure refactor also needs "same as main" |
| Art, keying | source plate under `_src/sources`, mirrored to the live path. Gear icons: `media.py gear-icons --check` (also in `gate.py build --batch`). Open-set stills: `media.py rekey-preview` counts, then the User looks at the blue composites. Not a play-camera shot. Not the same pixels as a live file the User has rejected |
| UI | baseline shot (opened) before the questions; no flow yet: create it first (step 0, `shot-flows.md`). One screen, its shot flow (`shots.py flow --flow N`). Open before and after of one place as one sheet (`shots.py show --group`) and say what is on it. After the commit and push, the done notice names the folder and says a playtest confirmation is required. Do not ask. Then "layout is clean" and "text readable" |
| Input | P7 binds smoke (`gate.py bot-smokes --phases 7`) plus the controls flows (`--flows camp-pause-menu,camp-billboard-controls`) |
| Save data | P8 (`gate.py bot-smokes --phases 8`: save backup on the smoke slot) |
| Docs (design docs, the agents file, `BOT.md`) | `check.py load-graph` in the same change. RESULT PASS is required before the change is reported done. It is not deferred to ship |
| Tools | `check.py tool-cli`, `check.py tool-docs --stale-refs`; a catalog edit also runs `check.py load-graph`; `shots.py inspect selftest` for imglib. A change that touches `design/code-map.md` or adds/moves a live `.gd` also runs `python tools/docs.py code-map check` (hard FAIL on MISSING or new UNMAPPED). |

## Existing prove cases

| Case | Command |
|---|---|
| P1 boot, P2 weapons, P3 floor, P4 roster, P5 gather, P6 forge and quests, P8 hub and save, P9 audio | `python tools/gate.py bot-smokes --phases N,...` (Build: `gate.py smokes`) |
| P7 HUD, pause, recap and `smoke_binds.gd` (bind table, swap / refuse, Back-key confirm, toasts, hint tokens) | `python tools/gate.py bot-smokes --phases 7` |
| Phases for a file or door | `gate.py bot-smokes --for FILE`, `--door D`, `--job D.J` |
| Menu and NPC flows, headless asserts | `gate.py bot-smokes --door D --flows` |
| New UI state has a flow | `shots.py gaps --changed` |
| Warnings before and after | `gate.py warnscan --save-baseline B`, then `--non-leak-diff B` |
| Dungeon map, load timing | `perf.py map --seed 42 --floor 1`, `perf.py load [--leg dungeon]` |
| Web build size and frame time | `perf.py web` (advisory) |

## Recipes

**Doc and code disagree.** Enough to pick the current one: `python tools/find.py changed --history DOC CODE` lists each path's latest commits (and flags uncommitted edits) and prints `newer=`. Trust the newer, and fix the older in the same job when that is a plain correction. Still unclear (similar dates, an uncommitted edit): Build asks with a question prompt, Web asks, Bot lists the line under `Stale doc lines (for the User)`.

Each says when it is enough. Image checks use `python tools/shots.py inspect CMD ...` (programmatic eyes: facts as text, optional annotated PNG; `tools-shots.md`; library `tools/lib/imglib/`). The `--json` flag gives one object.

**Same as main (shots).** Enough for a change that must not alter pixels. Fixed seed flows only (`fixed_fps`, `seed`; two runs are byte-identical). On a `main` checkout and on the branch: `shots.py flow --all --save-baseline DIR`; then `shots.py diff MAIN_DIR BRANCH_DIR --out OUT`. Expected diffs are the ones the change asked for; any other changed region is a finding. Frame-level detail: `shots.py inspect diff A B --out OUT`.

**Repeatable.** Enough to call a flow stable: run the same flow twice, `shots.py diff RUN1 RUN2` reports 0 changed. A flow that differs from itself needs a seed, `freeze` or `mask` first (`shot-flows.md`).

**Key is clean.** `python tools/media.py keytest` passes and the sheets in `_logs/keytest/sheets/` look right on checker, dark and light. For a live still, `python tools/media.py rekey-preview` too. Plate mixed into glow stays partial alpha. Solid outlines stay opaque. A veil the User asked to keep as alpha is not a rim to delete. "Looks the same as main" applies only when the live file is the accepted look.

**Layout is clean.** Enough for a screen: `shots.py inspect layout SHOT [--out OUT]` lists off-screen, clipped, outside-safe-area and overlapping elements, near-aligned edges and gaps. Pass `--box X,Y,W,H` per node rect when same-coloured elements touch. Clean: no off-screen, clipped or overlap lines.

**Text readable.** Enough with `assert_texts` (font floor, length, wording; `shot-flows.md`) for the copy: `shots.py inspect contrast SHOT --box X,Y,W,H ...` gives the WCAG ratio per text box (4.5, or `--large` 3.0); `zoom SHOT --box X,Y,W,H --factor 4 --out OUT` for a close look.

**Looks the same as main (one image).** Enough for a sprite, icon or panel: `shots.py inspect diff MAIN_PNG NEW_PNG --max-ratio 0.001 --out OUT` (changed px, regions, heatmap; `--mask` ignores live animation); `montage A B --out OUT` for a side-by-side.

**Moves as intended.** `shots.py inspect motion F1 F2 F3 ...` gives the changed share per step; `find SHOT TEMPLATE` locates an icon or glyph.

Build end-of-session: update docs/tasks/sources/tools, commit and push to the week branch, *then* inform that the unit is done and show the prove folder (do not ask) (see `grok-build.md`).
