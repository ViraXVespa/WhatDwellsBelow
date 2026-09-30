# Web / chat session flow

Status: protocol
Read when: web / chat path; every web session after the repo-review message

Binding for **web / chat** only. Grok Build and Grok Bot ignore it.
Second topic door: ask the User to name the owner first. That is the second *writer*. If `conflicts_with` lists the pair, do not implement the second core in this slice. Reading both is allowed.
The User pastes every emit. Never assume a disk write landed. Do not push `main` or create a side branch unless the User named that branch.

After Phase 3, one `tools/_scratch.py` is the whole remaining action. A scratch that writes a runnable this slice owns must run it before exit and print `RESULT checker=PASS|FAIL` when the load-graph checker applies. The User runs only `python tools/_scratch.py` from the repo root and pastes the RESULT. If a step cannot live in that scratch, say so and wait.

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
Implementation still uses one writer door. A second writer only when the User names the owner. `conflicts_with` still blocks implementing both cores in one slice.
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
Phase 3 may list multiple slices. Each slice has its own goal, writer, Source/Docs, and prove. Sequential one-writer: the writer may change per slice; one scratch does not own two cores.

This phase ends when the User accepts the list. Do not start Phase 4 without that. If Source is empty, Phase 4 is docs-only.

### Phase 4 — Emit

One action. Prefer one `tools/_scratch.py` for every revise/delete path and the docs in this pass. New source files emit one at a time (path line, blank line, full body in one language fence) until the User says `Next`.

Revise from a fetched raw body plus the artifact byte check, or from a User paste already in this conversation. Fetch budget: one pull per path. After a failed check, do not fetch again. Do not assemble a revision from a tool-card summary. Do not put a markdown fence opener inside a fenced emit. Do not reimplement `tools/doc_patch.py`.

Docs in this pass: same scratch updates topic files, one code-map row, and tunables the slice made wrong, writes `design/changelog/{label}.md` via `doc_patch.write_changelog`, and runs `tools/check_load_graph.py`. A later scratch in the same emit pass is a delta. Skip every path whose write already printed `wrote`, `deleted`, or `already applied` / `already gone`. Do not re-emit the whole Phase 3 list. Do not rewrite a file that already matches the accepted goal unless that file is why RESULT failed.

When a slice needs a visual proof, run `python tools/run_shots.py --mode web` and paste the clipboard image with the printed RESULT. Prove from work that landed, using only existing runners. The scratch runs the test through `doc_patch.dump_job(ROOT, job)` (or `run_checker` for the load-graph). After the process exits, print the summary file body, never the `Summary ->` path. Last line is `RESULT checker=PASS|FAIL` or `RESULT gate=PASS|FAIL` plus any extra marks. `sys.exit(0)` on PASS and `sys.exit(1)` on FAIL. If `dump_job` / import check reports a parse or compile error, stop; do not start a longer Godot prove.

| Work that landed | Prove | Dump |
|------|-------|------|
| design / AGENTS / routes / load-graph | `tools/check_load_graph.py` | checker line |
| GDScript / scenes / project.godot | `tools/run_build_gate.ps1` | gate summary |
| Title to Play load | `tools/run_load_timing.ps1` | load-timing summary |
| Hub to dungeon load | `tools/run_dungeon_load_timing.ps1` | dungeon-load-timing summary |
| Gen / map shape | `tools/run_dungeon_map.ps1` | dungeon-map summary |
| Named phase assert | `tools/run_smokes.ps1` | smokes summary |
| Postcard shot | `python tools/run_shots.py --mode web` | shots summary; paste clipboard image |

A slice that only edits protocol docs does not boot Godot. If there is no runner for that work, say so and prove with the load-graph / gate only.

Any slice that creates or edits a `.py` file must prove those files in the same scratch before RESULT: `python -m py_compile` on each touched path, then a dry run of that script's real entry (`--help`, `--what-if` / no-write, or an in-process call that does not mutate live design). Compiler errors or a non-zero dry run fail the scratch. Docs-only slices with no `.py` change skip this.

### Phase 5 — Test

Review the Phase 4 RESULT. Mechanical errors (failed replace, missing required sentence, checker FAIL on a line just written): emit the corrected Phase 4 scratch in the same turn. The corrected scratch owns only the failed step plus leftover cites that scan named. Already-landed files stay untouched. A judgment call the agent cannot infer: one blocking question, then wait.

After a pasted PASS on an accepted multi-slice list: go immediately to Phase 3 of the next unlanded slice (short: goal + paths + tests). Do not return to Phase 2 unless the User changes the remaining list or opens a new brainstorm topic.

## Build co-op prompts

A prompt for Grok Build is a sealed brief, not a session export. Only: named job, writer door, in-scope paths, out-of-scope one-liners, prove runner. Do not pack web protocol, park theory, hitch hypotheses, or "while you are in there." Do not echo the gather report into the brief. If a sentence would make Build invent a step the named job and door would not already require, delete it. If the brief needs a second page, it is two jobs.

## Scratch helpers

Do not reimplement doc_patch. Import it from tools/. Godot prove dumps go through `doc_patch.dump_job`; do not print `Summary ->` paths.
Reuse Brief items must be numbered `1. ` `2. ` so bot_status.parse_reuse_brief counts them. Prose under ## Brief counts as empty.
Changelog: doc_patch.write_changelog. If version.json lags the files in design/changelog/, use the next free 0.N.N label, do not reuse an existing note.
Code-map rows: code_map_lib / patch_code_map, not a hand regex on the table.
Markdown bytes: md_format_lib write helpers. Always run doc_patch.run_checker and print RESULT checker=PASS|FAIL.
lint_hostify out-dir takes ROOT, not root.

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
