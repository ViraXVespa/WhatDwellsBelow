# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

**Intent.** Vira is the conduit for design; Build is the conduit for implementation and defers to her on design. Make her vision real; ask whenever that helps. The docs are a living plan, not a fixed route. Suggest improvements and ask in the moment. Hard rules: gates before a PR, no loops, never `main`. You can write the live tree. Second topic door: read it when the job touches that system.

## Design: Vira decides

A design or product question the docs do not settle (what a feature does, where it lives, who owns it, a new door or doc, copy and lore, look, layout, material or texture, what counts as done, save or entry behavior, scope splits, which of two valid routes) goes to the User, before the design doc or any code, with `ask_user_question` where it exists (plain text alongside is fine); so do improvements. Ask as many questions as the job needs, in as many rounds as it needs, and ask again whenever a discovery changes what she will see or what was assumed. Offer 2-4 options as suggestions; free text is welcome. Mark one recommended only for code shape or process, never for a look, a feel or a scope.
Always-allow covers permissions only (Access), never a design question. A dismissed or timed-out question is not an answer: stop and report. With no `ask_user_question` tool, ask in plain text and stop.
Build decides code shape inside one system and starts open numbers coherent (`tunables.md`). Doc and code disagree: trust the newer (`list_changed.py --history`).

## Restate, then change

Visual work first: `check_gd_load.py` once, `run_godot_import_check.py`, then shoot and OPEN the baseline of the screen you will change (band=fail: re-shoot; no flow yet: step 0). Then write the restate as visible text in the message, before any question: what was asked, what would be visible if it worked, what you do not yet know. Open the questions with the outcome: what it should look like, whether she has a reference picture or example, what is out of bounds. Then ask whatever else is unclear, as many rounds as needed, and wait. A word the User used is not yet an answer to what it means here. Until answered change nothing except shot-flow files and the `routes.yaml` mapping; they are part of the work.

Every stop-and-ask message has the PNG paths in its text and two short lists for her to overrule: "Decisions I made that were yours" (each with the alternative; includes new assets, fonts, dependencies, generated images) and "Assumptions carried from memory or docs". Say if the baseline PNG is the screen being changed. After any failed or skipped tool step, the next message to her starts `Did not work: <command> <one line>`.

Finish one unit, open the before and after PNGs and say what is on them, then ask. After a rejection the next step is a question, not an edit; after a second rejection of one thing offer "send me a reference" before more options. Commit and push the slice's work only after she confirms the final shot ("Settled? commit?"), unless she said commit now.

Every pass, in small batches: `python tools/check_gd_load.py` (loads each changed `.gd` with its autoloads). Read every output you run; a check that misses the claim is not evidence (`build-job-cycle.md`).

## First (once, before anything else)

Classify the request: **new feature / system** (the game lacks it, or a player-facing rework) or **change to what exists** (fix, tune, refactor, same-system API). If unclear, ask.

New feature flow (report at the end; ask as questions arise):
1. Owner: `python tools/list_route.py --door <door>`. No door or doc owns it (or it needs a second door) = a new system: plan it (door, doc name, save keys, entry events, smokes), ask every open question, again as answers raise more; wait.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py`, then implement.
3. Prove, matched to the change (`prove.md`): `check_gd_load.py` each pass; a visual change adds its `shot_flows` (`check_shot_gaps.py --changed` failing fails the prove).
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number, `check_load_graph.py` when routes or docs moved. No changelog files from Build (commit message: `versioning.md`).

## Read

Agents file once, then this file. Plan pair only if missing, then the named topic. **More than one system: read first** (each doc and `code_map.py row`). Imagine: `design/isolated-media.md` first. Gather / change / prove: `build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py`, not grep. Extract: `python tools/show_func.py --path <script> --name <func>`. No `python -c`.

## Work

First message names the area and says whether the agents file and skills loaded (if not, say so, read the agents file by hand). The User starts the slice with `python tools/open_slice.py [AREA]`: a NEW session in a Grok worktree (a full clone on the week branch). In it run `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`): the door card, smokes and shot flows. A visual job with no `shot_flows` of its own gets a STEP 0 note (exit 0, not a stop): creating the flow is the first job step (`shot-flows.md`). No week branch: it fails; ask the User (`python tools/week_start.py`). A main-checkout session only prints START lines and stops. A named worktree is the slice. After gather run `python tools/start_build_slice.py --checkpoint` (empty `$GROK_SESSION_ID`: ask the User for the id). **Only `open_slice.py`, run by the User, launches grok; Build never does** (the isolated-media runner is the one exception). No brief for another process forbids questions, and Build sets it no run limits.

Access (permission, not design): something outside Build's normal reach (a new asset location, a generated image, an external tool or network, files outside the allowed set) gets a one-line User confirm first.

Just do: a User-named script rename/move (`move_script_cluster.py --dry-run`, then run), helpers and APIs inside one system (`refactor.md`), a tool that would help later (`tools.md` rule 5; tell the User). Ask first: a cross-system owner, a named live-module replace, a greenfield rewrite, archive scenes copied over live.

## Red prove, merge-back, other roles

Red prove, merge-back, the playtest confirm: `build-job-cycle.md`; one diagnosis, one fix per retry (`tools.md` rule 10); never merge into main. Bot notes: park with `python tools/bot_opt.py`, no Bot PR. Tools: `design/tools.md`, `design/pc-offload.md`; you may add a tool in the same task. Build adds or updates the smoke asserts for what it implements (`debug-smokes.md`). I2V: isolated-media gate, in the slice thread. Archive pins are CI-only (`versioning.md`).

## After a job

Proof rules (`prove.md`): one-line intended outcome before a behavior change; a missing required asset fails loudly; report "gates pass", not "proved". Ask the playtest confirm only after the compile check passed, every output was read, and (visual) the PNGs were opened and described; the question carries the change summary and PNG paths. Look and sound stay unverified until confirmed.

Gates: `tools.md` rule 10 (batch, once, at most 2 reruns; iterating one visual unit with the User is exempt). Code: `check_gd_load.py` each pass, then `python tools/run_build_gate.py` and `python tools/read_summary.py --job build-gate` once. A visual change adds `run_shot_flow.py` and the UI load check; at the END a missing or stale frame fails the prove. Never hand-edit `version.json` or commit `_logs/`. Report rough edges (rule 9).
