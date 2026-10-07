# Build job cycle

Status: protocol
Read when: Grok Build gather, change, or prove

For **Grok Build** only. Web / chat and Grok Bot do not load this file.

Intent: Vira owns design; Build implements it and defers to her on design, asking whenever that helps; the docs are the living plan, not a fixed route (`grok-build.md`).

A **job** is one cycle: gather, change, prove. Report when the work is done. Ask as many questions as the job needs, in as many rounds as it needs, and ask again whenever a discovery changes what the User will see or what was assumed. No limit on count or rounds. **Multi-system job:** before the first change, list every system it touches and read each one's doc and `code_map.py row`.

Gather is planned `list_xref` plus planned `show_func` plus one `code_map.py row` when a live script is in the slice. `summarize_scripts` is not gather. `list_route` and `list_changed` stay outside the gather set (`list_route` is slice boot; `list_changed` is git inventory).

Name a **planned gather list** (distinct xref patterns and show-func names, as long as the systems need) before the first catalog call. Those planned calls are one gather phase; add to the list when a new system turns up. Do not repeat the same command with the same args.

Change is one slice in a Grok worktree cut from the week branch `grok-build-w{N}`. The User starts it with `python tools/open_slice.py [AREA]`, which runs `grok --worktree=NAME --ref grok-build-w{N}` (a NEW session whose directory is the worktree: a full clone under `.grok/worktrees/<repo>/<name>`, `.git` a directory, HEAD the week branch itself). Gather and change run in that session. Its first command is `start_build_slice.py`, which prints the rules of the first message and every ask, and on a later run says where the slice stands (`SLICE ALREADY STARTED`). Do not edit the main checkout. A worktree the User already named is the slice. **Only `open_slice.py`, run by the User, launches grok; Build never does** (no fork, no headless run, no `--prompt-file`, no `--max-turns`; the isolated-media runner is the one exception).

**Restate first.** The start card has the order: import, baseline, the restate as visible text, Q0, then the other questions. A baseline with `band=fail` or script errors is invalid: find the cause, re-shoot, and never use it as the "before" shot or call its errors pre-existing without proof. A word the User used (a name, a metaphor) is not yet an answer to what it means here. Until answered change nothing, except shot-flow files (`tools/shot-flows/`) and the `routes.yaml` mapping.

**Every stop-and-ask message** is built as the card says (message first, every ask, ledger, `Did not work`). Details: a new asset, font, dependency or generated image is named with its alternative and size; a generated image gets the one-line User confirm of Access (below) before use; a font or asset must work in the web export, or say so. After a second rejection of the same thing, the next question offers "send me a reference (a picture, a game, a screen)" before more options.

**Step 0, a missing shot flow.** `start_build_slice.py` prints a STEP 0 note for a visual job with no flow mapped to it (exit 0; not a stop). Creating or adjusting the flow for the exact screen is the first job step (`shot-flows.md`, New UI state checklist); a job never borrows its door's flows as if they were its own. The end gates stay: the after-shot must exist and be opened, no missing or stale frame, and a new uncovered UI state needs a flow before the prove passes.

**Visual unit.** Baseline first (`run_shot_flow.py --job J`, or `--flow N`; `--save-baseline DIR` keeps it), looked at. Change one unit or screen. Re-shooting one state: `run_shot_flow.py --flow N --state NAME` (the steps up to that shot; says changed or same). A detail or a pixel question: `python tools/shot_crop.py PNG --box X,Y,W,H --zoom N` / `--probe X,Y` / `--near HEX`, not a script of your own. Shoot after, look at before and after, `python tools/show_png.py PATH=description ...` opens them for her, say what is on each, then stop and ask. Do not start the next unit. After a rejection the next step is a question about what was wrong, not an edit. Do not commit or push the slice's work until the User confirms the final shot: ask "Settled? commit?" (unless she said to commit now). Iterating one unit with the User is exempt from the rerun counts (`tools.md` rule 10).

**Every pass.** After each small batch of edits (a few files, never a sweep), run `python tools/check_gd_load.py`: it loads every changed and untracked `.gd` inside the project with its autoloads, so a stray `)` or a bad reference fails. The import check, a smoke and a standalone `--script` parse do not load every script, so none of them is evidence that the scripts compile. A multi-line splice gets its own check before the next edit.

