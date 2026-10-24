# Build job cycle

Status: protocol
Read when: Grok Build gather, change, or prove

For **Grok Build** only. Web / chat and Grok Bot do not load this file.

A **job** is one cycle: Gather, Prepare, Change, Prove, Complete. Report when the work is done. Ask as many questions as the job needs, in as many rounds as it needs, and ask again whenever a discovery changes what the User will see or what was assumed. No limit on count or rounds.

### Gather

Gather finishes before any change.

1. Read the relevant code and docs. First name a planned gather list (distinct `list_xref` patterns and `show_func` names; add to it when a new system turns up), plus one `code_map.py row` per live script. A multi-system job lists every system it touches and reads each one's doc and row. `summarize_scripts`, `list_route` (slice boot) and `list_changed` (git inventory) are not gather. Do not repeat a command with the same args.
2. State the observable outcome that will show the task is done (one line: what the User or the bench will see if the work is correct).
3. Confirm whether the existing tooling or in-game signal can show that outcome. Record what is missing, if anything.
4. For a bug or perf miss: does the repro's output name the cause (a row, phase, or field that points at one cause)? A repro that shows the failure but not its cause is a missing signal; Prepare adds detail to that repro before any fix.

No code changes. No new tools.  
End of Gather: tell the User to run `/fork`. Continue in the new peer session. The original session ID is the reset point. Later retries use `grok -r <original-session-id> --fork-session` from the worktree directory.

### Prepare

If a signal is missing, add the cheapest instrument that provides it, or run the information-gathering pass that does not alter behavior. Gate new instrumentation the same way existing debug logging is gated (runtime check, localhost/web or bench flag only) so shipping builds are unaffected. A tool that would help later tasks is added under `tools.md` rule 5.

If Prepare discovers the task is blocked or needs a design answer, stop and update the task instead of continuing.

### Change

Implement the task using the information and tooling from Gather and Prepare. A fix targets a cause the signal named, not a guess.  
Run `python tools/check_gd_load.py` once the edits for the unit are complete, before Prove.  
No formal prove yet.

### Prove

Final verification that the outcome is met.  
Run the compile check, then (for a visual change) the job’s shot flows and that door’s UI load check, then `run_build_gate.py --batch`.

A red prove allows at most one small corrective edit and one re-run (`tools.md` rule 10). Still red: stop and report the log path. Do not open a new diagnostic cycle inside the prove.

### Complete

Update docs and the task.  
- If done: close the task (`python tools/task.py done ID`).  
- If not: update the task with handoff notes (what was tried, what the prove showed, where to resume) and the command `grok -r <original-session-id> --fork-session` (run from the worktree directory).  

Commit and push (`commit_slice.py` then plain `git push` to the week branch).  
Present the user with any verification they still need to do and, when the task is not closed, the `grok -r <original-session-id> --fork-session` command.

A session finishes the whole request when it fits; a unit queue records the rest (`--unit-done`) only when it cannot.

A **slice** is one Grok worktree cut from the week branch `grok-build-w{N}`. The User starts it with `python tools/open_slice.py [AREA]`, which runs `grok worktree create NAME --ref grok-build-w{N}` and then `grok --cwd PATH --trust` (a NEW session whose directory is the worktree: a full clone under `.grok/worktrees/<repo>/<name>`, `.git` a directory, HEAD the week branch itself). Gather runs in that session; after `/fork`, Prepare through Complete run in the forked peer. Its first commands follow `grok-build.md` Work. `start_build_slice.py` prints the rules of the first message and every ask, and on a later run says where the slice stands (`SLICE ALREADY STARTED`). Do not edit the main checkout. A worktree the User already named is the slice. **Only `open_slice.py`, run by the User, launches grok; Build never does** (no fork, no headless run, no `--prompt-file`, no `--max-turns`; the isolated-media runner is the one exception).

**Restate first.** The start card has the order. A screen: import, baseline, the restate as visible text, Q0, then the other questions. A baseline with `band=fail` or script errors is invalid: find the cause, re-shoot, and never use it as the "before" shot or call its errors pre-existing without proof. A word the User used (a name, a metaphor) is not yet an answer to what it means here. Until answered change nothing, except shot-flow files (`tools/shot-flows/`) and the `routes.yaml` mapping. A task file whose Open questions are none already answered Q0, and a job the card marks NO PLAY CAMERA is not waiting on a play-camera baseline.

**Every stop-and-ask message** is built as the card says (message first, every ask, ledger, `Did not work`). Details: a new asset, font, dependency or generated image is named with its alternative and size; a generated image gets the one-line User confirm of Access (below) before use; a font or asset must work in the web export, or say so. After a second rejection of the same thing, the next question offers "send me a reference (a picture, a game, a screen)" before more options.

**Step 0, a missing shot flow.** `start_build_slice.py` prints a STEP 0 note for a visual job with no flow mapped to it (exit 0; not a stop). Creating or adjusting the flow for the exact screen is the first job step (`shot-flows.md`, New UI state checklist); a job never borrows its door's flows as if they were its own. The end gates stay: the after-shot must exist and be opened, no missing or stale frame, and a new uncovered UI state needs a flow before the prove passes.

