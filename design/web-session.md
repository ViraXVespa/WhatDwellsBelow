# Web / chat session flow

Status: protocol
Read when: web / chat path; every web session after the repo-review message

Binding for **web / chat** only. Grok Build and Grok Bot ignore it.
Second topic door: ask the User to name the owner first. That is the second *writer*. If `conflicts_with` lists the pair, do not implement the second core in this slice. Reading both is allowed. Packed pass: when the User names several owners (or says one go / pack these) and the paths do not share a live file and `conflicts_with` does not list the pair, one scratch may revise those Source paths together. Still one `tools/_scratch.py`. Still User-paste. Do not use a packed pass to invent a system.
The User pastes every emit. Never assume a disk write landed. Do not push `main` or create a side branch unless the User named that branch.

After Phase 3, one `tools/_scratch.py` is the whole remaining action. Emit a blank line, then one python fence. The blank line is required so the fence is not dropped. No other prose in that message. A scratch that writes a runnable this slice owns must run it before exit and print `RESULT checker=PASS|FAIL` when the load-graph checker applies. The User runs only `python3 tools/_scratch.py` from the repo root and pastes the RESULT plus any clipboard shot the scratch armed. If a step cannot live in that scratch, say so and wait. Never print prove commands for the User to run. Never write a `prove:` homework list. Load-graph, import check, build-gate, shots, bake, map, smokes, and load-timing belong inside the same scratch that landed the write. The chat after emit only reads the pasted RESULT.

I2V and complex animation packing stay in Grok Build unless the User says otherwise.
Web / chat may generate non-tile images. It does not spawn the isolated media runner and does not Imagine tiled world assets (floor, brick, dirt, grass, seamless walls).

If the next write would be an assumption, ask one blocking question and wait. That is not a phase change. Do not answer it yourself.

## Flows

After Phase 1, default to **brainstorm**. Directed-goal is opt-in.
Naming a goal is memory, not a mode switch. Several goals may sit in memory. Directed-goal / emit starts only when the User asks for the list, Phase 3, or emit.

| Flow | Start | Stay |
|------|-------|------|
| brainstorm | default after boot | discuss across subject swaps; no Phase 3 nudge |
| directed-goal | User asks for the list / Phase 3 / emit | phases 3-4 on the accepted list |
| build-coop | User names it | small fixes on Build work; gather first |
| parked | User names a parked task | existing park table |
| perf | User drops hitch / load-timing output | measure first; one hitch class per emit |
| build-week | User names it | process recommendations; gather first |

Do not open the Build path file, `BOT.md`, or Grok Bot Job files from this path unless the User named that path.

## Read vs write

When the User is present: picture-read is uncapped inside `design/` and the live tree the thread is talking about. Load-graph, topic index, and extra code-map rows are allowed on a docs or routing pass.
Implementation default is one writer door. A packed pass is the exception above. `conflicts_with` still blocks implementing both cores in one slice.
Inspect the live tree from **one system row** in `design/code-map.md` when editing live files.

## Phases

Move only when the User names the next phase, except the multi-slice loop below. Do not emit during Phase 1-3.

### Phase 1 — Boot

The User tells the agent to review the repo.

If the agents file already routed here, do not re-read it. Load `design/protocol.md` and `design/constraints.md` only when missing.
If the first message names a park, load only that Open file after the law pair and continue. If the park already has a mandate, Phase 2 is optional. Closing a finished park deletes the Open file and its parked-tasks row. Do not rewrite that file as closed.
If the User names build-coop or build-week, emit one gather scratch only (no game writes): `pack_grok_sessions` / `report_grok_sessions`, and `read_summary` only if the User also named a PC job. The User click-runs it; the paste is the packet. `_logs/sess/` is PC job output, not web memory.
If no park is named and no gather was requested, confirm ready. Default mode is brainstorm. Do not start implementation.

### Phase 2 — Discuss

Discuss only. Do not emit. Do not freeze a goal here.
Subject change is not a phase change. Owner doors bound writes, not talk.
This phase ends only when the User names the next phase. Do not treat "stop asking", "fix it", or a locked concept as a phase advance.

### End of brainstorm

Ask once: emit in this chat, or park. Default if unanswered: stay in discuss.

Emit here when the topic is settled enough that Phase 3 would not invent a system, the work fits a short series of scratch slices, and open questions are closed or explicitly deferred.
Park when questions remain, the work is a new system / a pile of new live modules, or the User wants a fresh focused chat.
Do not self-park because the thread is long or a RESULT already landed. Stop the emit loop only when the User says the session is going off the rails, or names park / stop.
If quality looks like it is slipping, say that in one sentence and ask. Do not quietly drop the rest of the list.

A park from brainstorm must carry: mandate, frozen decisions, open questions, likely Source / Docs paths, tests that would prove it, why parked. Do not park leftover slices without that packet.

### Phase 3 — Goal, questions, plan, emit list

Name the goal for this emit pass. Ask only what cannot be inferred.
Split the list: **Source** (`scripts/`, `scenes/`, `assets/`, `tools/`, `project.godot`, other non-doc live files) and **Docs**. Mark each path `new`, `revise`, or `delete`.
Phase 3 may list multiple slices, or one packed pass with several named owners. A packed pass still lists Source/Docs and prove per owner. One scratch may own those cores when the packed-pass rule holds.

This phase ends when the User accepts the list. Do not start Phase 4 without that. If Source is empty, Phase 4 is docs-only.

### Phase 4 — Emit

One action, one `tools/_scratch.py`. The emit rules (scratch shape, revise-from-fetch, docs in the pass, prove table, py_compile rule), Build co-op prompts, scratch helpers and the fetch recipe live in the emit sibling. Open it at Phase 4 and not before: `web-emit.md`.

### Phase 5 — Test

Review the Phase 4 RESULT. Mechanical errors (failed replace, missing required sentence, checker FAIL on a line just written): emit the corrected Phase 4 scratch in the same turn. The corrected scratch owns only the failed step plus leftover cites that scan named. Already-landed files stay untouched. A judgment call the agent cannot infer: one blocking question, then wait.

After a pasted PASS on an accepted multi-slice list: go immediately to Phase 3 of the next unlanded slice (short: goal + paths + tests). Do not return to Phase 2 unless the User changes the remaining list or opens a new brainstorm topic.

## Do not

- Do not emit during Phase 1-3.
- Do not hand the User a prove command list. The scratch runs the runners.
- Do not open Grok Bot Job files from this path.
- Do not emit `_logs/`, `scripts/data/changelog.json`, or a hand-edit of `scripts/data/version.json`.
- Do not write the label into `design/versioning.md`.
- Do not start a second emit pass until Phase 3 runs again.
