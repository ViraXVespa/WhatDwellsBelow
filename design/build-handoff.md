# Build surveys and resuming work

Status: protocol
Read when: surveying several surfaces, saving a survey handoff or resuming a unit queue

A normal task continues in its current session. Context breaks resume there too. Use a survey handoff only when a broad survey has not begun implementation; it is not a retry or a compaction mechanism.

## Survey

1. Inspect text summaries: `python tools/shots.py flow --survey` and `python tools/find.py route --digest --door D`. A door with a unit queue is already ordered work, not a new survey.
2. State the findings; ask about unresolved intent and which group to work on first. Do not capture every screen for context. A baseline intentionally not taken during the survey is not a failed step.
3. After the answers, run `python tools/slice.py start --handoff [--task ID]`. Fill the task skeleton with intent, decisions, selected surfaces/order, relevant baselines, files/functions, failed attempts and open questions. Use actual absolute baseline paths and descriptions; a still is not a gameplay shot.
4. Run `--handoff` again to validate/save the task and any survey flow/routes edits. The tool prints the launch command for the User. Stop; do not launch it or implement from the survey session.

## Resume

The opening prompt supplies `slice.py start --door D --from-handoff PATH` for a saved survey or `--from-task ID` for its committed task. Run that first. It restores the saved survey edits when appropriate and lists the references to inspect; it does not repeat the survey. Existing design answers stand unless new evidence changes them.

Commit the task with the first implementation unit. Its `resume:` line remains the User's launcher from the main checkout. The agent's first command is `slice.py start`, not that launcher.

## Unit queues and unfinished work

A task's `units:` and `done:` fields record progress. For a route-defined queue start with `--door`; for task-defined units pass `--task ID`. At completion, `slice.py start --unit-done` updates progress and compacts completed task notes, preserving decisions and open work.

Continue the remaining named units in the same session when they fit. Otherwise save the current task status, commit/push, and let the User open the next session. Include the next first command, exact remaining work and result paths; do not save stale session-fork commands as instructions. Keep notes in the task rather than creating a second pickup system.