**Visual unit.** A job the start card marks NO PLAY CAMERA is not one of these: no play-camera baseline, no new shot flow, no `--visual` on the gate. Its proof is the check the job doc names (a keyed still: `rekey_preview.py`). A screen: baseline first (`run_shot_flow.py --job J`, or `--flow N`; `--save-baseline DIR` keeps it), looked at. Change one unit or screen. Re-shooting one state: `run_shot_flow.py --flow N --state NAME` (the steps up to that shot; says changed or same). A detail or a pixel question: `python tools/shot_crop.py PNG --box X,Y,W,H --zoom N` / `--probe X,Y` / `--near HEX`, not a script of your own. Shoot after, look at before and after, `python tools/show_png.py PATH=description ...` opens them for her, say what is on each. Iterating one unit with the User is exempt from the rerun counts (`tools.md` rule 10).

**Compile check.** Run `python tools/check_gd_load.py` once the edits for the unit are complete (before Prove). It loads every changed and untracked `.gd` inside the project with its autoloads, so a stray `)` or a bad reference fails. The import check, a smoke and a standalone `--script` parse do not load every script, so none of them is evidence that the scripts compile.

**Read what you run:** `prove.md` Proof rules.

Commit, without waiting for a yes, with `python tools/commit_slice.py`: it needs a passing `run_build_gate.py --batch --visual JOB` after your last edit and prints the lines for the message; a gate you did not run is said in the final message (`Did not work: gate not run (why)`, `--gate-skipped`); a gate still red at Complete commits with `--red-gate LOGPATH` (marked `RED GATE:`; its `Red gate:` line opens the done notice). At Prove, a visual change's shot flows run as `run_shot_flow.py --job J` (one call; flows another picked flow covers are skipped; shown and described), or `--visual JOB` on the gate adds them in the same call. Do not import, then smoke, then import.

Smokes at prove: the phases mapped to the door or job in `routes.yaml` `smokes` (printed by `list_route` and `start_build_slice`; `run_smokes.py --door D` or `--job door.job` runs them). A system the slice implements or changes gets its asserts updated in the mapped phase helper (`debug-smokes.md`), or a new assert there, in the same change job. Unit runners (run the runner; do not open smoke helpers just to pick the command):

| Unit | Runner |
|------|--------|
| floor map / gen silhouette / placement specs | `tools/run_dungeon_map.py` `--seed 42 --floor 1` |
| Placeholdia to dungeon timing | `tools/run_load_timing.py --leg dungeon` |
| named phase asserts | `tools/run_smokes.py` `--door D` / `--job door.job` / `--phases N` |
| changed `.gd` load with autoloads (end of Change) | `tools/check_gd_load.py` (`--files`, `--all`, `--base REF`) |
| import + load graph + names / unnamed prove | `tools/run_build_gate.py` |
| exported web build load, frame time, heap, asset sizes (advisory) | `tools/web_perf.py` (`--flow`, `--baseline`) after `export_web.py --out DIR` (`--site DIR`, baseline `tools/web-perf-baseline.json`) |

A new numbered phase, `--wdb-*-smoke` flag, or host scene is allowed only when the feature is new and no mapped phase fits (add it with the feature; name it in the report). A new catalog runner is fine when it would reasonably help future tasks (`tools.md` rule 5). A postcard or shot flow (`shot-tool.md`) is a deliverable or a visual check, not the build gate or a smoke; the headless flow asserts (`bot_smokes.py --flows`) may be named in the prove step. When a task needs a picture the tool cannot stage, extend the tool inside the change job (`shot-flows.md` gap process); do not hand-drive Godot or edit a PNG. A red postcard (`fail` band) follows the same-command rerun rule below; otherwise fix the tool or script.

## New feature flow

