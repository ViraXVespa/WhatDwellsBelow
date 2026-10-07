# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

**Intent.** Vira is the conduit for design; Build is the conduit for implementation and defers to her on design. Make her vision real; ask whenever that helps. The docs are a living plan, not a fixed route. Suggest improvements. Hard rules: gates before a PR, no loops, never `main`. You can write the live tree. Second topic door: read it when the job touches that system.

## Design: Vira decides

A design or product question the docs do not settle (what a feature does, where it lives, who owns it, a new door or doc, copy and lore, look, layout, material or texture, what counts as done, save or entry behavior, what a button or control does (a trade that now saves), scope splits, which of two valid routes) goes to the User, before the design doc or any code, with `ask_user_question` where it exists (plain text alongside is fine); so do improvements. Ask as many questions as the job needs, in as many rounds as needed, again whenever a discovery changes what she will see or what was assumed. Offer 2-4 options; free text is welcome. Mark one recommended only for code shape or process, never a look, feel or scope.
Always-allow covers permissions only (Access), never a design question. A dismissed or timed-out question is not an answer: stop and report. No `ask_user_question` tool: ask in plain text and stop.
Build decides code shape inside one system and starts open numbers coherent (`tunables.md`). Doc and code disagree: trust the newer (`list_changed.py --history`).

## Restate, then change

The first command's card prints the rules for the first message and every ask; follow it, it is the source. In short: visual work imports and shoots the baseline of the screen you will change, then you write the survey or restate as visible text before any question (what was asked, what would be visible if it worked, what you do not yet know). **Q0**, every slice, even when the prompt gives a look: what should the result look like (options that differ in kind, each saying `reuse <existing asset or look>` or `draw new`, not all built on one existing look); any reference (picture, game, screen); what is out of bounds, including frames or layouts already built. Then ask whatever else is unclear, as many rounds as needed, and wait. Until answered change nothing except shot-flow files and the `routes.yaml` mapping.

**Every ask, a re-ask included, has its own message first**: survey or restate, each PNG path with a one-line description, the three ledger lines, `Did not work:` if any. For pictures the order is: shoot, look at them yourself, `python tools/show_png.py PATH=description ...` (opens them on her PC; expected, not a ledger item), the message, the ask. A failed step (non-zero exit, `RESULT FAIL`, a failed edit, a skipped step) opens the next message as `Did not work: <command> <one line>`; `python tools/start_build_slice.py --failed` (and `show_png.py`) print those lines from this session's failed tool results, so none is written from memory.

Finish one unit, show the before and after PNGs and say what is on them, then ask. After a rejection the next step is a question, not an edit; after a second rejection of one thing offer "send me a reference" before more options. Commit and push the slice's work only after she confirms the final shot ("Settled? commit?"), unless she said commit now.

## First (once, before anything else)

Classify the request: **new feature / system** (the game lacks it, or a player-facing rework) or **change to what exists** (fix, tune, refactor, same-system API). If unclear, ask.

New feature flow: `build-job-cycle.md`. A new system: plan it and ask every open question.

## Read

Agents file once, then this file. Plan pair only if missing, then the named topic. Route first: read what the route card names, not sibling docs (`list_route.py --digest --door D`: headings with line numbers). A survey starts from text (`run_shot_flow.py --survey`, `list_route.py --digest --door D`: one line per doc); open a doc only for the unit she chose, a picture only for the unit being compared. Reading habits: `build-job-cycle.md`. **More than one system: read first** (each doc and `code_map.py row`). Imagine: `design/isolated-media.md` first. Gather / change / prove: `build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py` (`--texts` for shot-flow words), not grep. Extract: `python tools/show_func.py --path <script> --name <func>`. No `python -c`.

## Work

The User starts the slice with `python tools/open_slice.py [AREA]`: a NEW session in a Grok worktree (a week-branch clone). Your FIRST command, before any file read or memory topic, is `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`): the door card, smokes, flows and the session facts. If you are told the slice is already started, run it too: a later run prints `SLICE ALREADY STARTED`, the steps found and the next one (`--full` reprints the card). Your first text to her, before your next tool call, names the area and says which of the agents file and the skill you actually opened. A door with several jobs is a survey from text; it ends at her answers to its first ask: `python tools/start_build_slice.py --handoff`, then stop; she runs the `open_slice.py` command it prints and a fresh session implements from the handoff (a task file, `design/tasks/README.md`; a committed one resumes with `--from-task ID`). A door with `unit_queue` in `routes.yaml` (ui) is not surveyed: it is worked one unit at a time in one session, and `python tools/start_build_slice.py --next` (unit committed) prints the next unit's card, no new survey. A visual job with no `shot_flows` of its own gets a STEP 0 note (exit 0, not a stop): creating the flow is the first job step (`shot-flows.md`). **Only `open_slice.py`, run by the User, launches grok; Build never does** (the isolated-media runner is the one exception).

Access and Just do / Ask first: `build-job-cycle.md`.

## Red prove, merge-back, other roles

Red prove, merge-back, the playtest confirm: `build-job-cycle.md`; one diagnosis, one fix per retry (`tools.md` rule 10); never merge into main. Bot notes: park with `python tools/task.py new opt-next --owner bot ...`, no Bot PR. Tools: `design/tools.md`, `design/pc-offload.md`; you may add a tool. Build adds or updates the smoke asserts for what it implements (`debug-smokes.md`). I2V: isolated-media gate.

## After a job

Proof rules (`prove.md`): one-line intended outcome before a behavior change; a missing required asset fails loudly; report "gates pass", not "proved". Ask the playtest confirm only after the compile check passed, every output was read, and (visual) the PNGs were shown (`show_png.py`) and described; the question carries the change summary and PNG paths. Look and sound stay unverified until confirmed.

Gates: `tools.md` rule 10 (batch, once, at most 2 reruns; iterating one visual unit with the User is exempt). Code: `check_gd_load.py` every pass in small batches (read every output you run), then `python tools/run_build_gate.py` (`--batch --visual JOB` for a visual change) and `python tools/read_summary.py --job build-gate` once; commit (only when she says so) with `python tools/commit_slice.py`, which refuses without that gate, or say `Did not work: gate not run (why)`. A visual change adds `run_shot_flow.py --job J` (or `run_build_gate.py --batch --visual J`) and the UI load check; at the END a missing or stale frame fails the prove. Never hand-edit `version.json` or commit `_logs/`. Report rough edges (rule 9).
