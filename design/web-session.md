# Web / chat session flow

Status: protocol  
Read when: web / chat path; every web session after the repo-review message  
See also: `AGENTS.md`, `design/protocol.md`, `design/versioning.md`

This file is binding for **web / chat** only. Grok Build (CLI) ignores it.

The User cannot be written to by this agent. The User pastes every emit. The User finishes each task before the next web task starts.

## Phases

Move to the next phase only when this file says to. Do not emit source during Phase 1–3.

### Phase 1 — Initial message

The User tells the agent to review the repo. That sets up the session.

Read `AGENTS.md`, `design/protocol.md`, `design/constraints.md`, then only the topic files for later work if already named. Inspect the live tree. `design/sessions.md` is context only, not this session’s hand-off. Do not read `design/changelog/` unless the named work is versioning, a named past build, or a revert.

Respond by confirming the review is done and that the session is ready for Phase 2. Do not start implementation.

### Phase 2 — Discussion

The User discusses proposed changes and/or session objectives: what would change, what needs to change, how to do it, questions about current implementation.

Discuss only. Do not emit files.

This phase ends when the User says to move to the next phase.

### Phase 3 — Confirmation

Identify gaps that block implementation of the Phase 2 plan. Ask questions that cannot be inferred easily.

List every path this goal will emit. Mark each `new`, `revise`, or `delete`. Do not ask the User to paste those files.

This phase ends when every pending question is answered. If there are no questions, send only the emit list and go to Phase 4.

### Phase 4 — File emitting

Emit every fully revised file **one at a time**. Do not emit the next file until the User says to (`Next`, or the same meaning).

Each emit response is only:

1. One line: the file path (`AGENTS.md`, `design/web-session.md`, `scripts/app.gd`, …).
2. A blank line.
3. The entire file body. No truncations. Include unchanged lines.

Markdown (`AGENTS.md`, `design/*.md`, `design/changelog/*.md`, other `.md`): plain text. No markdown code fence. The User copies the text directly.

Any other source (`.gd`, `.tscn`, `.json`, `.py`, …): wrap the entire body in one code fence for that language. Nothing else in the response except the path line, the blank line, and that fence.

If the User replies with observations or changes for the file just emitted, revise that file and emit it again. Do not emit a different file until they say `Next`.

New file: full body. Deleted file: one line naming the path and that it is deleted; no body.

Live body for a `revise` file:

1. One page fetch of the raw GitHub file. The tool card is a summary, not the file. Open the saved artifact path printed by the fetch (`/home/workdir/artifacts/browsed_files/<id>.text` or `.json`) with the code / REPL tool. Compare UTF-8 byte length to the GitHub contents API `size` for that path. Use that artifact when the path exists, the size matches, and the tail is a complete line.
2. If a User paste of that path is already in this conversation, that paste wins (local edits).
3. Ask the User to paste that live file only when step 1 failed and no paste is already in the thread. Stop. Do not emit it yet.

Do not request a paste as the normal path. Fetch plus the artifact byte check is the normal path.

Fetch budget: one pull per path. After a failed check, do not fetch again and do not describe another strategy (raw URL retry, “workspace copy”, “I’ll pull the full live file next”).

Do not assemble a revision from a tool-card summary, a truncated artifact, or a file older than the conversation.

### Phase 5 — Review

The User tests. Flagged issues loop back to Phase 2, then 3–4 as needed, until the User is satisfied.

The User will say something like “Looks good.” That means no more behavior changes for this goal. Go to Phase 6.

### Phase 6 — Sizing

Check emitted live `scripts/**/*.gd` against the **10,000 byte** cap in `AGENTS.md`.

Web / chat does **not** apply that cap during Phase 2–5. Over-cap files may be emitted and revised until this phase.

If any emitted live script is over the cap:

1. Tell the User which files are too large.
2. Tell the User which new helper / wrapper files will be created and how the facade stays at the original path.
3. Wait for confirmation.
4. Emit the split files with Phase 4 rules (`Next` between files).

If no emitted live script is over the cap, say so. Do not emit.

This phase ends when every needed size split has been emitted, or after reporting that nothing needs changing.

### Phase 7 — Documentation

Check the change against `design/` (and `AGENTS.md` when agent rules changed). Update topic files, code maps, and tunables that the slice made wrong.

If the goal shipped player-visible or agent-visible change, also emit one new file `design/changelog/{label}.md` for the version this goal assumed at Phase 2 (see `design/versioning.md`). Body shape is in that file. Do not read older changelog files to write it. Do not emit `scripts/data/changelog.json` or treat `scripts/data/version.json` as a ledger to hand-edit.

If nothing in the docs is wrong and no changelog entry is required, tell the User no documentation changes are required.

If docs need updates: same verify-then-emit flow as Phase 6. List the files, wait for confirmation, then emit with Phase 4 rules.

When documentation is done, this session goal is finished. The User should start a new session for a new goal.

## Do not

- Do not treat `design/sessions.md` as the web hand-off.
- Do not include `design/sessions.md` as a file that may require updating during phase 7.
- Do not chain a second goal after Phase 7 in the same web session.
- Do not split for the 10KB cap before Phase 6.
- Do not claim a write landed. The User pastes.
- Do not load `design/changelog/` during Phase 1–3.
- Do not treat a page-tool summary as the live file.
- Do not retry a fetch after the byte / tail check fails.
- Do not claim an artifact is the live file unless it is open and the size matches.
- Do not ask the User to paste a live file unless the fetch plus byte / tail check failed and no paste is already in the thread.