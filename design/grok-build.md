# Grok Build

Status: protocol
Read when: starting or resuming a Grok Build CLI task

Build implements the requested work. Vira owns design and scope. Work in the User-opened worktree, never on `main`, except a new week: that starts on clean `main` and then leaves it (`build-week-start.md`). Never force-push. Platform permissions and secret protections still apply.

## Start or resume

1. If the first message says a separate gather session already refined the packet, do not run `slice.py start`. First turn: the task file (when named) and one `wdb__lookup action=packet all=true` (the whole packet; do not page it or file-read `session-context.md`). Otherwise run the `slice.py start` command the first message names before other reads. A `route=in-worktree` failure means this is not a slice; do not create a replacement checkout.
2. Load the repository `pc-offload` skill once and use it for the whole task. It grants no runtime permission. Do not reload it. Bot, web/chat and isolated children do not load it.
3. With a task, read the task file whole (the file named in the first message); it is the assignment. The `## Next Steps (User Only)` section is the User's launcher, not an agent command.
4. `session-context.md` is the packet from the gitignored `session-plan.md` index. If the Approach disagrees with the inlined code, trust the code, `slice.py adjust approach`, then edit. Do not re-lookup a body it includes. A missing symbol is one lookup plus `slice.py adjust` in the same turn; do not re-read the packet that turn. Open a candidate with `action=packet query=ID` plus promote in that turn. Write the kept sections as facts land (`build-job-cycle.md`). Change the index and the Approach only with `slice.py adjust`. Read a RESULT with `session.py summary JOB`. Never open `_logs/`. `find.py changed` is for earlier work, not an untouched first unit. Read the plan pair once if this task's docs are missing.
5. A post-compact turn in this same worktree is one `action=packet all=true`, then continue. Do not re-run `slice.py start`. Update the kept sections when a fact lands, and again before the next planned compact stop. `build-handoff.md` covers a User-opened new session.

Only the User launches sessions with `slice.py open`. Do not fork, launch a second implementation session or edit the main checkout. A new-week request from the main checkout follows `build-week-start.md`, not slice startup.

## Work

Follow `build-job-cycle.md`. A planned compact stop is mandatory: the plan is current, then stop and wait for the User to compact or say continue. The worktree plan is same-session continuity, not the survey handoff.

Use isolated `shots.py review` when a text assessment is sufficient; use `shots.py show` for the User. Necessary direct reference access uses the explicit task/session grant in `build-references.md`. That guide also covers when Blender/Godot MCPs may fill a tooling gap. A reference grant does not authorize image generation or bypass host controls.

Generated media still follows the isolated-media gate. Read only the art job needed for this task. Second topic door: a system touched by the job needs its own source/docs review; unresolved design goes to Vira before implementation.

## Finish

Update the task and affected docs, run relevant checks, then `slice.py commit` and a plain push to the current `grok-build-wN` branch. Never hand-edit `version.json` or commit `_logs/`. Build records outcomes in commit messages, not changelog files. Explicitly report red or skipped gates; do not call them passes.

After pushing, report the changes, evidence paths and remaining limits. Show before/after together when visual confirmation is needed. Say whether playtest confirmation is required (look, sound, balance, controls), recommended (feel/timing not covered by gates), or unnecessary (tools/docs/refactor). The done notice is not a request for permission to commit. Stop after this task; keep unfinished work in its task file.
