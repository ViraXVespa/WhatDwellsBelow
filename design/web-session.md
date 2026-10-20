# Web / chat session flow

Status: protocol
Read when: web / chat path; every web session after the repo-review message

For **web / chat** only; Build and Bot ignore it.
Intent: Vira owns design; Web helps make it real, treats the docs as the living plan, and may suggest improvements (ask freely).
Second topic door: ask the User to name the owner first. That is the second *writer*. If `conflicts_with` lists the pair, do not implement the second core in this slice. Reading both is allowed. Packed pass: when the User names several owners (or says one go / pack these) and the paths do not share a live file and `conflicts_with` does not list the pair, one scratch may revise those Source paths together. Still one `tools/_scratch.py`. Still User-paste. No inventing a system in a packed pass.
The User pastes every emit. Do not push `main` or make a side branch unless the User named it.

After Phase 3, one `tools/_scratch.py` is the whole remaining action. Emit a blank line, then one python fence. The blank line is required so the fence is not dropped. No other prose in that message. A scratch that writes a runnable this slice owns must run it before exit and print `RESULT checker=PASS|FAIL` when the load-graph checker applies. The User runs only `python tools/_scratch.py` from the repo root and pastes the RESULT plus any clipboard shot the scratch armed. If a step cannot live in that scratch, say so and wait. Load-graph, import check, build-gate, shots, bake, map, smokes, and load-timing belong in the scratch that landed the write. The chat after emit only reads the pasted RESULT.

A pasted RESULT is "gates pass", not "proved" (proof rules: the agents file).
I2V and complex animation packing stay in Grok Build unless the User says otherwise.
Web / chat may generate non-tile images. It does not spawn the isolated media runner or Imagine tiled world assets (floor, brick, dirt, grass, seamless walls).

If the next write would be an assumption, ask, as many questions as needed, and wait (not a phase change); do not answer it yourself.

If a request needs multiple turns to investigate fully, say so instead of assuming.

## Flows

After Phase 1, default to **brainstorm**. Directed-goal is opt-in.
Naming a goal is memory, not a mode switch. Several goals may sit in memory. Directed-goal / emit starts only when the User asks for the list, Phase 3, or emit.

| Flow | Start | Stay |
|------|-------|------|
| brainstorm | default after boot | discuss across subject swaps; no Phase 3 nudge |
| directed-goal | User asks for the list / Phase 3 / emit | phases 3-4 on the accepted list |
| build-coop | User names it | small fixes on Build work; gather first |
| parked | User names a parked task | `design/tasks/README.md` (owner web) |
| perf | User drops hitch / load-timing output | measure first; one hitch class per emit |
| build-week | User names it | process recommendations; gather first |
| sweep | User names it and a goal | three-section report; Findings as soon as a body shows a player-visible defect; body-read as many remaining checklist items as the turn allows; request another turn only when no further files can be opened this turn |

Do not open the Build path file, `BOT.md`, or Grok Bot Job files from this path unless the User named that path.

## Read vs write

When the User is present: picture-read is uncapped inside `design/` and the live tree the thread is on. Load-graph, topic index and extra code-map rows are allowed on a docs or routing pass.
Implementation default is one writer door. A packed pass is the exception above. `conflicts_with` still blocks implementing both cores in one slice.
Inspect the live tree from **one system row** in `design/code-map.md` when editing live files.

## GitHub Read Notes

- Browse-page summaries are frequently truncated and can end on a clean-looking but incomplete thought. Always read the full file from the session artifact saved under `/home/workdir/artifacts/browsed_files/` when the body matters. Use the summary only as an index of what the file contains so you know which artifact to open.
- A raw URL or open_page result for a path is not proof the file still exists on the branch. Before treating a fetched body as current (especially any path that might have been moved into `notes/` or deleted), confirm the path appears in the branch tree or the contents API. If the tree does not list it, discard the body.
- Branch-tip raw URLs (`raw.githubusercontent.com/.../<branch>/...`) are CDN-cached for roughly five minutes. After a push, a fetch can still return the previous blob. When the session must see the latest commit (protocol edits, post-push verification, or any body-read that must not be stale), first obtain the current SHA for the branch (GitHub API or the commits page), then fetch with that SHA in the URL instead of the branch name. SHA URLs are immutable and bypass the branch-tip cache.

## Phases

Move only when the User names the next phase (except the multi-slice loop below). No emit in Phase 1-3.

### Phase 1 — Boot

The User tells the agent to review the repo.

If the agents file already routed here, do not re-read it. Load `design/protocol.md` and `design/constraints.md` only when missing.
If the first message names a park (a task id or its words), load only that task file and what its `resume` line names, after the law pair, and continue; with a mandate, Phase 2 is optional. A finished park is closed with `task.py done` (`design/tasks/README.md`).
If the User names build-coop or build-week, there is no gather tool: use `read_summary` only if the User also named a PC job (no game writes). `_logs/sess/` is PC job output.
If no park or gather is named, confirm ready (brainstorm; no implementation).

### Phase 2 — Discuss

Discuss only; no emit. Rules, end of brainstorm, park packet: `web-discuss.md`, opened at Phase 2 and not before.

### Phase 3 — Goal, questions, plan, emit list

Goal, questions, Source/Docs emit list; the User accepts it before Phase 4. Rules: `web-plan.md`, opened at Phase 3 and not before.

### Phase 4 — Emit

One action, one `tools/_scratch.py`. Always create, update, or close tasks via `doc_patch.task([...])` (`tools/task.py`); never hand-edit a task skeleton. The scratch must call the matching prove runner and base RESULT solely on the integer it returns—do not print RESULT until the runner has returned, and never hard-code PASS. The rest of the emit rules (scratch shape, revise-from-fetch, docs in the pass, prove table, py_compile rule), Build co-op prompts, scratch helpers and the fetch recipe live in the emit sibling. Open it at Phase 4 and not before: `web-emit.md`.

### Phase 5 — Test

Review the pasted Phase 4 RESULT. Rules (corrected scratch, next slice): `web-test.md`, opened at Phase 5 and not before.

Session end (any phase): the task offer in `web-discuss.md` (End of session).

## Do not

- Never hand the User a prove command list or a `prove:` homework list; the scratch runs the runners.
- Do not emit `_logs/`, `scripts/data/changelog.json`, or a hand-edit of `scripts/data/version.json`.
- Do not write the label into `design/versioning.md`.
- Do not start a second emit pass until Phase 3 runs again.
- Do not add changelog files when working out of a grok-build branch unless the User named changelog as the specific goal of the session. On main (or any non-grok-build session) the scratch emits the changelog by default.
