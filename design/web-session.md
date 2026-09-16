# Web / chat session flow

Status: protocol 
Read when: web / chat path; every web session after the repo-review message 
See also:

This file is binding for **web / chat** only. Grok Build (CLI) and Grok Bot ignore it.

The User cannot be written to by this agent. The User pastes every emit. The User finishes each task before the next web task starts.

This path does not run the Grok Build week pin ritual. I2V and complex animation packing stay in Grok Build unless the User says otherwise.

Docs-only goal (no Phase 4 source): after Phase 3, skip Phase 4–6 and emit Phase 7 when the User says to. Phase 6 is a no-op when no live `scripts/**/*.gd` were emitted.

`design/reuse-map.md` is a User-authored staging brief for the next Grok Bot reuse PR. This path writes or replaces that whole file in Phase 7 when the User named that staging work or parked leftover extract work. Do not crawl the live tree for new Bot items unless the User named that sweep. An empty template is valid. Do not invent queue rows.

`See also:` is not a read list. Load cap: `AGENTS.md` Shared (soft). Do not reopen `AGENTS.md` from this file.

## Phases

Move to the next phase only when this file says to. Do not emit source during Phase 1–3.

### Phase 1 — Initial message

The User tells the agent to review the repo. That sets up the session.

If `AGENTS.md` already routed this session here, do not re-read `AGENTS.md`. Read `design/protocol.md` and `design/constraints.md` only when they are not already in this session. Then only the topic door for work already named. Inspect the live tree from **one system row** in `design/code-map.md`. Do not open `design/grok-build.md`, `design/grok-bot-session.md`, or `design/README.md` for context. Do not open `design/sessions.md` or `design/session-log.md` from this path. Do not read `design/changelog/` on a mid-week slice. Open it only for **new week**, a revert, a named past build, or when the User asks what shipped. Do not open `design/reuse-map.md` unless this session’s goal is to write that brief.

Respond by confirming the review is done and that the session is ready for Phase 2. Do not start implementation.

### Phase 2 — Discussion

The User discusses proposed changes and/or session objectives: what would change, what needs to change, how to do it, questions about current implementation.

Discuss only. Do not emit files.

This phase ends when the User says to move to the next phase.

### Phase 3 — Confirmation

Identify gaps that block implementation of the Phase 2 plan. Ask questions that cannot be inferred easily.

Split the emit list in two. Mark each path `new`, `revise`, or `delete`. Do not ask the User to paste those files.

- **Phase 4 list:** shipping source only (`scripts/`, `scenes/`, `assets/`, `tools/`, `project.godot`, and other non-doc live files).
- **Phase 7 list:** every documentation path this goal may need (`AGENTS.md`, `design/*.md`, `design/changelog/*.md`, other `.md`). Phase 5 testing can change that list. Do not treat the Phase 7 list as a Phase 4 emit queue.

This phase ends when every pending question is answered. If there are no questions, send only the emit list and go to Phase 4. If the Phase 4 list is empty, say so and wait for the User to start Phase 7.

### Phase 4 — File emitting

Emit every fully revised **Phase 4** file **one at a time**. Do not emit the next file until the User says to (`Next`, or the same meaning).

Do **not** emit documentation in this phase. That includes `AGENTS.md`, `design/**/*.md`, `design/changelog/**/*.md`, and any other `.md` the slice will update. Those wait for Phase 7 so Phase 5 testing can still change them.

Each emit response is only:

1. One line: the file path (`scripts/app.gd`, `tools/export_web.ps1`, …).
2. A blank line.
3. The entire file body. No truncations. Include unchanged lines.

Markdown is not a Phase 4 emit. Any Phase 4 source (`.gd`, `.tscn`, `.json`, `.py`, `.ps1`, …): wrap the entire body in one code fence for that language. Nothing else in the response except the path line, the blank line, and that fence. GDScript follows `AGENTS.md` → GDScript types.

