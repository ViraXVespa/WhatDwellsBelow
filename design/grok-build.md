# Grok Build

Status: protocol
Read when: starting or resuming a Grok Build CLI task

Build implements the requested work. Vira owns design and scope. Work in the User-opened worktree, never on `main`, except a new week: that starts on clean `main` and then leaves it (`build-week-start.md`). Never force-push. Platform permissions and secret protections still apply.

## Start or resume

1. Run the `slice.py start` command in the opening prompt before other reads. Run it even if told the slice already started: it reports the current state; `--full` reprints the card. A `route=in-worktree` failure means this is not a slice; do not create a replacement checkout.
2. Load the repository `pc-offload` skill once and use it for the whole task. It grants no runtime permission. Do not reload it. Bot, web/chat and isolated children do not load it.
3. With `--task ID`, run `python tools/docs.py task show ID` and read that task once. Its `resume:` line is the User's launcher, not an agent command. The task stays the assignment.
4. For a named door or job, that start writes gitignored `session-plan.md`. Read it next and do not repeat what it holds. A function-name gap is `find.py scripts --names` or `--all-names` (one `--path`), not xref `^func`. Any other gap uses `find.py`. In that same turn, trim the gathered half to this unit and write the four sections above the marker (`build-job-cycle.md`). Read a RESULT with `session.py summary JOB`. Never open `_logs/`. `find.py changed` is for earlier work, not an untouched first unit. Read the plan pair once if this task's docs are missing from the plan.
5. A post-compact turn in this same worktree reads `session-plan.md` first. Do not re-run `slice.py start` or the opening lookups unless the plan is missing or the gathered half is stale. `--refresh` rebuilds that half and erases a trim. Update the four sections in the same turn a fact lands, and again before the next planned compact stop. `build-handoff.md` covers a User-opened new session.

Only the User launches sessions with `slice.py open`. Do not fork, launch a second implementation session or edit the main checkout. A new-week request from the main checkout follows `build-week-start.md`, not slice startup.

## Work

Follow `build-job-cycle.md`. A planned compact stop is mandatory: the plan is already trimmed and current, then stop and wait for the User to compact or say continue. The worktree plan is same-session continuity, not the survey handoff.

Use isolated `shots.py review` when a text assessment is sufficient; use `shots.py show` for the User. Necessary direct reference access uses the explicit task/session grant in `build-references.md`. That guide also covers when Blender/Godot MCPs may fill a tooling gap. A reference grant does not authorize image generation or bypass host controls.

Generated media still follows the isolated-media gate. Read only the art job needed for this task. Second topic door: a system touched by the job needs its own source/docs review; unresolved design goes to Vira before implementation.

## Finish

Update the task and affected docs, run relevant checks, then `slice.py commit` and a plain push to the current `grok-build-wN` branch. Never hand-edit `version.json` or commit `_logs/`. Build records outcomes in commit messages, not changelog files. Explicitly report red or skipped gates; do not call them passes.

After pushing, report the changes, evidence paths and remaining limits. Show before/after together when visual confirmation is needed. Say whether playtest confirmation is required (look, sound, balance, controls), recommended (feel/timing not covered by gates), or unnecessary (tools/docs/refactor). The done notice is not a request for permission to commit. Stop after this task; keep unfinished work in its task file.
