# Build job cycle

Status: protocol
Read when: Grok Build gather, change, or prove

For **Grok Build** only. Web / chat and Grok Bot do not load this file.

A **job** is one cycle: Gather, Prepare, Change, Prove, Complete. Report when the work is done.

### Gather

Gather finishes before any change.

1. Read the relevant code and docs. First name a planned gather list (distinct `list_xref` patterns and `show_func` names; add to it when a new system turns up), plus one `docs.py code-map row` per live script. A multi-system job lists every system it touches and reads each one's doc and row. `summarize_scripts`, `list_route` (slice boot) and `list_changed` (git inventory) are not gather. Do not repeat a command with the same args.
2. State the observable outcome that will show the task is done (one line: what the User or the bench will see if the work is correct).
3. Confirm whether the existing tooling or in-game signal can show that outcome. Record what is missing, if anything.
4. For a bug or perf miss: does the repro's output name the cause (a row, phase, or field that points at one cause)? A repro that shows the failure but not its cause is a missing signal; Prepare adds detail to that repro before any fix.

No code changes. No new tools.  
Gather ends in this session. Continue Prepare here. Do not `/fork`, and do not start a fresh session from Gather. Whether Gather also compacts, or the User rewinds to Gather after each change and prove, is not decided. Do not add a compact at the end of Gather on top of the one before Prove.

The session `slice.py open` started holds the shared gather (unit-only material stays out until that unit). The first session on a task, when nothing earlier has changed, starts unit 1 and does not run `find.py changed`. A later session continues gather for earlier sessions' changes (`find.py changed`) and material only that unit needs, then adds its own unit-only material (`shots.py review`, text report only).

### Prepare

If a signal is missing, add the cheapest instrument that provides it, or run the information-gathering pass that does not alter behavior. Gate new instrumentation the same way existing debug logging is gated (runtime check, localhost/web or bench flag only) so shipping builds are unaffected. A tool that would help later tasks is added under `tools.md` rule 5.

If Prepare discovers the task is blocked or needs a design answer, stop and update the task instead of continuing.

### Change

Implement the task using the information and tooling from Gather and Prepare. A fix targets a cause the signal named, not a guess.  
No formal prove yet.

Before the first prove run (or when context is approaching 120–150K): stop for one compact and resume in this same session. Either run the guided compact, or print the keep-list and stop so the User can compact.

/compact keep the restate, the intended observable outcome, the systems and doors read, the files changed this unit, any open questions, and the last RESULT if one exists. Drop raw tool logs and exploratory search results.

Do not `/fork`, do not start a fresh session, and do not use `slice.py start --handoff` or `grok -r <original-session-id> --fork-session` as this handoff. Then proceed to Prove.

### Prove

Final verification that the outcome is met.  
Run the compile check, then (for a visual change) the job’s shot flows and that door’s UI load check, then `gate.py build --batch`.

A red prove allows at most one small corrective edit and one re-run (`tools.md` rule 10). Still red: stop and report the log path. Do not open a new diagnostic cycle inside the prove.

### Complete

Update docs and the task.  
- If done: close the task (`docs.py task done ID`).  
- If not: update the task with what was tried, what the prove showed, and where to resume.

Commit and push (`slice.py commit` then plain `git push` to the week branch), then stop. The next session is one the User opens. It starts with the command its first message names. It does not `/fork`.

A session finishes the whole request when it fits; a unit queue records the rest (`--unit-done`) only when it cannot.

A **slice** is one Grok worktree cut from the week branch `grok-build-w{N}`. The User starts it with `python tools/slice.py open [AREA]`, which creates the worktree and launches a NEW session in it (full clone under `.grok/worktrees/<repo>/<name>`, HEAD the week branch). Gather through Complete run there. Before the first prove, one compact, then resume in that same session. First commands follow `grok-build.md` Work. `slice.py start` prints the rules and slice status. Do not edit the main checkout. A worktree the User already named is the slice. **Only `slice.py open` (User-run) launches grok; Build never does** (no fork, headless, `--prompt-file`, or `--max-turns`; isolated-media is the exception).

