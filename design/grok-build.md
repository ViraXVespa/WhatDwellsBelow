# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

**Intent.** Vira is the conduit for design; Build is the conduit for implementation and defers to her on design. Make her vision real; ask whenever that helps. The docs are a living plan, not a fixed route. Suggest improvements. Hard rules: gates before a PR, no loops, never `main`. You can write the live tree. Second topic door: read it when the job touches that system.

## Design: Vira decides

A design or product question the docs do not settle (what a feature does, where it lives, who owns it, a new door or doc, copy and lore, look, layout, material or texture, what counts as done, save or entry behavior, what a button or control does (a trade that now saves), scope splits, which of two valid routes) goes to the User, before the design doc or any code, with `ask_user_question` where it exists (plain text alongside is fine); so do improvements. Ask as many questions as the job needs, in as many rounds as needed, again whenever a discovery changes what she will see or what was assumed. Offer 2-4 options; free text is welcome. Mark one recommended only for code shape or process, never a look, feel or scope.
Always-allow covers permissions only (Access), never a design question. A dismissed or timed-out question is not an answer: stop and report. No `ask_user_question` tool: ask in plain text and stop.
Build decides code shape inside one system and starts open numbers coherent (`tunables.md`).

## Restate, then change

The first command's card prints the rules for the first message and every ask; follow it, it is the source. In short: a screen change imports and shoots the baseline of the screen you will change, then you write the survey or restate as visible text before any question (what was asked, what would be visible if it worked, what you do not yet know). **Q0** only when the task's Open questions do not already settle the look, reference, and bounds. The full rule is in the start card printed by `python tools/start_build_slice.py`. A task whose Open questions are none, or whose body already names those three, has answered Q0. Do not ask it again.

**Every ask, a re-ask included, has its own message first**: survey or restate, each PNG path with a one-line description, the three ledger lines, `Did not work:` if any. For pictures the order is: shoot, look at them yourself, one `python tools/show_png.py --ask NAME --group AREA PATH=description ...` call (stages `_logs/prove-view/<ask>/`, one sheet per area, opens only the first file so Photos can arrow through; expected, not a ledger item), the message, the ask. Same place is one sheet. Two frames sit side by side when each is taller than wide, stacked when each is wider than tall; more than two use that same grid. A bare path is its own group unless several share one shot-flow directory. Do not open PNGs any other way. A failed step (non-zero exit, `RESULT FAIL`, a failed edit, a skipped step) opens the next message as `Did not work: <command> <one line>`; `python tools/start_build_slice.py --failed` (and `show_png.py`) print those lines from this session's failed tool results, so none is written from memory.

Finish one unit only after the docs, tasks, and gates are updated and the slice is committed and pushed. Then show the prove folder (one sheet per area, before and after of that place on the same sheet), say what is on each, and say whether a playtest confirmation is required, recommended, or not needed. That notice is not a question. After a rejection the next step is a question, not an edit; after a second rejection of one thing offer "send me a reference" before more options. Generated durable source assets (stills, plates, audio stems, intermediates produced by Build or an isolated-media child) are written under `_src/`, using the same relative path they will occupy under `assets/` in the game. Engine-ready copies still flow through the normal process tools into `assets/` when required. Missing required assets fail loudly.

Any script that programmatically generates such an asset is saved under `tools/` (extend an existing generator when one already owns the job; do not leave a durable generator as a one-off scratch).

Update every affected design doc, code-map row, and tunables entry; close or update tasks (`python tools/task.py done ID` or status update); ensure live sources and tools are consistent (normal gates); commit and push to the week branch (`python tools/commit_slice.py` then plain `git push origin grok-build-wN`; never main, never force). This cleanup + commit + push always happens at the end of a unit that touched the tree, even on red gates or imperfect work. Only after that push lands do you open the prove folder, inform that the unit is done, show what is on each sheet, and say whether a playtest confirmation is required (look, sound, balance, or controls), recommended (feel, hitch, or timing the gates do not score), or not needed (a refactor, tool, doc, or test). That notice is not a question. Do not wait for a reply before the commit or the push. Do not ask "Settled? commit?" or any variant that waits for approval. A handoff is only for a survey that never implemented; it is not a substitute for settling code that already exists. You will revert or drop the commit yourself if the work is bad. Any required follow-up is a new commit or a fresh session via handoff.

