# Web / chat session flow

Status: protocol
Read when: web / chat path; every web session after the repo-review message

Binding for **web / chat** only. Grok Build and Grok Bot ignore it.
Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.
The User pastes every emit. Never assume a disk write landed. Do not push `main` or create a side branch unless the User named that branch.

After Phase 3, one `tools/_scratch.py` is the whole remaining action. A scratch that writes a runnable this slice owns must run it before exit and print `RESULT checker=PASS|FAIL` when the load-graph checker applies. The User runs only `python tools/_scratch.py` from the repo root and pastes the RESULT. If a step cannot live in that scratch, say so and wait.

I2V and complex animation packing stay in Grok Build unless the User says otherwise.

If the next write would be an assumption, ask one blocking question and wait. That is not a phase change. Do not answer it yourself.

## Phases

Move only when the User names the next phase. Do not emit during Phase 1-3.

### Phase 1 — Boot

The User tells the agent to review the repo.

If the agents file already routed here, do not re-read it. Load `design/protocol.md` and `design/constraints.md` only when missing. Then only the named topic. Inspect the live tree from **one system row** in `design/code-map.md`. Do not open the Build path file, `BOT.md`, `design/README.md`, or Grok Bot Job files. Do not treat git as the hand-off.

Open `design/parked-tasks.md` only when the User names a parked task. If the first message matches that table, load only that Open file after the law pair and continue. If the park already has a mandate, Phase 2 is optional. Closing a finished park deletes the Open file and its parked-tasks row. Do not rewrite that file as closed.

If no park is named, confirm ready for Phase 2. Do not start implementation.

### Phase 2 — Discuss

Discuss only. Do not emit. Do not freeze a goal here.
This phase ends only when the User names the next phase. Do not treat "stop asking", "fix it", or a locked concept as a phase advance.

### Phase 3 — Goal, questions, plan, emit list

Name the goal for this emit pass. Ask only what cannot be inferred.
Split the list: **Source** (`scripts/`, `scenes/`, `assets/`, `tools/`, `project.godot`, other non-doc live files) and **Docs**. Mark each path `new`, `revise`, or `delete`.

This phase ends when the User accepts the list. Do not start Phase 4 without that. If Source is empty, Phase 4 is docs-only.

### Phase 4 — Emit

One action. Prefer one `tools/_scratch.py` for every revise/delete path and the docs in this pass. New source files emit one at a time (path line, blank line, full body in one language fence) until the User says `Next`.

Revise from a fetched raw body plus the artifact byte check, or from a User paste already in this conversation. Fetch budget: one pull per path. After a failed check, do not fetch again. Do not assemble a revision from a tool-card summary. Do not put a markdown fence opener inside a fenced emit. Do not reimplement `tools/doc_patch.py`.

Docs in this pass: same scratch updates topic files, one code-map row, and tunables the slice made wrong, writes `design/changelog/{label}.md` via `doc_patch.write_changelog`, and runs `tools/check_load_graph.py`. A later scratch in the same emit pass is a delta. Skip every path whose write already printed `wrote`, `deleted`, or `already applied` / `already gone`. Do not re-emit the whole Phase 3 list. Do not rewrite a file that already matches the accepted goal unless that file is why RESULT failed.

### Phase 5 — Test

Review the Phase 4 RESULT. Mechanical errors (failed replace, missing required sentence, checker FAIL on a line just written): emit the corrected Phase 4 scratch in the same turn. The corrected scratch owns only the failed step plus leftover cites that scan named. Already-landed files stay untouched. A judgment call the agent cannot infer: one blocking question, then wait. Otherwise loop to Phase 2. The Phase 3 goal stays unless the User changes the goal or the list.

## Fetching a live path

1. One page fetch of the raw GitHub file. Open the saved artifact. Use it when the tail is a complete line and API `size` equals artifact UTF-8 bytes, or API `size` equals artifact bytes + 3 (UTF-8 BOM).
2. A User paste of that path already in this conversation wins.
3. Ask for a paste only when step 1 failed and no paste is in the thread. Stop.

Do not treat a page-tool summary as the live file.

## Do not

- Do not emit during Phase 1-3.
- Do not open Grok Bot Job files from this path.
- Do not emit `_logs/`, `scripts/data/changelog.json`, or a hand-edit of `scripts/data/version.json`.
- Do not write the label into `design/versioning.md`.
- Do not start a second emit pass until Phase 3 runs again.