**Read what you run.** Open stderr and every check result before you describe it; output you did not read is not harmless, and a passing check that does not cover the claim is not evidence of it. The playtest confirm is asked only after the compile check passed, the output is read, and (visual) the frames are shown and described. The question carries a short summary of what changed.

Commit (only when she says so) is `python tools/commit_slice.py`: it needs a passing `run_build_gate.py --batch --visual JOB` after your last edit and prints the lines for the message; a gate you did not run is said in the final message (`Did not work: gate not run (why)`, `--gate-skipped`). Prove matches the change, once at the end: the compile check each pass; a visual change adds its job's shot flows (`run_shot_flow.py --job J`: one call, flows that another picked flow covers are skipped; shown and described) and that door's UI load check; then `run_build_gate.py --batch` (`--visual JOB` adds the job's shot flows in the same call). Do not import, then smoke, then import.

Smokes at prove: the phases mapped to the door or job in `routes.yaml` `smokes` (printed by `list_route` and `start_build_slice`; `run_smokes.py --door D` or `--job door.job` runs them). A system the slice implements or changes gets its asserts updated in the mapped phase helper (`debug-smokes.md`), or a new assert there, in the same change job. Unit runners (run the runner; do not open smoke helpers just to pick the command):

| Unit | Runner |
|------|--------|
| floor map / gen silhouette / placement specs | `tools/run_dungeon_map.py` `--seed 42 --floor 1` |
| Placeholdia to dungeon timing | `tools/run_dungeon_load_timing.py` |
| named phase asserts | `tools/run_smokes.py` `--door D` / `--job door.job` / `--phases N` |
| changed `.gd` load with autoloads (every pass) | `tools/check_gd_load.py` (`--files`, `--all`, `--base REF`) |
| import + load graph + names / unnamed prove | `tools/run_build_gate.py` |
| exported web build load, frame time, heap, asset sizes (advisory) | `tools/web_perf.py` (`--flow`, `--baseline`) after `export_web.py --out DIR` (`--site DIR`, baseline `tools/web-perf-baseline.json`) |

A new numbered phase, `--wdb-*-smoke` flag, or host scene is allowed only when the feature is new and no mapped phase fits (add it with the feature; name it in the report). A new catalog runner is fine when it would reasonably help future tasks (`tools.md` rule 5). A postcard or shot flow (`shot-tool.md`) is a deliverable or a visual check, not the build gate or a smoke; the headless flow asserts (`bot_smokes.py --flows`) may be named in the prove step. When a task needs a picture the tool cannot stage, extend the tool inside the change job (`shot-flows.md` gap process); do not hand-drive Godot or edit a PNG. A red postcard (`fail` band) gets one same-command rerun only for `truncated`, timeout or `busy`; otherwise fix the tool or script.

## New feature flow

1. Owner: `python tools/list_route.py --door <door>`. No door or doc owns it (or it needs a second door) = a new system: plan it (door, doc name, save keys, entry events, smokes), ask every open question, again as answers raise more; wait.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py`, then implement.
3. Prove, matched to the change (`prove.md`): `check_gd_load.py` each pass; a visual change adds its `shot_flows` (`check_shot_gaps.py --changed` failing fails the prove).
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number, `check_load_graph.py` when routes or docs moved. No changelog files from Build (commit message: `versioning.md`).

## Survey, then a fresh session

A survey of several surfaces reads widely, and every later call re-reads that context. So it ends at her answers to its first ask, and a fresh session implements:

1. Survey from text: `python tools/run_shot_flow.py --survey` (a line per flow: about, states, last shot, band); `python tools/list_route.py --digest --door D` for several jobs. Open pictures only for the group or unit being compared. `run_shot_flow.py --sheet FLOW` tiles one flow's frames into a labeled sheet; fine text is not readable on it.
2. Send the survey message and ask (Q0, then which group, order and wants). A baseline a survey does not shoot is not a `Did not work` item.
3. After her answers: `python tools/start_build_slice.py --handoff` writes `_logs/handoff/handoff.md` (gitignored, never committed). Fill every `<fill>` line: task in her words, Q0 answers, her decisions, chosen surfaces in order, the ledger lists, baselines for the chosen surface (absolute PNG path and a line on what is on it), files and functions to touch, Did-not-work items, open questions. Run `--handoff` again: it validates, saves the survey's shot-flow and `routes.yaml` edits next to the file, and prints the command she runs from the main checkout: `python tools/open_slice.py AREA --prompt-file PATH`. This session then stops. The handoff does not depend on the checkpoint.
4. The fresh session's first command is `start_build_slice.py --door D --from-handoff PATH`: a compact start summary, the saved edits put back, and the baselines to open (those only). It does not re-run the survey. Answers in the handoff stand; it asks about the open questions and what a discovery changes.

`--checkpoint` is a different thing: it saves a session so a red prove can fork back to it. One surface or a small change needs no handoff: continue in place. A fresh session after a heavy context starts the same way, from a handoff. A retry point is saved only when asked for (`--checkpoint`); a slice does not need it.

## Reading habits

- Route first: the route card's read list, not sibling docs. A script of the system being edited: `show_func.py`, not the whole file; an edited file is not re-read in full. A search: `list_xref.py` (an index; `--expand FILE`), never a repo-root `list_dir` (`list_route.py` lists the doors).
- A picture is looked at only for the unit being compared (before and after); a survey starts from text. Another session's memory `_inbox` files are not read.
- Shared tool changes get a `list_xref` listing under "Also changed".

## Permissions

Access (permission, not design): something outside Build's normal reach (a new asset location, a generated image, an external tool or network, files outside the allowed set) gets a one-line User confirm first. Just do: a named script rename/move (`move_script_cluster.py --dry-run`, then run), helpers and APIs inside one system (`refactor.md`), a tool that would help later (`tools.md` rule 5; tell the User). Ask first: a cross-system owner, a named live-module replace, a greenfield rewrite, archive scenes copied over live.

## Next-session brief

Lean: the task in her words; where the last result and its handoff notes live (commit, docs); the first command, `python tools/start_build_slice.py --door D`, stated first (before any memory topic); Q0 first; baselines expected. A survey handoff file is such a brief.

## Red prove and merge-back

**Retry** (one diagnosis, one fix: `tools.md` rule 10). The checkpoint (the worktree's gather session) is the point a retry returns to. A red prove prints a RETRY block: the command `grok -r <checkpoint> --fork-session` for the User to run from the worktree directory (a fork keeps the directory of the session it forks, which is the worktree; no `--cwd`, never `--worktree`; gather context kept), and a paste-ready prompt: which prove failed, the red output in a line or two, the files in `git diff grok-build-w{N}` (working tree, so uncommitted edits show; untracked files are listed too) to look at first, and the ask for one diagnosis and one fix. The forked session does not re-gather: it reads only the changed files, diagnoses once, fixes once and reruns once. No checkpoint saved for this worktree: the block says so and forks nothing; run `--checkpoint` in the gather session, or ask the User for its id (`grok sessions list` in the worktree). Still red: stop and report. The worktree's git history holds the code.

**Merge-back** on a green prove, after the User confirms the final shot. A Grok worktree is a full clone on the week branch itself: commit there, then `git push origin grok-build-w{N}` (plain push, no force, never main); there is no separate commit to merge by hand, and the main checkout pulls it. Put a short note in the commit message (a file under the worktree's `_logs/`, `git commit -F`); resolve conflicts yourself. Anything the User would check by hand (game balance, audio, visuals / art, controls) first needs a question prompt asking whether the playtest looks good, with the change summary (and PNG paths); wait for approval before the merge. Refactors, tools, docs and tests merge automatically on green. Build writes no changelog files (the week-close `0.N.0.md` is a web session's: `versioning.md`).

Read each job summary once via `python tools/read_summary.py --job <name>` (index first, newest run). Do not open summary files directly.

A same-command rerun is valid only for `truncated`, crash, `busy` lock, or wrong scene, and then the same command once. A follow-up job with a new field named from a summary key does not need a User wait; questions still follow the rules above.

Proof recipes by change kind: `prove.md`. A proof that needs a check no tool does: extend the library (`imglib`, shot tools) in the change job and add the recipe there; do not work around it.

Concurrent agents share catalog tools. They do not share logs: each worktree has its own `_logs/`, cleared weekly.
