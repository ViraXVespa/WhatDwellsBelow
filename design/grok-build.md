# Grok Build

Status: protocol
Read when: starting or resuming a Grok Build CLI task

Build implements the requested work. Vira owns design and scope. Work in the User-opened worktree, never on `main`, except a new week: that starts on clean `main` and then leaves it (`build-week-start.md`). Never force-push. Platform permissions and secret protections still apply.

## Start or resume

1. Run the `slice.py start` command in the opening prompt before other reads. Run it even if told the slice already started: it reports the current state; `--full` reprints the card. A `route=in-worktree` failure means this is not a slice; do not create a replacement checkout.
2. Load the existing repository `pc-offload` skill once and use it throughout every Build task, including tools/docs and release work. It selects existing commands; it grants no PC/runtime permission. Do not reload it after each step or compact. Bot, web/chat and isolated children do not load it. If unavailable, report that fact and use documented equivalents only where they cover the task.
3. With `--task ID`, run `python tools/docs.py task show ID` and read that task before other topic files. Its `resume:` line is the User's launcher, not an agent command.
4. Read the route's documents and relevant code. Read the plan pair once if missing. Use `find.py route`, `find.py xref`, `find.py func` and `docs.py code-map row`; use `find.py changed` for earlier work, not on an untouched first unit.
5. State the requested outcome, the evidence that would show it works, and anything unsettled. Do not repeat design questions the task already answers.

Only the User launches sessions with `slice.py open`. Do not fork, launch a second implementation session or edit the main checkout. A new-week request from the main checkout follows `build-week-start.md`, not slice startup.

## Work

Follow `build-job-cycle.md`: understand the task, prepare evidence, implement, verify, finish. It owns context breaks, permissions, questions and red-gate handling. `build-handoff.md` covers surveys and saved work across sessions.

Use isolated `shots.py review` when a text assessment is sufficient; use `shots.py show` for the User. Necessary direct reference access uses the explicit task/session grant in `build-references.md`. That guide also covers when Blender/Godot MCPs may fill a tooling gap. A reference grant does not authorize image generation or bypass host controls.

Generated media still follows the isolated-media gate. Read only the art job needed for this task. Second topic door: a system touched by the job needs its own source/docs review; unresolved design goes to Vira before implementation.

## Finish

Update the task and affected docs, run relevant checks, then `slice.py commit` and a plain push to the current `grok-build-wN` branch. Never hand-edit `version.json` or commit `_logs/`. Build records outcomes in commit messages, not changelog files. Explicitly report red or skipped gates; do not call them passes.

After pushing, report the changes, evidence paths and remaining limits. Show before/after together when visual confirmation is needed. Say whether playtest confirmation is required (look, sound, balance, controls), recommended (feel/timing not covered by gates), or unnecessary (tools/docs/refactor). The done notice is not a request for permission to commit. Stop after this task; keep unfinished work in its task file.
