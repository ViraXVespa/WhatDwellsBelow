# Web / chat session flow

Status: protocol
Read when: web / chat path; every web session after the repo-review message

This file is binding for **web / chat** only. Grok Build (CLI) and Grok Bot ignore it.
Never open `notes/`.
Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

The User cannot be written to by this agent. The User pastes every emit. The User finishes each task before the next web task starts.

This path never pushes `main`. Do not `git push origin main`. Do not tell the User to push `main`. Do not create a side branch unless the User named that branch.

After Phase 3, do not give the User a command list, a multi-step bat block, or "then run this, then that." One `tools/_scratch.py` must perform the whole remaining action (file writes and checks only unless the User asked for git). A scratch that writes a runnable this slice owns must invoke that tool before exit and print `RESULT checker=PASS|FAIL` when the load-graph checker applies. The User runs only `python tools/_scratch.py` from the repo root and pastes the RESULT. If a step cannot live in that scratch, say so and wait.

I2V and complex animation packing stay in Grok Build unless the User says otherwise.


## Phases

Move to the next phase only when the User names it. Do not emit during Phase 1-3.

### Phase 1 — Boot

The User tells the agent to review the repo. That sets up the session.

If the agents file already routed this session here, do not re-read the agents file. Read `design/protocol.md` and `design/constraints.md` only when they are not already in this session. Then only topic for work already named. Inspect the live tree from **one system row** in `design/code-map.md`. Do not open the Build path file, `BOT.md`, or `design/README.md` for context. Do not treat git or git log as the web hand-off. Do not read `design/changelog/` on a mid-week slice. Open it only for a named pin, a revert, a named past build, or when the User asks what shipped. Open `design/parked-tasks.md` only when the User names a parked task or resume parked. Do not open Grok Bot Job files from this path.

If the first User message names a parked task (design/parked-tasks.md table: id or trigger words), load only that Open file after the law pair. Confirm the review is done and that this session is that parked task, ready to continue from its pickup. Do not wait for a separate go-to-Phase-2 message. If that park already has a mandate, Phase 2 is optional; when the User says go, implement, or emit, proceed.

If no park is named, confirm the review is done and that the session is ready for Phase 2. Do not start implementation.

### Phase 2 — Discuss

The User discusses proposed changes and/or session objectives: what would change, what needs to change, how to do it, questions about current implementation.

Discuss only. Do not emit files. Do not freeze a goal here.

This phase ends only when the User names the next phase. Do not treat "stop asking", "fix it", or a locked concept as a phase advance.

### Phase 3 — Goal, questions, plan, emit list

Name the goal for this emit pass. Identify gaps that block implementation. Ask questions that cannot be inferred easily.

Split the emit list in two. Mark each path `new`, `revise`, or `delete`. Do not ask the User to paste those files.

- **Source:** `scripts/`, `scenes/`, `assets/`, `tools/`, `project.godot`, and other non-doc live files.
- **Docs:** every documentation path the emit runner will write.

This phase ends when the User accepts the list. Do not start Phase 4 without that. If the source column is empty, Phase 4 is docs-only.

### Phase 4 — Emit

One action. Prefer one `tools/_scratch.py` that writes every revise/delete path and any docs in this pass. New source files still emit one at a time (path line, blank line, full body in one language fence). Do not emit the next new source file until the User says to (`Next`, or the same meaning).

A scratch that writes `tools/check_load_graph.py` or another runnable this slice owns must invoke that tool before exit and print `RESULT checker=PASS|FAIL` when the load-graph checker applies.

Revise already-live paths from a fetched raw body plus the artifact byte check, or from a User paste already in this conversation. Fetch budget: one pull per path. After a failed check, do not fetch again. Do not assemble a revision from a tool-card summary.

Do not put a markdown fence opener inside a fenced emit. Do not reimplement `tools/doc_patch.py`. Do not claim a write landed.

If this pass includes docs, the same scratch updates topic files, the live code map, and tunables the slice made wrong, writes `design/changelog/{label}.md` via `doc_patch.write_changelog`, and runs `tools/check_load_graph.py`.

### Phase 5 — Test, then back to Phase 2

The User reviews the Phase 4 RESULT. If Phase 4 already ran the checker or the shipped tool, do not emit a second script. Emit another scratch only to change the test or the tool.

Flagged issues loop back to Phase 2. The Phase 3 goal stays in force unless the User says the goal or the list changed. Phase 3 runs again only then.


## Fetching a live path

1. One page fetch of the raw GitHub file. The tool card is a summary, not the file. Open the saved artifact path printed by the fetch. Compare UTF-8 byte length to the GitHub contents API `size` for that path. Use that artifact when the path exists, the tail is a complete line, and either API `size` equals artifact UTF-8 byte length, or API `size` equals artifact UTF-8 byte length + 3 (UTF-8 BOM on the GitHub blob).
2. If a User paste of that path is already in this conversation, that paste wins.
3. Ask the User to paste that live file only when step 1 failed and no paste is already in the thread. Stop. Do not emit it yet.

Do not request a paste as the normal path. Do not treat a page-tool summary as the live file.


## Do not

- Do not emit during Phase 1-3.
- Do not open Grok Bot Job files from this path.
- Do not emit `_logs/`.
- Do not emit `scripts/data/changelog.json` or hand-edit `scripts/data/version.json`.
- Do not write the label into `design/versioning.md`.
- Do not start a second emit pass until Phase 3 runs again.
