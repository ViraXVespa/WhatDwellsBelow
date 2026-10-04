# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

**Intent.** Vira is the conduit for design; Build is the conduit for implementation and defers to her on design. Make her vision real; ask whenever that helps. The docs are a living plan, not a fixed route. Suggest improvements and ask in the moment. Hard rules: gates before a PR, no loops, never `main`. You can write the live tree. Second topic door: read it when the job touches that system.

## Design: Vira decides

A design or product question the docs do not settle (what a feature does, where it lives, who owns it, a new door or doc, copy and lore, look, layout, material or texture, what counts as done, save or entry behavior, scope splits, which of two valid routes) goes to the User, before the design doc or any code, with `ask_user_question` where it exists (plain text alongside is fine); so do improvements. Ask as many questions as the job needs, in as many rounds as it needs, and ask again whenever a discovery changes what she will see or what was assumed. Offer 2-4 options; free text is welcome. Mark one recommended only for code shape or process, never a look, feel or scope.
Always-allow covers permissions only (Access), never a design question. A dismissed or timed-out question is not an answer: stop and report. No `ask_user_question` tool: ask in plain text and stop.
Build decides code shape inside one system and starts open numbers coherent (`tunables.md`). Doc and code disagree: trust the newer (`list_changed.py --history`).

## Restate, then change

Visual work first: `check_gd_load.py` once, `run_godot_import_check.py`, then shoot and OPEN the baseline of the screen you will change (band=fail: re-shoot; no flow yet: step 0). Then write the survey or restate as visible text in the message, before any question: what was asked, what would be visible if it worked, what you do not yet know.

**Q0**, every slice, even when the prompt gives a look: what should the result look like; any reference (picture, game, screen); what is out of bounds, including frames or layouts already built. An inherited layout or frame is a Q0 item, never only a ledger line. Then ask whatever else is unclear, as many rounds as needed, and wait. Until answered change nothing except shot-flow files and the `routes.yaml` mapping; they are part of the work.

**An ask is always preceded by its message**: survey or restate, each PNG path with a one-line description, the ledger, `Did not work:` if any. Option labels are not the message. Realise it was not sent: send it before your next tool call. A multi-surface survey comes first; which group, the order and what she wants for each are separate questions after it.

Ledger, three short lines for her to overrule: "Decisions I made that were yours" (each with the alternative; includes new assets, fonts, dependencies, generated images), "Assumptions carried from memory or docs", "Also changed" (shared code and the screens that use it, from `list_xref`; states not shot; writes outside the worktree, Grok memory files too; windows opened on her PC). Build writes outside the worktree only for `run_isolated_grok.py` and the checkpoint file. Say if the baseline PNG is the screen being changed.

A failed step is any non-zero exit or `RESULT FAIL`, exploratory included, or a skipped step: the next message starts `Did not work: <command> <one line>` (`python tools/did_not_work.py` lists them). Opening a file on her PC (explorer, Start-Process) is not showing it: paths and descriptions go in the message; opening one needs a ledger entry.

Finish one unit, open the before and after PNGs and say what is on them, then ask. After a rejection the next step is a question, not an edit; after a second rejection of one thing offer "send me a reference" before more options. Commit and push the slice's work only after she confirms the final shot ("Settled? commit?"), unless she said commit now.

## First (once, before anything else)

Classify the request: **new feature / system** (the game lacks it, or a player-facing rework) or **change to what exists** (fix, tune, refactor, same-system API). If unclear, ask.

New feature flow: `build-job-cycle.md`. A new system: plan it and ask every open question.

## Read

Agents file once, then this file. Plan pair only if missing, then the named topic. **More than one system: read first** (each doc and `code_map.py row`). Imagine: `design/isolated-media.md` first. Gather / change / prove: `build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py` (`--texts` for shot-flow words), not grep. Extract: `python tools/show_func.py --path <script> --name <func>`. No `python -c`.

## Work

The User starts the slice with `python tools/open_slice.py [AREA]`: a NEW session in a Grok worktree (a week-branch clone). Your FIRST command, before any file read, is `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`): the door card, smokes, flows and the first-message statement. Your first message names the area and gives that statement as printed; never write "loaded" unverified. A visual job with no `shot_flows` of its own gets a STEP 0 note (exit 0, not a stop): creating the flow is the first job step (`shot-flows.md`). No week branch: it fails; ask the User (`python tools/week_start.py`). A main-checkout session only prints START lines and stops. After gather run `python tools/start_build_slice.py --checkpoint` (empty `$GROK_SESSION_ID`: ask the User for the id). **Only `open_slice.py`, run by the User, launches grok; Build never does** (the isolated-media runner is the one exception). No brief for another process forbids questions, and Build sets it no run limits.

Access (permission, not design): something outside Build's normal reach (a new asset location, a generated image, an external tool or network, files outside the allowed set) gets a one-line User confirm first.

Just do: a named script rename/move (`move_script_cluster.py --dry-run`, then run), helpers and APIs inside one system (`refactor.md`), a tool that would help later (`tools.md` rule 5; tell the User). Ask first: a cross-system owner, a named live-module replace, a greenfield rewrite, archive scenes copied over live.

## Red prove, merge-back, other roles

Red prove, merge-back, the playtest confirm: `build-job-cycle.md`; one diagnosis, one fix per retry (`tools.md` rule 10); never merge into main. Bot notes: park with `python tools/bot_opt.py`, no Bot PR. Tools: `design/tools.md`, `design/pc-offload.md`; you may add a tool in the same task. Build adds or updates the smoke asserts for what it implements (`debug-smokes.md`). I2V: isolated-media gate. Archive pins are CI-only (`versioning.md`).

## After a job

Proof rules (`prove.md`): one-line intended outcome before a behavior change; a missing required asset fails loudly; report "gates pass", not "proved". Ask the playtest confirm only after the compile check passed, every output was read, and (visual) the PNGs were opened and described; the question carries the change summary and PNG paths. Look and sound stay unverified until confirmed.

Gates: `tools.md` rule 10 (batch, once, at most 2 reruns; iterating one visual unit with the User is exempt). Code: `check_gd_load.py` every pass in small batches (read every output you run), then `python tools/run_build_gate.py` and `python tools/read_summary.py --job build-gate` once. A visual change adds `run_shot_flow.py` and the UI load check; at the END a missing or stale frame fails the prove. Never hand-edit `version.json` or commit `_logs/`. Report rough edges (rule 9).