**Restate first.** The start card has the order. The open session: import, the shared restate as visible text, Q0, then the other questions. A later session gathers this unit's baseline (`shots.py review` on those frames only) and earlier sessions' changes (`find.py changed`). A baseline with `band=fail` or script errors is invalid: find the cause, re-shoot, and never use it as the "before" shot or call its errors pre-existing without proof. A word the User used (a name, a metaphor) is not yet an answer to what it means here. Until answered change nothing, except shot-flow files (`tools/data/shot-flows/`) and the `routes.yaml` mapping. A task file whose Open questions are none already answered Q0, and a job the card marks NO PLAY CAMERA is not waiting on a play-camera baseline.

**Every stop-and-ask message** is built as the card says (message first, every ask, ledger, `Did not work`). Details: a new asset, font, dependency or generated image is named with its alternative and size; a generated image gets the one-line User confirm of Access (below) before use; a font or asset must work in the web export, or say so.

**Step 0, a missing shot flow.** `slice.py start` prints a STEP 0 note for a visual job with no flow mapped to it (exit 0; not a stop). Creating or adjusting the flow for the exact screen is the first job step (`shot-flows.md`, New UI state checklist); a job never borrows its door's flows as if they were its own. The end gates stay: the after-shot must exist and be opened, no missing or stale frame, and a new uncovered UI state needs a flow before the prove passes.

**Visual unit.** A job the start card marks NO PLAY CAMERA is not one of these: no play-camera baseline, no new shot flow, no `--visual` on the gate. Its proof is the check the job doc names (a keyed still: `media.py rekey-preview`). A screen's baseline is gathered in the session changing that screen (`shots.py flow --flow N --state S` or `--job J`; `--save-baseline DIR` keeps it), then `shots.py review` on those frames only. Do not `read_file` them. Change one unit or screen. Re-shoot one state with `shots.py flow --flow N --state NAME`. Pixel questions use `shots.py crop` / `--probe` / `--near`, not a custom script. Shoot after, compare before and after, `shots.py show` opens them, say what is on each. Iterating one unit with the User is exempt from rerun counts (`tools.md` rule 10). Green prove is not a visual pass: describe the wide play-camera shot cold first, compare with the last approved round and main, report what you saw.

**Compile check.** Run `python tools/gate.py gd-load` once the edits for the unit are complete (before Prove). It loads every changed and untracked `.gd` inside the project with its autoloads, so a stray `)` or a bad reference fails. The import check, a smoke and a standalone `--script` parse do not load every script, so none of them is evidence that the scripts compile.

**Read what you run:** `prove.md` Proof rules.

Commit, without waiting for a yes, with `python tools/slice.py commit`: it needs a passing `gate.py build --batch --visual JOB` after your last edit and prints the lines for the message; a gate you did not run is said in the final message (`Did not work: gate not run (why)`, `--gate-skipped`); a gate still red at Complete commits with `--red-gate LOGPATH` (marked `RED GATE:`; its `Red gate:` line opens the done notice). At Prove, a visual change's shot flows run as `shots.py flow --job J` (one call; flows another picked flow covers are skipped; shown and described), or `--visual JOB` on the gate adds them in the same call. Do not import, then smoke, then import.

Smokes at prove: the phases mapped to the door or job in `routes.yaml` `smokes` (printed by `list_route` and `start_build_slice`; `gate.py smokes --door D` or `--job door.job` runs them). A system the slice implements or changes gets its asserts updated in the mapped phase helper (`debug-smokes.md`), or a new assert there, in the same change job. Unit runners (run the runner; do not open smoke helpers just to pick the command):