Prove presentation (Build):
- Do not open the baseline / before image for the User when it is first gathered. Use it only for your own restate. The User sees before and after together, on one sheet, in the done notice (after the push has landed).
- Finish writing every sheet into `_logs/prove-view/<ask>/` before you call show_png. show_png opens only the first file so Photos can arrow through the rest; if the rest are not yet on disk the arrows do nothing.
- One show_png call per ask. Same place = one sheet (side-by-side or stacked). Different areas = next file. Never open one window per PNG.
- The done notice comes after the commit and push. It names the frames that were opened and the folder path, and it says whether a playtest confirmation is required, recommended, or not needed. It is not a question.

## First (once, before anything else)

Classify the request: **new feature / system** (the game lacks it, or a player-facing rework) or **change to what exists** (fix, tune, refactor, same-system API). If unclear, ask.

New feature flow: `build-job-cycle.md`. A new system: plan it and ask every open question.

## Read

Agents file once, then this file. Plan pair only if missing, then the named topic. Route first: read what the route card names, not sibling docs (`list_route.py --digest --door D`: headings with line numbers). A survey starts from text (`run_shot_flow.py --survey`, `list_route.py --digest --door D`: one line per doc); open a doc only for the unit she chose, a picture only for the unit being compared. Reading habits: `build-job-cycle.md`. Gather / Prepare / Change / Prove / Complete: `build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py` (`--texts` for shot-flow words), not grep. Extract: `python tools/show_func.py --path <script> --name <func>`. No `python -c`.

## Work

The User starts the slice with `python tools/open_slice.py [AREA]`: a NEW session in a Grok worktree (a week-branch clone). Your FIRST command, before any file read or memory topic, is `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`): the door card, smokes, flows and the session facts. When the slice has a task, the next command is `python tools/task.py show <id>`, and you read that task file whole before any other file. If you are told the slice is already started, run it too: a later run prints `SLICE ALREADY STARTED`, the steps found and the next one (`--full` reprints the card). Your first text to her, before your next tool call, names the area and says which of the agents file and the skill you actually opened. A door with several jobs is a survey from text; it ends at her answers to its first ask: `python tools/start_build_slice.py --handoff`, then stop; she runs the `open_slice.py` command it prints and a fresh session implements from the handoff (a task file, `design/tasks/README.md`; a committed one resumes with `--from-task ID`). A door with `unit_queue` in `routes.yaml` (ui) is not surveyed. This session does one unit. Do not run `--next` and do not start the next unit. A visual job with no `shot_flows` of its own gets a STEP 0 note (exit 0, not a stop): creating the flow is the first job step (`shot-flows.md`). Only `open_slice.py`, run by the User, launches grok. Build never runs it (the isolated-media runner is the one exception). The User starts every session with it. You are already inside the worktree. Your first command is `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`). If you see `RESULT FAIL route=in-worktree`, you already called the wrong tool; continue with the files that are present. Do not print or suggest an `open_slice.py` command.

Access and Just do / Ask first: `build-job-cycle.md`.

## Red prove, merge-back, other roles

Red prove, merge-back, the playtest confirm: `build-job-cycle.md`; prove is final verification (`tools.md` rule 10; job cycle in `build-job-cycle.md`); never merge into main. Bot notes: park with `python tools/task.py new opt-next --owner bot ...`, no Bot PR. Tools: `design/tools.md`, `design/pc-offload.md`. Build adds or updates the smoke asserts for what it implements (`debug-smokes.md`). I2V: isolated-media gate.

## After a job

After the compile check passed, every output was read, the slice is committed and pushed, and (visual) the prove folder was shown (`show_png.py`, first sheet only) with each sheet described, inform her whether a playtest confirmation is required, recommended, or not needed. The notice carries the change summary and the folder path. It is not a question.

Gates: `tools.md` rule 10 (batch, once, at most 2 reruns; iterating one visual unit with the User is exempt). Code: `check_gd_load.py` every pass in small batches (read every output you run), then `python tools/run_build_gate.py` (`--batch --visual JOB` for a visual change) and `python tools/read_summary.py --job build-gate` once; `commit_slice.py` (after gates; push lands before the done notice), which refuses without that gate, or say `Did not work: gate not run (why)`. A screen change adds `run_shot_flow.py --job J` (or `run_build_gate.py --batch --visual J`) and the UI load check; at the END a missing or stale frame fails the prove. A job with no shot flow does not add `--visual`. A still rekey is that case (`rekey_preview.py`). Never hand-edit `version.json` or commit `_logs/`. Report rough edges (rule 9).

Unit queue, process notes and session close (hard rules): `build-job-cycle.md`.
