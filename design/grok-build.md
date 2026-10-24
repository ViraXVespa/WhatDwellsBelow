# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

**Intent.** Vira is the conduit for design; Build is the conduit for implementation and defers to her on design. Make her vision real; ask whenever that helps. The docs are a living plan, not a fixed route. Suggest improvements. Hard rules: gates before a PR, no loops, never `main`. You can write the live tree. Second topic door: read it when the job touches that system.

## Design: Vira decides

A design or product question the docs do not settle (what a feature does, where it lives, who owns it, a new door or doc, copy and lore, look, layout, material or texture, what counts as done, save or entry behavior, what a button or control does (a trade that now saves), scope splits, which of two valid routes) goes to the User, before the design doc or any code, with `ask_user_question` where it exists (plain text alongside is fine); so do improvements. Ask as many questions as the job needs, in as many rounds as needed, again whenever a discovery changes what she will see or what was assumed. Offer 2-4 options; free text is welcome. Mark one recommended only for code shape or process, never a look, feel or scope.
Always-allow covers permissions only (Access), never a design question. A dismissed or timed-out question is not an answer: stop and report. No `ask_user_question` tool: ask in plain text and stop.
Build decides code shape inside one system and starts open numbers coherent (`tunables.md`).

## Restate, then change

The first command's card prints the rules for the first message and every ask; follow it, it is the source. In short: a screen change imports and shoots the baseline of the screen you will change, then you write the survey or restate as visible text before any question (what was asked, what would be visible if it worked, what you do not yet know). **Q0** only when the task's Open questions do not already settle the look, reference, and bounds; a task whose Open questions are none, or whose body names those three, has answered it.

**Every ask, a re-ask included, has its own message first** (format: the start card). Pictures: shoot, look yourself, write every sheet, then one `python tools/shots.py show --ask NAME --group AREA PATH=description ...` call (`_logs/prove-view/<ask>/`, one sheet per area, opens only the first file so Photos can arrow through). Same place is one sheet: side by side when taller than wide, stacked when wider. Never open PNGs any other way, never one window per PNG. A text-answer-only check goes to `python tools/shots.py review PNG... --question Q`: isolated, only its report returns; FAIL means no review ran. The baseline is for your restate; she sees before and after together in the done notice. A failed step opens the next message as `Did not work: <command> <one line>` (`slice.py start --failed`, `shots.py show`), never from memory.

After a rejection the next step is a question, not an edit; after a second rejection of one thing offer "send me a reference" before more options. Generated source assets and their generators: isolated-media gate (`_src/`, `tools/`). Missing required assets fail loudly.

**Finish a unit** that touched the tree, even on red gates or imperfect work: update affected design docs, code-map rows and tunables; close or update tasks (`python tools/docs.py task done ID`); `python tools/slice.py commit`, then plain `git push origin grok-build-wN` (never main, never force). Only after the push lands: open the prove folder, say the unit is done and what is on each sheet, and say whether a playtest confirmation is required (look, sound, balance, controls), recommended (feel, hitch, timing the gates do not score) or not needed (refactor, tool, doc, test). That notice is not a question; never ask "Settled? commit?". Bad work is reverted or fixed by a new commit or a fresh session; a `--handoff` file is only for a survey that never implemented; unfinished work keeps notes in its task.

## First (once, before anything else)

Classify the request: **new feature / system** (the game lacks it, or a player-facing rework) or **change to what exists** (fix, tune, refactor, same-system API). If unclear, ask.

New feature flow: `build-job-cycle.md`. A new system: plan it and ask every open question.

## Read

Agents file once, then this file. Plan pair only if missing, then the named topic. Route first: read what the route card names, not sibling docs (`find.py route --digest --door D`: headings with line numbers). A survey starts from text (`shots.py flow --survey`, `find.py route --digest --door D`: one line per doc); open a doc only for the unit she chose, a picture only for the unit being compared. Reading habits and Gather / Prepare / Change / Prove / Complete: `build-job-cycle.md`.

Git inventory (not gather): `tools/find.py changed`. Search: `tools/find.py xref` (`--texts` for shot-flow words), not grep. Extract: `python tools/find.py func --path <script> --name <func>`. No `python -c`.

## Work

The User starts the slice with `python tools/slice.py open [AREA]`: a NEW session in a Grok worktree (a week-branch clone); you are already inside it. Only she runs it (the isolated-media runner is the one exception); never run, print or suggest it. Your FIRST command, before any file read or memory topic, is the `slice.py start` line your first message names (from a task: `--job door.job` or `--door door`, plus `--task ID`; else `--door <door>`, `--job` or `--area`): the door card, smokes, flows and session facts. Told the slice is already started? Run it anyway (`SLICE ALREADY STARTED`, steps found, next one; `--full` reprints the card). `RESULT FAIL route=in-worktree`: wrong tool called; go on with the files present. With a task, next run `python tools/docs.py task show <id>` and read that task file whole before any other file. Your first text to her names the area and which of the agents file and the skill you actually opened. A door with several jobs is a survey from text; it ends at her answers to its first ask: `python tools/slice.py start --handoff`, then stop (task file, `design/tasks/README.md`; resume with `--from-task ID`). A door with `unit_queue` (ui) is not surveyed. A task's own `units:` labels are its queue. Finish the whole request in one session when it fits; queue the rest (`--unit-done`) only when it cannot. A visual job with no `shot_flows` gets a STEP 0 note: creating the flow is the first job step (`shot-flows.md`).

Access and Just do / Ask first: `build-job-cycle.md`.

## Red prove, merge-back, other roles

Red prove, merge-back, the playtest confirm: `build-job-cycle.md`; prove is final verification (`tools.md` rule 10); never merge into main. Bot notes: park with `python tools/docs.py task new opt-next --owner bot ...`, no Bot PR. Tools: `design/tools.md`, `design/pc-offload.md`. Build adds or updates the smoke asserts for what it implements (`debug-smokes.md`). I2V: isolated-media gate.

## After a job

Gates: `tools.md` rule 10 and Prove in `build-job-cycle.md`: `gate.py gd-load` once the edits are complete (read every output), then `python tools/gate.py build` (`--batch --visual JOB` for a visual change) and `python tools/session.py summary --job build-gate` once; `slice.py commit` refuses without that gate; a gate never run: `--gate-skipped` (`Did not work: gate not run (why)`); still red at Complete: `--red-gate LOGPATH`. A job with no shot flow does not add `--visual`; a still rekey is that case (`media.py rekey-preview`). Never hand-edit `version.json` or commit `_logs/`. Report rough edges (rule 9). Then Finish a unit (above).

Unit queue, process notes and session close (hard rules): `build-job-cycle.md`.