| Unit | Runner |
|------|--------|
| floor map / gen silhouette / placement specs | `tools/perf.py map` `--seed 42 --floor 1` |
| Placeholdia to dungeon timing | `tools/perf.py load --leg dungeon` |
| named phase asserts | `tools/gate.py smokes` `--door D` / `--job door.job` / `--phases N` |
| changed `.gd` load with autoloads (end of Change) | `tools/gate.py gd-load` (`--files`, `--all`, `--base REF`) |
| import + load graph + names / unnamed prove | `tools/gate.py build` |
| exported web build load, frame time, heap, asset sizes (advisory) | `tools/perf.py web` (`--flow`, `--baseline`) after `release.py export-web --out DIR` (`--site DIR`, baseline `tools/data/web-perf-baseline.json`) |

A new numbered phase, `--wdb-*-smoke` flag, or host scene is allowed only when the feature is new and no mapped phase fits (add it with the feature; name it in the report). A new catalog runner is fine when it would reasonably help future tasks (`tools.md` rule 5). A postcard or shot flow (`shot-tool.md`) is a deliverable or a visual check, not the build gate or a smoke; the headless flow asserts (`gate.py bot-smokes --flows`) may be named in the prove step. When a task needs a picture the tool cannot stage, extend the tool inside the change job (`shot-flows.md` gap process); do not hand-drive Godot or edit a PNG. A red postcard (`fail` band) follows the same-command rerun rule below; otherwise fix the tool or script.

## New feature flow

1. Owner: `python tools/find.py route --door <door>`. No door or doc owns it (or it needs a second door) = a new system: plan it (door, doc name, save keys, entry events, smokes), ask every open question, again as answers raise more; wait.
2. Design doc first: write or extend the owning topic via `tools/docs.py patch`, then implement.
3. Prove, matched to the change (`prove.md`): `gate.py gd-load` each pass; a visual change adds its `shot_flows` (`shots.py gaps --changed` failing fails the prove).
4. Ship notes: `docs.py code-map patch` for touched live scripts, `tunables.md` for any number. Any edit of a design doc, the agents file, or `BOT.md` runs `check.py load-graph` before the change is reported done. RESULT PASS is required. It is not deferred to ship. No changelog files from Build (commit message: `versioning.md`).

## Survey, then a fresh session

A survey of several surfaces reads widely, and every later call re-reads that context. So it ends at her answers to its first ask, and a fresh session implements:

1. Survey from text: `python tools/shots.py flow --survey` (a line per flow: about, states, last shot, band); `python tools/find.py route --digest --door D` for several jobs. Open pictures only for the group or unit being compared. `shots.py flow --sheet FLOW` tiles one flow's frames into a labeled sheet; fine text is not readable on it.
2. Send the survey message and ask (Q0, then which group, order and wants). A baseline a survey does not shoot is not a `Did not work` item.
3. After her answers: `python tools/slice.py start --handoff [--task ID]` writes the task file `ID.md` in `design/tasks/` (default ID: the door; rules: `design/tasks/README.md`). Fill every `<fill>` line: done-when, task in her words, Q0 answers, her decisions, chosen surfaces in order, the ledger lists, baselines for the chosen surface (absolute PNG path and a line on what is on it), files and functions to touch, Did-not-work items, open questions. Run `--handoff` again: it validates, saves the task file and the survey's shot-flow and `routes.yaml` edits for the fresh session, and prints the command she runs from the main checkout: `python tools/slice.py open AREA --prompt-file PATH`. This session then stops.
4. The fresh session's first command is `slice.py start --door D --from-handoff PATH`: a compact start summary, the saved edits put back, and the baselines to open (those only). It points the task's first command at `--from-task ID` (a later session the User opens with the task's `resume:` line starts there); commit the task file with the first unit, so any later session resumes with `slice.py start --door D --from-task ID`. `--unit-done` keeps `done:` current and compacts the task; the commit that finishes the task runs `docs.py task done ID`. It does not re-run the survey. Answers in the handoff stand; it asks about the open questions and what a discovery changes.

One surface or a small change needs no handoff: continue in place. A heavy context uses the compact before Prove and resumes in the same session. A survey handoff is only for a survey that never implemented. A retry stays in the session that ran the prove.

## Reading habits

- Route first: the route card's read list, not sibling docs. A script of the system being edited: `find.py func`, not the whole file; an edited file is not re-read in full. A search: `find.py xref` (an index; `--expand FILE`), never a repo-root `list_dir` (`find.py route` lists the doors).
- Another session's memory `_inbox` files are not read.
- Shared tool changes get a `list_xref` listing under "Also changed".

## Permissions

Access (permission, not design): something outside Build's normal reach (a new asset location, a generated image, an external tool or network, files outside the allowed set) gets a one-line User confirm first. Just do: a named script rename/move (`lint.py move --dry-run`, then run), helpers and APIs inside one system (`refactor.md`), a tool that would help later (`tools.md` rule 5; tell the User). Ask first: a cross-system owner, a named live-module replace, a greenfield rewrite, archive scenes copied over live.

## Next-session brief

Lean: the task in her words; where the last result and its handoff notes live (commit, docs); the first command (`grok-build.md` Work), stated first; Q0 first; baselines expected. A survey handoff file is such a brief.

## Red prove and merge-back

**Retry** (`tools.md` rule 10: one small corrective edit, one re-run). The session that ran the prove does the retry. It does not `/fork` and it does not run `grok -r <original-session-id> --fork-session`. A red prove prints a RETRY block: which prove failed, the red output in a line or two, the files in `git diff grok-build-w{N}` (working tree, so uncommitted edits show; untracked files are listed too) to look at first, and the ask for one small corrective edit. Read only the changed files, diagnose once, fix once and rerun once. Still red: stop and report. The worktree's git history holds the code.

**Merge-back** (green prove, or red with `--red-gate`). A Grok worktree is a full clone on the week branch itself: commit there, then `git push origin grok-build-w{N}` (plain push, no force, never main); there is no separate commit to merge by hand, and the main checkout pulls it. Put a short note in the commit message (a file under the worktree's `_logs/`, `git commit -F`); resolve conflicts yourself. Do not wait for approval before the commit or the push. After the push: the done notice (`grok-build.md` Finish a unit).

Read each job summary once via `session.py summary --job <name>` (index first, newest run). A slice of that file or a JSONL log uses `--section`, `--match`, or `--jsonl --where key=eq:VALUE` (PowerShell compares: `key=ge:N`, never an unquoted `>`). A `.jsonl` path with no filter is refused. Do not open summary files directly.

A same-command rerun is valid only for `truncated`, timeout, crash, `busy` lock, or wrong scene, and then the same command once. A follow-up job with a new field named from a summary key does not need a User wait; questions still follow the rules above.

Proof recipes by change kind: `prove.md`. A proof that needs a check no tool does: extend the library (`imglib`, shot tools) in the change job and add the recipe there; do not work around it.

Concurrent agents share catalog tools. They do not share logs: each worktree has its own `_logs/`, cleared weekly.

## Process notes (Build)

- Unit-queue doors start with `--door` (not only `--job`) so the queue is armed.
- Follow the start-card ORDER: load/import check, shared restate, questions, then Prepare in this session. Before the first prove, one compact and resume here.
- Prefer `docs.py code-map row` and targeted `show_func` / `list_xref` over open-ended searches.
- Normalize fancy punctuation (curly quotes, ellipses) in lore lines on first data pass, or document the encoding.
- Keep the ledger tight: one xref per shared script, list every other screen that uses it.
- Surface art-survey items (frame, portrait, refs) in the initial restate so the draw-new vs reuse decision is explicit.
- Use `--handoff` for a survey that never implemented, not `--next`.
- Visual review: `grok-build.md` Pictures rule.

## Session close (hard rules)
- A session never moves on to another task.
- After Complete (done notice: prove folder shown, playtest confirmation required, recommended, or not needed; not a question): stop. Unfinished or red-gated work keeps its handoff notes in the same task file (status, what remains, rough edges, prove paths); that task is reopened next session.