1. Owner: `python tools/list_route.py --door <door>`. No door or doc owns it (or it needs a second door) = a new system: plan it (door, doc name, save keys, entry events, smokes), ask every open question, again as answers raise more; wait.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py`, then implement.
3. Prove, matched to the change (`prove.md`): `check_gd_load.py` each pass; a visual change adds its `shot_flows` (`check_shot_gaps.py --changed` failing fails the prove).
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number. Any edit of a design doc, the agents file, or `BOT.md` runs `check_load_graph.py` before the change is reported done. RESULT PASS is required. It is not deferred to ship. No changelog files from Build (commit message: `versioning.md`).

## Survey, then a fresh session

A survey of several surfaces reads widely, and every later call re-reads that context. So it ends at her answers to its first ask, and a fresh session implements:

1. Survey from text: `python tools/run_shot_flow.py --survey` (a line per flow: about, states, last shot, band); `python tools/list_route.py --digest --door D` for several jobs. Open pictures only for the group or unit being compared. `run_shot_flow.py --sheet FLOW` tiles one flow's frames into a labeled sheet; fine text is not readable on it.
2. Send the survey message and ask (Q0, then which group, order and wants). A baseline a survey does not shoot is not a `Did not work` item.
3. After her answers: `python tools/start_build_slice.py --handoff [--task ID]` writes the task file `ID.md` in `design/tasks/` (default ID: the door; rules: `design/tasks/README.md`). Fill every `<fill>` line: done-when, task in her words, Q0 answers, her decisions, chosen surfaces in order, the ledger lists, baselines for the chosen surface (absolute PNG path and a line on what is on it), files and functions to touch, Did-not-work items, open questions. Run `--handoff` again: it validates, saves the task file and the survey's shot-flow and `routes.yaml` edits for the fresh session, and prints the command she runs from the main checkout: `python tools/open_slice.py AREA --prompt-file PATH`. This session then stops.
4. The fresh session's first command is `start_build_slice.py --door D --from-handoff PATH`: a compact start summary, the saved edits put back, and the baselines to open (those only). It points the task's first command at `--from-task ID`; commit the task file with the first unit, so any later session resumes with `start_build_slice.py --door D --from-task ID`. `--unit-done` keeps its `done:` line current; the commit that finishes the task runs `python tools/task.py done ID`. It does not re-run the survey. Answers in the handoff stand; it asks about the open questions and what a discovery changes.

One surface or a small change needs no handoff: continue in place. A fresh session after a heavy context starts the same way, from a handoff. A handoff is not the retry point; that is the original session ID from the end of Gather (`/fork`).

## Reading habits

- Route first: the route card's read list, not sibling docs. A script of the system being edited: `show_func.py`, not the whole file; an edited file is not re-read in full. A search: `list_xref.py` (an index; `--expand FILE`), never a repo-root `list_dir` (`list_route.py` lists the doors).
- A picture is looked at only for the unit being compared (before and after); a survey starts from text. Another session's memory `_inbox` files are not read.
- Shared tool changes get a `list_xref` listing under "Also changed".

## Permissions

Access (permission, not design): something outside Build's normal reach (a new asset location, a generated image, an external tool or network, files outside the allowed set) gets a one-line User confirm first. Just do: a named script rename/move (`move_script_cluster.py --dry-run`, then run), helpers and APIs inside one system (`refactor.md`), a tool that would help later (`tools.md` rule 5; tell the User). Ask first: a cross-system owner, a named live-module replace, a greenfield rewrite, archive scenes copied over live.

## Next-session brief

Lean: the task in her words; where the last result and its handoff notes live (commit, docs); the first command (`grok-build.md` Work), stated first; Q0 first; baselines expected. A survey handoff file is such a brief.

## Red prove and merge-back

**Retry** (`tools.md` rule 10: one small corrective edit, one re-run). The original session ID (the session before the `/fork` at the end of Gather) is the point a retry returns to. The User runs `grok -r <original-session-id> --fork-session` from the worktree directory (a fork keeps the directory of the session it forks, which is the worktree; no `--cwd`, never `--worktree`; gather context kept). A red prove prints a RETRY block with a paste-ready prompt: which prove failed, the red output in a line or two, the files in `git diff grok-build-w{N}` (working tree, so uncommitted edits show; untracked files are listed too) to look at first, and the ask for one small corrective edit. The forked session does not re-gather: it reads only the changed files, diagnoses once, fixes once and reruns once. Still red: stop and report. The worktree's git history holds the code.

**Merge-back** (green prove, or red with `--red-gate`). A Grok worktree is a full clone on the week branch itself: commit there, then `git push origin grok-build-w{N}` (plain push, no force, never main); there is no separate commit to merge by hand, and the main checkout pulls it. Put a short note in the commit message (a file under the worktree's `_logs/`, `git commit -F`); resolve conflicts yourself. Do not wait for approval before the commit or the push. After the push: the done notice (`grok-build.md` Finish a unit).

Read each job summary once via `python tools/read_summary.py --job <name>` (index first, newest run). Do not open summary files directly.

A same-command rerun is valid only for `truncated`, timeout, crash, `busy` lock, or wrong scene, and then the same command once. A follow-up job with a new field named from a summary key does not need a User wait; questions still follow the rules above.

Proof recipes by change kind: `prove.md`. A proof that needs a check no tool does: extend the library (`imglib`, shot tools) in the change job and add the recipe there; do not work around it.

Concurrent agents share catalog tools. They do not share logs: each worktree has its own `_logs/`, cleared weekly.

## Process notes (Build)

- Unit-queue doors start with `--door` (not only `--job`) so the queue is armed.
- Follow the start-card ORDER: load/import check, baseline shot, restate, questions, then edit.
- Prefer `code_map.py row` and targeted `show_func` / `list_xref` over open-ended searches.
- Normalize fancy punctuation (curly quotes, ellipses) in lore lines on first data pass, or document the encoding.
- Keep the ledger tight: one xref per shared script, list every other screen that uses it.
- Surface art-survey items (frame, portrait, refs) in the initial restate so the draw-new vs reuse decision is explicit.
- Use `--handoff` for a survey that never implemented, not `--next`.
- Visual review: `grok-build.md` Pictures rule.

## Session close (hard rules)
- A session never moves on to another task.
- After Complete (done notice: prove folder shown, playtest confirmation required, recommended, or not needed; not a question): stop. Unfinished or red-gated work keeps its handoff notes in the same task file (status, what remains, rough edges, prove paths); that task is reopened next session.