If the User replies with observations or changes for the file just emitted, revise that file and emit it again. Do not emit a different file until they say `Next`.

New file: full body. Deleted file: one line naming the path and that it is deleted; no body.

Live body for a `revise` file:

1. One page fetch of the raw GitHub file. The tool card is a summary, not the file. Open the saved artifact path printed by the fetch (`/home/workdir/artifacts/browsed_files/<id>.text` or `.json`) with the code / REPL tool. Compare UTF-8 byte length to the GitHub contents API `size` for that path. Use that artifact when the path exists, the tail is a complete line, and either:
 - API `size` == artifact UTF-8 byte length, or
 - API `size` == artifact UTF-8 byte length + 3 (UTF-8 BOM on the GitHub blob; the artifact is still the live body).
2. If a User paste of that path is already in this conversation, that paste wins (local edits).
3. Ask the User to paste that live file only when step 1 failed and no paste is already in the thread. Stop. Do not emit it yet.

Do not request a paste as the normal path. Fetch plus the artifact byte check is the normal path.

Fetch budget: one pull per path. After a failed check, do not fetch again and do not describe another strategy (raw URL retry, “workspace copy”, “I’ll pull the full live file next”).

Do not assemble a revision from a tool-card summary, a truncated artifact, or a file older than the conversation.

### Phase 5 — Review

The User tests. Flagged issues loop back to Phase 2, then 3–4 as needed, until the User is satisfied.

The User will say something like “Looks good.” That means no more behavior changes for this goal. Go to Phase 6.

### Phase 6 — Sizing

Check emitted live `scripts/**/*.gd` against the **10,000 byte** cap in `AGENTS.md`. Use `design/refactor.md` for the split recipe only. Do not open `design/grok-bot-session.md` from that recipe. Do not aim at Grok Bot's 5KB sweep target.

Web / chat does **not** apply that cap during Phase 2–5. Over-cap files may be emitted and revised until this phase.

If any emitted live script is over the cap:

1. Tell the User which files are too large.
2. Tell the User which new helper / wrapper files will be created and how the facade stays at the original path.
3. Wait for confirmation.
4. Emit the split files with Phase 4 rules (`Next` between files).

If no emitted live script is over the cap, say so. Do not emit.

This phase ends when every needed size split has been emitted, or after reporting that nothing needs changing.

### Phase 7 — Documentation

All documentation changes for this goal happen in this phase. Phase 5 testing can change what the docs must say. Do not emit those files in Phase 4.

Check the change against `design/` (and `AGENTS.md` when agent rules changed). Update topic files, `design/code-map.md`, and tunables that the slice made wrong. Re-list the Phase 7 paths if testing changed them, wait for confirmation, then emit with Phase 4 cadence (`Next` between files). Markdown emits are plain text and use no code fence.

If the goal shipped player-visible or agent-visible change, also emit one new file `design/changelog/{label}.md` as the **final** file in this phase. Label math and body shape: `design/versioning-log.md`. Do not read older changelog files to write it. Do not emit `scripts/data/changelog.json` or hand-edit `scripts/data/version.json`. Do not write the label into `design/versioning.md`.

Do not emit `design/sessions.md` or `design/session-log.md` unless the User explicitly overrides that for this session. Do not emit `_logs/`.

If nothing in the docs is wrong and no changelog entry is required, tell the User no documentation changes are required.

When documentation is done, this session goal is finished. The User should start a new session for a new goal.

## Do not

- Do not emit documentation during Phase 4.
- Do not treat `design/sessions.md` or `design/session-log.md` as the web hand-off.
- Do not run a Grok Build week pin from this path.
- Do not chain a second goal after Phase 7 in the same web session.
- Do not split for the 10KB cap before Phase 6, and do not keep splitting toward 5KB.
- Do not claim a write landed. The User pastes.
- Do not treat a page-tool summary as the live file.
- Do not retry a fetch after the byte / tail check fails.
- Do not open `See also:` files as a default read set.
